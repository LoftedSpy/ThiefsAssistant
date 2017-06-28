-- Find out what parts of addon are enabled and then create the window based on the allocated width of each part
ThiefsAssistant = {}

local ADDON_NAME = "ThiefsAssistant"
ThiefsAssistant.name = ADDON_NAME
local VERSION = 0.6
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

	-- Add textures and controls
	local savedWindowData = saveData.window
	local xLocation = 5
	
	NewTexture("esoui/art/stats/justice_bounty_icon-white.dds", "Bounty", xLocation, savedWindowData["showBounty"])
	AddLabel("BountyTitle", xLocation + 25, savedWindowData["showBounty"], "Bounty:")
	AddLabel("BountyValue", xLocation + 70, savedWindowData["showBounty"], GetFullBountyPayoffAmount())
	if savedWindowData["showBounty"] then xLocation = xLocation + 125 end

	local totalSells, sellsUsed, fenceResetTime = GetFenceSellTransactionInfo()
	
	NewTexture("esoui/art/stats/justice_bounty_icon-red.dds", "FenceSells", xLocation, savedWindowData["showSells"])
	AddLabel("FenceSellsTitle", xLocation + 25, savedWindowData["showSells"], "Sells Remaining:")
	AddLabel("FenceSellsValue", xLocation + 125, savedWindowData["showSells"], totalSells - sellsUsed .. "/" .. totalSells)
	if savedWindowData["showSells"] then xLocation = xLocation + 155 end

	local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()

	
	NewTexture("esoui/art/stats/justice_bounty_icon-red.dds", "FenceLaunders", xLocation, savedWindowData["showLaunders"])
	AddLabel("FenceLaundersTitle", xLocation + 25, savedWindowData["showLaunders"], "Launders Remaining:")
	AddLabel("FenceLaundersValue", xLocation + 145, savedWindowData["showLaunders"], totalLaunders - laundersUsed .. "/" .. totalLaunders)
	if savedWindowData["showLaunders"] then xLocation = xLocation + 180 end

	
	NewTexture("esoui/art/stats/justice_bounty_icon-white.dds", "FenceTimer", xLocation, savedWindowData["showFenceResetTimer"])
	AddLabel("FenceTimerTitle", xLocation + 25, savedWindowData["showFenceResetTimer"], "Fence Reset:")
	AddLabel("FenceTimerValue", xLocation + 105, savedWindowData["showFenceResetTimer"], FormatTimeSeconds(fenceResetTime, ThiefsAssistant.timeStyle))
	if savedWindowData["showFenceResetTimer"] then xLocation = xLocation + 145 end

	NewTexture("esoui/art/stats/justice_bounty_icon-white.dds", "BountyTimer", xLocation, savedWindowData["showBountyTimer"])
	AddLabel("BountyTimerTitle", xLocation + 25, savedWindowData["showBountyTimer"], "Bounty Reset:")
	AddLabel("BountyTimerValue", xLocation + 105, savedWindowData["showBountyTimer"], FormatTimeSeconds(0, ThiefsAssistant.timeStyle))
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
			GetControl(ThiefsAssistantWindow, "BountyTimerValue"):SetHidden(true)
			GetControl(ThiefsAssistantWindow, "BountyTimerTitle"):SetHidden(true)
			GetControl(ThiefsAssistantWindow, "TextureBountyTimer"):SetHidden(true)
		else
			GetControl(ThiefsAssistantWindow, "BountyTimerValue"):SetHidden(false)
			GetControl(ThiefsAssistantWindow, "BountyTimerTitle"):SetHidden(false)
			GetControl(ThiefsAssistantWindow, "TextureBountyTimer"):SetHidden(false)
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
		GetControl(win, "TextureBounty"):SetHidden(false)
		GetControl(win, "TextureBounty"):ClearAnchors()
		GetControl(win, "TextureBounty"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		GetControl(win, "BountyTitle"):SetHidden(false)
		GetControl(win, "BountyTitle"):ClearAnchors()
		GetControl(win, "BountyTitle"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 25, 5)
		GetControl(win, "BountyValue"):SetHidden(false)
		GetControl(win, "BountyValue"):ClearAnchors()
		GetControl(win, "BountyValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 70, 5)
		xLocation = xLocation + 125
	else
		GetControl(win, "TextureBounty"):SetHidden(true)
		GetControl(win, "BountyTitle"):SetHidden(true)
		GetControl(win, "BountyValue"):SetHidden(true)
	end
	if(savedWindowData["showSells"]) then
		GetControl(win, "TextureFenceSells"):SetHidden(false)
		GetControl(win, "TextureFenceSells"):ClearAnchors()
		GetControl(win, "TextureFenceSells"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		GetControl(win, "FenceSellsTitle"):SetHidden(false)
		GetControl(win, "FenceSellsTitle"):ClearAnchors()
		GetControl(win, "FenceSellsTitle"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 25, 5)
		GetControl(win, "FenceSellsValue"):SetHidden(false)
		GetControl(win, "FenceSellsValue"):ClearAnchors()
		GetControl(win, "FenceSellsValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 125, 5)
		xLocation = xLocation + 155
	else
		GetControl(win, "TextureFenceSells"):SetHidden(true)
		GetControl(win, "FenceSellsTitle"):SetHidden(true)
		GetControl(win, "FenceSellsValue"):SetHidden(true)
	end
	if(savedWindowData["showLaunders"]) then
		GetControl(win, "TextureFenceLaunders"):SetHidden(false)
		GetControl(win, "TextureFenceLaunders"):ClearAnchors()
		GetControl(win, "TextureFenceLaunders"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		GetControl(win, "FenceLaundersTitle"):SetHidden(false)
		GetControl(win, "FenceLaundersTitle"):ClearAnchors()
		GetControl(win, "FenceLaundersTitle"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 25, 5)
		GetControl(win, "FenceLaundersValue"):SetHidden(false)
		GetControl(win, "FenceLaundersValue"):ClearAnchors()
		GetControl(win, "FenceLaundersValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 145, 5)
		xLocation = xLocation + 180
	else
		GetControl(win, "TextureFenceLaunders"):SetHidden(true)
		GetControl(win, "FenceLaundersTitle"):SetHidden(true)
		GetControl(win, "FenceLaundersValue"):SetHidden(true)
	end
	if(savedWindowData["showFenceResetTimer"]) then
		GetControl(win, "TextureFenceTimer"):SetHidden(false)
		GetControl(win, "TextureFenceTimer"):ClearAnchors()
		GetControl(win, "TextureFenceTimer"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		GetControl(win, "FenceTimerTitle"):SetHidden(false)
		GetControl(win, "FenceTimerTitle"):ClearAnchors()
		GetControl(win, "FenceTimerTitle"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 25, 5)
		GetControl(win, "FenceTimerValue"):SetHidden(false)
		GetControl(win, "FenceTimerValue"):ClearAnchors()
		GetControl(win, "FenceTimerValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 105, 5)
		xLocation = xLocation + 145
	else
		GetControl(win, "TextureFenceTimer"):SetHidden(true)
		GetControl(win, "FenceTimerTitle"):SetHidden(true)
		GetControl(win, "FenceTimerValue"):SetHidden(true)
	end
	if(savedWindowData["showBountyTimer"]) then
		GetControl(win, "TextureBountyTimer"):SetHidden(false)
		GetControl(win, "TextureBountyTimer"):ClearAnchors()
		GetControl(win, "TextureBountyTimer"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation, 5)
		GetControl(win, "BountyTimerTitle"):SetHidden(false)
		GetControl(win, "BountyTimerTitle"):ClearAnchors()
		GetControl(win, "BountyTimerTitle"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 25, 5)
		GetControl(win, "BountyTimerValue"):SetHidden(false)
		GetControl(win, "BountyTimerValue"):ClearAnchors()
		GetControl(win, "BountyTimerValue"):SetAnchor(TOPLEFT, win, TOPLEFT, xLocation + 105, 5)
		xLocation = xLocation + 145
	else
		GetControl(win, "TextureBountyTimer"):SetHidden(true)
		GetControl(win, "BountyTimerTitle"):SetHidden(true)
		GetControl(win, "BountyTimerValue"):SetHidden(true)
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)