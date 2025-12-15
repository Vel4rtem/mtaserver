
local tableName = "interkassa"
local server = "server_"..exports.config:getCCDPlanetNumber()

-- Старый способ выдачи
local x2donate = false
local donatCoeff = 5000
local donatCoeff2Start = 500
local donatCoeff2 = 7500
local x2donatCoeff = 10000


local logDB = dbConnect("sqlite", "donatedb.db")
dbExec(logDB, "CREATE TABLE IF NOT EXISTS 'errors' ('ID' INTEGER PRIMARY KEY AUTOINCREMENT, 'baseID' INTEGER, 'datetime' TEXT, 'playerName' TEXT, 'playerAccount' TEXT, 'paidSum' REAL, 'ikNomer' INTEGER, 'giver' TEXT, 'reason' TEXT)")
dbExec(logDB, "CREATE TABLE IF NOT EXISTS 'finished' ('ID' INTEGER PRIMARY KEY AUTOINCREMENT, 'baseID' INTEGER, 'datetime' TEXT, 'playerName' TEXT, 'playerAccount' TEXT, 'givenSum' REAL, 'paidSum' REAL, 'ikNomer' INTEGER, 'giver' TEXT, 'destination' TEXT)")
-- ID, server, login, sum, sumReal, date, responsible, ik_nomer, reason, status
-- CREATE TABLE errors (ID, baseID, datetime, playerName, playerAccount, paidSum, ikNomer, giver, reason)
-- CREATE TABLE finished (ID, baseID, datetime, playerName, playerAccount, givenSum, paidSum, ikNomer, giver, destination)

local start = getTickCount()
local remoteDB = dbConnect("mysql", "host=127.0.0.1;dbname=server_9888_ccdplanet2;charset=utf8", "server_9888", "yzwmjcv9nl" )
-- =========================================================================================================================
-- local remoteDB = dbConnect("mysql", "host=94.251.56.192;dbname=ccdplanet", "daeman", "daeman" )
-- set("lastID", 0)
-- =========================================================================================================================
outputDebugString("[DONATESYSTEM] Connection: "..getTickCount()-start.." ms.")

if not get("lastID") then
	outputDebugString("[DONATE] Error getting lastID. Please check settings.xml", 1)
	stopResource(resource)
end

function dbCheck()
	start = getTickCount()
	local query = dbQuery(remoteDB, "SELECT * FROM ?? WHERE ID > ? AND server = ? ORDER BY ID ASC;", tableName, get("lastID"), server)
	local data, errorCode, errorString = dbPoll(query, 500)
	if (data == nil) then
		dbFree(query)
		outputDebugString("[DONATESYSTEM][ERROR] dbPoll unsuccessful (execution longer than 500 ms)")
	elseif (data == false) then
		outputDebugString("[DONATESYSTEM][ERROR] dbPoll unsuccessful. Error "..tostring(errorCode).." ("..tostring(errorString)..")")
	else
		local pollTime = getTickCount()-start
		for _, row in ipairs(data) do
			giveMoney(row)
			set("lastID", row.ID)
		end
		local fullGivingTime = getTickCount()-start
		if fullGivingTime > 150 then
			outputDebugString("[DONATESYSTEM] Donate operation: "..fullGivingTime.." ms, poll time: "..pollTime.." ms. Rows: "..#data)
		end
	end
end
setTimer(dbCheck, 5000, 1)
setTimer(dbCheck, 60000, 0)

-- ======================================
-- addCommandHandler("donate", dbCheck)
-- ======================================

function giveMoney(row)
	row.ID = tonumber(row.ID)
	row.sum = tonumber(row.sum)
	row.ik_nomer = tonumber(row.ik_nomer)
	row.login = tostring(row.login)
	row.responsible = tostring(row.responsible)
	local account = getAccountByName(row.login)
	local datetime = isResourceRunning("login") and exports.login:dateTimeToString() or ""
	local realMoney = row.sum
	
	if (not account) then
		dbExec(logDB, "INSERT INTO errors VALUES (NULL, ?, ?, NULL, ?, ?, ?, ?, ?)", row.ID, datetime, row.login, row.sum, row.ik_nomer, row.responsible, "Account not found")
		outputDebugString("[DONATESYSTEM][FAIL] Account \""..row.login.."\" was not found. RowID: "..tostring(row.ID)..", datetime: "..tostring(datetime)..", paynumber: "..tostring(row.ik_nomer))
		dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[FAIL] Account not found", row.ID))
		
	elseif (not realMoney) then
		dbExec(logDB, "INSERT INTO errors VALUES (NULL, ?, ?, NULL, ?, ?, ?, ?, ?)", row.ID, datetime, row.login, row.sum, row.ik_nomer, row.responsible, "Invalid money amount")
		outputDebugString("[DONATESYSTEM][FAIL] Invalid money amount ("..tostring(row.sum).."). RowID: "..tostring(row.ID)..", datetime: "..tostring(datetime)..", paynumber: "..tostring(row.ik_nomer))
		dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[FAIL] Invalid money amount", row.ID))
		
	elseif (realMoney == 0) then
		local player = getAccountPlayer(account)
		local playerName = player and getPlayerName(player) or ""
		exports.bank:giveAccountBankMoney(account, realMoney, "DONATE")
		if isResourceRunning("bank") then
			local money = tostring(exports.bank:getAccountBankMoney(account, "DONATE"))
			dbExec(logDB, "INSERT INTO finished VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)", row.ID, datetime, playerName, getAccountName(account), realMoney, realMoney, row.ik_nomer, row.responsible, "money sum check: "..money)
			outputDebugString("[DONATESYSTEM][INFO] Money sum check: "..tostring(money).."DONATE. RowID: "..tostring(row.ID)..", datetime: "..tostring(datetime)..", paynumber: "..tostring(row.ik_nomer))
			dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[INFO] Money amount: "..money, row.ID))
		else
			dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[FAIL] Bank is offline", row.ID))
		end
		
	else
		local player = getAccountPlayer(account)
		if isResourceRunning("bank") then
			exports.bank:giveAccountBankMoney(account, realMoney, "DONATE")
			if player then
				triggerClientEvent(player, "playDonateSound", resourceRoot)
				outputChatBox("[CCDPlanet] #FFFFFFВы успешно получили "..realMoney.." "..edinicReplace(realMoney).." донат-валюты на банковский счет.", player, 59,89,152, true)
				outputDebugString("[DONATESYSTEM][AUTO] "..getPlayerName(player).." (acc "..getAccountName(account).." bank "..exports.bank:getPlayerBankMoney(player, "DONATE").."DONATE) got "..realMoney.." to his bank account")
				dbExec(logDB, "INSERT INTO finished VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)", row.ID, datetime, getPlayerName(player), getAccountName(account), realMoney, realMoney, row.ik_nomer, row.responsible, "bank")
				dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[SUCCESS] Player got to bank", row.ID))
			else
				outputDebugString("[DONATESYSTEM][AUTO] Account "..getAccountName(account).." (bank "..exports.bank:getAccountBankMoney(account, "DONATE").."DONATE) got "..realMoney.." to his bank account")
				dbExec(logDB, "INSERT INTO finished VALUES (NULL, ?, ?, NULL, ?, ?, ?, ?, ?, ?)", row.ID, datetime, getAccountName(account), realMoney, realMoney, row.ik_nomer, row.responsible, "bank")
				dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[SUCCESS] Account got to bank", row.ID))
			end
		else
			local summa = convertRoublesToDonate(realMoney)	
			if player then
				givePlayerMoney(player, summa)
				triggerClientEvent(player, "playDonateSound", resourceRoot)
				outputChatBox("[CCDPlanet] #FFFFFFВы успешно получили "..summa.." игровой валюты", player, 59,89,152, true)
				outputDebugString("[DONATESYSTEM][AUTO] "..getPlayerName(player).." (acc "..getAccountName(account).." money "..getPlayerMoney(player)..") got "..summa.." as donate money. RowID: "..tostring(row.ID)..", datetime: "..tostring(datetime)..", paynumber: "..tostring(row.ik_nomer))
				dbExec(logDB, "INSERT INTO finished VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)", row.ID, datetime, getPlayerName(player), getAccountName(account), summa, realMoney, row.ik_nomer, row.responsible, "handmoney")
				dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[SUCCESS] Player got money", row.ID))
			else
				local newMoney = (tonumber(getAccountData(account, "money")) or 0) + summa
				setAccountData(account, "money", newMoney)
				outputDebugString("[DONATESYSTEM][AUTO] Account "..getAccountName(account).." (money "..newMoney..") got "..summa.." as donate money. RowID: "..tostring(row.ID)..", datetime: "..tostring(datetime)..", paynumber: "..tostring(row.ik_nomer))
				dbExec(logDB, "INSERT INTO finished VALUES (NULL, ?, ?, NULL, ?, ?, ?, ?, ?, ?)", row.ID, datetime, getAccountName(account), summa, realMoney, row.ik_nomer, row.responsible, "account")
				dbFree(dbQuery(remoteDB, "UPDATE ?? SET status = ? WHERE ID = ?", tableName, "[SUCCESS] Account got money", row.ID))
			end
		end
	end
end

-- ==========     Замена слова "единиц" в зависимости от числа     ==========
local wordsTable = {[1] = "единицу", [2] = "единицы", [3] = "единицы", [4] = "единицы"}
function edinicReplace(sum)
	local mod = sum%10
	return wordsTable[mod] or "единиц"
end

-- ==========     Проверка, что ресурс запущен     ==========
function isResourceRunning(resName)
	local res = getResourceFromName(resName)
	return (res) and (getResourceState(res) == "running")
end

function getAccountByName(accName)
	local account = getAccount(accName)
	if account then
		return account
	else
		local accNameLower = utf8.lower(accName)
		for _, tempAcc in ipairs(getAccounts()) do
			if (utf8.lower(getAccountName(tempAcc)) == accNameLower) then
				return tempAcc
			end
		end
	end
end

function convertRoublesToDonate(roubles)
	roubles = tonumber(roubles) or 0
	if (not x2donate) and (roubles < donatCoeff2Start) then
		return roubles * donatCoeff
	elseif (not x2donate) then
		return roubles * donatCoeff2
	else
		return roubles * x2donatCoeff
	end
end

-- function getNextID(tableName)
	-- local result = dbPoll(dbQuery(logDB, "SELECT ID FROM "..tableName.." ORDER BY ID DESC LIMIT 1"), -1)
	-- local newID = false
	-- if (type(result[1]) == "table") then
		-- newID = result[1].ID or 0
	-- end
	-- if newID then
		-- return newID + 1
	-- else
		-- return 1
	-- end
-- end

-- function toLower(text)
	-- text = string.gsub(text, "А", "а")
	-- text = string.gsub(text, "Б", "б")
	-- text = string.gsub(text, "В", "в")
	-- text = string.gsub(text, "Г", "г")
	-- text = string.gsub(text, "Д", "д")
	-- text = string.gsub(text, "Е", "е")
	-- text = string.gsub(text, "Ё", "е")
	-- text = string.gsub(text, "Ж", "ж")
	-- text = string.gsub(text, "З", "з")
	-- text = string.gsub(text, "И", "и")
	-- text = string.gsub(text, "Й", "й")
	-- text = string.gsub(text, "К", "к")
	-- text = string.gsub(text, "Л", "л")
	-- text = string.gsub(text, "М", "м")
	-- text = string.gsub(text, "Н", "н")
	-- text = string.gsub(text, "О", "о")
	-- text = string.gsub(text, "П", "п")
	-- text = string.gsub(text, "Р", "р")
	-- text = string.gsub(text, "С", "с")
	-- text = string.gsub(text, "Т", "т")
	-- text = string.gsub(text, "У", "у")
	-- text = string.gsub(text, "Ф", "ф")
	-- text = string.gsub(text, "Х", "х")
	-- text = string.gsub(text, "Ц", "ц")
	-- text = string.gsub(text, "Ч", "ч")
	-- text = string.gsub(text, "Ш", "ш")
	-- text = string.gsub(text, "Щ", "щ")
	-- text = string.gsub(text, "Ъ", "ъ")
	-- text = string.gsub(text, "Ы", "ы")
	-- text = string.gsub(text, "Ь", "ь")
	-- text = string.gsub(text, "Э", "э")
	-- text = string.gsub(text, "Ю", "ю")
	-- text = string.gsub(text, "Я", "я")
	-- text = string.lower(text)
	-- return text
-- end
	
--setTimer(checkDatabase, 2000, 1)
--setTimer(checkDatabase, 60000, 0)


--[[
function checkDatabase()
	local startTime = getTickCount()
	
	local lastID = get("lastID")
	local rowsCount = 0
	--local result = dbPoll(dbQuery(remoteDB, "SELECT * FROM interkassa WHERE ID > ? ORDER BY ID", lastID), -1)
	local result = mysql_query(remoteDB, "SELECT * FROM interkassa WHERE ID > "..lastID.." ORDER BY ID")
	
	local queryTime = getTickCount() - startTime
	
	if result then
		local row = false
		repeat
			row = mysql_fetch_row(result)
			if row then
				row.id = row[1]
				row.login = row[2]
				row.sum = row[3]
				row.cur = row[4]
				giveMoney(row)
				set("lastID", row.id)
			end
		until row == nil
		rowsCount = mysql_num_rows(result)
		mysql_free_result(result)
	end
	
	local fullTime = getTickCount() - startTime
	
	if (fullTime > 100) then
		outputDebugString("[DONATESYSTEM] Donate operation: "..fullTime.." ms, query time: "..queryTime.." ms. Rows: "..rowsCount)
	end
		
	--if (type(result) == "table") and (#result > 0) then
		--for _, row in ipairs(result) do
		--	giveMoney(row)
		--	set("lastID", row.id)
		--end
	--end
end
]]
--[[
function giveMoneyManual(playerSource, _, donateAccName, summaReal)
	local srcAccName = getAccountName(getPlayerAccount(playerSource))
	if not isObjectInACLGroup("user."..srcAccName, aclGetGroup("GLAdmin")) then
		outputDebugString("[DONATESYSTEM][FAIL] "..getPlayerName(playerSource).." (acc "..srcAccName.." money "..getPlayerMoney(playerSource)..") used command with parameters "..tostring(donateAccName)..", "..tostring(summa))
		return
	end
	if (not donateAccName) or (not summaReal) then
		outputChatBox("Введи аккаунт и сумму доната в НЕигровых рублях, например: /giveMoney qwertyo1 100", playerSource, 255,0,0, true)
		return
	end
	local summa = convertRoublesToDonate(summaReal)
	
	local account = getAccountByName(donateAccName)
	if not account then
		outputChatBox("Аккаунт "..donateAccName.." не найден", playerSource, 255,0,0, true)
		return
	end
	
	local player = getAccountPlayer(account)
	if player then
		givePlayerMoney(player, summa)
		outputChatBox("[CCDPlanet] #FFFFFFВы успешно получили "..summa.." игровой валюты", player, 59,89,152, true)
		outputChatBox("[CCDPlanet] #00FF00Ты успешно выдал "..summa.." игроку "..getPlayerName(player), playerSource, 59,89,152, true)
		outputDebugString("[DONATESYSTEM][MANUAL] "..getPlayerName(player).." (acc "..getAccountName(account).." money "..getPlayerMoney(player)..") got "..summa.." as donate money (giver "..getPlayerName(playerSource).." acc "..srcAccName..")")
		dbExec(logDB, "INSERT INTO finished VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", getNextID("finished"), exports.login:dateTimeToString(), getPlayerName(player), getAccountName(account), summa, summaReal, "", getPlayerName(playerSource), srcAccName, "Manual to player")
		triggerClientEvent(player, "playDonateSound", resourceRoot)
	else
		local newMoney = (tonumber(getAccountData(account, "money")) or 0) + summa
		setAccountData(account, "money", newMoney)
		outputChatBox("[CCDPlanet] #00FF00Ты успешно выдал "..summa.." игроку под аккаунтом "..getAccountName(account), playerSource, 59,89,152, true)
		outputDebugString("[DONATESYSTEM][MANUAL] Account "..getAccountName(account).." money "..getAccountData(account, "money")..") got "..summa.." as donate money (giver "..getPlayerName(playerSource).." acc "..srcAccName..")")
		dbExec(logDB, "INSERT INTO finished VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", getNextID("finished"), exports.login:dateTimeToString(), "", getAccountName(account), summa, summaReal, "", getPlayerName(playerSource), srcAccName, "Manual to account")
	end
end
addCommandHandler("giveMoney", giveMoneyManual, false, false)
]]


