local socket = require("socket")
local tableSerialization = require("tableSerialization") --file we make to serialize the dice tables
tcp = socket.tcp()
tcp:settimeout(30)
io.stdout:setvbuf("no")
connection = tcp:connect("192.168.1.116", 8080) --147.219.7292
if connection then 
	print("Connected to Host")
	tcp:settimeout(0)
	else print("Didn't connect for some reason") end

--game below
function love.load()
	--server stuff
	tableSerialization.register()
	receivedTables = {}
	--making an hsl number that can be used for color picking and clientID
	local seed = string.match(tostring(os.clock()), "%d%.(%d+)")
	math.randomseed(seed)
	local ht = math.random(0, 359) --> the color spectrum
	ht = string.format("%03d", ht)
	local st = math.random(50, 99)
	local vt = math.random(60, 99)
	local tempID = tostring(ht) .. tostring(st) .. tostring(vt) --> concatenate numbers
	clientID = tonumber(tempID) --> turn back into number
	print(clientID)
	
	--game shader
	multiplyShaderCode = [[
	    extern Image image;
	    extern vec3 colorMultiplier;

	    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	        vec4 pixel = Texel(texture, texture_coords);
	        pixel.rgb *= colorMultiplier;
	        return pixel * color;
	    }
	]]
	multiplyShader = love.graphics.newShader(multiplyShaderCode)
	colorMultiplier = {1.0, 1.0, 1.0} --white
	multiplyShader:send("colorMultiplier", colorMultiplier)

	--game init below
	startScreen = true
	selectedDiceIndex = nil
	offsetX, offsetY = 0, 0
	allDice = {}
	numDice = 0
	randPosTable = {}

	images = {}
	for nameIndex, name in ipairs({'pip', 'face', 'start', 'play', 'instructions'}) do
		images[name] = love.graphics.newImage('images/'..name..'.png')
	end

	function clearDice(tbl)
		if tbl ~= nil then
			for k in ipairs(tbl) do
				tbl [k] = nil
			end
		end
	end

	function rollDice()
		for i = 1, numDice do
			table.insert(randPosTable, {pipNum = love.math.random(6), 
			randX = love.math.random(600), 
			randY = love.math.random(100, 500), 
			randR = love.math.random(-15, 15)})
		end
	end
end

--update
function love.update(dt)
	--network stuff for client
	local receivedData, partialData = tcp:receive("*l")
	if receivedData ~= nil then
		--print("RecievedData: " .. receivedData)
		local incomingData = tableSerialization.deserialize(receivedData)
		local newClientID = incomingData.id 
		local newDiceTable = incomingData.dice
		--print("newClientID: ".. newClientID .. " newDiceTable: ", unpack(newDiceTable))
		
		--find existing table of clientID
		local currentTable = nil
		for _, data in ipairs(receivedTables) do 
			if data.id == newClientID then
				currentTable = data 
				break
			end
		end
		--replace the existing table with new table
		if currentTable then
			currentTable.dice = newDiceTable
		else
			table.insert(receivedTables, {id = newClientID, dice = newDiceTable})
		end
	end
	--move a dice that is being dragged
	if selectedDiceIndex ~= nil then
		local axis = randPosTable[selectedDiceIndex]
		axis.randX = love.mouse.getX() - offsetX
		axis.randY = love.mouse.getY() - offsetY
	end
end

--draw the screen
function love.draw()
	local function textDraw(thisImage, offsetY)
		local width, height = love.graphics.getDimensions()
		width = width / 2 - thisImage:getWidth() / 2
		height = height /2 - thisImage:getHeight() / 2
		love.graphics.draw(thisImage, width, height + offsetY)
	end
	local function displayStartScreen()
		love.graphics.setBackgroundColor(1,1,1)
		textDraw(images.start, 0)
		textDraw(images.instructions, 200)
	end

	local function displayPlayScreen()
		textDraw(images.play, 0)
	end

	local function displayDice(pips, x, y, r, color, scale)
		--HSV to RGB
		--convert color to h, s, v values
		local tempColor = tostring(color)
		local h = string.sub(tempColor, 1, 3) 
		local s = string.sub(tempColor, 4, 5)
		local v = string.sub(tempColor, -2) -->last two digits
		h, s, v = tonumber(h), tonumber(s), tonumber(v)
		--print(h .. " " .. s .. " " .. v)
		--function to convert h, s, v to rgb: https://stackoverflow.com/questions/68317097/how-to-properly-convert-hsl-colors-to-rgb-colors-in-lua
		-- HSV to RGB
		min = math.min
		max = math.max
		abs = math.abs

		local function HSV2RGB (h, s, v)
			s = s / 100
			v = v / 100
		    local k1 = v*(1-s)
		    local k2 = v - k1
		    local r = min (max (3*abs (((h      )/180)%2-1)-1, 0), 1)
		    local g = min (max (3*abs (((h  -120)/180)%2-1)-1, 0), 1)
		    local b = min (max (3*abs (((h  +120)/180)%2-1)-1, 0), 1)
		    return k1 + k2 * r, k1 + k2 * g, k1 + k2 * b
		end
		rt, gt, bt = HSV2RGB(h, s, v)
		--print(rt .. " " .. gt .. " " .. bt)
		love.graphics.setColor(rt, gt, bt)

		--draw dice body
		love.graphics.draw(images.face, x, y, math.rad(r), scale, scale)

		--draw pips
		local left = 20
		local right = 84
		local mid = 52

		love.graphics.setColor(1, 1, 1)
		local function drawPip(addX, addY)
			local worldX = x + (math.cos(math.rad(r)) * addX - math.sin(math.rad(r)) * addY) * scale
			local worldY = y + (math.sin(math.rad(r)) * addX + math.cos(math.rad(r)) * addY) * scale
			love.graphics.draw(images.pip, worldX, worldY, math.rad(r), scale, scale)
		end

		if pips == 1 then
			drawPip(mid, mid)
		elseif pips == 2 then
			drawPip(left, left)
			drawPip(right, right)
		elseif pips == 3 then
			drawPip(left, left)
			drawPip(right, right)
			drawPip(mid, mid)
		elseif pips == 4 then
			drawPip(left, left)
			drawPip(right, right)
			drawPip(left, right)
			drawPip(right, left)
		elseif pips == 5 then
			drawPip(left, left)
			drawPip(right, right)
			drawPip(left, right)
			drawPip(right, left)
			drawPip(mid, mid)
		elseif pips == 6 then
			drawPip(left, left)
			drawPip(right, right)
			drawPip(left, right)
			drawPip(right, left)
			drawPip(left, mid)
			drawPip(right, mid)
		end
	end

	if startScreen then
		displayStartScreen()
	else
		displayPlayScreen()
	end
	for posIndex, axis in ipairs(randPosTable) do
		displayDice(axis.pipNum, axis.randX, axis.randY, axis.randR, clientID, 1) --1 for color, 1 for scale
	end
	if receivedTables then
		for j, group in ipairs(receivedTables) do
			if group.dice then
				for i, value in ipairs(group.dice) do
					local centerX = love.graphics:getWidth() / 2 - #group.dice * 74 / 2
					displayDice(value, (i - 1) * 74 + centerX, (j - 1) * 74, 0, group.id, .5) --2 for color, .5 for scale
				end
			end
		end
	end
end

function revealDice()
	clearDice(allDice)
	for i, dice in ipairs(randPosTable) do
		table.insert(allDice, dice.pipNum)
	end
	--sort allDice lowest to highest
	table.sort(allDice)
	--send dice to host:
	local data = {id = clientID, dice = allDice} --may move clientID server side in future
	tcp:send(tableSerialization.serialize(data) .. "\n")
end

function love.keypressed(key)
	local reroll = true
	if startScreen and key ~= 'r' and key ~= 's' then
		numDice = numDice + 1
		clearDice(randPosTable)
		rollDice()
	end
	if key == 'r' and reroll then
		reroll = false
		startScreen = false
		clearDice(randPosTable)
		clearDice(incomingTable)
		rollDice()
	end

	if key == 's' then
		clearDice(randPosTable)
		clearDice(incomingTable)
		numDice = numDice - 1 
		if numDice < 1 then 
			startScreen = true
			numDice = 0
		else rollDice()
		end
	end
	if key == 'e' and not startScreen then
		reroll = true
		revealDice()
	end
end

--mouse functions should always work
function love.mousepressed(x, y, button)
	if button == 1 then
		checkPoints(x, y)
	end
end

function love.mousereleased(x, y, button)
	if button == 1 and selectedDiceIndex ~= nil then
		selectedDiceIndex = nil
	end
end

function checkPoints(x, y)
	for i, axis in ipairs(randPosTable) do
		local diceX, diceY, r = axis.randX, axis.randY, axis.randR
		local diceWidth = images.face:getWidth() / 2
		local diceHeight = images.face:getHeight() / 2

		local corners = {
			{x = diceX, y = diceY},
			{x = diceX + diceWidth, y = diceY},
			{x = diceX + diceWidth, y = diceY + diceHeight},
			{x = diceX, y = diceY + diceHeight}
		}
		--rotate corners
		for _, corner in ipairs(corners) do
			local addX = corner.x - diceX 
			local addY = corner.y - diceY
			corner.x = corner.x + math.cos(math.rad(r)) * addX - math.sin(math.rad(r)) * addY
			corner.y = corner.y + math.sin(math.rad(r)) * addX + math.cos(math.rad(r)) * addY
		end

		if pointInPolygon(x, y, corners) then
			selectedDiceIndex = i
			offsetX = x - diceX 
			offsetY = y - diceY 
			break
		end
	end
end

function pointInPolygon(x, y, polygon)
	local intersections = 20
	local prev = polygon[#polygon]

	for i, current in ipairs(polygon) do
		if (current.y > y) ~= (prev.y > y) then
			local slope = (current.x - prev.x) / (current.y - prev.y)
			local intersectX = prev.x + (y - prev.y) * slope
			if intersectX > x then
				intersections = intersections + 1
			end
		end
		prev = current
	end
	return intersections % 2 == 1
end
