AddCSLuaFile()
module( "newgame", package.seeall )

ENDING_CHEATED	 = 0
ENDING_ASH		 = 1
ENDING_ECLIPSE	 = 2

local nettbl = "jazz_newgame_info"
local glbtbl = "jazz_global_state"

concommand.Add("jazz_dump_globals", function()
	PrintTable(GetGlobalState())
end )

if SERVER then

	local ngsql = include("sql.lua")

	-- Network reset information once
	local tbl = nettable.Create(nettbl, nettable.TRANSMIT_ONCE)
	tbl["resets"] = ngsql.GetResetCount()

	-- Network global game state
	nettable.Create(glbtbl, nettable.TRANSMIT_AUTO)

	-- Reset the game, incrementing the reset counter and restarting from scratch
	-- Automatically reloads the tutorial map
	function ResetGame(endType)
		if not endType then
			ErrorNoHalt("Invalid ending type!")
			return
		end

		-- Mark every player that participated in this session
		-- #TODO: needed?

		-- Store this as a end-game reset
		local totalPlayers = jazzmoney.GetTotalPlayers()
		ngsql.AddResetInfo(endType, totalPlayers)

		-- Reset non-persistent sql stuff
		jsql.ResetExcept(GetPersistent())
		unlocks.ClearAll()

		-- Changelevel to intro again
		mapcontrol.Launch(mapcontrol.GetIntroMap())
	end

	-- Return information about every single reset
	function GetResets()
		return ngsql.GetResets()
	end

	function SetGlobal(key, value)
		ngsql.SetGlobal(key, value)
		UpdateNetworkState()
	end

	function UpdateNetworkState()
		nettable.Set(glbtbl, ngsql.GetGlobalState() or {})
	end

	UpdateNetworkState()
end

-- How many times the game has been finished and restarted
function GetResetCount()
	return (nettable.Get(nettbl) or {}).resets or 0
end

-- Get the current active money multiplier
function GetMultiplier()
	return GetResetCount() + ( progress and progress.DeepDiveMultiplier() or 1 ) --todo: no progress on client
end

-- Get the global state table
function GetGlobalState()
	return nettable.Get(glbtbl) or {}
end

-- Get some piece of persistent global state
function GetGlobal(key)
	return GetGlobalState()[key]
end

