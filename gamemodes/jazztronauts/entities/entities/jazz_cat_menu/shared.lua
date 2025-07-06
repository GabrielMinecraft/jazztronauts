--entity for holding custom menu information

AddCSLuaFile()

ENT.Type = "point"

function ENT:SetupDataTables()
	self:NetworkVar( "String", "MenuStr" )
	self:NetworkVar( "Int", "NPCID" )
end

function ENT:KeyValue( key, value )

	self.menu = self.menu or {}

	if key == "npcid" then
		self:SetNPCID( tonumber(value) )
	end
	if key == "WelcomeText" then
		self.menu.WT = string.Trim(value)
	end

	local _, _, label = string.find( key, "ChatChoiceLabel([%d]+)" )
	local _, _, command = string.find( key, "ChatChoice([%d]+)" )

	if label then
		self.menu[label] = self.menu[label] or {}
		self.menu[label].Lb = string.Trim(value)
	end

	if command then
		self.menu[command] = self.menu[command] or {}
		self.menu[command].Co = string.Trim(value)
	end

end

function ENT:SetCatMenu()
	timer.Simple(1,function()
		if not IsValid(self) then return end

		local cats, cat = ents.FindByClass("jazz_cat"), nil
		
		for _, v in ipairs(cats) do
			if not IsValid(v) then continue end
			if v:GetNPCID() == self:GetNPCID() then cat = v break end
		end
		if not IsValid(cat) then return end

		cat.ChatChoices = cat.ChatChoices or {}

		local options = util.JSONToTable(self:GetMenuStr())

		--need them added in order, without gaps
		local listed, maxlisted = {}, 0

		for k, v in pairs(options) do
			--top label
			if k == "WT" and v ~= "" then cat.ChatChoices.WelcomeText = options.WT
			elseif tonumber(k) then
				maxlisted = math.max(maxlisted,tonumber(k))
			end
		end
		for i = 0, maxlisted do
			if options[i] then table.insert(listed,options[i]) end
		end

		local entries = {
			["UPGRADES"] = function(cat,v) cat.chatmenu.AddChoice(cat.ChatChoices, v.Lb, function(cat, ply) ClientRun(ply, "jstore.OpenUpgradeStore()") end) end,
			["STORE"] = function(cat,v) cat.chatmenu.AddChoice(cat.ChatChoices, v.Lb, function(cat, ply) ClientRun(ply, "jstore.OpenStore()") end) end,
			["CHAT"] = function(cat,v) cat.chatmenu.AddChoice(cat.ChatChoices, v.Lb, function(cat, ply) cat:StartChat(ply) end) end,
			["HUB"] = function(cat,v) timer.Simple(1, function() cat:addHubChat(v.Lb) end) end,
			--todo: need an option for map I/O
		}

		for _, v in ipairs(listed) do

			--start entry with ^ to denote a scene to play
			local _, _, scene = string.find( v.Co, "^^(.+)" )
			
			if entries[v.Co] then
				entries[v.Co](cat,v)
			elseif scene then
				cat.chatmenu.AddChoice(cat.ChatChoices, v.Lb, function(cat, ply) cat:runScript( scene, ply ) end)
			else
				cat.chatmenu.AddChoice(cat.ChatChoices, v.Lb, function(cat, ply) ClientRun(ply, v.Co) end)
			end
		end

		-- Allow mouse clicks on the chat menu (and make it so clicking doesn't shoot their weapon)
		if CLIENT and cat.ChatChoices and #cat.ChatChoices > 0 then
			hook.Add("KeyPress", cat, function(cat, ply, key) return cat:OnMouseClicked(ply, key) end )
			hook.Add("KeyRelease", cat, function(cat, ply, key) return cat:OnMouseReleased(ply, key) end)
		end
	end)
end

if SERVER then

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	local defaultLabels = {
		["jstore.OpenUpgradeStore()"] = "#jazz.store.upgrade",
		["UPGRADES"] = "#jazz.store.upgrade",
		["jstore.OpenStore()"] = "#jazz.store.store",
		["STORE"] = "#jazz.store.store",
		["CHAT"] = "#jazz.store.chat",
		["HUB"] = "#jazz.store.hub",
	}

	function ENT:Initialize()
		self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
		self.menu = self.menu or {}
		--set defaults (todo: later)
		/*for i = 1, #self.menu do
			local ref = self.menu[tostring(i)]
			if not ref then continue end
			if ref.Co and (string.Trim(ref.Lb) == "" or ref.Lb == nil) then
				ref.Lb = defaultLabels[ref.Co] and defaultLabels[ref.Co] or ""
			end
		end--*/
		
		self:SetMenuStr(util.TableToJSON(self.menu))

		self:SetCatMenu()
	end

else --CLIENT

	function ENT:Initialize()
		self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
		self:SetCatMenu()
	end

end
