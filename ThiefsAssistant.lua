ThiefsAssistant = {}

local ADDON_NAME = "ThiefsAssistant"
local VERSION = 0.8

-- Initialize timers
local time = 0
local timerTime = 0

-- Add important stuff to global table
ThiefsAssistant.name = ADDON_NAME
ThiefsAssistant.version = VERSION
ThiefsAssistant.StolenStuff = {}

---------------
-- Constants --
---------------

local ICON_OFFSET_LARGE = 22				-- For large icons (like justice_bounty_icon)
local ICON_OFFSET_SMALL = 26				-- For small icons (like bank_tabicon_gold_up)

local BOUNTY_VALUE_OFFSET = 71				-- Distance of value label from left of bounty control
local BOUNTY_LENGTH_FULL = 119				-- Length of bounty control
local BOUNTY_LENGTH_SHORT = 74				-- Length of bounty control not including title length

local FENCE_SELLS_VALUE_OFFSET = 122		-- Distance of value label from left of fencesells control
local FENCE_SELLS_LENGTH_FULL = 154			-- Length of fencesells control
local FENCE_SELLS_LENGTH_SHORT = 58			-- Length of fencesells control not including title length
											-- The remaining descriptions go about the same as those above
local FENCE_LAUNDERS_VALUE_OFFSET = 146
local FENCE_LAUNDERS_LENGTH_FULL = 177
local FENCE_LAUNDERS_LENGTH_SHORT = 57

local FENCE_TIMER_VALUE_OFFSET = 100
local FENCE_TIMER_LENGTH_FULL = 138
local FENCE_TIMER_LENGTH_SHORT = 62

local INVENTORY_VALUE_VALUE_OFFSET = 119
local INVENTORY_VALUE_LENGTH_FULL = 164
local INVENTORY_VALUE_LENGTH_SHORT = 71

local INVENTORY_NUM_ITEMS_VALUE_OFFSET = 110
local INVENTORY_NUM_ITEMS_LENGTH_FULL = 150
local INVENTORY_NUM_ITEMS_LENGTH_SHORT = 66

local BOUNTY_TIMER_VALUE_OFFSET = 106
local BOUNTY_TIMER_LENGTH_FULL = 148
local BOUNTY_TIMER_LENGTH_SHORT = 68

local DIRECTION_HORIZONTAL = 0
local DIRECTION_VERTICAL = 1

-- Defaults
local defaults = {
	["updateSpeed"] = 60,
	["updateSpeedTimers"] = 10,
	window = {
		["x"] = 550,
		["y"] = 900,
		["width"] = 1055,
		["height"] = 30,
		["alphaText"] = 1,
		["alphaBg"] = 0.6,
		["displayTitles"] = true,
		["direction"] = DIRECTION_HORIZONTAL,
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
		["destroyGearUnderValue"] = 0,							-- 0 means do not destroy stolen gear under value
		["destroyTreasuresOfRarity"] = ITEM_QUALITY_TRASH,		-- Trash means do not destroy treasures
	},
	BData = {
		["lastVal"] = 0,
		heat = {},
	},
}

-- Prints a message to chat along with the addon's name
local function Print(message) 
	df("[%s]: %s", ADDON_NAME, message)
end

function ThiefsAssistant.OnAddonLoad(eventType, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	local saveData = ZO_SavedVars:NewAccountWide("ThiefsAssistantSavedVars", VERSION, nil, defaults)
	ThiefsAssistant.savedVars = saveData

	ThiefsAssistant.destructionEnabledForInstance = saveData.itemManager["allowDestruction"]

	ThiefsAssistant.timeStyle = saveData.window["timeFormatStyle"]

	ThiefsAssistant.setUpMenu()

	ThiefsAssistant.estimatedBountyTime = (GetFullBountyPayoffAmount() / (0.007454646 + (0.001675579 * GetUnitLevel("player")))) + (GetPlayerInfamyData() / 2)	--estimated bounty time formula
	ThiefsAssistant.bountyWillHit0In = GetTimeStamp() + ThiefsAssistant.estimatedBountyTime

	local window = ThiefsAssistantWindow

	ThiefsAssistant.window = ThiefsAssistantWindow

	GetControl(window, "Bg"):SetAlpha(saveData.window["alphaBg"])

	-- xCoords should be formatted like {distance from left end of toplevelcontrol, offset of title from left of this control, offset of value from left of this control}
	local function BuildGroup(name, xCoords, yCoord, shown, icon, title, value)
		ctrl = WINDOW_MANAGER:CreateControlFromVirtual(("$(parent)" .. name), window, "ThiefsAssistantGroupTemplate")
		ctrl:SetAnchor(TOPLEFT, window, TOPLEFT, xCoords[1], 5)
		ctrl:SetHidden(not shown)
		ctrl:GetChild(1):SetTexture(icon)
		ctrl:GetChild(1):SetAnchor(TOPLEFT, ctrl, TOPLEFT, 0, yCoord - 5)
		ctrl:GetChild(2):SetText(title)
		ctrl:GetChild(2):SetAnchor(TOPLEFT, ctrl, TOPLEFT, xCoords[2], yCoord)
		ctrl:GetChild(2):SetHidden(not saveData.window["displayTitles"])
		ctrl:GetChild(3):SetText(value)
		if(saveData.window["displayTitles"]) then
			ctrl:GetChild(3):SetAnchor(TOPLEFT, ctrl, TOPLEFT, xCoords[3], yCoord)
		else
			ctrl:GetChild(3):SetAnchor(TOPLEFT, ctrl, TOPLEFT, xCoords[2], yCoord)
		end
		ctrl:SetAlpha(saveData.window["alphaText"])
	end

	-- Add textures and controls
	local savedWindowData = saveData.window
	
	local totalSells, sellsUsed, fenceResetTime = GetFenceSellTransactionInfo()
	local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()

	local displayTitles = saveData.window["displayTitles"]

	if(saveData.window["direction"] == DIRECTION_HORIZONTAL) then
		local xLocation = 5

		BuildGroup("Bounty", {xLocation, ICON_OFFSET_SMALL, BOUNTY_VALUE_OFFSET}, 0, savedWindowData["showBounty"], "esoui/art/bank/bank_tabicon_gold_up.dds", "Bounty:", GetFullBountyPayoffAmount())
		if(savedWindowData["showBounty"] and displayTitles) then xLocation = xLocation + BOUNTY_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + BOUNTY_LENGTH_SHORT end

		GetControl(window, "BountyIcon"):SetColor(255, 0, 0)

		BuildGroup("FenceSells", {xLocation, ICON_OFFSET_SMALL, FENCE_SELLS_VALUE_OFFSET}, 0, savedWindowData["showSells"], "esoui/art/vendor/vendor_tabicon_sell_up.dds", "Sells Remaining:", totalSells - sellsUsed .. "/" .. totalSells)
		if(savedWindowData["showSells"] and displayTitles) then xLocation = xLocation + FENCE_SELLS_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + FENCE_SELLS_LENGTH_SHORT end

		BuildGroup("FenceLaunders", {xLocation, ICON_OFFSET_SMALL, FENCE_LAUNDERS_VALUE_OFFSET}, 0, savedWindowData["showLaunders"], "esoui/art/vendor/vendor_tabicon_buy_up.dds", "Launders Remaining:", totalLaunders - laundersUsed .. "/" .. totalLaunders)
		if(savedWindowData["showLaunders"] and displayTitles) then xLocation = xLocation + FENCE_LAUNDERS_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + FENCE_LAUNDERS_LENGTH_SHORT end

		BuildGroup("FenceTimer", {xLocation, ICON_OFFSET_SMALL, FENCE_TIMER_VALUE_OFFSET}, 0, savedWindowData["showFenceResetTimer"], "esoui/art/vendor/vendor_tabicon_fence_up.dds", "Fence Reset:", FormatTimeSeconds(fenceResetTime, ThiefsAssistant.timeStyle))
		if(savedWindowData["showFenceResetTimer"] and displayTitles) then xLocation = xLocation + FENCE_TIMER_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + FENCE_TIMER_LENGTH_SHORT end

		BuildGroup("InventoryValue", {xLocation, ICON_OFFSET_SMALL, INVENTORY_VALUE_VALUE_OFFSET}, 0, savedWindowData["showInvValue"], "esoui/art/bank/bank_tabicon_gold_up.dds", "Inventory Value:", "na")
		if(savedWindowData["showInvValue"] and displayTitles) then xLocation = xLocation + INVENTORY_VALUE_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + INVENTORY_VALUE_LENGTH_SHORT end

		BuildGroup("InventoryNumItems", {xLocation, ICON_OFFSET_SMALL, INVENTORY_NUM_ITEMS_VALUE_OFFSET}, 0, savedWindowData["showInvNumItems"], "esoui/art/inventory/inventory_all_tabicon_inactive.dds", "# Stolen Items:", "na")
		if(savedWindowData["showInvNumItems"] and displayTitles) then xLocation = xLocation + INVENTORY_NUM_ITEMS_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + INVENTORY_NUM_ITEMS_LENGTH_SHORT end

		BuildGroup("BountyTimer", {xLocation, ICON_OFFSET_SMALL, BOUNTY_TIMER_VALUE_OFFSET}, 0, savedWindowData["showBountyTimer"], "esoui/art/treeicons/achievements_indexicon_justice_up.dds", "Bounty Reset:", FormatTimeSeconds(0, ThiefsAssistant.timeStyle))
		if(savedWindowData["showBountyTimer"] and displayTitles) then xLocation = xLocation + BOUNTY_TIMER_LENGTH_FULL elseif(savedWindowData["showBounty"]) then xLocation = xLocation + BOUNTY_TIMER_LENGTH_SHORT end
		
		saveData.window["height"] = 30
		saveData.window["width"] = xLocation
	else
		local yLocation = 0
		local longestControl = 0

		BuildGroup("Bounty", {0, ICON_OFFSET_SMALL, BOUNTY_VALUE_OFFSET}, yLocation, savedWindowData["showBounty"], "esoui/art/bank/bank_tabicon_gold_up.dds", "Bounty:", GetFullBountyPayoffAmount())
		GetControl(window, "BountyIcon"):SetColor(255, 0, 0)
		if savedWindowData["showBounty"] then
			yLocation = yLocation + 20
			if(displayTitles and BOUNTY_LENGTH_FULL > longestControl) then
				longestControl = BOUNTY_LENGTH_FULL
			elseif(not displayTitles and BOUNTY_LENGTH_SHORT > longestControl) then
				longestControl = BOUNTY_LENGTH_SHORT
			end
		end

		BuildGroup("FenceSells", {0, ICON_OFFSET_SMALL, FENCE_SELLS_VALUE_OFFSET}, yLocation, savedWindowData["showSells"], "esoui/art/vendor/vendor_tabicon_sell_up.dds", "Sells Remaining:", totalSells - sellsUsed .. "/" .. totalSells)
		if savedWindowData["showSells"] then
			yLocation = yLocation + 20
			if(displayTitles and FENCE_SELLS_LENGTH_FULL > longestControl) then
				longestControl = FENCE_SELLS_LENGTH_FULL
			elseif(not displayTitles and FENCE_SELLS_LENGTH_SHORT > longestControl) then
				longestControl = FENCE_SELLS_LENGTH_SHORT
			end
		end

		BuildGroup("FenceLaunders", {0, ICON_OFFSET_SMALL, FENCE_LAUNDERS_VALUE_OFFSET}, yLocation, savedWindowData["showLaunders"], "esoui/art/vendor/vendor_tabicon_buy_up.dds", "Launders Remaining:", totalLaunders - laundersUsed .. "/" .. totalLaunders)
		if savedWindowData["showLaunders"] then
			yLocation = yLocation + 20
			if(displayTitles and FENCE_LAUNDERS_LENGTH_FULL > longestControl) then
				longestControl = FENCE_LAUNDERS_LENGTH_FULL
			elseif(not displayTitles and FENCE_LAUNDERS_LENGTH_SHORT > longestControl) then
				longestControl = FENCE_LAUNDERS_LENGTH_SHORT
			end
		end

		BuildGroup("FenceTimer", {0, ICON_OFFSET_SMALL, FENCE_TIMER_VALUE_OFFSET}, yLocation, savedWindowData["showFenceResetTimer"], "esoui/art/vendor/vendor_tabicon_fence_up.dds", "Fence Reset:", FormatTimeSeconds(fenceResetTime, ThiefsAssistant.timeStyle))
		if savedWindowData["showFenceResetTimer"] then
			yLocation = yLocation + 20
			if(displayTitles and FENCE_TIMER_LENGTH_FULL > longestControl) then
				longestControl = FENCE_TIMER_LENGTH_FULL
			elseif(not displayTitles and FENCE_TIMER_LENGTH_SHORT > longestControl) then
				longestControl = FENCE_TIMER_LENGTH_SHORT
			end
		end

		BuildGroup("InventoryValue", {0, ICON_OFFSET_SMALL, INVENTORY_VALUE_VALUE_OFFSET}, yLocation, savedWindowData["showInvValue"], "esoui/art/bank/bank_tabicon_gold_up.dds", "Inventory Value:", "na")
		if savedWindowData["showInvValue"] then
			yLocation = yLocation + 20
			if(displayTitles and INVENTORY_VALUE_LENGTH_FULL > longestControl) then
				longestControl = INVENTORY_VALUE_LENGTH_FULL
			elseif(not displayTitles and INVENTORY_VALUE_LENGTH_SHORT > longestControl) then
				longestControl = INVENTORY_VALUE_LENGTH_SHORT
			end
		end

		BuildGroup("InventoryNumItems", {0, ICON_OFFSET_SMALL, INVENTORY_NUM_ITEMS_VALUE_OFFSET}, yLocation, savedWindowData["showInvNumItems"], "esoui/art/inventory/inventory_all_tabicon_inactive.dds", "# Stolen Items:", "na")
		if savedWindowData["showInvNumItems"] then
			yLocation = yLocation + 20
			if(displayTitles and INVENTORY_NUM_ITEMS_LENGTH_FULL > longestControl) then
				longestControl = INVENTORY_NUM_ITEMS_LENGTH_FULL
			elseif(not displayTitles and INVENTORY_NUM_ITEMS_LENGTH_SHORT > longestControl) then
				longestControl = INVENTORY_NUM_ITEMS_LENGTH_SHORT
			end
		end

		BuildGroup("BountyTimer", {0, ICON_OFFSET_SMALL, BOUNTY_TIMER_VALUE_OFFSET}, yLocation, savedWindowData["showBountyTimer"], "esoui/art/treeicons/achievements_indexicon_justice_up.dds", "Bounty Reset:", FormatTimeSeconds(0, ThiefsAssistant.timeStyle))
		if savedWindowData["showBountyTimer"] then
			yLocation = yLocation + 20
			if(displayTitles and BOUNTY_TIMER_LENGTH_FULL > longestControl) then
				longestControl = BOUNTY_TIMER_LENGTH_FULL
			elseif(not displayTitles and BOUNTY_TIMER_LENGTH_SHORT > longestControl) then
				longestControl = BOUNTY_TIMER_LENGTH_SHORT
			end
		end

		saveData.window["width"] = longestControl + 10
		saveData.window["height"] = yLocation + 10
	end

	ThiefsAssistantWindow:SetDimensions(saveData.window["width"], saveData.window["height"])

	-- The following event only triggers when bounty increases so updater is still necessary
	-- EVENT_JUSTICE_INFAMY_UPDATED will also work
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(event, oldBounty, newBounty, isInitialize)
		if(ThiefsAssistant.savedVars.window["showBounty"]) then
			ThiefsAssistant:ChangeText("BountyValue", newBounty, false, true)
			time = 0
		end
	end)

	-- When # fence sells or launders availible changes
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

-- Change text of a label that is a child of ThiefsAssistantWindow
-- Set isTime or isCurrency flags to true to format as a time or currency using user settings
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

-- Returns value of stolen items and the total number of items stolen
function ThiefsAssistant:GetStolenStuffValue()
	local value = 0
	local num = 0
	for i, array in ipairs(self.StolenStuff) do
		local stack, val = select(2, GetItemInfo(INVENTORY_BACKPACK, array[2]))
		num = num + stack
		if GetItemLinkItemType(array[1]) == ITEMTYPE_TREASURE then
			value = value + (stack * val)
		end
	end
	return value, num
end

-- Populates or modifies StolenStuff list
function ThiefsAssistant:InitializeOrUpdateStolenList()
	local size = GetBagSize(INVENTORY_BACKPACK)
	local loc = 1
	for slot = 0, size do
		if(IsItemStolen(INVENTORY_BACKPACK, slot)) then
			self.StolenStuff[loc] = {GetItemLink(INVENTORY_BACKPACK, slot), slot}
			loc = loc + 1
		end
	end
end

-- Updates fence and bounty timers
function ThiefsAssistant:UpdateAllTimers()
	if(self.savedVars.window["showFenceResetTimer"]) then
		local a, b, timeSeconds = GetFenceSellTransactionInfo()
		ThiefsAssistant:ChangeText("FenceTimerValue", timeSeconds, true)
	end
	if(self.savedVars.window["showBountyTimer"]) then
		if(self.savedVars.window["needBountyForTimer"] and not (GetFullBountyPayoffAmount() > 0)) then
			if(not GetControl(ThiefsAssistantWindow, "BountyTimer"):IsHidden()) then
				GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(true)
				if(ThiefsAssistant.savedVars.window["direction"] == DIRECTION_HORIZONTAL) then
					if(ThiefsAssistant.savedVars.window["displayTitles"]) then
						ThiefsAssistantWindow:SetDimensions(ThiefsAssistant.savedVars.window["width"] - BOUNTY_TIMER_LENGTH_FULL, ThiefsAssistant.savedVars.window["height"])
					else
						ThiefsAssistantWindow:SetDimensions(ThiefsAssistant.savedVars.window["width"] - BOUNTY_TIMER_LENGTH_SHORT, ThiefsAssistant.savedVars.window["height"])
					end
				else
					ThiefsAssistantWindow:SetDimensions(ThiefsAssistant.savedVars.window["width"], ThiefsAssistant.savedVars.window["height"] - 20)
				end
			end
		else
			GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(false)
			ThiefsAssistantWindow:SetDimensions(ThiefsAssistant.savedVars.window["width"], ThiefsAssistant.savedVars.window["height"])
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

-- Called every frame and updates everything
function ThiefsAssistantOnUpdate()
	if(ThiefsAssistant.savedVars) then
		time = time + 1
		timerTime = timerTime + 1

		if(not IsInJusticeEnabledZone()) then
			ThiefsAssistant.window:SetHidden(true)
			return
		end

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

function ThiefsAssistant.ResetGroup(control, isHidden, x, y)
	control:SetHidden(isHidden)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
	control:SetAlpha(ThiefsAssistant.savedVars.window["alphaText"])
end

function ThiefsAssistant.AddOrRemoveTitles(control, isHidden, visibleOffset, invisibleOffset)
	control:GetChild(1):SetAnchor(TOPLEFT, control, TOPLEFT, 0, -5)
	control:GetChild(2):SetHidden(isHidden)
	control:GetChild(3):ClearAnchors()
	if(isHidden) then
		control:GetChild(3):SetAnchor(TOPLEFT, control, TOPLEFT, invisibleOffset)
	else
		control:GetChild(3):SetAnchor(TOPLEFT, control, TOPLEFT, visibleOffset)
	end
end

-- Redraws the window from current user settings
function ThiefsAssistant:UpdateWindowFromSettings()
	local savedWindowData = self.savedVars.window
	local win = ThiefsAssistantWindow
	
	GetControl(win, "Bg"):SetAlpha(savedWindowData["alphaBg"])

	if(savedWindowData["direction"] == DIRECTION_HORIZONTAL) then	-- Vertical formatting
		local xLocation = 5

		if(savedWindowData["showBounty"]) then
			local ctrl = GetControl(win, "Bounty")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], BOUNTY_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + BOUNTY_LENGTH_FULL
			else
				xLocation = xLocation + BOUNTY_LENGTH_SHORT
			end
		else
			GetControl(win, "Bounty"):SetHidden(true)
		end
		if(savedWindowData["showSells"]) then
			local ctrl = GetControl(win, "FenceSells")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_SELLS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + FENCE_SELLS_LENGTH_FULL
			else
				xLocation = xLocation + FENCE_SELLS_LENGTH_SHORT
			end
		else
			GetControl(win, "FenceSells"):SetHidden(true)
		end
		if(savedWindowData["showLaunders"]) then
			local ctrl = GetControl(win, "FenceLaunders")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_LAUNDERS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + FENCE_LAUNDERS_LENGTH_FULL
			else
				xLocation = xLocation + FENCE_LAUNDERS_LENGTH_SHORT
			end
		else
			GetControl(win, "FenceLaunders"):SetHidden(true)
		end
		if(savedWindowData["showFenceResetTimer"]) then
			local ctrl = GetControl(win, "FenceTimer")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_TIMER_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + FENCE_TIMER_LENGTH_FULL
			else
				xLocation = xLocation + FENCE_TIMER_LENGTH_SHORT
			end
		else
			GetControl(win, "FenceTimer"):SetHidden(true)
		end
		if(savedWindowData["showInvValue"]) then
			local ctrl = GetControl(win, "InventoryValue")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], INVENTORY_VALUE_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + INVENTORY_VALUE_LENGTH_FULL
			else
				xLocation = xLocation + INVENTORY_VALUE_LENGTH_SHORT
			end
		else
			GetControl(win, "InventoryValue"):SetHidden(true)
		end
		if(savedWindowData["showInvNumItems"]) then
			local ctrl = GetControl(win, "InventoryNumItems")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], INVENTORY_NUM_ITEMS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + INVENTORY_NUM_ITEMS_LENGTH_FULL
			else
				xLocation = xLocation + INVENTORY_NUM_ITEMS_LENGTH_SHORT
			end
		else
			GetControl(win, "InventoryNumItems"):SetHidden(true)
		end
		if(savedWindowData["showBountyTimer"]) then
			local ctrl = GetControl(win, "BountyTimer")
			self.ResetGroup(ctrl, false, xLocation, 5)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], BOUNTY_TIMER_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				xLocation = xLocation + BOUNTY_TIMER_LENGTH_FULL
			else
				xLocation = xLocation + BOUNTY_TIMER_LENGTH_SHORT
			end
		else
			GetControl(win, "BountyTimer"):SetHidden(true)
		end
		
		savedWindowData["width"] = xLocation
		savedWindowData["height"] = 30
		ThiefsAssistantWindow:SetDimensions(savedWindowData["width"], savedWindowData["height"])
	else	-- Horizontal formatting
		local yLocation = 5
		local longestControl = 0

		if(savedWindowData["showBounty"]) then
			local ctrl = GetControl(win, "Bounty")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], BOUNTY_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(BOUNTY_LENGTH_FULL > longestControl) then longestControl = BOUNTY_LENGTH_FULL end
			else
				if(BOUNTY_LENGTH_SHORT > longestControl) then longestControl = BOUNTY_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "Bounty"):SetHidden(true)
		end
		if(savedWindowData["showSells"]) then
			local ctrl = GetControl(win, "FenceSells")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_SELLS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(FENCE_SELLS_LENGTH_FULL > longestControl) then longestControl = FENCE_SELLS_LENGTH_FULL end
			else
				if(FENCE_SELLS_LENGTH_SHORT > longestControl) then longestControl = FENCE_SELLS_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "FenceSells"):SetHidden(true)
		end
		if(savedWindowData["showLaunders"]) then
			local ctrl = GetControl(win, "FenceLaunders")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_LAUNDERS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(FENCE_LAUNDERS_LENGTH_FULL > longestControl) then longestControl = FENCE_LAUNDERS_LENGTH_FULL end
			else
				if(FENCE_LAUNDERS_LENGTH_SHORT > longestControl) then longestControl = FENCE_LAUNDERS_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "FenceLaunders"):SetHidden(true)
		end
		if(savedWindowData["showFenceResetTimer"]) then
			local ctrl = GetControl(win, "FenceTimer")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], FENCE_TIMER_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(FENCE_TIMER_LENGTH_FULL > longestControl) then longestControl = FENCE_TIMER_LENGTH_FULL end
			else
				if(FENCE_TIMER_LENGTH_SHORT > longestControl) then longestControl = FENCE_TIMER_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "FenceTimer"):SetHidden(true)
		end
		if(savedWindowData["showInvValue"]) then
			local ctrl = GetControl(win, "InventoryValue")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], INVENTORY_VALUE_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(INVENTORY_VALUE_LENGTH_FULL > longestControl) then longestControl = INVENTORY_VALUE_LENGTH_FULL end
			else
				if(INVENTORY_VALUE_LENGTH_SHORT > longestControl) then longestControl = INVENTORY_VALUE_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "InventoryValue"):SetHidden(true)
		end
		if(savedWindowData["showInvNumItems"]) then
			local ctrl = GetControl(win, "InventoryNumItems")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], INVENTORY_NUM_ITEMS_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(INVENTORY_NUM_ITEMS_LENGTH_FULL > longestControl) then longestControl = INVENTORY_NUM_ITEMS_LENGTH_FULL end
			else
				if(INVENTORY_NUM_ITEMS_LENGTH_SHORT > longestControl) then longestControl = INVENTORY_NUM_ITEMS_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "InventoryNumItems"):SetHidden(true)
		end
		if(savedWindowData["showBountyTimer"]) then
			local ctrl = GetControl(win, "BountyTimer")
			self.ResetGroup(ctrl, false, 5, yLocation)
			self.AddOrRemoveTitles(ctrl, not savedWindowData["displayTitles"], BOUNTY_TIMER_VALUE_OFFSET, ICON_OFFSET_SMALL)
			if(savedWindowData["displayTitles"]) then
				if(BOUNTY_TIMER_LENGTH_FULL > longestControl) then longestControl = BOUNTY_TIMER_LENGTH_FULL end
			else
				if(BOUNTY_TIMER_LENGTH_SHORT > longestControl) then longestControl = BOUNTY_TIMER_LENGTH_SHORT end
			end
			yLocation = yLocation + 20
		else
			GetControl(win, "BountyTimer"):SetHidden(true)
		end

		savedWindowData["width"] = longestControl + 10
		savedWindowData["height"] = yLocation + 10
		ThiefsAssistantWindow:SetDimensions(savedWindowData["width"], savedWindowData["height"])
	end

	ThiefsAssistantOnUpdate()
	ThiefsAssistant:UpdateAllTimers()
end

-- Tries to destroy an item and returns whether it was successful or not
local function AttemptDestroy(link, bagId, slotId)
	-- Fails destruction if destruction was not enabled at time of addon load
	if(not destructionEnabledForInstance) then return false end

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

-- Called when an item is picked up
function ThiefsAssistant.OnItemAcquired(eventType, bagId, slotId)
	local link = GetItemLink(bagId, slotId, LINK_STYLE_BRACKETS)

	if(IsItemStolen(bagId, slotId)) then
		if(not AttemptDestroy(link, bagId, slotId)) then
			ThiefsAssistant:InitializeOrUpdateStolenList()
			local val, num = ThiefsAssistant:GetStolenStuffValue()
			ThiefsAssistant:ChangeText("InventoryValueValue", val, false, true)
			ThiefsAssistant:ChangeText("InventoryNumItemsValue", num .. " (" .. #ThiefsAssistant.StolenStuff .. ")")
		elseif(ThiefsAssistant.savedVars.itemManager["notifyOnDestroy"]) then
			Print("Destroyed " .. link)
		end
	end

	-- If the item is purple or gold
	if(ThiefsAssistant.savedVars.window["minQualityNotify"] ~= ITEM_QUALITY_TRASH and GetItemLinkQuality(link) >= ThiefsAssistant.savedVars.window["minQualityNotify"]) then
		Print("Picked up " .. link)
	end
end

------------
-- Events --
------------

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function(eventType, initial)
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
		ThiefsAssistant:InitializeOrUpdateStolenList()
		local val, num = ThiefsAssistant:GetStolenStuffValue()
		ThiefsAssistant:ChangeText("InventoryValueValue", val, false, true)
		ThiefsAssistant:ChangeText("InventoryNumItemsValue", num .. " (" .. #ThiefsAssistant.StolenStuff .. ")")

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ThiefsAssistant.OnItemAcquired)
end)

-- Shows window if the reticle is visible
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_RETICLE_HIDDEN_UPDATE, function(eventType, hidden)
	if(not hidden) then
		ThiefsAssistantWindow:SetHidden(false)
	end
end)

-- Hides window when entering an 'alt' menu
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_CHARACTER_FRAMING_STARTED, function(eventCode)
	ThiefsAssistantWindow:SetHidden(true)
end)

