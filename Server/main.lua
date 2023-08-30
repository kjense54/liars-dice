--THIS IS THE SERVER FOR LIAR'S DICE
local socket = require("socket")
--local tableSerialization = require("tableSerialization") --file we make to serialize the dice tables

server = assert(socket.bind("192.168.1.116", 8080)) --192.168.1.21
--local ip, port = server:getsockname()
server:settimeout(0)
io.stdout:setvbuf("no") --print immediately

local clients = {} --create table to store connected clients

local function handle_client(client) -- where all server-client communication goes
	while true do --recieve and send data
		local data, err = client:receive("*l")
		if data then
			--send to all other clients
			for other_client, _ in pairs(clients) do
				if other_client ~= client then 
					other_client:send(data .. "\n")
				end
			end
		elseif err == "closed" then 
			break
		end
		coroutine.yield()
	end
	client:close()
	clients[client] = nil
end

--update
function love.update(dt)
	local client = server:accept()
	if client then 
		client:settimeout(0)
		print("client accepted")
		--socket.sleep(0.1)
		--clients[client] = true --add client to clients table as key w/ value pair "true"
		co = coroutine.create(function()
			handle_client(client) --coroutine stays alive bc while loop
		end)
		clients[client] = co --> Associate the coroutine with the client
		coroutine.resume(co) --> coroutines are suspended on birth so have to (re)start w/ resume
	end
	for client, co in pairs(clients) do
		coroutine.resume(co)
	end
end
