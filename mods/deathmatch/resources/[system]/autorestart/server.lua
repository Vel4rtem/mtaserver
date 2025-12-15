
local restartLaunched = false

function checkTimer()
	if (not restartLaunched) then
		local lastRestart = tonumber(get("lastAutoRestart")) -- Читаем, какой день года был на момент последнего авторестарта
		local curTime = getRealTime()
		if (lastRestart) then
			if (curTime.hour == 4) and (lastRestart<curTime.yearday or lastRestart>curTime.yearday) then
				restartLaunched = true
				for i=15, 3, -1 do
					local timer = (15-i) * 60000 + 50
					local color = 255 - (15-i)*19
					setTimer(outputChatBox, timer, 1, "Внимание! Автоматический рестарт сервера состоится через "..i.." минут.", root, 255,color,color)
				end
				setTimer(startAutorestart, 780000, 1)
			end
		else
			set("lastAutoRestart", curTime.yearday)
		end
	end
end
setTimer(checkTimer, 60000, 0)

function startAutorestart()
	local curTime = getRealTime()
	set("lastAutoRestart", curTime.yearday)
	setServerPassword(generateString(8))
	kickall()
	outputDebugString("[AUTORESTART] Autorestart triggered by timer")
end

function kickall(player)
	outputChatBox("[CCDPLANET] ВНИМАНИЕ!", root, 255,0,0)
	outputChatBox("[CCDPLANET] ПЕРЕЗАПУСК СЕРВЕРА ЧЕРЕЗ 2 МИНУТЫ", root, 255,0,0)
	outputChatBox("[CCDPLANET] НАЧАЛО ОТКЛЮЧЕНИЯ ИГРОКОВ ЧЕРЕЗ 30 СЕКУНД", root, 255,0,0)
	setTimer(kick, 30000, 1)
	if (player) then
		outputDebugString("[KICKALL] Kickall triggered by "..getPlayerName(player).." (acc "..getAccountName(getPlayerAccount(player))..")")
	end
end
addCommandHandler("kickall", kickall, true, true)

function kick()
	local playersTable = getElementsByType("player")
	if #playersTable > 0 then
		outputDebugString("[KICKALL] "..getPlayerName(playersTable[1]).." will be kicked")
		kickPlayer(playersTable[1], "Server restart")
		setTimer(kick, 500, 1)
	else
		outputDebugString("[KICKALL] Kicking complete!")
		if (restartLaunched) then
			setServerPassword(nil)
			shutdown("Automatic restart at 4:00")
		end
	end
end




local allowed = {{48, 57}, {65, 90}, {97, 122}} -- numbers/lowercase chars/uppercase chars 
function generateString(len) 
	math.randomseed(getTickCount()) 
	local str = ""
	for i = 1, len do
		local charlist = allowed[math.random(1, 3)]
		str = str..string.char(math.random(charlist[1], charlist[2]))
	end 
	return str
end