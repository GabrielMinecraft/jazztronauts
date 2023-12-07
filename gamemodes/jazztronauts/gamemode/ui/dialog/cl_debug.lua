local function printNPCIDs()
	for k, v in pairs(missions.NPCList) do
		print(v.name .. " \t\t= " .. k .. " (" .. v.prettyname .. ")")
	end
end
concommand.Add("jazz_debug_printnpcs", function(ply, cmd, args)
	printNPCIDs()
end )

local function FindNPCByID(npcid)
	local npcs = ents.FindByClass("jazz_cat")
	for _, v in pairs(npcs) do
		if v.GetNPCID and v:GetNPCID() == npcid then
			return v
		end
	end
end

concommand.Add("jazz_debug_runscript", function(ply, cmd, args)
	local script = args[1]
	if dialog.IsReady() and not dialog.IsScriptValid(script) then
		print("Invalid script \"" .. script .. "\"!")
		return
	end

	local npcid = tonumber(args[2])
	local npc = npcid and FindNPCByID(npcid)
	if npcid and not IsValid(npc) then
		print("Failed to find NPC with ID " .. npcid)
		return
	end

	if npc then
		dialog.SetFocus(npc)
	end

	dialog.StartGraph(script)
end )

CreateClientConVar("jazz_debug_sceneEditor_inCamera","1",false,false,"Set false to allow player control while playing a scene",0,1)