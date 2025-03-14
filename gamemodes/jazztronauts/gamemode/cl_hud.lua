//Draws the dynamic money counter

//MODIFIABLES
local HideDelay = 2 //How many seconds to show the amt after it is done filling the counter?
local FillDelay = propfeed.StayDuration //Number of seconds before the money can begin filling
local FadeSpeed = 900 //How fast to fade out

local distFromSide = ScreenScale(6)
local coinDistance = ScreenScale(32)
local coinSize = ScreenScale(20)
local distFromTop = ScreenScale(7)

//NON-MODIFIABLES
local bgWidth = 15
local lastWidth = 1
local CurAlpha = 200
local VisualAmount = 0
local HideTime = 0
local KeepShowing = mapcontrol.IsInHub() and true or false
local moneyFillDelay = 0 //Delay before the money begin filling into the main dude
local moneyFillVelocity = 1 //Amount of money to fill per frame. Adjusted based on how many money to fill
local lastMoneyCount = -1

local catcoin = Material("materials/ui/jazztronauts/catcoin.png", "smooth")
local catcoin_silver = Material("materials/ui/jazztronauts/catcoin_silver.png", "smooth")

surface.CreateFont( "JazzNote",
{
	font		= "KG Shake it Off Chunky Mono",
	size		= ScreenScale(20),
	weight		= 1500
})
surface.CreateFont( "JazzNoteFill",
{
	font		= "KG Shake it Off Chunky Mono",
	size		= ScreenScale(12),
	weight		= 500,
	antialias	= true
})
surface.CreateFont( "JazzNoteMultiplier",
{
	font		= "KG Shake it Off Chunky",
	size		= ScreenScale(12),
	weight		= 1500,
	antialias	= true
})
surface.CreateFont( "JazzNoteMultiplierExtra",
{
	font		= "KG Shake it Off Chunky",
	size		= ScreenScale(9),
	weight		= 1500,
	antialias	= true
})
surface.CreateFont( "JazzBlackShard",
{
	font		= "Palatino Linotype",
	size		= ScreenScale(20),
	weight		= 1500
})

local function drawTextRotated(text, font, x, y, color, rotation, maxWidth)
	surface.SetFont(font)
	local w, h = surface.GetTextSize(text)
	local actualWidth = math.cos(math.rad(rotation)) * w
	local scaleMult = math.min(1, maxWidth / actualWidth)

	local rotMat = Matrix()
	rotMat:Translate(Vector(x, y, 0))
	rotMat:Rotate(Angle(0, rotation, 0))
	rotMat:Scale(Vector(1, 1, 1) * scaleMult)
	rotMat:Translate(Vector(-x, -y, 0))


	cam.PushModelMatrix(rotMat)
		surface.SetTextColor(color)
		surface.SetTextPos(x - w/2, y - h/2)
		surface.DrawText(text)
	cam.PopModelMatrix()
end

local function FadeOutNotes()
	return math.Clamp(CurAlpha - (FrameTime() * FadeSpeed ), 0, 255 )
end

local function FadeInNotes()
	return math.Clamp(CurAlpha + (FrameTime() * FadeSpeed ), 0, 255 )
end

local function DrawNoteCount()
	local amt = LocalPlayer() and LocalPlayer():GetNotes() or 0

	--fix just loading in
	if lastMoneyCount < 0 and amt ~= 0 then
		lastMoneyCount = amt
		VisualAmount = amt
	end

	-- Typical state is don't draw unless amount changing, dialog should override KeepShowing
	if dialog.IsInDialog() or not KeepShowing then
		if amt ~= VisualAmount then
			HideTime = CurTime() + HideDelay
		end

		if CurTime() > HideTime and CurAlpha <= 0 then
			return -- Don't draw if the alpha is 0
		elseif CurTime() > HideTime then
			CurAlpha = FadeOutNotes()
		else
			CurAlpha = 200
		end
	-- Don't change state mid-transition, instantly swap if transitioned out
	elseif not isTransitioning() then
		if isTransitionedOut() then
			CurAlpha = 200
		end

		if CurAlpha < 200 then
			CurAlpha = FadeInNotes()
		end
	end

	if amt ~= lastMoneyCount then
		-- Only delay if earning money
		if amt > lastMoneyCount then
			moneyFillDelay = CurTime() + FillDelay:GetFloat()
		end

		lastMoneyCount = amt
	end

	-- Current multiplier for all earned money
	local noteMultiplier = newgame.GetMultiplierBase() + 1
	local noteMultiplierExtra = newgame.GetMultiplierExtra(true) - 1
	local finalText = jazzloc.Localize("jazz.hud.money",string.Comma( VisualAmount ))

	surface.SetFont( "JazzNote")
	bgWidth, bgHeight = surface.GetTextSize( finalText )

	lastWidth = Lerp( FrameTime() * 10, lastWidth, bgWidth + coinSize + ScreenScale(13) )
	draw.RoundedBox( 4, ScrW() - (distFromSide + lastWidth), distFromTop, lastWidth, bgHeight, Color( 0, 0, 0, CurAlpha ) )

	//Draw how many money we have
	local FinalAmountText = {}
	FinalAmountText["pos"] = { ScrW() - distFromSide - coinSize - ScreenScale(10), distFromTop }
	FinalAmountText["color"] = Color(255, 255, 255, CurAlpha)
	FinalAmountText["text"] = finalText
	FinalAmountText["font"] = "JazzNote"
	FinalAmountText["xalign"] = TEXT_ALIGN_RIGHT
	FinalAmountText["yalign"] = TEXT_ALIGN_TOP

	draw.TextShadow( FinalAmountText, 2, math.Clamp( CurAlpha - 40, 0, 200 ) )

	//Draw the new money text
	local text = ""
	local color = Color( 255, 0, 0 )
	if amt - VisualAmount > 0 then
		text = "+"
		color = Color( 0, 255, 0 )
	end
	text = text .. tostring( math.floor( amt - VisualAmount ) )

	if amt - VisualAmount ~= 0 then
		draw.DrawText( text, "JazzNoteFill", ScrW() - distFromSide, bgHeight + ScreenScale(6), color, TEXT_ALIGN_RIGHT)
	end

	if CurTime() > moneyFillDelay then
		moneyFillVelocity = FrameTime() * (math.abs(amt - VisualAmount) ) + 5
		moneyFillVelocity = math.Round( moneyFillVelocity )

		if amt - VisualAmount > 0 then
			VisualAmount = VisualAmount + moneyFillVelocity
			if amt - VisualAmount <= 0 then
				VisualAmount = amt
			end
		elseif amt - VisualAmount < 0 then
			VisualAmount = VisualAmount - moneyFillVelocity

			if amt - VisualAmount >= 0 then
				VisualAmount = amt
			end
		else
			VisualAmount = amt
		end
	end

	-- Draw Cat Coin
	surface.SetDrawColor(255, 255, 255, CurAlpha)
	surface.SetMaterial(catcoin)
	surface.DrawTexturedRect(ScrW() - coinDistance, distFromTop, coinSize, coinSize)

	-- Draw money multiplier
	if noteMultiplier > 1 then

		local multCol = Color(108, 52, 0, math.min( 255, CurAlpha * 1.25)) --250
		drawTextRotated(noteMultiplier, "JazzNoteMultiplier",
			ScrW() - coinDistance / 2 - distFromSide, distFromTop + coinSize / 2 - ScreenScale(1),
			multCol, 0, coinSize/1.3)
	end

	if noteMultiplierExtra > 0 then
		--draw silver coin
		surface.SetDrawColor(255, 255, 255, CurAlpha)
		surface.SetMaterial(catcoin_silver)
		surface.DrawTexturedRect(ScrW() - coinDistance * .625, distFromTop * 2.125, coinSize * .75, coinSize * .75)

		multCol = Color(90, 92, 118, math.min( 255, CurAlpha * 1.25)) --250
		drawTextRotated("+" .. tostring(noteMultiplierExtra), "JazzNoteMultiplierExtra",
			ScrW() - (coinDistance / 2 + distFromSide) * .625, distFromTop * 2.125 + coinSize * .75 / 2 - ScreenScale(0.75),
			multCol, 0, coinSize/1.3 * .75)
	end

end

local function DrawBlackShardCount()
	local bshard = IsValid(bshard) and bshard or ents.FindByClass("jazz_shard_black")[1]
	if not IsValid(bshard) or not bshard.GetStartSuckTime then return end

	local sucktime = bshard:GetStartSuckTime()
	local left, total = sucktime > 0 and sucktime < CurTime() and 0 or 1, 1
	local str = jazzloc.Localize("jazz.shards.one")
	local color = Color(100, 100, 100, 100)
	if left == 0 then
		color = Color(200, 10, 10)
		str = jazzloc.Localize("jazz.shards.none")
	end

	surface.SetFont("JazzBlackShard")
	local offset = surface.GetTextSize(str) / 2
	offset = offset + 5
	draw.WordBox( 5, ScrW() / 2 - offset, 5, str, "JazzBlackShard", color, color_white )
end

local function DrawShardCount()
	local left, total = mapgen.GetShardCount()
	local roadtrip = newgame.GetMultiplierExtra(true) - 1
	local str = jazzloc.Localize("jazz.shards.partialcollected",total - left,total)
	local color = Color(143, 0, 255, 100)
	if left == 0 then
		str = total == 1 and jazzloc.Localize("jazz.shards.all1") or jazzloc.Localize("jazz.shards.all",total)
		color = HSVToColor(math.fmod(CurTime() * 360, 360), .3, .7)
	end

	surface.SetFont("JazzNote")
	local offset = surface.GetTextSize(str) / 2
	offset = offset + 5
	local w, h = draw.WordBox( 5, ScrW() / 2 - offset, 5, str, "JazzNote", color, color_white )

	--draw roadtrip totals
	if roadtrip > 0 then
		surface.SetFont("JazzNoteFill")
		local lefttotal, totaltotal = newgame.GetRoadtripTotals()
		local str2 = tostring(lefttotal) .. "/" .. tostring(totaltotal)
		local offset2 = surface.GetTextSize(str2) / 2
		draw.WordBox( 3, ScrW() / 2 - offset2, h - 5,str2, "JazzNoteFill", color, color_white )
	end
end

hook.Add("HUDPaint", "JazzDrawHUD", function()
	if jazzHideHUD then return end

	DrawNoteCount()

	if mapcontrol.IsInGamemodeMap() then return end

	local isCommitted = mapgen.GetTotalCollectedBlackShards() > mapgen.GetTotalRequiredBlackShards() / 2
	if isCommitted then
		DrawBlackShardCount()
	else
		DrawShardCount()
	end

end )

-- If always showing the moneybux, skip the scoreboard stuff below
if KeepShowing == true then return end

//Show the money count when pressing tab
hook.Add( "ScoreboardShow", "jazz_scoreboardShow", function()
	KeepShowing = true
end )
hook.Add("ScoreboardHide", "jazz_scoreboardHide", function()
	KeepShowing = false
end )
