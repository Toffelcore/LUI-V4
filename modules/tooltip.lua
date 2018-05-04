-- This module handle tooltips shown around the interface and skinning GameTooltip.

------------------------------------------------------
-- / SETUP AND LOCALS / --
------------------------------------------------------
local _, LUI = ...
local module = LUI:NewModule("Tooltip", "AceHook-3.0")
local Media = LibStub("LibSharedMedia-3.0")
local L = LUI.L
local db

local _G = _G
local pairs = pairs

local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsPlayer = UnitIsPlayer
local GetGuildInfo = GetGuildInfo
local UnitReaction = UnitReaction
local UnitPVPName = UnitPVPName
local UnitExists = UnitExists
local UnitIsDND = UnitIsDND
local UnitIsAFK = UnitIsAFK
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local IsInGuild = IsInGuild
local UnitRace = UnitRace
local UnitName = UnitName

-- Constants
local CHAT_FLAG_DND = CHAT_FLAG_DND
local CHAT_FLAG_AFK = CHAT_FLAG_AFK
local PVP_ENABLED = PVP_ENABLED
local GUILD = GUILD
local LEVEL = LEVEL
local DEAD = DEAD

local TOOLTIPS_LIST = {
	"GameTooltip",
	"ItemRefTooltip",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
	"ShoppingTooltip1",
	"WorldMapTooltip",
	"ShoppingTooltip2",
	"FriendsTooltip",
	"TicketStatusFrameButton",
	"DropDownList1MenuBackdrop",
	"DropDownList2MenuBackdrop",
	"BrowserSettingsTooltip",
	"FrameStackTooltip",
	"EventTraceTooltip",
	"AddonTooltip",
	"WorldMapCompareTooltip1",
	"WorldMapCompareTooltip2",
	"ReputationParagonTooltip",
	"ScenarioStepRewardTooltip",
	"PVPRewardTooltip",
	"ConquestTooltip",
	"FloatingBattlePetTooltip",
	"FloatingPetBattleAbilityTooltip",
	"PetJournalPrimaryAbilityTooltip",
	"FloatingGarrisonFollowerTooltip",
	"GarrisonFollowerAbilityTooltip",
	"GarrisonMissionMechanicTooltip",
	"GarrisonShipyardMapMissionTooltip",
	"GarrisonMissionMechanicFollowerCounterTooltip",
	"ContributionTooltip",
	"ContributionBuffTooltip",
}

-- Need Localization
-- was local classification
local MOB_CLASSIFICATION = {
	worldboss = BOSS,
	rareelite = L["Tooltip_Rare"].."+",
	elite = "+",
	rare = L["Tooltip_Rare"],
	minus = "-",  -- Does not give experience or reputation.
}

-- local variables
local oldDefault = {}
local initialScale = {}

--Defaults
module.defaults = {
	profile = {
		hideCombat = false,
		hideCombatSkills = false,
		hideCombatUnit = false,
		hideUF = false,
		hidePVP = true,
		showSex = false,
		Cursor = false,
		Point = "RIGHT",
		Scale = 1,
		X = -150,
		Y = 0,
		Textures = {
			healthBar = "LUI_Minimalist",
			backgroundTex = "Blizzard Dialog Background Dark",
			borderTex = "Stripped_medium",
			borderSize = 14,
		},
		Colors = {
			Background = { r = 0.19, g = 0.19, b = 0.19, a = 1, t = "Individual", },
			Border =     { r = 0.3,  g = 0.3,  b = 0.3,  a = 1, t = "Individual", },
			Guild =      { r = 0,    g = 1,    b = 0.1,                           },
			MyGuild =    { r = 0,    g = 0.55, b = 1,                             },
		},
		Fonts = {
			Health = { Name = "vibroceb", Size = 12, Flag = "OUTLINE", },
		},
	},
}

------------------------------------------------------
-- / REVERT FUNCTIONS / --
------------------------------------------------------
function module:RevertTooltipBackdrop()
	for i = 1, #TOOLTIPS_LIST do
		local tooltipName = TOOLTIPS_LIST[i]
		_G[tooltipName]:SetBackdrop(oldDefault[tooltipName])
		_G[tooltipName]:SetScale(1)
	end
end

function module:RevertHealthBar()
	local health = GameTooltipStatusBar
	local numPoints = health:GetNumPoints()
	health:ClearAllPoints()
	for i = 1, numPoints do
		local point, relativeTo, relativePoint, xOffset, yOffset = unpack(oldDefault.Health.Points[i])
		health:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
	end
	health:SetHeight(oldDefault.Health.Height)
	health:SetStatusBarTexture(oldDefault.Health.StatusBarTexture)
end
 
------------------------------------------------------
-- / MODULE FUNCTIONS / --
------------------------------------------------------
-- Get a unit token out of a tooltip frame for use in many Unit functions.
local function GetTooltipUnit(frame)
	if not frame.GetUnit then return end
	local _, unit = frame:GetUnit()
	-- If GetUnit fails, look for a mouseover target.
	if not unit and UnitExists("mouseover") then
		unit = "mouseover"
	end
	return unit
end

-- Debug function, this will call UpdateTooltipBackdrop, optionally add a tooltip before doing so.
function LUI:ForceTooltipUpdate(ttip)
	if ttip then
		tinsert(TOOLTIPS_LIST, ttip)
	end
	module:UpdateTooltipBackdrop()
end

function module:UpdateTooltipBackdrop()
	for i = 1, #TOOLTIPS_LIST do
		local tooltipName = TOOLTIPS_LIST[i]
		local tooltip = _G[tooltipName]
		--Make sure the tooltip exists.
		if tooltip then
			-- Store the original backdrop so we can revert.
			-- Make sure we don't overwrite it if we update the tooltips again later.
			if not oldDefault[tooltipName] then
				oldDefault[tooltipName] = tooltip:GetBackdrop()
				initialScale[tooltipName] = tooltip:GetScale()
			end
			tooltip:SetBackdrop({
				bgFile = Media:Fetch("background", db.Textures.backgroundTex),
				edgeFile = Media:Fetch("border", db.Textures.borderTex),
				edgeSize = db.Textures.borderSize, tile = false,
				insets = {left = 0, right = 0, top = 0, bottom = 0, }
			})
			if not module:IsHooked(tooltip, "OnShow") then
				module:HookScript(tooltip, "OnShow", "OnTooltipShow")
			end
		else
			--module:Mod(tooltipName.." Not Found")
		end
	end
end

function module:GetUnitColor(unit)
	if UnitIsPlayer(unit) and not UnitHasVehicleUI(unit) then
		local _, class = UnitClass(unit)
		return module:Color(class)
	else
		return LUI:GetReactionColor(unit)
	end
end

function module:SetTooltip()
	module:SecureHook("GameTooltip_SetDefaultAnchor", function(frame, parent)
		if db.Cursor then
			frame:SetOwner(parent, "ANCHOR_CURSOR")
		else
			frame:SetOwner(parent, "ANCHOR_NONE")
			frame:ClearAllPoints()
			frame:SetPoint(db.Point, UIParent, db.X, db.Y)
		end
	end)

	module:SetStatusHealthBar()
	module:HookScript(GameTooltip, "OnTooltipSetUnit", "OnGameTooltipSetUnit")

	--Hide ability tooltips if option is enabled
	module:SecureHook(GameTooltip, "SetAction", "HideCombatSkillTooltips")
	module:SecureHook(GameTooltip, "SetPetAction", "HideCombatSkillTooltips")
	module:SecureHook(GameTooltip, "SetShapeshift", "HideCombatSkillTooltips")
end

function module:SetStatusHealthBar()
	local health = GameTooltipStatusBar

	-- Save default data before replacing it (for reverting)
	if not oldDefault.Health then
		oldDefault.Health = {}
		oldDefault.Health.Points = {}
		for i = 1, health:GetNumPoints() do
			oldDefault.Health.Points[i] = { health:GetPoint(i) }
		end
		oldDefault.Health.Height = health:GetHeight()
		oldDefault.Health.StatusBarTexture = health:GetStatusBarTexture()
	end

	-- Change the Health bar
	health:ClearAllPoints()
	health:SetHeight(6)
	health:SetPoint("BOTTOMLEFT", health:GetParent(), "TOPLEFT", 2, 5)
	health:SetPoint("BOTTOMRIGHT", health:GetParent(), "TOPRIGHT", -2, 5)
	health:SetStatusBarTexture(Media:Fetch("statusbar", db.Textures.healthBar))

	-- Add health values.
	health:SetScript("OnValueChanged", module.OnStatusBarValueChanged)
end

function module:SetBorderColor(frame)
	local unit = GetTooltipUnit(frame)
	local health = GameTooltipStatusBar

	frame:SetBackdropColor(module:Color("Background"))
	frame:SetBackdropBorderColor(module:Color("Border"))
	health:SetStatusBarColor(module:Color("Border"))

	-- Tooltip is a player unit
	if unit and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local r, g, b = module:Color(class)
		frame:SetBackdropBorderColor(r, g, b)
		health:SetStatusBarColor(r, g, b)

	-- Tooltip is a NPC unit
	elseif unit and UnitReaction(unit, "player") then
		local r, g, b = LUI:GetReactionColor(unit)
		frame:SetBackdropBorderColor(r, g, b)
		health:SetStatusBarColor(r, g, b)

	-- Tooltip is an item
	elseif not unit and frame.GetItem and frame:GetItem() then
		local _, itemLink = frame:GetItem()
		local _, _, quality = GetItemInfo(itemLink)
		-- Only need to change border color for Uncommon and above.
		if quality and quality >= 2 then
			local r, g, b = GetItemQualityColor(quality)
			frame:SetBackdropBorderColor(r, g, b)
		end
	end
end

function module:UpdateBackdropColors()
	GameTooltip:SetBackdropColor(module:Color("Background"))
	GameTooltip:SetBackdropBorderColor(module:Color("Border"))
	GameTooltipStatusBar:SetStatusBarColor(module:Color("Border"))
end

------------------------------------------------------
-- / HOOKS / SCRIPTS FUNCTIONS / --
------------------------------------------------------

function module.OnStatusBarValueChanged(frame, value_)
	local unit = GetTooltipUnit(GameTooltip)
	if not unit then return end

	if not frame.text then
		frame.text = module:SetFontString(frame, nil, "Health", "OVERLAY")
		frame.text:SetPoint("CENTER", GameTooltipStatusBar, 0, 6)
		frame.text:Show()
	end

	if unit then
		local minValue, maxValue = UnitHealth(unit), UnitHealthMax(unit)
		if UnitIsGhost(unit) then
			frame.text:SetText(L["Tooltip_Ghost"])
		elseif minValue == 0 or UnitIsDead(unit) then
			frame.text:SetText(DEAD)
		else
			frame.text:SetFormattedText("%s / %s", BreakUpLargeNumbers(minValue), BreakUpLargeNumbers(maxValue))
		end
		frame:Show()
	else
		frame:Hide()
	end
end

function module:OnTooltipShow(frame)
	if db.hideCombat and InCombatLockdown() then
		frame:Hide()
		return
	end

	--If a frame as a smaller scale than normal for any reasons, make sure that's respected.
	frame:SetScale(initialScale[frame:GetName()] * db.Scale)
	module:SetBorderColor(frame)
end

function module:OnGameTooltipSetUnit(frame)
	if db.hideCombatUnit and InCombatLockdown() then
		frame:Hide()
		return
	end

	local unit = GetTooltipUnit(frame)
	-- If that fails, report it so we can investigate.
	if not unit then
		return
	end

	-- Hide tooltip on unitframes if that option is enabled
	if frame:GetOwner() ~= UIParent and db.hideUF then
		frame:Hide()
		return
	end

	local sex = UnitSex(unit)
	local race = UnitRace(unit)
	local level = UnitLevel(unit)
	local title = UnitPVPName(unit)
	local guild = GetGuildInfo(unit)
	local name, realm = UnitName(unit)
	local creatureType = UnitCreatureType(unit)
	local localizedClass, class_ = UnitClass(unit)
	local classification = UnitClassification(unit)
	local r, g, b = LUI:GetDifficultyColor(level)
	local colorString = "|cff"..LUI:ColorToHex(module:GetUnitColor(unit))
	GameTooltipTextLeft1:SetFormattedText("%s%s%s|r", colorString, title or name, (realm) and " - "..realm or "")

	local offset = 2
	if UnitIsPlayer(unit) then
		-- Display status next to name
		if UnitIsDND(unit) then
			frame:AppendText(" "..CHAT_FLAG_DND)
		elseif UnitIsAFK(unit) then
			frame:AppendText(" "..CHAT_FLAG_AFK)
		end
		if guild then
			local guildColor = "Guild"
			-- Color guild name differently if it's your guild
			if IsInGuild() and GetGuildInfo("player") == guild then guildColor = "MyGuild" end
			GameTooltipTextLeft2:SetText(LUI:ColorToString(guild, module:Color(guildColor)))
			offset = offset + 1
		end
	end

	-- The line with level information isnt always the same, so we need to do some scanning.
	for i = offset, frame:NumLines() do
		local line = _G["GameTooltipTextLeft"..i]
		if line:GetText() then
			-- Level line for players
			if line:GetText():find("^"..LEVEL) and race then
				local levelString = LUI:ColorToString((level > 0) and level or "??", r, g, b)
				local sexString = (db.showSex) and LUI.GENDERS[sex].." " or ""
				line:SetFormattedText("%s %s%s%s %s",levelString, sexString, race, colorString, localizedClass.."|r")
			-- Level line for creatures
			elseif line:GetText():find("^"..LEVEL) or (creatureType and line:GetText():find("^"..creatureType)) then
				--HACK: Not sure if needed anymore.
				--if level == -1 and classification == "elite" then classification = "worldboss" end
				if classification == "worldboss" then
					-- Always color world bosses as skulls.
					r, g, b = LUI:Color("DiffSkull")
				end
				local levelString = (level > 0) and LUI:ColorToString(level, r, g, b) or ""
				local classifString = LUI:ColorToString(MOB_CLASSIFICATION[classification], r, g, b)
				line:SetFormattedText("%s%s %s", levelString, classifString, creatureType or "")
			-- Remove the PVP line if the option is set
			elseif line:GetText() == PVP_ENABLED and db.hidePVP then
				line:SetText()
			end
		end
	end

	--Add ToT Line
	if UnitExists(unit.."target") and unit~="player" then
		GameTooltip:AddLine(UnitName(unit.."target"), module:GetUnitColor(unit.."target"))
	end

	module:SetBorderColor(frame)
end

function module:HideCombatSkillTooltips(frame)
	if db.hideCombatSkills and InCombatLockdown() and not IsShiftKeyDown() then
		frame:Hide()
	end
end

------------------------------------------------------
-- / FRAMEWORK FUNCTIONS / --
------------------------------------------------------

module.enableButton = true

function module:LoadOptions()

	local function disableIfTooltipsHidden(info_)
		return db.hideCombat
	end

	local options = {
		Header = module:NewHeader(L["Tooltip_Name"], 1),
		General = module:NewRootGroup(L["Settings"], 2, nil, nil, {
			hideCombat = module:NewToggle(L["Tooltip_HideCombat_Name"], L["Tooltip_HideCombat_Desc"], 1),
			hideCombatSkills = module:NewToggle(L["Tooltip_HideCombatSkills_Name"],
			                                    L["Tooltip_HideCombatSkills_Desc"], 2, nil, nil, disableIfTooltipsHidden),
			hideCombatUnit = module:NewToggle(L["Tooltip_HideCombatUnit_Name"],
			                                  L["Tooltip_HideCombatUnit_Desc"], 2, nil, nil, disableIfTooltipsHidden),
			hideUF = module:NewToggle(L["Tooltip_HideUF_Name"], L["Tooltip_HideUF_Desc"], 3),
			hidePVP = module:NewToggle(L["Tooltip_HidePVP_Name"], L["Tooltip_HidePVP_Desc"], 4),
			showSex = module:NewToggle(L["Tooltip_ShowSex_Name"], L["Tooltip_ShowSex_Desc"], 5),
			Scale = module:NewScale(L["Tooltip_Scale_Name"], L["Tooltip_Scale_Desc"], 6),
		}),
		Position = module:NewGroup(L["Position"], 3, nil, nil, {
			Cursor = module:NewToggle(L["Tooltip_Cursor_Name"], L["Tooltip_Cursor_Desc"], 1),
			PosDesc = module:NewDesc(L["Tooltip_PosDesc"], 2),
			Positions = module:NewPosition(L["Tooltip_Positions"], 3, true, true),
		}),
		Textures = module:NewGroup(L["Textures"], 3, nil, nil, {
			Background = module:NewHeader(L["Background"], 1),
			backgroundTex = module:NewTexBackground(L["Tooltip_BackgroundTex_Name"],
			                                        L["BackgroundDesc"], 2, "UpdateTooltipBackdrop", "double"),
			Health = module:NewHeader(L["Health Bar"], 3),
			healthBar = module:NewTexStatusBar(L["Tooltip_HealthBar_Name"],
			                                   L["Tooltip_HealthBar_Desc"], 4, "SetStatusHealthBar", "double"),
			Border = module:NewHeader(L["Border"], 5),
			borderTex = module:NewTexBorder(L["Tooltip_BorderTex_Name"], L["BorderDesc"], 6, "UpdateTooltipBackdrop", "double"),
			borderSize = module:NewSlider(L["Tooltip_BorderSize_Name"],
			                              L["Tooltip_BorderSize_Desc"], 7, 1, 30, 1, nil, "UpdateTooltipBackdrop", "double"),
		}),
		Colors = module:NewGroup(L["Colors"], 3, nil, nil, {
			Guild = module:NewColor(GUILD, nil, 1),
			MyGuild = module:NewColor(L["Tooltip_MyGuild"], nil, 2),
			Tapped = module:NewColor(L["Tapped"], nil, 3),
			Blank = module:NewLineBreak(4),
			-- Those two are supposed to be LUI Colors.
			Background = module:NewColor(L["Background"], nil, 5, nil, "UpdateBackdropColors"),
			Border = module:NewColor(L["Border"], nil, 6, "UpdateBackdropColors"),
		}),
	}
	return options
end

function module:OnInitialize()
	LUI:RegisterModule(module)
	
end

--[[
function module:WorldMapSpecialHandling()
	local tooltip = WorldMapTooltip.BackdropFrame
	LUI:Print(tooltip:GetName(), tooltip:GetDebugName())
	tooltip:SetBackdrop({
		bgFile = Media:Fetch("background", db.Textures.backgroundTex),
		edgeFile = Media:Fetch("border", db.Textures.borderTex),
		edgeSize = db.Textures.borderSize, tile = false,
		insets = {left = 0, right = 0, top = 0, bottom = 0, }
	})
	if not module:IsHooked(tooltip, "OnShow") then
		module:HookScript(tooltip, "OnShow", "OnTooltipShow")
	end
	tooltip:SetBackdropColor(module:Color("Background"))
	tooltip:SetBackdropBorderColor(module:Color("Border"))
end--]]

function module:OnEnable()
	db = module:GetDB()
	module:UpdateTooltipBackdrop()
	module:SetTooltip()

	-- Many tooltips are found in Blizzard LoadOnDemand addons
	module:RegisterEvent("ADDON_LOADED", "UpdateTooltipBackdrop")

	--TODO: Move Elsewhere
	TicketStatusFrame:ClearAllPoints()
	TicketStatusFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -175, -70)
end

function module:OnDisable()
	module:RevertTooltipBackdrop()
	module:RevertHealthBar()
end

-- Debug function, will print frames with Tooltip in the name that we arent skinning.
-- Useful whenever we looking for something.
function PrintTooltips()
	for k, v in pairs(_G) do
		if strmatch(k, "Tooltip%d?$") and type(v) == "table" then
			-- Do not show tooltips ending in TooltipTooltip, those are generally embedded tooltips.
			if not strmatch(k, "TooltipTooltip$") then
				if not tContains(TOOLTIPS_LIST, k) then LUI:Print(k) end
			end
		end
	end
end
