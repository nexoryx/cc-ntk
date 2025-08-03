-- internal helper functions
function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
        copy[deepCopy(key)] = deepCopy(value)
    end
    return copy
end

function subInString(mainString, subString, start)
	local send = start + string.len(subString)
	local tempString = ""
	if start ~= 1 then
		tempString = string.sub(mainString, 1, start - 1)
	end
	tempString = tempString .. subString
	if send < string.len(mainString) then
		tempString = tempString .. string.sub(mainString, send, string.len(mainString))
	end
	return tempString
end

local function ripairs(t)
    local i = #t + 1
    return function()
        i = i - 1
        if i > 0 then
            return i, t[i]
        end
    end
end

-- start exported
local ntk = {}

local screens = {}
local renderUpdate = false

local elements = {}
local elementOrder = {}

function nextElementId()
	for i,v in pairs(elements) do
		if v == nil then
			return i
		end
	end
	return table.getn(elements) + 1
end

function ntk.addElement(screen, x, y, width, height, color, background)
	screen = screen or "term"
	x = x or 1
	y = y or 1
	width = width or 1
	height = height or 1
	color = color or "0"
	background = background or "7"
	local eid = nextElementId()
	elements[eid] = {
		screen = screen,
		x = x,
		y = y,
		width = width,
		height = height,
		color = color,
		background = background,
		type = "none",
		hide = false,
		blocked = false,
		value = nil,
		frame = {},
		parent = 0,
		offsetx = 0,
		offsety = 0,
		children = {},
		clickFunc = nil,
		enterFunc = nil,
		keyUpFunc = nil,
		keyDownFunc = nil,

	}
	table.insert(elementOrder, eid)
	return eid
end

function removeWithChildren(eid)
	for i,v in ripairs(elementOrder) do
		if v == eid then
			table.remove(elementOrder, i)
		end
	end
	local toRemove = deepCopy(elements[eid].children)
	if table.getn(toRemove) > 0 then
		for i,v in ipairs(toRemove) do
			ntk.removeElement(v)
		end
	end
	elements[eid] = nil
end

function ntk.removeElement(eid)
	if elements[eid] then
		if elements[eid].parent then
			local parent = elements[elements[eid].parent]
			ntk.removeElementChild(elements[eid].parent, eid)
		end
		removeWithChildren(eid)
		renderUpdate = true
		return true
	end
	return true
end

function ntk.addElementChild(eid, childid)
	if elements[eid] and elements[childid] then
		table.insert(elements[eid].children, childid)
		elements[childid].parent = eid
		elements[childid].offsetx = elements[eid].x - elements[childid].x
		elements[childid].offsety = elements[eid].y - elements[childid].y
		setElementBlock(childid, elements[eid].hide or elements[eid].blocked)
		renderUpdate = true
		return true
	end
	return false
end

function ntk.removeElementChild(eid, childid)
	if elements[eid] then
		local element = elements[eid]
		for i,v in ipairs(element.children) do
			if v == childid then
				if elements[childid] then
					local child = elements[childid]
					child.parent = 0
					child.offsetx = 0
					child.offsety = 0
				end
				table.remove(element.children, i)
			end
		end
	end
end


-- element getters
function ntk.getElementScreen(eid)
	if elements[eid] then
		return elements[eid].screen
	end
	return nil
end

function ntk.getElementPos(eid)
	if elements[eid] then
		return elements[eid].x, elements[eid].y
	end
	return nil, nil
end

function ntk.getElementSize(eid)
	if elements[eid] then
		return elements[eid].width, elements[eid].height
	end
	return nil, nil
end

function ntk.getElementColor(eid)
	if elements[eid] then
		return elements[eid].color
	end
	return nil
end

function ntk.getElementBackground(eid)
	if elements[eid] then
		return elements[eid].background
	end
	return nil
end

function ntk.getElementType(eid)
	if elements[eid] then
		return elements[eid].type
	end
	return nil
end

function ntk.getElementHide(eid)
	if elements[eid] then
		return elements[eid].hide
	end
	return nil
end

function ntk.getElementBlocked(eid)
	if elements[eid] then
		if elements[eid].hide or elements[eid].blocked then
			return true
		else
			return false
		end
	end
	return nil
end

function ntk.getElementValue(eid)
	if elements[eid] then
		return elements[eid].value
	end
	return nil
end

function ntk.getElementFrame(eid)
	if elements[eid] then
		return elements[eid].frame
	end
	return nil
end

function ntk.getElementParent(eid)
	if elements[eid] and elements[eid].parent ~= 0 then
		return elements[eid].parent
	end
	return nil
end

function ntk.getElementParentOffset(eid)
	if elements[eid] then
		return elements[eid].offsetx, elements[eid].offsety
	end
	return nil
end

function ntk.getElementChildren(eid)
	if elements[eid] and table.getn(elements[eid].children) > 0 then
		return elements[eid].children
	end
	return nil
end

function ntk.getElementClickFunc(eid)
	if elements[eid] and elements[eid].clickFunc then
		return elements[eid].clickFunc
	end
	return nil
end

function ntk.getElementEnterFunc(eid)
	if elements[eid] and elements[eid].enterFunc then
		return elements[eid].enterFunc
	end
	return nil
end

function ntk.getElementKeyDownFunc(eid)
	if elements[eid] and elements[eid].keyDownFunc then
		return elements[eid].keyDownFunc
	end
	return nil
end

function ntk.getElementKeyUpFunc(eid)
	if elements[eid] and elements[eid].keyUpFunc then
		return elements[eid].keyUpFunc
	end
	return nil
end


-- element setters
function ntk.setElementScreen(eid, screen)
	if elements[eid] and screens[screen] then
		elements[eid].screen = screen
		for i,v in ipairs(elements[eid].children) do
			ntk.setElementScreen(v, screen)
		end
		renderUpdate = true
		return true
	end
	return false
end

function ntk.setElementSize(eid, width, height)
	if elements[eid] then
		local deltax = elements[eid].width - width
		local deltay = elements[eid].height - height
		elements[eid].width = width
		elements[eid].height = height
		for i,v in ipairs(elements[eid].children) do
			ntk.setElementSize(v, elements[v].width - deltax, elements[v].height - deltay)
		end
		updateElementContent(eid)
		return true
	end
	return false
end

function ntk.setElementPos(eid, x, y)
	if elements[eid] then
		elements[eid].x = x
		elements[eid].y = y
		for i,v in ipairs(elements[eid].children) do
			ntk.setElementPos(v, x + elements[v].offsetx, y + elements[v].offsety)
		end
		renderUpdate = true
		return true
	end
	return false
end

function ntk.setElementColor(eid, color)
	if elements[eid] then
		elements[eid].color = color
		updateElementContent(eid)
		return true
	end
	return false
end

function ntk.setElementBackground(eid, background)
	if elements[eid] then
		elements[eid].background = background
		updateElementContent(eid)
		return true
	end
	return false
end

function ntk.setElementType(eid, type)
	if elements[eid] then
		elements[eid].type = string.lower(type)
		updateElementContent(eid)
		return true
	end
	return false
end

function setElementBlock(eid, state)
	if elements[eid] then
		elements[eid].blocked = state
		for i,v in ipairs(elements[eid].children) do
			setElementBlock(v, elements[eid].hide or state)
		end
	end
end

function ntk.setElementHide(eid, state)
	if elements[eid] then
		elements[eid].hide = state
		for i,v in ipairs(elements[eid].children) do
			setElementBlock(v, state)
		end
		renderUpdate = true
		return true
	end
	return false
end

function ntk.setElementFrame(eid, frame)
	if elements[eid] then
		elements[eid].frame = frame
		renderUpdate = true
		return true
	end
	return false
end

function ntk.setElementValue(eid, value)
	if elements[eid] then
		elements[eid].value = value
		updateElementContent(eid)
		return true
	end
	return false
end

function ntk.setElementParentOffset(eid, offsetx, offsety)
	if elements[eid] then
		elements[eid].offsetx = offsetx
		elements[eid].offsety = offsety
		updateElementContent(eid)
		return true
	end
	return false
end

function ntk.setElementClickFunc(eid, clickFunc)
	if elements[eid] and type(clickFunc) == "function" then
		elements[eid].clickFunc = clickFunc
		return true
	end
	return false
end

function ntk.setElementEnterFunc(eid, enterFunc)
	if elements[eid] and type(enterFunc) == "function" then
		elements[eid].enterFunc = enterFunc
		return true
	end
	return false
end

function ntk.setElementKeyDownFunc(eid, keyDownFunc)
	if elements[eid] and type(keyDownFunc) == "function" then
		elements[eid].keyDownFunc = keyDownFunc
		return true
	end
	return false
end

function ntk.setElementKeyUpFunc(eid, keyUpFunc)
	if elements[eid] and type(keyUpFunc) == "function" then
		elements[eid].keyUpFunc = keyUpFunc
		return true
	end
	return false
end


-- element removers
function ntk.removeElementClickFunc(eid)
	if elements[eid] then
		elements[eid].clickFunc = nil
		return true
	end
	return false
end

function ntk.removeElementEnterFunc(eid)
	if elements[eid] then
		elements[eid].enterFunc = nil
		return true
	end
	return false
end

function ntk.removeElementKeyDownFunc(eid)
	if elements[eid] then
		elements[eid].keyDownFunc = nil
		return true
	end
	return false
end

function ntk.removeElementKeyUpFunc(eid)
	if elements[eid] then
		elements[eid].keyUpFunc = nil
		return true
	end
	return false
end


-- element helpers
function ntk.moveElement(eid, x, y)
	if elements[eid] then
		x = elements[eid].x + x
		y = elements[eid].y + y
		ntk.setElementPos(eid, x, y)
		return true
	end
	return false
end

function ntk.elementBringToFront(eid)
	if elements[eid] then
		local element = elements[eid]
		for i,v in ipairs(elementOrder) do
			if v == eid then
				table.remove(elementOrder, i)
				table.insert(elementOrder, eid)
			end
		end
		for i,v in ipairs(element.children) do
			ntk.elementBringToFront(v)
		end
		return true
	end
	return false
end

-- toolkit make functions
function ntk.makeText(screen, x, y, text, color, background)
	local width = string.len(text)
	local textElement = ntk.addElement(screen, x, y, width, 1, color, background)
	ntk.setElementType(textElement, "text")
	ntk.setElementValue(textElement, text)
	return textElement
end

function ntk.makeTextBox(screen, x, y, width, color, background)
	local textBoxElement = ntk.addElement(screen, x, y, width, 1, color, background)
	ntk.setElementType(textBoxElement, "textbox")
	return textBoxElement
end

function ntk.makeCheckBox(screen, x, y, color, background)
	local checkBoxElement = ntk.addElement(screen, x, y, 3, 1, color, background)
	ntk.setElementType(checkBoxElement, "checkbox")
	ntk.setElementValue(checkBoxElement, false)
	function toggleCheckbox()
		checkBoxElement.value = not checkBoxElement.value
	end
	ntk.setElementClickFunc(checkBoxElement, toggleCheckbox)
	return checkBoxElement
end

function ntk.makePercent(screen, x, y, width, color, background)
	local percentElement = ntk.addElement(screen, x, y, width, 1, color, background)
	ntk.setElementType(percentElement, "percent")
	ntk.setElementValue(percentElement, 0)
	return percentElement
end

function ntk.makeLabel(screen, x, y, text, color, background, padt, padr, padb, padl)
	padt = padt or 1
	padr = padr or 1
	padb = padb or 1
	padl = padl or 1
	local width = padl + string.len(text) + padr
	local height = padt + 1 + padb
	local labelElement = ntk.addElement(screen, x, y, width, height, color, background)
	ntk.setElementType(labelElement, "fill")
	local textElement = ntk.makeText(screen, x + padl, y + padt, text, color, background)
	ntk.addElementChild(labelElement, textElement)
	return labelElement
end

function ntk.makeButton(screen, x, y, text, clickFunc, color, background, padt, padr, padb, padl)
	padt = padt or 0
	padr = padr or 0
	padb = padb or 0
	padl = padl or 0
	local labelElement = ntk.makeLabel(screen, x, y, text, color, background, padt, padr, padb, padl)
	ntk.setElementClickFunc(labelElement, clickFunc)
	return labelElement
end

function ntk.makeYNPrompt(screen, x, y, width, height, text, yesFunc, noFunc, color1, background1, color2, background2, padx, pady)
	color1 = color1 or "f"
	background1 = background1 or "8"
	color2 = color2 or "0"
	background2 = background2 or "7"
	padx = padx or 1
	pady = pady or 1
	local promptElement = ntk.addElement(screen, x, y, width, height, color1, background1)
	ntk.setElementType(promptElement, "fill")
	local textElement = ntk.makeText(screen, x + padx, y + pady, text, color1, background1)
	ntk.addElementChild(promptElement, textElement)
	function noIntercept()
		ntk.removeElement(promptElement)
		noFunc()
	end
	local noButtonElement = ntk.makeButton(screen, (x + width) - padx - 3, (y + height) - pady - 1, "No", noIntercept, color2, background2, 0, 1)
	ntk.addElementChild(promptElement, noButtonElement)
	function yesIntercept()
		ntk.removeElement(promptElement)
		yesFunc()
	end
	local yesButtonElement = ntk.makeButton(screen, x + padx, (y + height) - pady - 1, "Yes", yesIntercept, color2, background2)
	ntk.addElementChild(promptElement, yesButtonElement)
	return promptElement
end

function ntk.makeTextPrompt(screen, x, y, width, height, text, yesFunc, noFunc, color1, background1, color2, background2, color3, background3, padx, pady)
	color1 = color1 or "f"
	background1 = background1 or "8"
	color2 = color2 or "0"
	background2 = background2 or "7"
	padx = padx or 1
	pady = pady or 1
	local promptElement = ntk.addElement(screen, x, y, width, height, color1, background1)
	ntk.setElementType(promptElement, "fill")
	local textElement = ntk.makeText(screen, x + padx, y + pady, text, color1, background1)
	ntk.addElementChild(promptElement, textElement)
	local textBoxElement = ntk.makeTextBox(screen, x + padx, (y + height) - (pady * 2) - 2, width - (padx * 2), 1, color3, background3)
	ntk.addElementChild(promptElement, textBoxElement)
	function noIntercept()
		ntk.removeElement(promptElement)
		noFunc()
	end
	local noButtonElement = ntk.makeButton(screen, (x + width) - padx - 6, (y + height) - pady - 1, "Cancel", noIntercept, color2, background2)
	ntk.addElementChild(promptElement, noButtonElement)
	function yesIntercept()
		local value = ntk.getElementValue(textBoxElement)
		ntk.removeElement(promptElement)
		yesFunc(value)
	end
	ntk.setElementEnterFunc(textBoxElement, yesIntercept)
	local yesButtonElement = ntk.makeButton(screen, x + padx, (y + height) - pady - 1, "OK", yesIntercept, color2, background2, 0, 1)
	ntk.addElementChild(promptElement, yesButtonElement)
	return promptElement
end


-- handlers
local activeElement = 0
function handleChar(char)
	if activeElement ~= 0 and elements[activeElement] then
		local element = elements[activeElement]
		if element.type == "textbox" then
			if not element.value then
				element.value = ""
			end
			ntk.setElementValue(activeElement, element.value .. char)
		end
	end
end

function handleKeyDown(keyCode)
	if activeElement ~= 0 and elements[activeElement] then
		local element = elements[activeElement]
		if type(element.keyDownFunc) == "function" then
			element.keyDownFunc(keyCode)
		end
	end
end

function handleKeyUp(keyCode)
	if activeElement ~= 0 and elements[activeElement] then
		local element = elements[activeElement]
		if type(element.keyUpFunc) == "function" then
			element.keyUpFunc(keyCode)
		end
		if keyCode == keys.enter then
			if type(element.enterFunc) == "function" then
				element.enterFunc()
			end
		end
	end
end

function clickAllParents(eid)
	local element = elements[eid]
	if element.clickFunc then
		element.clickFunc()
	end
	if element.parent ~= 0 then
		clickAllParents(element.parent)
	end
end

function handleClick(screen, x, y)
	for i,v in ripairs(elementOrder) do
		local element = elements[v]
		if element.screen == screen and not element.hide and not element.blocked and
		   x+1 >= element.x and x+1 < element.x + element.width and
		   y+1 > element.y and y+1 <= element.y + element.height then
		   	activeElement = v
		   	if element.type == "checkbox" then
		   		if element.value then
		   			element.value = false
		   		else
		   			element.value = true
		   		end
		   	end
		   	clickAllParents(v)
			return
		end
	end
	activeElement = 0
end


-- Buffer Management
function clearBuffer(screen)
	screens[screen].renderedFrame = {}
	for i=1,screens[screen].y do
		local tempData = ""
		local tempColor = ""
		local tempBackground = ""
		for j=1,screens[screen].x do
			tempData = tempData .. " "
			tempColor = tempColor .. "0"
			tempBackground = tempBackground .. "f"
		end
		local tempRow = {
			d = tempData,
			c = tempColor,
			b = tempBackground,
			r = true
		}
		table.insert(screens[screen].renderedFrame, tempRow)
		screens[screen].frameUpdate = true
	end
end

function drawFrameToBuffer(screen, frame, x, y, af)
	local offsetWidth = frame.width
	if af then
		frame = frame[af]
	else
		frame = frame[1]
	end
	if x + offsetWidth > screens[screen].x then
		offsetWidth = offsetWidth - ((x + offsetWidth) - screens[screen].x)
	end
	for i,v in ipairs(frame) do
		local row = screens[screen].renderedFrame[(y + i) - 1]
		if row then
			local tempd = string.sub(v.d, 1, offsetWidth)
			row.d = subInString(row.d, tempd, x)
			local tempc = string.sub(v.c, 1, offsetWidth)
			row.c = subInString(row.c, tempc, x)
			local tempb = string.sub(v.b, 1, offsetWidth)
			row.b = subInString(row.b, tempb, x)
			row.r = true
		end
	end
end


-- core functions
function makeBlankFrame(eid)
	local element = elements[eid]
	element.frame = {
		height = element.height,
		width = element.width,
		animation = false,
		aftime = 0,
		[1] = {}
	}
	for i=1,element.height do
		local tempData = ""
		local tempColor = ""
		local tempBackground = ""
		for j=1,element.width do
			tempData = tempData .. " "
			tempColor = tempColor .. element.color
			tempBackground = tempBackground .. element.background
		end
		local tempRow = {
			d = tempData,
			c = tempColor,
			b = tempBackground
		}
		table.insert(element.frame[1], tempRow)
	end
end

function writeTextToFrame(eid, value)
	local element = elements[eid]
	local lines = {}
    local line = ""
   	for i = 1, string.len(value) do
   		line = line .. string.sub(value, i, i)

   		if i % element.width == 0 then
   			table.insert(lines, line)
   			line = ""
   		end
    end
    if line ~= "" then
    	table.insert(lines, line)
    end
    local linecount = table.getn(lines)
    if linecount > element.height then
    	for i = linecount, (element.height + 1), -1 do
    		lines[i] = nil
    	end
    	lines[(element.height)] = string.sub(lines[element.height], 1, (element.width - 3)) .. "..."
    end
    for i,v in ipairs(lines) do
    	local newD = ""
    	newD = newD .. v
    	if string.len(newD) < element.width then
    		for i=1,element.width - string.len(newD) do
    			newD = newD .. " "
    		end
    	end
    	element.frame[1][i].d = newD
    end
end

function updateElementContent(eid)
	local element = elements[eid]
	element.frame = {}
	if element.type == "fill" then
		makeBlankFrame(eid)
	elseif element.type == "text" or element.type == "textbox" then
		makeBlankFrame(eid)
		if element.value then
			writeTextToFrame(eid, element.value)
		end
	elseif element.type == "checkbox" then
		makeBlankFrame(eid)
		local boxText = "["
		if element.value then
			boxText = boxText .. string.char(7)
		else
			boxText = boxText .. " "
		end
		boxText = boxText .. "]"
		writeTextToFrame(eid, boxText)
	elseif element.type == "percent" then
		makeBlankFrame(eid)
		if element.value then
			if element.width ~= 3 then
				element.width = 3
			end
			local barText = ""
			for i=1,3 do
				if element.value * element.width < i then
					barText = barText .. string.char(143)
				else
					barText = barText .. " "
				end
			end
			writeTextToFrame(eid, barText)
		end
	end
	renderUpdate = true
end

function ntk.init(screensList)
	screens = {}
	elements = {}
	elementOrder = {}
	for i,s in ipairs(screensList) do
		local screen = false
		if s == "term" then
			screen = term
		else
			screen = peripheral.wrap(s)
		end
		if screen then
			screens[s] = {}
			screens[s].screen = screen
			screens[s].frameUpdate = true
			screens[s].x, screens[s].y = screen.getSize()
			screens[s].renderedFrame = {}
			clearBuffer(s)
		end
	end
end

function ntk.tick(event, e1, e2, e3, e4)
	if event == "frametimer" then
		if renderUpdate then
			for _,v in ipairs(elementOrder) do
				local element = elements[v]
				if not element.hide and not element.blocked then
					drawFrameToBuffer(element.screen, element.frame, element.x, element.y)
					screens[element.screen].frameUpdate = true
				end
			end
			renderUpdate = false
		end
		for s,v in pairs(screens) do
			if v.frameUpdate then
				v.frameUpdate = false
				for i,r in ipairs(v.renderedFrame) do
					if r.r then
						v.screen.setCursorPos(1, i)
						v.screen.blit(r.d, r.c, r.b)
						r.r = false
					end
				end
			end
		end
	elseif event == "monitor_touch" then
        handleClick(e1, e2, e3)
    elseif event == "mouse_click" and e1 == 1 then
        handleClick("term", e2, e3)
    elseif event == "char" then
    	handleChar(e1)
    elseif event == "key" then
    	handleKeyDown(e1)
	elseif event == "key_up" then
		handleKeyUp(e1)
	end
end

return ntk