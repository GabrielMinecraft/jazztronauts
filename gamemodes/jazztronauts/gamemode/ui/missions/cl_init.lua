
surface.CreateFont( "Mission_ProgressPercent", {
	font = "KG Shake it Off Chunky",
	size = ScreenScale(10),
	weight = 500,
} )

surface.CreateFont( "Mission_Description", {
	font = "Tahoma",
	size = ScreenScale(7),
	weight = 1000,
} )

local CurAlpha = 255

local function drawProgressBar(m, x, y, width, height, prog, max, animclip)
	local perc = prog * 1.0 / max

	local flash = CurTime() - (m.progbump or 0)
	local flash2 = .5 + math.sin(8 * (flash-.5) * math.pi)/2
	if flash > 1 then flash2 = 0 else flash2 = flash2 * (1 - flash) end

	perc = math.max( perc - (1/max) * flash2 * flash2, 0 )
	perc = math.min( perc, 1 )

	if perc >= 1 then
		draw.RoundedBox(4, x, y, width, height, Color(55, 164, 44, CurAlpha))
	else
		draw.RoundedBox(4, x, y, width, height, Color(80, 0, 80, CurAlpha))
		if perc > 0 then
			draw.RoundedBox(4, x, y, width * perc, height, Color(255, 200, flash2*255, CurAlpha))
		end
	end

	local subclip = Rect(x,y,width,height)
	subclip.w = width*perc
	subclip:Clamp( animclip )
	subclip:SetClip(true)
	draw.SimpleText(prog .. "/" .. max, "Mission_ProgressPercent", x + width/2, y + height/2, Color(0, 0, 0, CurAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	subclip.x = x + width*perc
	subclip.w = width - width*perc
	subclip:Clamp( animclip )
	subclip:SetClip(true)
	draw.SimpleText(prog .. "/" .. max, "Mission_ProgressPercent", x + width/2, y + height/2, Color(255, 255, 255, CurAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local metrics = {
	width = ScreenScale(125),
	height = ScreenScale(25),
	spacing = ScreenScale(2),
}

local tables = {}
local function MissionTable(mid)
	tables[mid] = tables[mid] or {}
	return tables[mid]
end

local function DrawMission(mission, x, y)
	local font = "Mission_Description"
	local mid = mission.missionid
	local m = MissionTable(mid)
	local width = metrics.width
	local height = metrics.height
	local minfo = missions.GetMissionInfo(mid)

	if mission.progress ~= m.prev_progress then
		m.prev_progress = mission.progress
		m.progbump = CurTime()
	end

	local bumpdt = 1-math.min( CurTime() - (m.progbump or 0), 1 )
	bumpdt = bumpdt * bumpdt
	height = height + bumpdt * 10

	y = y - height

	local rect = Rect(x,y,width,height)

	m.opentimer = m.opentimer or CurTime()
	local duration = .35
	local dt = math.min( (CurTime() - m.opentimer) / duration, 1 )

	dt = math.sin( dt * math.pi/2 )

	local animclip = Rect( rect )
	animclip.w = animclip.w * dt
	animclip:SetClip(true)

	local missionstr = jazzloc.Localize(minfo.Instructions,minfo.Count)

	local tr = TextRect( missionstr, font ):Dock( rect, DOCK_TOP + DOCK_LEFT):Inset(ScreenScale(2))

	draw.RoundedBox(5, x, y, width, height, Color(255 - bumpdt*255, bumpdt*255, 255 - bumpdt*255, math.max(CurAlpha - 155, 0)))
	draw.SimpleText( missionstr, font, tr.x + ScreenScale(1), tr.y, Color(255 - bumpdt*255,255,255 - bumpdt*255, CurAlpha))

	font = "Mission_ProgressPercent"

	if not mission.completed then
		drawProgressBar(m, x + ScreenScale(2.5), y + height - ScreenScale(14), width - ScreenScale(5), height - ScreenScale(14), missions.Active[mid], minfo.Count, animclip)
	elseif mission.completed then
		draw.SimpleText(jazzloc.Localize("jazz.mission.finished"), font, tr.x + ScreenScale(1), y + ScreenScale(11), Color(255, 255, 0, CurAlpha))
	else
		draw.SimpleText(jazzloc.Localize("jazz.mission.locked"), font, tr.x + ScreenScale(1), y + ScreenScale(11), Color(200, 200, 200, CurAlpha))
	end

	animclip:SetClip(false)

	return y - metrics.spacing
end

local ActiveMissions = {}
local CompletedMissions = {}
hook.Add("JazzMissionsUpdateUI", "JazzMissionListsToRender", function(prog, hist)
	ActiveMissions = prog
	CompletedMissions = table.Reverse(hist) -- more recent missions towards the bottom (vaguely, it's separated by cat rather than order number)
end)

local MissionsXShow = ScreenScale(12)
local MissionsXHide = -(metrics.width)
local MissionsX = MissionsXShow
local SlideSpeed = ScreenScale(450) -- needs to get faster the more pixels there are to travel
local function SlideOutMissions()
	local fraction = Lerp( (MissionsX - MissionsXHide) * 0.01, 0, 1)
	local ease = math.ease.OutQuad(fraction)
	return MissionsX - (FrameTime() * SlideSpeed) * ease
end
local function SlideInMissions()
	local fraction = Lerp( (MissionsXShow - MissionsX) * 0.01, 0, 1)
	local ease = math.ease.OutQuad(fraction)
	return MissionsX + (FrameTime() * SlideSpeed) * ease
end

local ChatOpen = false
hook.Add( "StartChat", "JazzMissionTyping", function()
	ChatOpen = true
end )
hook.Add( "FinishChat", "JazzMissionDoneTyping", function()
	ChatOpen = false
end )

local FadeSpeed = 1200
local function FadeOutMissions()
	return math.Clamp(CurAlpha - (FrameTime() * FadeSpeed ), 0, 255 )
end
local function FadeInMissions()
	return math.Clamp(CurAlpha + (FrameTime() * FadeSpeed ), 0, 255 )
end

local ShowFinishedMissions = false
hook.Add("HUDPaint", "JazzDrawMissions", function()
	if jazzHideHUD then return end

	if ChatOpen then
		if CurAlpha <= 0 then return end
		CurAlpha = FadeOutMissions()
	elseif CurAlpha < 255 then
		CurAlpha = FadeInMissions()
	end

	if dialog.IsInDialog() then
		if MissionsX <= MissionsXHide then
			return -- Don't render if offscreen
		else
			MissionsX = SlideOutMissions()
		end
	-- Don't change state mid-transition, instantly swap if transitioned out
	elseif not isTransitioning() then
		if isTransitionedOut() then
			MissionsX = MissionsXShow
		end

		if MissionsX < MissionsXShow then
			MissionsX = SlideInMissions()
		end
	end

	local offset = ScreenScale(40)
	local y = ScrH() - offset

	for k, v in pairs(ActiveMissions) do
		y = DrawMission(v, MissionsX, y)
	end

	if not ShowFinishedMissions then return end

	for k, v in pairs(CompletedMissions) do
		y = DrawMission(v, MissionsX, y)
	end
end )

hook.Add( "ScoreboardShow", "jazz_showFinishedMissions", function()
	ShowFinishedMissions = true
end )
hook.Add("ScoreboardHide", "jazz_hideFinishedMissions", function()
	ShowFinishedMissions = false
end )
