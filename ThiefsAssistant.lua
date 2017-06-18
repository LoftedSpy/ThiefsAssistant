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

	local MyTexture = WINDOW_MANAGER:CreateControl("ThiefsAssistantTextureTest", window, CT_TEXTURE)
	MyTexture:SetDimensions(20, 20)
	MyTexture:SetAnchor(TOPLEFT, window, TOPLEFT, 5, 5)
	MyTexture:SetTexture("esoui/art/stats/justice_bounty_icon-white.dds")

	-- The following event only triggers when bounty increases so updater is still necessary
	-- EVENT_JUSTICE_INFAMY_UPDATED will also work
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(event, oldBounty, newBounty, isInitialize)
		GetControl(window, "BountyValue"):SetText(newBounty)
		time = 0
	end)

	-- Initialize bounty
	GetControl(window, "BountyValue"):SetText(GetFullBountyPayoffAmount())

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

function ThiefsAssistantOnUpdate()
	time = time + 1
	-- exectues every updateTimer seconds
	if(time > UPDATE_TIMER) then
		GetControl(ThiefsAssistantWindow, "BountyValue"):SetText(GetFullBountyPayoffAmount())
		time = 0
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, ThiefsAssistant.OnAddonLoad)