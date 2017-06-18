-- Find out what parts of addon are enabled and then create the window based on the allocated width of each part
ThiefsAssistant = {}

local ADDON_NAME = "ThiefsAssistant"
local UPDATE_TIMER = 300
local time = 0

function ThiefsAssistant:Init()
	--Determine required length of bar on this line

end

function ThiefsAssistant.OnAddonLoad(eventType, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	local window = ThiefsAssistantWindow

	-- Add textures
	-- put this in a loop for god's sake
	local texB = WINDOW_MANAGER:CreateControl("ThiefsAssistantTextureBounty", window, CT_TEXTURE)
	texB:SetDimensions(20, 20)
	texB:SetAnchor(TOPLEFT, window, TOPLEFT, 5, 5)
	texB:SetTexture("esoui/art/stats/justice_bounty_icon-white.dds")

	local texS = WINDOW_MANAGER:CreateControl("ThiefsAssistantTextureSells", window, CT_TEXTURE)
	texS:SetDimensions(20, 20)
	texS:SetAnchor(TOPLEFT, window, TOPLEFT, 130, 5)
	texS:SetTexture("esoui/art/stats/justice_bounty_icon-red.dds")

	local texL = WINDOW_MANAGER:CreateControl("ThiefsAssistantTextureLaunders", window, CT_TEXTURE)
	texL:SetDimensions(20, 20)
	texL:SetAnchor(TOPLEFT, window, TOPLEFT, 285, 5)
	texL:SetTexture("esoui/art/stats/justice_bounty_icon-red.dds")

	local texFT = WINDOW_MANAGER:CreateControl("ThiefsAssistantTextureFenceTimer", window, CT_TEXTURE)
	texFT:SetDimensions(20, 20)
	texFT:SetAnchor(TOPLEFT, window, TOPLEFT, 465, 5)
	texFT:SetTexture("esoui/art/stats/justice_bounty_icon-white.dds")

	-- The following event only triggers when bounty increases so updater is still necessary
	-- EVENT_JUSTICE_INFAMY_UPDATED will also work
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(event, oldBounty, newBounty, isInitialize)
		GetControl(window, "BountyValue"):SetText(newBounty)
		time = 0
	end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_FENCE_UPDATE, function()
		local totalSells, sellsUsed = GetFenceSellTransactionInfo()
		local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
		GetControl(window, "FenceSellsValue"):SetText(totalSells - sellsUsed .. "/" .. totalSells)
		GetControl(window, "FenceLaundersValue"):SetText(totalLaunders - laundersUsed .. "/" .. totalLaunders)
		time = 0
	end)

	-- Initialize values
	GetControl(window, "BountyValue"):SetText(GetFullBountyPayoffAmount())
	local totalSells, sellsUsed, fenceResetTime = GetFenceSellTransactionInfo()
	local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
	GetControl(window, "FenceSellsValue"):SetText(totalSells - sellsUsed .. "/" .. totalSells)
	GetControl(window, "FenceLaundersValue"):SetText(totalLaunders - laundersUsed .. "/" .. totalLaunders)
	GetControl(window, "FenceTimerValue"):SetText(fenceResetTime)

	local saveData = ZO_SavedVars:NewAccountWide("ThiefsAssistantSavedVars", 1)
	ThiefsAssistant.savedVars = saveData
	local test = saveData.window or {}
	saveData.window = test

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

local function secondsToTime(original)
	seconds = math.floor(original % 60)
	hours = math.floor(original / 3600)
	minutes = math.floor(original / 60) - (60 * hours)
	
	result = hours .. ":" .. minutes .. ":" .. seconds
	return result
end

function ThiefsAssistantOnUpdate()
	time = time + 1
	-- Every UPDATE_TIMER frames update values
	if(time > UPDATE_TIMER) then
		GetControl(ThiefsAssistantWindow, "BountyValue"):SetText(GetFullBountyPayoffAmount())
		time = 0
	end
	-- Every 30 frames update timers
	if(time % 30 == 0) then
		local a, b, timeSeconds = GetFenceSellTransactionInfo()
		GetControl(ThiefsAssistantWindow, "FenceTimerValue"):SetText(secondsToTime(timeSeconds))
		time = 0
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)