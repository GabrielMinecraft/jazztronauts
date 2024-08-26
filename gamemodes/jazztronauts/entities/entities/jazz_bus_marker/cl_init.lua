include("shared.lua")

local ReticleCircleMaterial	= Material("ui/jazztronauts/bus_circle")
local ReticleCenterMaterial	 = Material("icon16/car.png")
local BeamMat				   = Material("cable/physbeam")
surface.CreateFont( "JazzMouseHint", {
	font	  = "KG Shake it Off Chunky",
	size	  = ScreenScale(8),
	weight	= 700,
	antialias = true
})

local funnydraw = GetConVar("r_drawtranslucentworld")

ENT.SpawnScale = 0
function ENT:Initialize()
	self:DrawShadow(false)
end


function ENT:Think()
	self.BaseClass.Think(self)

	if not self:GetIsBeingDeleted() then
		LocalPlayer().ActiveBusMarkers = LocalPlayer().ActiveBusMarkers or {}
		table.insert(LocalPlayer().ActiveBusMarkers, self)
	end

	-- Approach spawn scale for a nice womp in
	local goalScale = self.GetIsBeingDeleted and self:GetIsBeingDeleted() and 0 or 1
	self.SpawnScale = math.Approach(self.SpawnScale, goalScale, FrameTime() * 5)
	self:SetModelScale(math.max( 0.001, self.SpawnScale ) )

end

function ENT:AddJazzRenderBeam(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	self.BusCallerPlayers = self.BusCallerPlayers or {}
	self.BusCallerPlayers[ply:SteamID()] = ply
end

function ENT:Draw()
	--jazzvoid.SetupVoidLighting(self,0.5)
	self:DrawModel()
	--render.SuppressEngineLighting(false)
end

local function drawSemiCircle(cx, cy, w, h, perc)
	local verts = {{x = cx, y = cy}}

	for i=0,32 do
		local rad = perc * 2 * math.pi * i / 32.0
		table.insert(verts, {
			x = math.cos(rad) * w + cx,
			y = math.sin(rad) * h + cy
		})
	end

	surface.DrawPoly(verts)
end

local function getHeldMarker()
	local wep = LocalPlayer():GetWeapon("weapon_buscaller")
	if not IsValid(wep) or wep != LocalPlayer():GetActiveWeapon() then return nil end

	local marker = wep:GetBusMarker()
	return IsValid(marker) and marker or nil
end

local function renderPlayerBeam(marker, ply)
	if not IsValid(ply) then return false end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() != "weapon_buscaller" then return false end
	if wep:GetBusMarker() != marker then return false end

	-- Get attach point of gun's muzzle
	local attach = ply:GetShootPos()
	local attachIdx = wep.AttachIdx or 1

	if attachIdx > 0 then
		local wepattach = wep:GetAttachment(attachIdx)
		if wepattach then attach = wepattach.Pos end-- World model position, at very least
		
		local vm = ply:GetViewModel()
		if wep:IsCarriedByLocalPlayer() and IsValid(vm) then
			local attachInfo = vm:GetAttachment(attachIdx)
			if attachInfo then attach = attachInfo.Pos end -- View model position
		end
	end
	
	--just kidding check for bus stop
	local busstop = wep:GetBusStop()
	if IsValid(busstop) then
		attach = busstop:GetAttachment(busstop:LookupAttachment("sign")).Pos
	end

	-- Draw beam
	local dist = attach:Distance(marker:GetPos())
	local offset = -CurTime()*4

	render.SetMaterial(BeamMat)
	render.DrawBeam(attach, marker:GetPos(), 3, offset, dist/100 + offset, color_blue)
	return true
end

local function drawdembeams()
	local markers = LocalPlayer().ActiveBusMarkers
	if !markers or #markers == 0 then return end

	for _, v in pairs(markers) do
		-- Render the beams for each player
		local activePlayers = v.BusCallerPlayers or {}
		for _, ply in pairs(activePlayers) do
			if IsValid(ply) and !renderPlayerBeam(v, ply) then
				v.BusCallerPlayers[ply:SteamID()] = nil
			end
		end
	end
end

hook.Add("PostDrawOpaqueRenderables", "JazzDrawBusMarkerBeams", function()
	--work around for a bug where translucent won't render
	if funnydraw:GetBool() == false then
		drawdembeams()
	end
end )

hook.Add("PostDrawTranslucentRenderables", "JazzDrawBusMarkerBeams", function()
	drawdembeams()
end )

hook.Add( "PostDrawHUD", "JazzDrawBusMarker", function()
	local markers = LocalPlayer().ActiveBusMarkers
	if !markers or #markers == 0 then return end

	cam.Start2D()
		local pfov = LocalPlayer():GetFOV()
		local eyepos = LocalPlayer():EyePos()
		local eyeang = LocalPlayer():EyeAngles()

		for _, v in pairs(markers) do
			if !IsValid(v) then continue end
			local heldMarker = getHeldMarker()

			local isLookNotHold = v:IsLookingAt(eyepos, eyeang:Forward(), pfov) and !heldMarker
			local isLook = (v == heldMarker) or isLookNotHold
			local isMoving = v:GetSpawnPercent() > 0
			v.SmoothPercent = v.SmoothPercent or 0
			v.SmoothPercent = math.Approach(v.SmoothPercent, v:GetSpawnPercent(), FrameTime() * 0.25)

			-- ToScreen only works in a 3d rendering context....
			local scrpos = nil
			cam.Start3D() scrpos = v:GetPos():ToScreen() cam.End3D()

			local x = math.Clamp(scrpos.x, 100, ScrW() - 100)
			local y = math.Clamp(scrpos.y, 100, ScrH() - 100)

			local radius = (ScrW() / 2) * math.tan(math.rad(90 - pfov/2)) * math.tan(math.rad(v.CircleCone))
			surface.SetDrawColor( 255, 0, 0, 255 )
			draw.NoTexture()
			//surface.DrawCircle(x, y, radius, 255, isLook and 0 or 255, 255, 100)

			draw.NoTexture()
			surface.SetDrawColor(255, 255, 255, 100)
			drawSemiCircle(x, y, radius * 0.73, radius* 0.73, v:GetSpawnPercent())

			local size = radius * 2.55
			ReticleCircleMaterial:SetFloat("$glowstart", isLook and 0 or 1)
			ReticleCircleMaterial:SetFloat("$glowend", 1.0)
			ReticleCircleMaterial:SetFloat("$glowalpha", 2)

			ReticleCircleMaterial:SetFloat("$edgesoftnessstart", .48)
			ReticleCircleMaterial:SetFloat("$edgesoftnessend", 0.4 - v:GetSpawnPercent() * 0.4)

			ReticleCircleMaterial:SetVector("$glowcolor", Vector(255/255.0, 247/255.0, 114/255.0))
			surface.SetMaterial(ReticleCircleMaterial)
			surface.SetDrawColor(255, isLook and 247 or 255, isLook and 114 or 255, 255)
			surface.DrawTexturedRect(x - size/2, y - size/2, size, size)

			local size = radius * 1
			surface.SetMaterial(ReticleCenterMaterial)
			surface.SetDrawColor(255, 255, 255, 255)
			local rot = math.sin(CurTime()* 4) * 20
			rot = rot + ( v.SmoothPercent + math.pow(v.SmoothPercent * 100, 2))

			surface.DrawTexturedRectRotated(x, y, size, size, rot)

			//Draw hint to hold mouse1 while hovered
			if isLookNotHold then
				draw.DrawText(string.upper(jazzloc.Localize("jazz.weapon.buscaller.holdhint",jazzloc.Localize(input.LookupBinding("+attack")))), "JazzMouseHint", x, y + radius - ScreenScale(4), Color(255, 247, 114, 255), TEXT_ALIGN_CENTER)
			end

			//draw.DrawText(tostring(v:GetSpawnPercent()), nil, x, y)
		end
	cam.End2D()

	LocalPlayer().ActiveBusMarkers = {}
end )

hook.Add("PreDrawHalos", "JazzDrawBusMarkerHalos", function()
	local wobbly = math.sin(CurTime())
	halo.Add(ents.FindByClass("jazz_bus_marker"), Color(240 - wobbly * 15, 90 - wobbly * 40, 222 + wobbly * 30), 15 + wobbly * 5, 7 - wobbly * 3)
end)