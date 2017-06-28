local ADDON_NAME = ThiefsAssistant.name

local panelData = {
	type = "panel",
	name = "Thief's Assistant Options",
	displayName = "|cFF0000Thief's Assistant|r Options",
	author = "LoftedSpy",
	version = ThiefsAssistant.version,
	--website
	keywords = "thiefsassistantoptions thiefsassistantsettings",
	registerForRefresh = true;
}

local optionsData = {
	[1] = {
		type = "checkbox",
		name = "Show remaining fence sells",
		getFunc = function() return ThiefsAssistant.savedVars.window["showSells"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showSells"] = value
			ThiefsAssistant.UpdateWindowFromSettings()
		end,
	},
	[2] = {
		type = "checkbox",
		name = "Show remaining launders",
		getFunc = function() return ThiefsAssistant.savedVars.window["showLaunders"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showLaunders"] = value
			ThiefsAssistant.UpdateWindowFromSettings()
		end,
	},
	[3] = {
		type = "checkbox",
		name = "Show time remaining until fence resets",
		getFunc = function() return ThiefsAssistant.savedVars.window["showFenceResetTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showFenceResetTimer"] = value
			ThiefsAssistant.UpdateWindowFromSettings()
		end,
	},
	[4] = {
		type = "checkbox",
		name = "Show time remaining until bounty expires",
		getFunc = function() return ThiefsAssistant.savedVars.window["showBountyTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showBountyTimer"] = value
			ThiefsAssistant.UpdateWindowFromSettings()
		end,
	},
	[5] = {
		type = "checkbox",
		name = "Only display bounty timer if you have a bounty",
		getFunc = function() return ThiefsAssistant.savedVars.window["needBountyForTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["needBountyForTimer"] = value
			ThiefsAssistant.UpdateWindowFromSettings()
		end,
		disabled = function() return not ThiefsAssistant.savedVars.window["showBountyTimer"] end, 
	},
	[6] = {
		type = "dropdown",
		name = "Timer style",
		choices = {"Default", "Largest unit", "Descriptive"},
		choicesValues = {TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL},
		getFunc = function() return ThiefsAssistant.savedVars.window["timeFormatStyle"] end,
		setFunc = function(var)
			ThiefsAssistant.savedVars.window["timeFormatStyle"] = var
			ThiefsAssistant.UpdateAllTimers()
		end,
		tooltip = "This affects the bounty and fence timers",
		disabled = function() return not (ThiefsAssistant.savedVars.window["showFenceResetTimer"] or ThiefsAssistant.savedVars.window["showBountyTimer"]) end,
	},
	[7] = {
		type = "slider",
		name = "Refresh speed (in frames)",
		getFunc = function() return ThiefsAssistant.savedVars["updateSpeed"] end,
		setFunc = function(value) ThiefsAssistant.savedVars["updateSpeed"] = value end,
		min = 1,
		max = 300,
		warning = "This may cause lag at low values",
	},
	[8] = {
		type = "slider",
		name = "Timer refresh rate (in frames)",
		getFunc = function() return ThiefsAssistant.savedVars["updateSpeedTimers"] end,
		setFunc = function(value) ThiefsAssistant.savedVars["updateSpeedTimers"] = value end,
		min = 1,
		max = 60,
		warning = "This may cause lag at low values",
	},
}

ThiefsAssistant.setUpMenu = function()
	local LAM2 = LibStub:GetLibrary("LibAddonMenu-2.0")
	LAM2:RegisterAddonPanel("ThiefsAssistantOptions", panelData)
	LAM2:RegisterOptionControls("ThiefsAssistantOptions", optionsData)
end