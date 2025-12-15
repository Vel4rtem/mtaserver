local highPing = {}

function kickPingChecker()
	for i, player in ipairs(getElementsByType("player")) do
		if (getPlayerPing(player) >= 500) then
			if highPing[player] then
				highPing[player] = highPing[player] + 1
				if (highPing[player] == 3) then
					outputChatBox("Ваш пинг слишком высокий! Вы будете кикнуты через 15 секунд", player, 255,50,50)
				elseif (highPing[player] == 6) then
					highPing[player] = nil
					outputDebugString("[PINGKICKER] "..getPlayerName(player).." was kicked for high ping")
					kickPlayer(player, "Your ping is too high")
				end
			else
				highPing[player] = 1
			end
		elseif highPing[player] then
			highPing[player] = highPing[player] - 1
			if highPing[player] < 1 then
				highPing[player] = nil
			end
		end
	end
end
setTimer(kickPingChecker, 5000, 0)