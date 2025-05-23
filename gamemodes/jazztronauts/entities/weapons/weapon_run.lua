if SERVER then
	AddCSLuaFile()
end

SWEP.Base					= "weapon_basehold"
SWEP.PrintName				= jazzloc.Localize("jazz.weapon.run")
SWEP.Slot					= 2
SWEP.Category				= "#jazz.weapon.category"
SWEP.Purpose				= jazzloc.Localize("jazz.weapon.run.desc")
SWEP.AutoSwitchFrom			= false

SWEP.WepSelectIcon = "r"
SWEP.WepSelectColor = Color(247,92,30)
SWEP.AutoIconAngle = Angle(25, 90, 0)

SWEP.ViewModel				= "models/weapons/c_run.mdl"
SWEP.WorldModel				= "models/weapons/w_run.mdl"

SWEP.UseHands		= true

SWEP.HoldType				= "duel"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 0.1
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "weapons/357/357_fire2.wav" )
SWEP.Primary.Automatic		= false

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo		= "none"

SWEP.Spawnable				= true
SWEP.RequestInfo			= {}
SWEP.JumpMultiplier			= 1
SWEP.CrouchTime				= -1
SWEP.JumpChargeSound		= Sound( "sierra/run/jump_chargeup.wav" )

SWEP.Falling				= false

local walkspeedinvert = CreateClientConVar("jazz_run_invert_walk_toggle",0,true,true,"By default, sprinting will disable Run's speed boost.\n\tSet this to 1 to cause speed boost to ONLY be provided when sprinting. Set to -1 to remove sprint disabling run speed entirely.",-1,1)

cvars.AddChangeCallback("jazz_run_invert_walk_toggle", function(name, old, new)
	for _, self in ipairs( ents.FindByClass("weapon_run") ) do
		timer.Simple(0,function() --wait a frame to update
			if not IsValid(self) then return end
			local owner = self:GetOwner()
			if IsValid(owner) then
				self:SetWalkingToggle(tobool( owner:GetInfoNum("jazz_run_invert_walk_toggle", 0) ))
				self:SetWalkingToggleDisable(owner:GetInfoNum("jazz_run_invert_walk_toggle", 0) < 0)
			end
		end)
	end
end)

-- List this weapon in the store
local storeRun = jstore.Register(SWEP, 10000, { type = "tool" })

-- No fall damage upgrade
local run_nofall = jstore.Register("run_nofall", 15000, {
	name = jazzloc.Localize("jazz.weapon.run.upgrade.nofall"),
	--cat = jazzloc.Localize("jazz.weapon.run"),
	desc = jazzloc.Localize("jazz.weapon.run.upgrade.nofall.desc"),
	type = "upgrade",
	requires = storeRun
})

-- Super Jump
local run_highjump = jstore.Register("run_highjump", 25000, {
	name = jazzloc.Localize("jazz.weapon.run.upgrade.highjump"),
	desc = jazzloc.Localize("jazz.weapon.run.upgrade.highjump.desc"),
	type = "upgrade",
	requires = run_nofall
})

-- Reduce physics damage
local run_propbump = jstore.RegisterSeries("run_propbump", 15000, 6, {
	name = jazzloc.Localize("jazz.weapon.run.upgrade.propbump"),
	desc = function(num) local num = num or 0 return jazzloc.Localize("jazz.weapon.run.upgrade.propbump.desc",15*num,num) end,
	type = "upgrade",
	requires = storeRun,
	priceMultiplier = 1.1,
})

-- Block trigger_hurt damage
local run_radsuit = jstore.RegisterSeries("run_radsuit", 1000, 8, {
	name = jazzloc.Localize("jazz.weapon.run.upgrade.radsuit"),
	desc = function(num) local num = num or 0 return jazzloc.Localize("jazz.weapon.run.upgrade.radsuit.desc", math.Round((1 - (1 / math.pow(2,num))) * 100, 1), 10 - num) end,
	type = "upgrade",
	requires = storeRun,
	priceMultiplier = 2,
})

--haha just kidding what if these chargesound functions don't work on the client on the first life
function SWEP:PlayChargeSound(pitch)
	
	if SERVER then return end

	self.ChargeSound:Play()
	self.ChargeSound:ChangeVolume(1)
	local pitch = pitch or 100

	self.ChargeSound:ChangePitch(pitch)

end

function SWEP:StopChargeSound()
	
	if SERVER then return end
	self.ChargeSound:ChangePitch(70)
	self.ChargeSound:Stop()
end

function SWEP:Initialize()

	self.BaseClass.Initialize( self )
	self:SetWeaponHoldType( self.HoldType )
	self.ChargeSound = CreateSound( self, self.JumpChargeSound )

	self.LastThink = CurTime()
	self.JumpMultiplier	= 1
	self.CrouchTime = -1

	if CLIENT then
		self:SetUpgrades()
	end
	if SERVER then
		timer.Simple(0,function() --no owner on first frame of server life
			local owner = self:GetOwner()
			if IsValid(owner) then
				self:SetWalkingToggle(tobool( owner:GetInfoNum("jazz_run_invert_walk_toggle", 0) ))
				self:SetWalkingToggleDisable(owner:GetInfoNum("jazz_run_invert_walk_toggle", 0) < 0)
			end
		end)
	end
end

function SWEP:OwnerChanged()
	self.JumpMultiplier	= 1
	self.CrouchTime	= -1
	self:SetUpgrades()
end

-- Query and apply current upgrade settings to this weapon
function SWEP:SetUpgrades()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self.IgnoreFallDamage = unlocks.IsUnlocked("store", owner, run_nofall)
	self.HighJump = unlocks.IsUnlocked("store", owner, run_highjump)
end

function SWEP:ShouldTakeFallDamage()
	return not self.IgnoreFallDamage
end
function SWEP:PhysDmgScale()
	return math.max(0,1 - (jstore.GetSeries(self:GetOwner(), run_propbump) * 0.15 or 0))
end
function SWEP:PhysDmgLevel()
	return jstore.GetSeries(self:GetOwner(), run_propbump) or 0
end

function SWEP:TriggerHurtScale()
	return 1 / math.pow(2,jstore.GetSeries(self:GetOwner(), run_radsuit))
end
function SWEP:TriggerHurtLevel()
	return jstore.GetSeries(self:GetOwner(), run_radsuit) or 0
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", "WalkingToggle") --if we have our sprint-to-walk toggle enabled
	self:NetworkVar("Bool", "WalkingToggleDisable") --if we have our sprint-to-walk toggle enabled
	self:NetworkVar("Float", "OldRunSpeed")
	self:NetworkVar("Float", "OldWalkSpeed")
	self:NetworkVar("Float", "OldJumpPower")
	self.BaseClass.SetupDataTables( self )
end

function SWEP:Deploy()

	if SERVER then
		local owner = self:GetOwner()
		if IsValid(owner) then
			self:SetOldRunSpeed( owner:GetRunSpeed() )
			self:SetOldWalkSpeed( owner:GetWalkSpeed() )
			self:SetOldRunSpeed( owner:GetRunSpeed() / (owner.JazzSizeMultiplier or 1) )
			self:SetOldWalkSpeed( owner:GetWalkSpeed() / (owner.JazzSizeMultiplier or 1) )
			self:SetOldJumpPower( owner:GetJumpPower() / ( math.min( 1, (owner.JazzSizeMultiplier and owner.JazzSizeMultiplier * 2) or 1 ) ) )
		end
	else
		self.ChargeSound:SetSoundLevel(75)
		self.ChargeSound:ChangePitch(70)
	end

	self.JumpMultiplier	= 1
	self.CrouchTime	= -1

	self:SendWeaponAnim(ACT_VM_IDLE)

	return true

end

function SWEP:Cleanup()

	local owner = self:GetOwner()

	if self:GetOldRunSpeed() ~= 0 and IsValid(owner) then
		owner:SetRunSpeed( self:GetOldRunSpeed() * (owner.JazzSizeMultiplier or 1) )
		owner:SetWalkSpeed( self:GetOldWalkSpeed() * (owner.JazzSizeMultiplier or 1) )
		owner:SetJumpPower( self:GetOldJumpPower() * ( math.min( 1, (owner.JazzSizeMultiplier and owner.JazzSizeMultiplier * 2) or 1 ) ) )
	end
	
	if CLIENT and IsValid(owner) then
		--clean up posing
		local arm_right = owner:LookupBone( "ValveBiped.Bip01_R_UpperArm" )
		local arm_right2 = owner:LookupBone( "ValveBiped.Bip01_R_ForeArm" )
		local arm_left = owner:LookupBone( "ValveBiped.Bip01_L_UpperArm" )
		local arm_left2 = owner:LookupBone( "ValveBiped.Bip01_L_ForeArm" )
		local spine = owner:LookupBone( "ValveBiped.Bip01_Spine1" )

		if arm_left and arm_left2 then
			owner:ManipulateBoneAngles( arm_left, angle_zero )
			owner:ManipulateBoneAngles( arm_left2, angle_zero )
		end

		if arm_right and arm_right2 then
			owner:ManipulateBoneAngles( arm_right, angle_zero )
			owner:ManipulateBoneAngles( arm_right2, angle_zero )
		end

		if spine then
			owner:ManipulateBoneAngles( spine, angle_zero )
		end

	end

	--self:StopChargeSound()
	self.ChargeSound:ChangePitch(70)
	self.ChargeSound:Stop()

end

function SWEP:DrawWorldModel()

	self:DrawModel()

	local ent = self:GetOwner()

	if not IsValid( ent ) then return end

	local arm_right = ent:LookupBone( "ValveBiped.Bip01_R_UpperArm" )
	local arm_right2 = ent:LookupBone( "ValveBiped.Bip01_R_ForeArm" )
	local arm_left = ent:LookupBone( "ValveBiped.Bip01_L_UpperArm" )
	local arm_left2 = ent:LookupBone( "ValveBiped.Bip01_L_ForeArm" )
	local spine = ent:LookupBone( "ValveBiped.Bip01_Spine1" )


	--[[for i=0, ent:GetBoneCount() do

		print( tostring( ent:GetBoneName( i ) ) )

	end]]

	local t = 0--CurTime() * 1000

	local v = math.min( ent:GetVelocity():Length() / 100, 1 )

	if ent:OnGround() then t = 0 end

	if arm_left and arm_left2 then
		ent:ManipulateBoneAngles( arm_left, Angle(0,80*v,0) )
		ent:ManipulateBoneAngles( arm_left2, Angle(0,80*v,0) )
	end

	if arm_right and arm_right2 then
		ent:ManipulateBoneAngles( arm_right, Angle(0,100*v,0) )
		ent:ManipulateBoneAngles( arm_right2, Angle(0,70*v,0) )
	end

	if spine then
		ent:ManipulateBoneAngles( spine, Angle(0,30*v,0) )
	end

end

function SWEP:PreDrawViewModel(viewmodel, weapon, ply)

	if IsValid(ply) then
        local movex = ply:GetPoseParameter("move_x") or 0.5
        local movey = ply:GetPoseParameter("move_y") or 0.5
		local playback = 0.5 + ply:GetVelocity():Length2DSqr() / 1280000 --(800 * 800 * 2)
		
        self.CurPoseX = self.CurPoseX or 0.5
        self.CurPoseY = self.CurPoseY or 0.5
		self.CurPlayback = self.CurPlayback or 0.5

        -- Approach goal
        local APPROACH_SPEED = 2
        self.CurPoseX = math.Approach(self.CurPoseX, movex, FrameTime() * APPROACH_SPEED)
        self.CurPoseY = math.Approach(self.CurPoseY, movey, FrameTime() * APPROACH_SPEED)
		self.CurPlayback = math.Approach(self.CurPlayback, playback, FrameTime() * APPROACH_SPEED)

		local walkmultiplier = (not self:GetWalkingToggleDisable() and self:GetWalkingToggle() ~= ply:KeyDown(IN_SPEED)) and .8 or 1
		local playmultiplier = (not self:GetWalkingToggleDisable() and self:GetWalkingToggle() ~= ply:KeyDown(IN_SPEED)) and .5 or 1
        viewmodel:SetPoseParameter("move_x", math.Remap( self.CurPoseX, 0, 1, -1, 1) * walkmultiplier)
        viewmodel:SetPoseParameter("move_y", math.Remap( self.CurPoseY, 0, 1, -1, 1) * walkmultiplier)
		viewmodel:SetPlaybackRate(self.CurPlayback * playmultiplier)
    end

end

function SWEP:DrawHUD()

end

function SWEP:CalcViewModelView( viewmodel, oldpos, oldang, pos, ang )

	return pos, ang

end

function SWEP:CalcView( ply, pos, ang, fov )

	return pos, ang, fov

end

function SWEP:Think()

	local owner = self:GetOwner()

	if IsValid(owner) then
		--view model animations
		local oldfall = self.Falling
		
		self.Falling = owner:OnGround() == false and owner:GetVelocity().z < -100
		if oldfall ~= self.Falling then self:SendWeaponAnim(self.Falling and ACT_VM_HAULBACK or ACT_VM_IDLE) end
		
		--high jump charging
		if self.HighJump then
			if owner:Crouching() then
				if self.CrouchTime < 0 then
					--print("crouching at "..tostring(CurTime()))
					self.CrouchTime = CurTime()
					--self:PlayChargeSound(math.Remap(self.JumpMultiplier,1,3,70,150))
					self.ChargeSound:Play()
					self.ChargeSound:ChangeVolume(1)
					self.ChargeSound:ChangePitch(math.Remap(self.JumpMultiplier,1,3,70,150))
				end
			else
				--if self.CrouchTime > 0 then print("uncrouch") end
				self.CrouchTime = -1
			end
			if self.CrouchTime > 0 and self.CrouchTime <= CurTime() - 1 then --wait a second to start charging
				if self.JumpMultiplier < 3 then
					self.JumpMultiplier = math.min(3,self.JumpMultiplier + (CurTime() - self.LastThink) * .5)
				else
					self.JumpMultiplier = 3
				end
				--self:PlayChargeSound(math.Remap(self.JumpMultiplier,1,3,70,150))
				self.ChargeSound:Play()
				self.ChargeSound:ChangeVolume(1)
				self.ChargeSound:ChangePitch(math.Remap(self.JumpMultiplier,1,3,70,150))
			end
			--drain full jump power with movement
			if not owner:Crouching() or owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT) then
				if self.CrouchTime > 0 then
					self.CrouchTime = math.min(self.CrouchTime,CurTime() - .75) --slight delay to recharge
					--print("moving while crouched, crouch time now "..tostring(self.CrouchTime))
				end
				self.JumpMultiplier = math.max(1,self.JumpMultiplier - (CurTime() - self.LastThink) * 2)
			end

			if self.CrouchTime < 0 or self.JumpMultiplier <= 1 or owner:InVehicle() or not owner:Alive() then
				--self:StopChargeSound()
				self.ChargeSound:ChangePitch(70)
				self.ChargeSound:Stop()
			end
		end
		local runspeed = (not self:GetWalkingToggleDisable() and self:GetWalkingToggle() ~= owner:KeyDown(IN_SPEED)) and self:GetOldWalkSpeed() or 800 --let player hold sprint to go at regular speed
		owner:SetWalkSpeed( runspeed * (owner.JazzSizeMultiplier or 1) )
		owner:SetRunSpeed( runspeed * (owner.JazzSizeMultiplier or 1) )
		--print(self.CrouchTime, self.JumpMultiplier)
		owner:SetJumpPower( 500 * self.JumpMultiplier  * ( math.min( 1, ( owner.JazzSizeMultiplier and owner.JazzSizeMultiplier * 4) or 1) ) )
	end
	self.LastThink = CurTime()
end

function SWEP:CanPrimaryAttack()

	return true

end

function SWEP:PrimaryAttack()

	self.BaseClass.PrimaryAttack( self )

end

function SWEP:ShootEffects()

	local owner = self:GetOwner()
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )

end

function SWEP:Reload() return false end
function SWEP:CanSecondaryAttack() return false end

function SWEP:GetPlayerColor()
	local owner = self:GetOwner()
	if not IsValid(owner) then return nil end
	return owner:GetPlayerColor()
end
