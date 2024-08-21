module( "jazzvoid", package.seeall )

local refract = Material("effects/jazz_void_refract.vmt")
void_mat = refract
snatch.void_mat = void_mat

should_render_hub = CreateConVar("jazz_void_renderinhub", 1, bit.bor(FCVAR_PROTECTED, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE, FCVAR_UNLOGGED, FCVAR_UNREGISTERED),"",0,1)

should_render = should_render or true

-- Performance convars
convar_drawprops = CreateClientConVar("jazz_void_drawprops", "1", true, false, "Render additional props/effects in the jazz void.")
convar_drawonce = CreateClientConVar("jazz_void_drawonce", "0", true, false, "Don't render the void for water reflections, mirrors, or additional scenes. Will introduce rendering artifacts in water/mirrors, but is much faster.")
convar_resscale = CreateClientConVar("jazz_void_resolution_scale", "1.0", true, false, "Resolution scale to render the void at. 1.0 is full screen resolution, 0.5 is half resolution.")

-- Void rendering parameters
local surfaceMaterial = Material("sunabouzu/JazzShell") //glass/reflectiveglass002 brick/brick_model
overlayColor = Color(255, 255, 255, 255)

void_prop_count = 10
void_prop_side = math.ceil(math.pow(void_prop_count, 1/3.0))
void_view_offset = Vector()

function CreateVoidRT()
	local renderScale = math.Clamp(convar_resscale:GetFloat(), 0, 8)
	local rt = irt.New("jazz_snatch_voidbg", ScrW() * renderScale, ScrH() * renderScale)
	rt:EnableDepth( true, true )

	return rt
end

-- Create the render target at least once on client startup
local rt = rt or CreateVoidRT()

-- Also recreate if they change the resolution scale
cvars.AddChangeCallback(convar_resscale:GetName(), function(name, old, new)
	rt = CreateVoidRT()
end, "jazz_void_res_callback")

function GetVoidTexture()
	return rt:GetTarget()
end

function GetVoidOverlay()
	return void_mat, surfaceMaterial
end

function SetOverlayColor(col)
	overlayColor = col
end

function GetOverlayColor()
	return overlayColor
end

function SetOverlayRefract(amt)
	void_mat:SetFloat("$refractamount", amt)
end

function SetShouldRender(shouldRender)
	should_render = shouldRender
end

function GetShouldRender()
	return should_render
end

local function SharedRandomVec(seed)
	return Vector(
		util.SharedRandom("x", 0, 1, seed),
		util.SharedRandom("y", 0, 1, seed),
		util.SharedRandom("z", 0, 1, seed))
end

local function ModVec(vec, mod)
	vec.x = vec.x % mod
	vec.y = vec.y % mod
	vec.z = vec.z % mod
	return vec
end

local function MapVec(vec, func)
	vec.x = func(vec.x)
	vec.y = func(vec.y)
	vec.z = func(vec.z)
	return vec
end

-- Render the entire void scene
local propProximityFade = 200
local range = 9000.0
local zrangediv = 8
local hRangeVec = Vector(range/2, range/2, range/2)
local function renderFollowCats(plyPos)

	local skull = ManagedCSEnt("jazz_snatchvoid_skull", "models/krio/jazzcat1.mdl")
	skull:SetNoDraw(true)
	skull:SetModelScale(4)

	for i=1, void_prop_count do

		-- Create a "treadmill" so they don't move until they get far away, then wrap around

		local basex = (i - 1) % void_prop_side
		local basey = math.floor((i - 1) / void_prop_side) % void_prop_side
		local basez = math.floor((i - 1) / math.pow(void_prop_side, 2))
		local basevec = Vector(basex, basey, basez)

		local modvec = ModVec(plyPos + (basevec / void_prop_side + SharedRandomVec(i) * 0.3) * range, range)
		local p = plyPos - modvec + hRangeVec

		-- Mod z even closer
		local zrange = range / zrangediv
		modvec.z = modvec.z % (zrange)
		p.z = plyPos.z - modvec.z + (hRangeVec.z/zrangediv)

		skull:SetPos(p)

		-- Face the player
		local ang = (skull:GetPos() - plyPos):Angle()
		skull:SetAngles(ang)
		skull:SetupBones()

		-- Calculate the 'distance' from the center by where they are in the offset
		local d = MapVec(math.pi * modvec / range, math.sin)
		d.z = math.sin(math.pi * modvec.z / zrange)

		-- Fade out if it's super close
		local dfade = MapVec( modvec - hRangeVec, math.abs) / propProximityFade

		-- Apply blending and draw
		local distFade = math.max(0, 2.0 - dfade:Length())
		local alpha = math.min(d.x, d.y, d.z) - distFade
		if alpha > 0 then
			render.SetBlend(alpha)
			skull:DrawModel()
		end

	end
end
local function renderVoid(eyePos, eyeAng, fov)

	local oldW, oldH = ScrW(), ScrH()
	local sizeX, sizeY = rt.width, rt.height
	render.Clear( 0, 0, 0, 0, true, true )
	render.SetViewPort( 0, 0, sizeX, sizeY )

	local eyeOffset = eyePos + void_view_offset
	local oldFog = render.GetFogMode()
	render.SuppressEngineLighting(true)
	render.FogMode(MATERIAL_FOG_NONE)

	-- Skybox pass
	cam.Start3D(Vector(), eyeAng, fov, 0, 0, sizeX, sizeY)
		-- Render the sky first, don't write to depth so everything draws over it
		render.OverrideDepthEnable(true, false)
			hook.Call("JazzPreDrawVoidSky", GAMEMODE)

			local tunnel = ManagedCSEnt("jazz_snatchvoid_tunnel", "models/props/jazz_dome.mdl")
			tunnel:SetNoDraw(true)
			tunnel:SetPos(Vector())
			tunnel:SetupBones()

			-- Draw the background with like a million different materials because
			-- fuck it they're all additive and look pretty
			tunnel:SetMaterial("sunabouzu/JazzLake01")
			tunnel:DrawModel()

			tunnel:SetMaterial("sunabouzu/JazzSwirl01")
			tunnel:DrawModel()

			tunnel:SetMaterial("sunabouzu/JazzSwirl02")
			tunnel:DrawModel()

			tunnel:SetMaterial("sunabouzu/JazzSwirl03")
			tunnel:DrawModel()

		hook.Call("JazzPostDrawVoidSky", GAMEMODE)
		render.OverrideDepthEnable(true, true)
	cam.End3D()


	-- Random props pass
	if convar_drawprops:GetBool() then

	-- Pre draw void with movement offset
	cam.Start3D(eyeOffset, eyeAng, fov, 0, 0, sizeX, sizeY)
		hook.Call("JazzPreDrawVoidOffset", GAMEMODE)

		renderFollowCats(eyeOffset)
	cam.End3D()

	-- Pre draw and draw void without movement offset
	cam.Start3D(eyePos, eyeAng, fov, 0, 0, sizeX, sizeY)
		hook.Call("JazzPreDrawVoid", GAMEMODE)

		render.SetBlend(1) -- Finished, reset blend
		render.ClearDepth()

		render.OverrideDepthEnable(false)
		hook.Call("JazzDrawVoid", GAMEMODE)

	cam.End3D()

	-- Draw void WITH movement offset
	cam.Start3D(eyeOffset, eyeAng, fov, 0, 0, sizeX, sizeY)
		hook.Call("JazzDrawVoidOffset", GAMEMODE)
	cam.End3D()

	end

	-- Draw Busstops
	for _, v in ipairs(ents.FindByClass("jazz_stanteleportmarker")) do
		if not IsValid(v) or not v:GetBusMarker() then continue end
		v:DrawModel()
	end

	render.OverrideDepthEnable(false)
	render.FogMode(oldFog)
	render.SuppressEngineLighting(false)

	render.SetViewPort( 0, 0, oldW, oldH )
end

-- Render the brush lines, keeping performant by only rendering a few at a time over the span of many frames
local offset = 0
local maxlinecount = 25
local nextgrouptime = 0
local groupFadeTime = 0.25
local function renderBrushLines()
	if #snatch.removed_brushes == 0 then return end

	if RealTime() > nextgrouptime then
		nextgrouptime = RealTime() + groupFadeTime

		offset = (offset + maxlinecount) % #snatch.removed_brushes
	end

	local mtx = Matrix()
	local p = (nextgrouptime - RealTime()) / groupFadeTime

	for i=1, math.min(maxlinecount, #snatch.removed_brushes) do
		local curidx = ((offset + i - 1) % #snatch.removed_brushes) + 1
		local v = snatch.removed_brushes[curidx]

		mtx:SetTranslation( v.center )

		cam.PushModelMatrix( mtx )
		v:Render(HSVToColor((CurTime() * 50 + curidx * 1) % 360, 1, p), true, nil, true)
		cam.PopModelMatrix()
	end
end

function UpdateVoidTexture(origin, angles, fov)
	rt:Render(renderVoid, origin, angles, fov)
end

-- Draw the spooky jazz world to its own texture
hook.Add("RenderScene", "snatch_void_inside", function(origin, angles, fov)
	-- If draw once is enabled, draw it once here when the scene begins
	if convar_drawonce:GetBool() then
		UpdateVoidTexture(origin, angles, fov)
	end

	-- Also make sure this is always set
	local rtTex = rt:GetTarget()
	if void_mat:GetTexture("$basetexture"):GetName() != rtTex:GetName() then
		print("Setting void basetexture")
		void_mat:SetTexture("$basetexture", rtTex)
	end
end )



local post_filter = {
	["$basetexture"] = "concrete/concretefloor001a",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$model"] = 0,
	["$additive"] = 0,
}

local post_filter2 = {
	["$basetexture"] = "concrete/concretefloor001a",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$model"] = 0,
	["$additive"] = 1,
}

local monitor_plz = {
	["$basetexture"] = "effects/map_monitor_noise",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$model"] = 0,
	["$additive"] = 0,
	["$basetexturetransform"] = "center .5 .5 scale -5 5 rotate 0 translate 0 0",
	["Proxies"] =
	{
		["AnimatedTexture"] =
		{
			["animatedTextureVar"] = "$basetexture",
			["animatedTextureFrameNumVar"] = "$frame",
			["animatedTextureFrameRate"] = "40",
		}
	}
}

local shard = {
	--["$basetexture"] = "sunabouzu/JazzSwirl03",
	["$basetexture"] = "sunabouzu/JazzLake01_a",
	--["$basetexture"] = "models/sunabouzu/jazzShard_core",
	--["$basetexturetransform"] = "center .5 .5 scale -.2 .2 rotate 0 translate 0 0",
	["$nocull"] = "1",
	["Proxies"] =
	{
		["TextureScroll"] =
		{
			["texturescrollvar"] = "$baseTextureTransform",
			["texturescrollrate"] = ".2",
			["texturescrollangle"] = "-90",
		}
	}
}

local post_filter_mat = CreateMaterial("VoidPostFilter" .. FrameNumber(), "UnLitGeneric", post_filter)
local post_filter_mat2 = CreateMaterial("VoidPostFilter2" .. FrameNumber(), "UnLitGeneric", post_filter2)
local monitor_mat = CreateMaterial("VoidStatic" .. FrameNumber(), "UnLitGeneric", shard)



-- Keep track of if we're currently rendering 3D sky so we don't draw extra
-- The 'sky' arg in PostDrawOpaqueRenderables returns true on maps without a skybox,
-- so we keep track of it ourselves
local isInSky = false
hook.Add("PreDrawSkyBox", "JazzDisableSkyDraw", function()
	isInSky = true
end )
hook.Add("PostDrawSkyBox", "JazzDisableSkyDraw", function()
	isInSky = false
end)

local color_mat = Material("model_color")

local function DrawProps()
	render.SetColorModulation(1,1,1)
	render.SuppressEngineLighting(true)
	render.MaterialOverride(monitor_mat)
	for k,v in pairs(ents.FindByClass("jazz_static_proxy")) do
		v:DrawModel()
	end
	render.MaterialOverride(nil)
	render.SuppressEngineLighting(false)
end

local function PurgeRender()
	local renderPurge = ManagedCSEnt("renderPurgeFix1", "models/hunter/blocks/cube025x025x025.mdl" ) //models/props_junk/PopCan01a.mdl, "models/hunter/blocks/cube025x025x025.mdl"
	renderPurge:SetNoDraw(true)
	renderPurge:SetModelScale(0.0001) --0 spams console now
	renderPurge:DrawModel()
end

-- Render the inside of the jazz void with the default void material
-- This void material has a rendertarget basetexture we update each frame
hook.Add( "PostDrawOpaqueRenderables", "snatch_void", function(depth, sky)
	if isInSky then return end
	if not should_render then return end

	if mapcontrol.IsInHub() and not should_render_hub:GetBool() then return end

	-- Re-render this for every new scene if not drawing once
	if not convar_drawonce:GetBool() then
		UpdateVoidTexture(EyePos(), EyeAngles(), nil)
	end

	//render.UpdateScreenEffectTexture()

	render.SuppressEngineLighting(true)
	render.SetMaterial(void_mat)
	render.MaterialOverride(void_mat)

	-- Draw all map meshes
	for _, v in pairs(snatch.map_meshes) do
		v:Get():Draw()
	end

	-- Draw again with overlay
	render.MaterialOverride(surfaceMaterial)
	render.SetMaterial(surfaceMaterial)
	render.SetColorModulation(overlayColor.r / 255.0, overlayColor.g / 255.0, overlayColor.b / 255.0)
	//render.SetBlend((overlayColor.a or 255) / 255.0)

	PurgeRender()


	for _, v in pairs(snatch.map_meshes) do
		v:Get():Draw()
	end
	render.MaterialOverride(nil)
	render.SuppressEngineLighting(false)
	render.SetColorModulation(1,1,1)
	render.SetBlend(1.0)
	--DrawProps()

	//renderBrushLines()

end )

hook.Add( "PreDrawEffects", "snatch_void_lines", function()
	//renderBrushLines()

end)

--monitor_mat = Material("models/sunabouzu/jazzShard_core")

hook.Add( "PostRender", "snatch_props", function()

	if true then return end

	local w = ScrW()
	local h = ScrH()

	local rt = irt.New("post_layer", w, h)
		:EnableDepth(true,true)
		:EnableFullscreen(false)
		:EnablePointSample(true)
		:SetAlphaBits(8)

	post_filter_mat:SetTexture("$basetexture", rt:GetTarget())
	post_filter_mat2:SetTexture("$basetexture", rt:GetTarget())
	--monitor_mat:SetVector("$color", Vector(1,.5,1))
	--monitor_mat:SetVector("$color", Vector(1,1,1))
	--monitor_mat:SetTexture("$basetexture", GetVoidTexture():GetName())


	render.UpdateScreenEffectTexture()

	render.PushRenderTarget(rt:GetTarget())
	render.Clear( 0, 0, 0, 0, true, true )

	render.OverrideAlphaWriteEnable(true, false)
	render.OverrideColorWriteEnable(true, false)
	render.RenderView({ w = w, h = h, origin = EyePos() })
	render.OverrideColorWriteEnable(false, false)
	render.OverrideAlphaWriteEnable(false, false)
	render.SetWriteDepthToDestAlpha( false )

	render.SetStencilEnable(true)
	render.SetStencilReferenceValue(1)
	render.ClearStencil()
	render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
	render.SetStencilTestMask(0x00)
	render.SetStencilWriteMask(0xFF)

	render.OverrideColorWriteEnable(true, true)
	cam.Start(
		{
			x = 0,
			y = 0,
			w = w,
			h = h,
			origin = EyePos() + EyeAngles():Forward() * .1,
		})

		DrawProps()

	cam.End()
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilWriteMask(0x00)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

	cam.Start2D()
	render.OverrideColorWriteEnable(true, false)
	--render.SetColorMaterial()
	render.SetMaterial(monitor_mat)
	render.DrawScreenQuad()
	render.OverrideColorWriteEnable(false, false)
	cam.End2D()


	render.SetStencilEnable(false)

	render.BlurRenderTarget( rt:GetTarget(), 2, 2, 10 )
	render.PopRenderTarget()

	cam.Start2D()

	surface.SetDrawColor(255,255,255,255)
	render.SetMaterial(post_filter_mat)
	render.DrawScreenQuad()

	render.SetMaterial(post_filter_mat2)
	render.DrawScreenQuad()
	render.DrawScreenQuad()
	render.DrawScreenQuad()
	render.DrawScreenQuad()
	render.DrawScreenQuad()

	cam.End2D()

end)

dialog.RegisterFunc("voidbreak", function(d)
	SetOverlayRefract(0)
	SetOverlayColor(Color(0, 0, 0))
end )

function SetupVoidLighting(ent,intensity)
	local intensity = intensity or tonumber(ent) or 1
	render.SuppressEngineLighting(true)
	render.SetModelLighting(BOX_FRONT, 100/255.0 * intensity, 0, 244/255.0 * intensity)
	render.SetModelLighting(BOX_BACK, 150/255.0 * intensity, 0, 234/255.0 * intensity)
	render.SetModelLighting(BOX_LEFT, 40/255.0 * intensity, 0, 144/255.0 * intensity)
	render.SetModelLighting(BOX_RIGHT, 100/255.0 * intensity, 0, 244/255.0 * intensity)
	render.SetModelLighting(BOX_TOP, intensity, intensity, intensity)
	render.SetModelLighting(BOX_BOTTOM, 20/255.0 * intensity, 0, 45/255.0 * intensity)

	if not IsValid(ent) then return end
	local fogOffset = EyePos():Distance(ent:GetPos())
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(100 + fogOffset)
	render.FogEnd(20000 + fogOffset)
	render.FogMaxDensity(.35)
	render.FogColor(180, 169, 224)
end