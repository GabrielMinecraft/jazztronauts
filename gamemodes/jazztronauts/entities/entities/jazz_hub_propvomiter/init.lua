AddCSLuaFile("cl_init.lua")

util.AddNetworkString("jazz_propvom_effect")
util.AddNetworkString("jazz_propvom_propsavailable")

ENT.VomitVelocity = Vector(0, 0, -200)
ENT.MaxPipeSize = 50
ENT.ConstipateOdds = 50 -- The odds to do the constipated thing (0 is always, 50 is 1/50)
ENT.ConstipateCount = 100 -- How many props to spawn at once
ENT.ConstipateMinProps = 20 -- Minimum number of props required to roll the dice for constipation

ENT.Type = "point"
ENT.DisableDuplicator = true
ENT.VomitMusicFile = Sound("jazztronauts/music/trash_chute_music_loop.wav")
ENT.VomitFinishFile = Sound("jazztronauts/music/trash_chute_music_stop.wav")
ENT.VomitEmptyFile = Sound("jazztronauts/music/trash_chute_music_empty.wav")
ENT.VomitSpeed = 2 -- Props per vomit
ENT.StartDelay = 0 -- Delay before anything at all happens
ENT.MusicDelay = 3.5 -- Delay to let the music play before props begin to fall
ENT.ConstipateDelay = 10.5 -- Delay when the tube is constipated
ENT.FinishDelay = 2.0 -- How long to wait before closing the blinds

local propr_unlock_list = "props"
unlocks.Register(propr_unlock_list)

local randomGibProps =
{
	Model("models/props_interiors/Furniture_Vanity01a.mdl"),
	Model("models/props_interiors/Furniture_Desk01a.mdl"),
	Model("models/props_junk/wood_crate001a_damaged.mdl"),
	Model("models/props_junk/wood_pallet001a.mdl"),
	Model("models/props_c17/FurnitureTable001a.mdl")
}

local groanSounds =
{
	"ambient/materials/metal_stress1.wav",
	"ambient/materials/metal_stress2.wav",
	"ambient/materials/metal_stress3.wav",
	"ambient/materials/metal_stress4.wav",
	"ambient/materials/metal_stress5.wav"
}

local bowelMovementSounds =
{
	"ambient/machines/thumper_shutdown1.wav",
	"ambient/machines/floodgate_move_short1.wav"
}

local outputs =
{
	"OnVomitEnd",
	"OnVomitEndEmpty",
	"OnVomitStart",
	"OnVomitStartEmpty",
	"OnVomitNPC"
}


function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "Marker")
end

-- Task for precaching models over a few frames so we dont destroy everyone
local function PrecacheProps(props)
	for _, v in pairs(props) do
		if v.type != "prop" then continue end
		util.PrecacheModel(v.propname)
		task.Sleep(0)
	end

	task.Yield("done")
end

local function CreatePrecacheTask(props, callback)
	local precacheTask = task.New(PrecacheProps, 1, props)
	function precacheTask:done()
		callback()
	end
end

local function UpdatePlayerPropMarker(ply, enabled, marker)

	net.Start("jazz_propvom_propsavailable")
		net.WriteBool(enabled)
		net.WriteVector(marker)
	net.Send(ply)
end

function ENT:Initialize()
	//self:VomitNewProps()
end

function ENT:KeyValue( key, value )
	if key == "marker" then
		local marker = Vector(value) or Vector(self:GetPos())
		self:SetMarker(marker)
	elseif key == "vomitmusic" then
		self.VomitMusicFile = Sound(value)
	elseif key == "vomitmusicfinish" then
		self.VomitFinishFile = Sound(value)
	elseif key == "vomitmusicempty" then
		self.VomitEmptyFile = Sound(value)
	end

	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end
end

function ENT:StopVomit()
	self:StartMusic(self.VomitFinishFile)
	self.SpawnQueue = nil
	self.IsStopping = true

	timer.Simple(self.FinishDelay, function()
		self:TriggerOutput(self.WasEmpty and "OnVomitEndEmpty" or "OnVomitEnd", self)
		self.IsStopping = false
	end )
end

function ENT:VomitMultiple(count)

	for i=1, count do
		if not self:VomitProp() then
			self:StopVomit()
			break
		end
	end
end

function ENT:Think()
	if !self.StartAt or CurTime() < self.StartAt then return end
	if not self.SpawnQueue then return end
	if self.IsStopping then return end

	if not self.Constipated then
		self:VomitMultiple(self.VomitSpeed)
	end

	jazzboards.UpdateLeaderboards(self.CurrentUser, -self.TotalCount)
end

function ENT:StopMusic(fadeTime)
	if self.VomitMusic then
		if not fadeTime or fadeTime <= 0 then
			self.VomitMusic:Stop()
			self.VomitMusic = nil
		elseif not self.WasEmpty then
			self.VomitMusic:FadeOut(fadeTime)
		end
	end
end

function ENT:StartMusic(f)
	self:StopMusic()

	--local f = self.WasEmpty and self.VomitEmptyFile or self.VomitMusicFile
	self.VomitMusic = CreateSound(self, f)
	self.VomitMusic:SetSoundLevel(80)
	self.VomitMusic:Play()
end

function ENT:VomitNewProps(ply)
	if not IsValid(ply) then
		self:TriggerOutput("OnVomitEnd", self)
		return
	end


	self.CurrentUser = ply -- TODO: Store steamid, not player reference

	local counts = snatch.GetPlayerPropCounts(ply, true)
	snatch.ClearPlayerRecentProps(ply)

	-- Store original use counts
	self.SpawnQueue = counts

	-- Store the index on each keyvalue pair to make it easier to lookup later
	self.TotalCount = 0
	for k, v in pairs(self.SpawnQueue) do
		v.Index = k
		self.TotalCount = self.TotalCount + v.recent
	end

	-- Add this as a 'session' prop for leaderboards
	if IsValid(self.CurrentUser) then
		jazzboards.AddSessionProps(self.CurrentUser:SteamID64(), self.TotalCount)
	end

	UpdatePlayerPropMarker(self.CurrentUser, false, self:GetMarker())

	-- Precache all the props first, then start the show
	self.StartAt = math.huge
	local loadStartTime = CurTime()
	CreatePrecacheTask(self.SpawnQueue, function()
		local loadTime = CurTime() - loadStartTime
		print("LOAD TOOK: " .. loadTime .. " seconds!")

		-- Random chance for the pipe to be constipated
		self.WasEmpty = next(self.SpawnQueue) == nil
		self.Constipated = not self.WasEmpty
			and self.TotalCount > self.ConstipateMinProps
			and math.random(0, self.ConstipateOdds) == 0

		if self.Constipated then
			self:DoConstipatedEffects()
		end

		-- Fire outputs
		self:TriggerOutput(self.WasEmpty and "OnVomitStartEmpty" or "OnVomitStart", self)

		-- Start the music and away we go
		local startDelay = self.StartDelay - loadTime
		self.StartAt = CurTime() + self.MusicDelay + startDelay
		timer.Simple(startDelay, function()
			self:StartMusic(self.WasEmpty and self.VomitEmptyFile or self.VomitMusicFile)
		end )
	end )
end

function ENT:DoConstipatedEffects()
	local pos, ang = self:GetPos() + self:GetAngles():Up() * 100, self:GetAngles()

	-- Delay for initial groan sound
	timer.Simple(self.MusicDelay, function()
		self:EmitSound("ambient/materials/creaking.wav", 85, 100)
		self:EmitSound("ambient/materials/metal_groan.wav", 85, 90)
		--self:StopMusic(0.5) -- Actually it's funnier if the music keeps going
		self:SpawnRandomGibs(pos, ang)
	end )

	-- Spark delay, dribble of poopy
	timer.Simple(self.MusicDelay + 4.5, function()
		self:SpawnRandomGibs(pos, ang)
		self:EmitSound(groanSounds[math.random(1, #groanSounds)], 85)

		util.ScreenShake(self:GetPos(), 2, 5, 3.0, 10000)

		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetScale(1)
		ed:SetRadius(4096)
		ed:SetMagnitude(5)
		util.Effect("ElectricSpark", ed)
	end )

	-- One more long groan....
	timer.Simple(self.MusicDelay + 7.5, function()
		self:EmitSound(bowelMovementSounds[math.random(1, #bowelMovementSounds)], 85)
		self:SpawnRandomGibs(pos, ang)
		util.ScreenShake(self:GetPos(), 5, 0.5, 5.5, 10000)
	end )

	-- Destroy the anus
	timer.Simple(self.MusicDelay + self.ConstipateDelay, function()
		self:EmitSound("physics/metal/metal_large_debris2.wav", 85)
		util.ScreenShake(self:GetPos(), 25, 0.5, 5.5, 10000)
		self:VomitMultiple(self.ConstipateCount)
		self.Constipated = false -- If they somehow had more props, trickle the rest out

		jazzboards.UpdateLeaderboards(self.CurrentUser, -self.TotalCount)
	end )
end

function ENT:Decrement(idx)
	if not self.SpawnQueue or not self.SpawnQueue[idx] then return end

	-- Decrement the count by one
	local newCount = self.SpawnQueue[idx].recent - 1
	self.SpawnQueue[idx].recent = newCount
	self.TotalCount = self.TotalCount - 1

	-- If that puts it below zero, nil out entry
	if newCount <= 0 then
		self.SpawnQueue[idx] = nil
	end
end

function ENT:SpawnRandomGibs(pos, ang)
	local e2 = mapgen.SpawnHubProp(randomGibProps[math.random(1, #randomGibProps)],
		pos, ang)
	e2:GetPhysicsObject():SetVelocity(self.VomitVelocity)
	e2:PrecacheGibs()
	e2:GibBreakClient(self.VomitVelocity)
	e2:Remove()
end

local down = Angle(Vector(0,0,-1)) --sue me --todo maybe: make prop vomiter able to be angled other ways?
local comballsize = GetConVar("sk_weapon_ar2_alt_fire_radius")
local maxnpcs = CreateConVar("jazz_propvomiter_npcs", 5, FCVAR_NONE, "Max number of NPCs the vomiter could make")
local chancenpcs = CreateConVar("jazz_propvomiter_npcchance", 0.1, FCVAR_NONE, "Chance for the 'real' thing to spawn when vomited.", 0, 1)
local totalnpcs = 0
local spacenpcs = 0 --give a little breathing room for stuff being spawned to help it not all get caught inside eachother

local function simplemake(self, name, pos)
	if not IsValid(self) then return nil end
	self:TriggerOutput("OnVomitNPC", self.CurrentUser)
	local ent = ents.Create(name)
	if IsValid(ent) then
		ent:SetPos(pos)
		ent:Spawn()
		ent:Activate()
		totalnpcs = totalnpcs + 1
	end
	return ent
end

local alternatespawns = {
	["models/manhack.mdl"] = function(self, pos) return simplemake(self, "npc_manhack", pos) end,
	["models/combine_scanner.mdl"] = function(self, pos) return simplemake(self, "npc_cscanner", pos) end,
	["models/shield_scanner.mdl"] = function(self, pos) return simplemake(self, "npc_clawscanner", pos) end,
	["models/effects/combineball.mdl"] = function(self, pos)
		--will eventually remove itself, so, no need for adding to total
		local spawner = ents.Create("point_combine_ball_launcher")
		if IsValid(spawner) then
			spawner:SetPos(pos)
			spawner:SetAngles(down)
			spawner:SetKeyValue("launchconenoise", 1)
			spawner:SetKeyValue("ballradius", comballsize:GetFloat())
			spawner:SetKeyValue("ballcount", 0)
			spawner:SetKeyValue("maxballbounces", 7)
			spawner:SetKeyValue("minspeed", 1000)
			spawner:SetKeyValue("maxspeed", 1000)
			spawner:SetSpawnFlags(2) --Ball/player collide
			spawner:Spawn()
			spawner:Fire("launchball")
			timer.Simple( 0, function()
				if IsValid(spawner) then spawner:Fire("kill") end
			end)
		end
	end,
	["models/combine_turrets/floor_turret.mdl"] = function(self, pos) return simplemake(self, "npc_turret_floor", pos) end,
	["models/roller.mdl"] = function(self, pos) return simplemake(self, "npc_rollermine", pos) end,
	["models/props_combine/combine_mine01.mdl"] = function(self, pos) return simplemake(self, "combine_mine", pos) end,
	["models/headcrabclassic.mdl"] = function(self, pos) return simplemake(self, "npc_headcrab", pos) end,
	["models/headcrab.mdl"] = function(self, pos) return simplemake(self, "npc_headcrab_fast", pos) end,
	["models/headcrabblack.mdl"] = function(self, pos) return simplemake(self, "npc_headcrab_black", pos) end,
	["models/combine_helicopter/helicopter_bomb01.mdl"] = function(self, pos)
		local bomb = simplemake("grenade_helicopter", pos)
		if bomb then totalnpcs = totalnpcs - 1 end --eh, just cancel it out
		return bomb
	end,
	["models/weapons/w_grenade.mdl"] = function(pos)
		local ent = ents.Create("npc_grenade_frag")
		--will eventually remove itself, so, no need for adding to total
		if IsValid(ent) then
			ent:SetPos(pos)
			ent:Spawn()
			ent:Activate()
			timer.Simple(0, function()
				if IsValid(ent) then ent:Fire("settimer", 3) end
			end)
		end
	end,
	["models/crow.mdl"]=function(pos) return simplemake("npc_crow",pos) end,
	["models/pigeon.mdl"]=function(pos) return simplemake("npc_pigeon",pos) end,
	["models/seagull.mdl"]=function(pos) return simplemake("npc_seagull",pos) end,
	["models/props/turret_01.mdl"]=function(pos) return simplemake("npc_portal_turret_floor",pos) end,
}
alternatespawns["models/roller_spikes.mdl"] = alternatespawns["models/roller.mdl"]
alternatespawns["models/roller_vehicledriver.mdl"] = alternatespawns["models/roller.mdl"]
alternatespawns["models/weapons/w_npcnade.mdl"] = alternatespawns["models/weapons/w_grenade.mdl"]
alternatespawns["models/nova/w_headcrab.mdl"] = alternatespawns["models/headcrab.mdl"]
alternatespawns["models/lamarr.mdl"] = alternatespawns["models/headcrab.mdl"]

function ENT:SpawnPropEffect(propinfo, pos)
	local filter = RecipientFilter()
	filter:AddPVS(self:GetPos())

	if math.random() <= chancenpcs:GetFloat() and spacenpcs < 1 and totalnpcs < maxnpcs:GetFloat() and alternatespawns[propinfo.propname] then
		alternatespawns[propinfo.propname](self, pos)
		spacenpcs = self.VomitSpeed * 3
		-- do we remove these after a certain time or do we keep them?
	else
		net.Start("jazz_propvom_effect")
			net.WriteVector(pos)
			net.WriteString(propinfo.propname)
			net.WriteString(propinfo.type) -- #TODO: int types?
		net.Send(filter)
		spacenpcs = spacenpcs - 1
	end
end

function ENT:ShouldToy(ent)
	return ent:BoundingRadius() > self.MaxPipeSize or util.IsValidRagdoll(ent:GetModel())
end

local lastPropName = nil
function ENT:VomitProp()
	if not self.SpawnQueue then return false end

	local prop = table.Random(self.SpawnQueue)
	if not prop then return false end

	if not IsValid(self.CurrentUser) then return false end

	local worth = prop.worth
	local pos, ang = self:GetPos() + self:GetAngles():Up() * 100, self:GetAngles()

	unlocks.Unlock( propr_unlock_list, self.CurrentUser, prop.propname )

	-- Spawn some placeholder gibs, this prop doesnt normally break
	self.CurrentUser:ChangeNotes(worth)
	self:SpawnPropEffect(prop, pos)

	-- Don't do it _every_ time, but adjustable odds
	if lastPropName != prop.propname then
		if math.Rand(0, 1) <= math.min( 0.75, 1.5 / self.VomitSpeed ) then --decrease chance of gibs as speed increases todo: move this to client and have it affected by prop percentage
			self:SpawnRandomGibs(pos, ang)
		end

		lastPropName = prop.propname
	end

	-- Decrement
	self:Decrement(prop.Index)

	return true
end

function ENT:IsActive()
	return self.SpawnQueue or self.IsStopping
end

function ENT:AcceptInput( name, activator, caller, data )
	if name == "Vomit" and not self:IsActive() then
		self:VomitNewProps(activator)
		return true
	end
	number = tonumber(data)
	if name == "SetSpeed" then
		if number > 0 then
			self.VomitSpeed = number
		else
			self.VomitSpeed = 1
		end
		return true
	end
	if name == "SetConstipateOdds" then
		self.ConstipateOdds = number
		return true
	end

	return false
end

if mapcontrol.IsInHub() then
	hook.Add("PlayerInitialSpawn", "JazzInformPropsAvailable", function(ply)
		local counts = snatch.GetPlayerPropCounts(ply, true)
		local vomiter = ents.FindByClass("jazz_hub_propvomiter")[1]
		if IsValid(vomiter) then
			UpdatePlayerPropMarker(ply, next(counts) ~= nil,vomiter:GetMarker())
		end
	end )
end
