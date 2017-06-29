-- Find out what parts of addon are enabled and then create the window based on the allocated width of each part
ThiefsAssistant = {}

local ADDON_NAME = "ThiefsAssistant"
ThiefsAssistant.name = ADDON_NAME
local VERSION = 0.65
ThiefsAssistant.version = VERSION
--local UPDATE_TIMER = 30
local time = 0
local timerTime = 0

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
	},
	BData = {
		["lastVal"] = 0,
		heat = {},
	},
}

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

	-- makes a new texture
	local function NewTexture(texture, name, xCoord, hidden)
		tex = WINDOW_MANAGER:CreateControl(("ThiefsAssistantWindowTexture" .. name), window, CT_TEXTURE)
		tex:SetDimensions(20, 20)
		tex:SetAnchor(TOPLEFT, window, TOPLEFT, xCoord, 5)
		tex:SetTexture(texture)
		tex:SetHidden(not hidden)
	end

	-- makes a new label from virtual. Text optional
	local function AddLabel(name, xCoord, hidden, text)
		lbl = WINDOW_MANAGER:CreateControlFromVirtual(("$(parent)" .. name), window, "ThiefsAssistantLabelTemplate")
		lbl:SetAnchor(TOPLEFT, window, TOPLEFT, xCoord, 5)
		if(text) then lbl:SetText(text) end
		lbl:SetHidden(not hidden)
	end

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

	BuildGroup("BountyTimer", {xLocation, 25, 105}, savedWindowData["showBountyTimer"], "esoui/art/stats/justice_bounty_icon-white.dds", "Bounty Reset:", FormatTimeSeconds(0, ThiefsAssistant.timeStyle))
	if savedWindowData["showBountyTimer"] then xLocation = xLocation + 145 end


	-- The following event only triggers when bounty increases so updater is still necessary
	-- EVENT_JUSTICE_INFAMY_UPDATED will also work
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(event, oldBounty, newBounty, isInitialize)
		if(ThiefsAssistant.savedVars.window["showBounty"]) then
			GetControl(window, "BountyValue"):SetText(newBounty)
			time = 0
		end
	end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_FENCE_UPDATE, function()
		if(ThiefsAssistant.savedVars.window["showSells"]) then
			local totalSells, sellsUsed = GetFenceSellTransactionInfo()
			GetControl(window, "FenceSellsValue"):SetText(totalSells - sellsUsed .. "/" .. totalSells)
		end
		if(ThiefsAssistant.savedVars.window["showLaunders"]) then
			local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
			GetControl(window, "FenceLaundersValue"):SetText(totalLaunders - laundersUsed .. "/" .. totalLaunders)
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

function ThiefsAssistant.UpdateAllTimers()
	if(ThiefsAssistant.savedVars.window["showFenceResetTimer"]) then
		local a, b, timeSeconds = GetFenceSellTransactionInfo()
		GetControl(ThiefsAssistantWindow, "FenceTimerValue"):SetText(FormatTimeSeconds(timeSeconds, ThiefsAssistant.savedVars.window["timeFormatStyle"]))
	end
	if(ThiefsAssistant.savedVars.window["showBountyTimer"]) then
		if(ThiefsAssistant.savedVars.window["needBountyForTimer"] and not (GetFullBountyPayoffAmount() > 0)) then
			GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(true)
		else
			GetControl(ThiefsAssistantWindow, "BountyTimer"):SetHidden(false)
		end
		if(GetFullBountyPayoffAmount() > 0 and ThiefsAssistant.bountyWillHit0In - GetTimeStamp() > 0) then
			GetControl(ThiefsAssistantWindow, "BountyTimerValue"):SetText(FormatTimeSeconds(ThiefsAssistant.bountyWillHit0In - GetTimeStamp(), ThiefsAssistant.savedVars.window["timeFormatStyle"]))
		elseif(not ThiefsAssistant.savedVars.window["needBountyForTimer"]) then
			GetControl(ThiefsAssistantWindow, "BountyTimerValue"):SetText(FormatTimeSeconds(0, ThiefsAssistant.savedVars.window["timeFormatStyle"]))
		end
	end
end

function ThiefsAssistantOnUpdate()
	if(ThiefsAssistant.savedVars) then
		time = time + 1
		timerTime = timerTime + 1

		if(timerTime == ThiefsAssistant.savedVars["updateSpeedTimers"]) then
			timerTime = 0
			ThiefsAssistant.UpdateAllTimers()
		end

		if(time == ThiefsAssistant.savedVars["updateSpeed"]) then
			time = 0
			if(not ThiefsAssistant.oldBounty or ThiefsAssistant.oldBounty ~= GetFullBountyPayoffAmount()) then
				ThiefsAssistant.estimatedBountyTime = (GetFullBountyPayoffAmount() / (0.0050 + (0.0017 * (GetUnitLevel("player") - 1)))) + (GetPlayerInfamyData() / 2)	--estimated bounty time formula
				ThiefsAssistant.bountyWillHit0In = GetTimeStamp() + ThiefsAssistant.estimatedBountyTime
				ThiefsAssistant.oldBounty = GetFullBountyPayoffAmount()
				d("updating time till bounty reset")
			end
			if(ThiefsAssistant.savedVars.window["showBounty"]) then
				GetControl(ThiefsAssistantWindow, "BountyValue"):SetText(GetFullBountyPayoffAmount())
			end
			-- Stores data related to bounties
			local savedLastVal = ThiefsAssistant.savedVars.BData["lastVal"]
			local currentVal = GetFullBountyPayoffAmount()
			local currentHeat = GetPlayerInfamyData()
			if(savedLastVal ~= currentVal or not savedLastVal or currentHeat ~= 0) then
				ThiefsAssistant.savedVars.BData["lastVal"] = currentVal
				ThiefsAssistant.savedVars.BData[GetTimeStamp() .. "_" .. (GetUnitLevel("player") + GetUnitChampionPoints("player"))] = currentVal
				ThiefsAssistant.savedVars.BData.heat[GetTimeStamp() .. "_" .. (GetUnitLevel("player") + GetUnitChampionPoints("player")) .. "_heat"] = currentHeat
				d("bounty changed")
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
	if(savedWindowData["showBountyTimer"]) then
		GetControl(win, "BountyTimer"):SetHidden(false)
		GetControl(win, "BountyTimer"):ClearAnchors()
		GetControl(win, "BountyTimer"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		xLocation = xLocation + 145
	else
		GetControl(win, "BountyTimer"):SetHidden(true)
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)