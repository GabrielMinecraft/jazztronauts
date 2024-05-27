
-------------------------
------ PLAYER DATA ------
-------------------------
local money = {}

-- Per-player data money data
jsql.Register("jazz_player_money",
[[
	steamid BIGINT NOT NULL PRIMARY KEY,
	earned INT UNSIGNED NOT NULL DEFAULT 0 CHECK (earned >= 0),
	spent INT UNSIGNED NOT NULL DEFAULT 0 CHECK (spent >= 0)
]])

jsql.Register("jazz_playerdata_persist",
[[
	steamid BIGINT NOT NULL PRIMARY KEY,
	resets INT UNSIGNED NOT NULL DEFAULT 0
]])

newgame.MarkPersistent("jazz_playerdata_persist")

local SERVER_ID = "-1"

-- Get the total amount of money earned by everybody this session
function money.GetTotalEarned()
	local sel = "SELECT SUM(earned) as total FROM jazz_player_money"
	local res = jsql.Query(sel)
	if res == false or #res == 0 then return 0 end

	return tonumber(res[1].total) or 0
end

function money.ChangeNotes(ply64, delta, onlyearn)
	if delta == 0 then return false end

	local column = "earned"
	if delta < 0 and not onlyearn then
		delta = math.abs(delta)
		column = "spent"

		-- Not enough money
		local mon = money.GetNotes(ply64)
		if (jazzmoney.IsShared() and money.GetTotalEarned() or mon.earned) - mon.spent < delta then return false end
	end

	local deltaStr = delta >= 0 and "+ " .. delta or tostring(delta)

	local update = "UPDATE jazz_player_money "
		.. string.format("SET %s = %s %s ", column, column, deltaStr)
		.. string.format(" WHERE steamid='%s'", ply64)

	local insert = "INSERT OR IGNORE INTO jazz_player_money(steamid) "
		.. string.format("VALUES ('%s')", ply64)

	-- Try an insert first to make sure they exist
	if jsql.Query(insert) == false then return false end
	if jsql.Query(update) == false then return false end

	return true
end

local function ConvertTypes(entry)
	if not entry then return nil end

	entry.earned = tonumber(entry.earned) or 0
	entry.spent = tonumber(entry.spent) or 0

	return entry
end

-- Get the earned and spent of every player
function money.GetAllNotes()
	local sel = "SELECT * FROM jazz_player_money"
	local res = jsql.Query(sel)
	if type(res) == "table" then
		for _, v in pairs(res) do
			ConvertTypes(v)
		end

		return res
	end

	return {}
end

-- Retrieve the note count of a specific player
function money.GetNotes(ply)
	if isentity(ply) then
		if ply:IsValid() then
			ply = ply:SteamID64()
		else
			return nil
		end
	end

	local sel = "SELECT * FROM jazz_player_money "
		.. string.format("WHERE steamid='%s'", ply)

	local res = jsql.Query(sel)
	if type(res) == "table" then
		return ConvertTypes(res[1])
	end

	return nil
end

-- Get the total number of players that have played in this session
-- Money is reset every time the map resets
function money.GetTotalPlayers()
	local sel = "SELECT COUNT(*) as count FROM jazz_player_money "
		.. "WHERE id!=" .. SERVER_ID
	local res = jsql.Query(sel)
	if type(res) == "table" then
		return tonumber(res[1].count) or 0
	end

	return 0
end

return money
