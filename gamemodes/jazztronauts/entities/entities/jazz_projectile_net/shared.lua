AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.OuterSphereModel = Model("models/sunabouzu/toycapsule.mdl")

function ENT:Initialize()
	if self:GetRadius() == 0 then
		self:SetRadius(2)
	end
	local outerRadius = self:GetRadius()

	if SERVER then
		self:EnableCustomCollisions(true)
		self:PhysicsInitSphere(outerRadius, "glass")
		self:GetPhysicsObject():SetMass(1)
		self:SetSolid(SOLID_VPHYSICS)

		self:GetPhysicsObject():AddAngleVelocity(VectorRand() * 10000)
		--self:NextThink(CurTime())
	end

	local maxs = Vector(1, 1, 1) * outerRadius/2
	self:SetCollisionBounds(-maxs, maxs)

	self.CreationTime = CurTime()
	self:DrawShadow(false)
	self.used = false

	if CLIENT then
		self:SetupModel()
	end
end

function ENT:OnTakeDamage(dmginfo)
	self:TakePhysicsDamage( dmginfo )
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Radius")
end

function ENT:OnRemove()

end

--wanted it to grow a bit as it flies but fuck me I guess
/*if SERVER then
	function ENT:Think()
		local time = CurTime() - self.CreationTime
		if time > 0 then
			if time < 1 then
				self:SetRadius(time * 32)
				self:NextThink(CurTime())
				local maxs = Vector(1, 1, 1) * (time * 16)
				self:SetCollisionBounds(-maxs, maxs)
			else
				self:SetRadius(32)
				local maxs = Vector(16, 16, 16)
				self:SetCollisionBounds(-maxs, maxs)
			end
		else
			self:NextThink(CurTime())
		end
		return true
	end
--end --*/

local catreacts = {
	2, --bartender
	6, --singer
	2, --pianist
	2 --cellist
}

local acceptEnts = {
	["prop_physics"] = function(prop) return true end,
	["prop_physics_multiplayer"] = function(prop) return true end,
	["prop_ragdoll"] = function(prop) return true end,
	["prop_dynamic"] = function(prop) return (prop:GetName() == nil or prop:GetName() == "") end,
	["jazz_factscreen"] = function(prop) return true end,
	["item_healthcharger"] = function(prop) return true end,
}
acceptEnts.prop_dynamic_override = acceptEnts.prop_dynamic

function ENT:PhysicsCollide( data, ent )
	--prevents weirdness later
	if self.used then return end
	self.used = true

	--effects, spark and crackle
	local effect = EffectData()
	effect:SetOrigin( data.HitPos )
	util.Effect( "cball_bounce", effect )
	self:EmitSound( "GlassBottle.Break", 75, math.random( 120, 135 ), 1, CHAN_ITEM, SND_NOFLAGS )

	--the meat, what do we hit
	local hit = data.HitEntity
	if IsValid(hit) then
		--ow!
		if hit:GetClass() == "jazz_cat" then
			local cat = hit:GetNPCID()
			local oldface = hit:GetSkin()
			if not (cat == 4 and oldface == 3) then --too high
				hit:SetSkin(catreacts[cat])
				timer.Simple(2, function()
					if IsValid(hit) and hit:GetSkin() == catreacts[cat] then --make sure we didn't change face some other way
						hit:SetSkin(oldface)
					end
				end)
			end
		elseif hit:IsNPC() or hit:IsPlayer() or hit:IsWeapon() or (acceptEnts[hit:GetClass()] and acceptEnts[hit:GetClass()](hit)) then
			--complains about changing collision rules while in a callback if we do it same frame
			timer.Simple(0, function()
			local cap = ents.Create("jazz_prop_sphere")
				if IsValid(cap) and IsValid(hit) then
					--find bounds center to prevent spawning halfway into floor
					local pos = hit:GetPos()
					local min, max = hit:GetModelBounds()
					max:Add(-min)
					pos.z = pos.z + max.z / 2 --todo: should be moved half up *world* Z rather than assuming the object is upright?
					cap:SetModel(hit:GetModel())
					cap:SetPos(pos)
					cap:SetAngles(hit:GetAngles())
					cap:SetRadius(max.z / 2)
					cap:SetNetGun(true)
					cap:Spawn()
					cap.JazzWorth = (hit.JazzWorth and hit.JazzWorth or 1) * 2 
					if not hit:IsPlayer() then hit:Remove() else hit:Kill() end --todo: make player ragdoll funny happen
				end
			end)
		end
	end

	timer.Simple(0, function() if IsValid(self) then self:Remove() end end)
end

if SERVER then return end

local function getInnerRadius(ent)
	local min, max = ent:GetModelBounds()
	local rad = 0
	for i=1, 3 do
		rad = math.max( max[i] - min[i] , rad )
	end

	return rad / 2
end

local function getBoundingRadius(ent)
	local min, max = ent:GetModelBounds()
	local center = (min + max) / 2

	return center:Distance(max)
end

function ENT:SetupModel()
	local maxs = Vector(1, 1, 1) * self:GetRadius()/2
	self:SetRenderBounds(-maxs, maxs)

	self.SphereModel = ClientsideModel(self.OuterSphereModel)

	/*

	local scale = getInnerRadius(self) / radius
	*/

	self:UpdateMeshes()
end

function ENT:GetRandomColor()
	local h = util.SharedRandom("jazz_toycolor", 0, 360, self:EntIndex())

	return HSVToColor(h, 1, 1)
end

function ENT:UpdateMeshes()
	if IsValid(self.SphereModel) and self.SphereModel:GetParent() != self then
		local min, max = self:GetModelBounds()
		local center = (max + min) / 2
		local radius = getInnerRadius(self.SphereModel)
		local sphereScale = self:GetRadius() / radius
		local propScale = self:GetRadius() / getBoundingRadius(self)

		-- Update outer sphere model scale
		self.SphereModel:SetPos(self:GetPos())
		self.SphereModel:SetAngles(self:GetAngles())
		self.SphereModel:SetParent(self)
		self.SphereModel:SetModelScale(sphereScale)
		self.SphereModel:SetColor(self:GetRandomColor())

		-- Update render transform for the inside prop
		local scaleMat = Matrix()
		scaleMat:SetTranslation(-center * propScale)
		scaleMat:SetScale(Vector(propScale, propScale, propScale))

		//self:DisableMatrix("RenderMultiply")
		self:EnableMatrix("RenderMultiply", scaleMat)
	end
end

function ENT:OnRemove()
	if IsValid(self.SphereModel) then
		self.SphereModel:Remove()
	end
end

function ENT:Draw()
	self:UpdateMeshes()
	if IsValid(self.SphereModel) then self.SphereModel:DrawModel() end
	render.SuppressEngineLighting(true)
	if self:GetModel() ~= "models/error.mdl" then self:DrawModel() end
	render.SuppressEngineLighting(false)
end
