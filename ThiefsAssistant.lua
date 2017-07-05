-- Find out what parts of addon are enabled and then create the window based on the allocated width of each part
ThiefsAssistant = {}

local ADDON_NAME = "ThiefsAssistant"
ThiefsAssistant.name = ADDON_NAME
local VERSION = 0.7
ThiefsAssistant.version = VERSION
--local UPDATE_TIMER = 30
local time = 0
local timerTime = 0
-- INVENTORY_BACKPACK
ThiefsAssistant.StolenStuff = {}

local defaults = {
	["updateSpeed"] = 60,
	["updateSpeedTimers"] = 10,
	window = {
		["x"] = 550,
		["y"] = 900,
		["showSells"] = true,
		["showLaunders"] = true,
		["showFenceResetTimer"] = true,
		["showBountyTimer"] = true,
		["showBounty"] = true,
		["needBountyForTimer"] = true,
		["timeFormatStyle"] = TIME_FORMAT_STYLE_COLONS,
		["timeFormatPrecision"] = TIME_FORMAT_PRECISION_SECONDS,
		["showInvValue"] = true,
		["showInvNumItems"] = true,
		["minQualityNotify"] = ITEM_QUALITY_ARTIFACT,

	},
	itemManager = {
		["allowDestruction"] = false,
		["notifyOnDestroy"] = true,
		["destroyIngredients"] = true,
		["destroyFood"] = true,
		["destroyKnownRecipes"] = true,
		["destroyRecipesOfRarity"] = ITEM_QUALITY_TRASH,		-- Trash means do not destroy recipes under rarity
		["destroyGearUnderValue"] = 0,								-- 0 means do not destroy stolen gear under value
		["destroyTreasuresOfRarity"] = ITEM_QUALITY_TRASH,		-- Trash means do not destroy treasures
	},
	BData = {
		["lastVal"] = 0,
		heat = {},
	},
}

local function Print(message) 
	df("[%s]: %s", ADDON_NAME, message)
end

function ThiefsAssistant.OnAddonLoad(eventType, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	local saveData = ZO_SavedVars:NewAccountWide("ThiefsAssistantSavedVars", VERSION, nil, defaults)
	ThiefsAssistant.savedVars = saveData

	ThiefsAssistant.timeStyle = saveData.window["timeFormatStyle"]

	ThiefsAssistant.setUpMenu()

	ThiefsAssistant.estimatedBountyTime = (GetFullBountyPayoffAmount() / (0.007454646 + (0.001675579 * GetUnitLevel("player")))) + (GetPlayerInfamyData() / 2)	--estimated bounty time formula
	ThiefsAssistant.bountyWillHit0In = GetTimeStamp() + ThiefsAssistant.estimatedBountyTime

	local window = ThiefsAssistantWindow

	ThiefsAssistant.window = ThiefsAssistantWindow

	--[[local function NewTexture(texture, name, xCoord, hidden)
		tex = WINDOW_MANAGER:CreateControl(("ThiefsAssistantWindowTexture" .. name), window, CT_TEXTURE)
		tex:SetDimensions(20, 20)
		tex:SetAnchor(TOPLEFT, window, TOPLEFT, xCoord, 5)
		tex:SetTexture(texture)
		tex:SetHidden(not hidden)
	end]]

	--[[local function AddLabel(name, xCoord, hidden, text)
		lbl = WINDOW_MANAGER:CreateControlFromVirtual(("$(parent)" .. name), window, "ThiefsAssistantLabelTemplate")
		lbl:SetAnchor(TOPLEFT, window, TOPLEFT, xCoord, 5)
		if(text) then lbl:SetText(text) end
		lbl:SetHidden(not hidden)
	end]]

	local function BuildGroup(name, xCoords, shown, icon, title, value)
		ctrl = WINDOW_MANAGER:CreateControlFromVirtual(("$(parent)" .. name), window, "ThiefsAssistantGroupTemplate")
		ctrl:SetAnchor(TOPLEFT, window, TOPLEFT, xCoords[1], 5)
		ctrl:SetHidden(not shown)
		ctrl:GetChild(1):SetTexture(icon)
		ctrl:GetChild(2):SetText(title)
		ctrl:GetChild(2):SetAnchor(TOPLEFT, ctrl, TOPLEFT, xCoords[2])
		ctrl:GetChild(3):SetText(value)
		ctrl:GetChild(3):SetAnchor(TOPLEFT, ctrl, TOPLEFT, xCoords[3])
	end

	-- Add textures and controls
	local savedWindowData = saveData.window
	local xLocation = 5

	BuildGroup("Bounty", {xLocation, xLocation + 25, xLocation + 70}, savedWindowData["showBounty"], "esoui/art/stats/justice_bounty_icon-white.dds", "Bounty:", GetFullBountyPayoffAmount())
	if savedWindowData["showBounty"] then xLocation = xLocation + 125 end

	local totalSells, sellsUsed, fenceResetTime = GetFenceSellTransactionInfo()
	
	BuildGroup("FenceSells", {xLocation, 25, 125}, savedWindowData["showSells"], "esoui/art/stats/justice_bounty_icon-red.dds", "Sells Remaining:", totalSells - sellsUsed .. "/" .. totalSells)
	if savedWindowData["showSells"] then xLocation = xLocation + 155 end

	local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()

	BuildGroup("FenceLaunders", {xLocation, 25, 145}, savedWindowData["showLaunders"], "esoui/art/stats/justice_bounty_icon-red.dds", "Launders Remaining:", totalLaunders - laundersUsed .. "/" .. totalLaunders)
	if savedWindowData["showLaunders"] then xLocation = xLocation + 180 end

	BuildGroup("FenceTimer", {xLocation, 25, 105}, savedWindowData["showFenceResetTimer"], "esoui/art/stats/justice_bounty_icon-white.dds", "Fence Reset:", FormatTimeSeconds(fenceResetTime, ThiefsAssistant.timeStyle))
	if savedWindowData["showFenceResetTimer"] then xLocation = xLocation + 145 end	

	BuildGroup("InventoryValue", {xLocation, 25, 125}, savedWindowData["showInvValue"], "esoui/art/bank/bank_tabicon_gold_up.dds", "Inventory Value:", "na")
	if savedWindowData["showInvValue"] then xLocation = xLocation + 155 end

	BuildGroup("InventoryNumItems", {xLocation, 25, 115}, savedWindowData["showInvValue"], "esoui/art/inventory/inventory_all_tabicon_inactive.dds", "# Stolen Items:", "na")
	if savedWindowData["showInvNumItems"] then xLocation = xLocation + 135 end

	BuildGroup("BountyTimer", {xLocation, 25, 105}, savedWindowData["showBountyTimer"], "esoui/art/stats/justice_bounty_icon-white.dds", "Bounty Reset:", FormatTimeSeconds(0, ThiefsAssistant.timeStyle))
	if savedWindowData["showBountyTimer"] then xLocation = xLocation + 145 end

	


	-- The following event only triggers when bounty increases so updater is still necessary
	-- EVENT_JUSTICE_INFAMY_UPDATED will also work
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(event, oldBounty, newBounty, isInitialize)
		if(ThiefsAssistant.savedVars.window["showBounty"]) then
			ThiefsAssistant:ChangeText("BountyValue", newBounty, false, true)
			time = 0
		end
	end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_FENCE_UPDATE, function()
		if(ThiefsAssistant.savedVars.window["showSells"]) then
			local totalSells, sellsUsed = GetFenceSellTransactionInfo()
			ThiefsAssistant:ChangeText("FenceSellsValue", totalSells - sellsUsed .. "/" .. totalSells)
		end
		if(ThiefsAssistant.savedVars.window["showLaunders"]) then
			local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
			ThiefsAssistant:ChangeText("FenceLaundersValue", totalLaunders - laundersUsed .. "/" .. totalLaunders)
		end
		time = 0
	end)

	-- Restore position of window
	if(saveData.window) then
		window:ClearAnchors()
		window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saveData.window.x, saveData.window.y)
	end

	-- Save window coords on move
	window:SetHandler("OnMoveStop", function(control)
		local xLoc, yLoc = control:GetScreenRect()
		ThiefsAssistant.savedVars.window["x"] = xLoc
		ThiefsAssistant.savedVars.window["y"] = yLoc
	end)
end

function ThiefsAssistant:ChangeText(objName, text, isTime, isCurrency)
	local ctl = GetControl(self.window, objName)
	if(isTime) then
		ctl:SetText(FormatTimeSeconds(text, self.savedVars.window["timeFormatStyle"]))
	elseif(isCurrency) then
		ctl:SetText(text .. "|t15:15:esoui/art/currency/currency_gold_32.dds|t")
	else
		ctl:SetText(text)
	end
end

function ThiefsAssistant:GetStolenStuffValue()
	local value = 0
	for i, link in ipairs(self.StolenStuff) do
		if GetItemLinkItemType(link) == ITEMTYPE_TREASURE then
			value = value + GetItemLinkValue(link, false)
		end
	end
	return value
end

function ThiefsAssistant:InitializeOrUpdateStolenList()
	local size = GetBagSize(INVENTORY_BACKPACK)
	local loc = 1
	for slot = 0, size do
		if(IsItemStolen(INVENTORY_BACKPACK, slot)) then
			self.StolenStuff[loc] = GetItemLink(INVENTORY_BACKPACK, slot)
			loc = loc + 1
		end
	end
end

function ThiefsAssistant:UpdateAllTimers()
	if(self.savedVars.window["showFenceResetTimer"]) then
		local a, b, timeSeconds = GetFenceSellTransactionInfo()
		ThiefsAssistant:ChangeText("FenceTimerValue", timeSeconds, true)
	end
	if(self.savedVars.window["showBountyTimer"]) then
		if(self.savedVars.window["needBountyForTimer"] and not (GetFullBountyPayoffAmount() > 0)) then
			GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(true)
		else
			GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(false)
		end
		if(GetFullBountyPayoffAmount() > 0 and self.bountyWillHit0In - GetTimeStamp() > 0) then
			-- Set timer to time remaining if there is a bounty and the timer won't be less than 0
			ThiefsAssistant:ChangeText("BountyTimerValue", self.bountyWillHit0In - GetTimeStamp(), true)
		elseif(not self.savedVars.window["needBountyForTimer"]) then
			-- Otherwise set the timer to equal 0
			ThiefsAssistant:ChangeText("BountyTimerValue", 0, true)
		end
	end
end

function ThiefsAssistantOnUpdate()
	if(ThiefsAssistant.savedVars) then
		time = time + 1
		timerTime = timerTime + 1

		if(timerTime == ThiefsAssistant.savedVars["updateSpeedTimers"]) then
			timerTime = 0
			ThiefsAssistant:UpdateAllTimers()
		end

		if(time == ThiefsAssistant.savedVars["updateSpeed"]) then
			time = 0
			if(not ThiefsAssistant.oldBounty or ThiefsAssistant.oldBounty ~= GetFullBountyPayoffAmount()) then
				ThiefsAssistant.estimatedBountyTime = (GetFullBountyPayoffAmount() / (0.0050 + (0.0017 * (GetUnitLevel("player") - 1)))) + (GetPlayerInfamyData() / 2)	--estimated bounty time formula
				ThiefsAssistant.bountyWillHit0In = GetTimeStamp() + ThiefsAssistant.estimatedBountyTime
				ThiefsAssistant.oldBounty = GetFullBountyPayoffAmount()
				--d("updating time till bounty reset")
			end
			if(ThiefsAssistant.savedVars.window["showBounty"]) then
				ThiefsAssistant:ChangeText("BountyValue", GetFullBountyPayoffAmount(), false, true)
			end
			-- Stores data related to bounties
			local savedLastVal = ThiefsAssistant.savedVars.BData["lastVal"]
			local currentVal = GetFullBountyPayoffAmount()
			local currentHeat = GetPlayerInfamyData()
			if(savedLastVal ~= currentVal or not savedLastVal or currentHeat ~= 0) then
				ThiefsAssistant.savedVars.BData["lastVal"] = currentVal
				ThiefsAssistant.savedVars.BData[GetTimeStamp() .. "_" .. (GetUnitLevel("player") + GetUnitChampionPoints("player"))] = currentVal
				ThiefsAssistant.savedVars.BData.heat[GetTimeStamp() .. "_" .. (GetUnitLevel("player") + GetUnitChampionPoints("player")) .. "_heat"] = currentHeat
				--d("bounty changed")
			end
		end
	end
end

function ThiefsAssistant.UpdateWindowFromSettings()
	savedWindowData = ThiefsAssistant.savedVars.window
	win = ThiefsAssistantWindow
	xLocation = 5
	
	if(savedWindowData["showBounty"]) then
		GetControl(win, "Bounty"):SetHidden(false)
		GetControl(win, "Bounty"):ClearAnchors()
		GetControl(win, "Bounty"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 125
	else
		GetControl(win, "Bounty"):SetHidden(true)
	end
	if(savedWindowData["showSells"]) then
		GetControl(win, "FenceSells"):SetHidden(false)
		GetControl(win, "FenceSells"):ClearAnchors()
		GetControl(win, "FenceSells"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 155
	else
		GetControl(win, "FenceSells"):SetHidden(true)
	end
	if(savedWindowData["showLaunders"]) then
		GetControl(win, "FenceLaunders"):SetHidden(false)
		GetControl(win, "FenceLaunders"):ClearAnchors()
		GetControl(win, "FenceLaunders"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 180
	else
		GetControl(win, "FenceLaunders"):SetHidden(true)
	end
	if(savedWindowData["showFenceResetTimer"]) then
		GetControl(win, "FenceTimer"):SetHidden(false)
		GetControl(win, "FenceTimer"):ClearAnchors()
		GetControl(win, "FenceTimer"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 145
	else
		GetControl(win, "FenceTimer"):SetHidden(true)
	end
	if(savedWindowData["showInvValue"]) then
		GetControl(win, "InventoryValue"):SetHidden(false)
		GetControl(win, "InventoryValue"):ClearAnchors()
		GetControl(win, "InventoryValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 155
	else
		GetControl(win, "InventoryValue"):SetHidden(true)
	end
	if(savedWindowData["showInvNumItems"]) then
		GetControl(win, "InventoryNumItems"):SetHidden(false)
		GetControl(win, "InventoryNumItems"):ClearAnchors()
		GetControl(win, "InventoryNumItems"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 135
	else
		GetControl(win, "InventoryNumItems"):SetHidden(true)
	end
	if(savedWindowData["showBountyTimer"]) then
		GetControl(win, "BountyTimer"):SetHidden(false)
		GetControl(win, "BountyTimer"):ClearAnchors()
		GetControl(win, "BountyTimer"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 145
	else
		GetControl(win, "BountyTimer"):SetHidden(true)
	end
end

local function AttemptDestroy(link, bagId, slotId)
	local saved = ThiefsAssistant.savedVars.itemManager
	local type = GetItemLinkItemType(link)
	local success = false
	if(type == ITEMTYPE_INGREDIENT and saved["destroyIngredients"]) then
		DestroyItem(bagId, slotId)
		success = true
	elseif((type == ITEMTYPE_DRINK or type == ITEMTYPE_FOOD) and saved["destroyFood"]) then
		DestroyItem(bagId, slotId)
		success = true
	elseif(type == ITEMTYPE_RECIPE and (saved["destroyKnownRecipes"] or saved["destroyRecipesOfRarity"] ~= ITEM_QUALITY_TRASH)) then
		if((saved["destroyKnownRecipes"] and GetRecipeInfo(GetItemLinkGrantedRecipeIndices(link))) and (saved["destroyRecipesOfRarity"] ~= ITEM_QUALITY_TRASH and GetItemLinkQuality(link) <= saved["destroyRecipesOfRarity"])) then
			DestroyItem(bagId, slotId)
			success = true
		elseif(saved["destroyKnownRecipes"] and GetRecipeInfo(GetItemLinkGrantedRecipeIndices(link))) then
			DestroyItem(bagId, slotId)
			success = true
		elseif(saved["destroyRecipesOfRarity"] ~= ITEM_QUALITY_TRASH and GetItemLinkQuality(link) <= saved["destroyRecipesOfRarity"]) then
			DestroyItem(bagId, slotId)
			success = true
		end
	elseif((type == ITEMTYPE_WEAPON or type == ITEMTYPE_ARMOR) and saved["destroyGearUnderValue"] ~= 0 and GetItemLinkValue(link, false) < saved["destroyGearUnderValue"]) then
		DestroyItem(bagId, slotId)
		success = true
	elseif(type == ITEMTYPE_TREASURE and saved["destroyTreasuresOfRarity"] ~= ITEM_QUALITY_TRASH and GetItemLinkQuality(link) <= saved["destroyTreasuresOfRarity"]) then
		DestroyItem(bagId, slotId)
		success = true
	end
	return success
end

function ThiefsAssistant.OnItemAcquired(eventType, bagId, slotId)
	local link = GetItemLink(bagId, slotId, LINK_STYLE_BRACKETS)

	if(IsItemStolen(bagId, slotId)) then
		if(not AttemptDestroy(link, bagId, slotId)) then
			ThiefsAssistant:InitializeOrUpdateStolenList()
			ThiefsAssistant:ChangeText("InventoryValueValue", ThiefsAssistant:GetStolenStuffValue(), false, true)
			ThiefsAssistant:ChangeText("InventoryNumItemsValue", #ThiefsAssistant.StolenStuff)
		elseif(ThiefsAssistant.savedVars.itemManager["notifyOnDestroy"]) then
			Print("Destroyed " .. link)
		end
	end

	-- If the item is purple or gold
	if(GetItemLinkQuality(link) >= ThiefsAssistant.savedVars.window["minQualityNotify"]) then
		Print("Picked up " .. link)
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function(eventType, initial)
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
		ThiefsAssistant:InitializeOrUpdateStolenList()
		ThiefsAssistant:ChangeText("InventoryValueValue", ThiefsAssistant:GetStolenStuffValue(), false, true)
		ThiefsAssistant:ChangeText("InventoryNumItemsValue", #ThiefsAssistant.StolenStuff)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ThiefsAssistant.OnItemAcquired)
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_RETICLE_HIDDEN_UPDATE, function(eventType, hidden)
	if(not hidden) then
		ThiefsAssistant.window:SetHidden(false)
	end
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_CHARACTER_FRAMING_STARTED, function(eventCode)
	ThiefsAssistant.window:SetHidden(true)
end)

