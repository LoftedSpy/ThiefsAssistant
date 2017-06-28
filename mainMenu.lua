local ADDON_NAME = ThiefsAssistant.name

local panelData = {
	type = "panel",
	name = "Thief's Assistant Options",
	displayName = "|cFF0000Thief's Assistant|r Options",
	author = "LoftedSpy",
	version = ThiefsAssistant.version,
	--website
	keywords = "thiefsassistantoptions thiefsassistantsettings",
}

local optionsData = {
	[1] = {
		type = "checkbox",
		name = "Show remaining fence sells",
		getFunc = function() return ThiefsAssistant.savedVars.window["showSells"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showSells"] = value
			local UpdateSettings = ThiefsAssistant.UpdateSettings
			UpdateSettings()
		end,
	},
	[2] = {
		type = "checkbox",
		name = "Show remaining launders",
		getFunc = function() return ThiefsAssistant.savedVars.window["showLaunders"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showLaunders"] = value
			local UpdateSettings = ThiefsAssistant.UpdateSettings
			UpdateSettings()
		end,
	},
	[3] = {
		type = "checkbox",
		name = "Show time remaining until fence resets",
		getFunc = function() return ThiefsAssistant.savedVars.window["showLaunders"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showLaunders"] = value
			local UpdateSettings = ThiefsAssistant.UpdateSettings
			UpdateSettings()
		end,
	},
	[4] = {
		type = "dropdown",
		name = "Timer style",
		choices = {"12 hour", "24 hour", "Largest unit", "Descriptive 24 hour", "Descriptive 12 hour"},
		choicesValues = {
			{TIME_FORMAT_PRECISION_TWELVE_HOUR, TIME_FORMAT_STYLE_COLONS},
			{TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR, TIME_FORMAT_STYLE_COLONS},
			{TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE},
			{TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL},
			{TIME_FORMAT_PRECISION_TWELVE_HOUR, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL},
		},
		getFunc = function()
			local precision = ThiefsAssistant.window["timeFormatPrecision"]
			local style = ThiefsAssistant.window["timeFormatStyle"]
			if(precision == TIME_FORMAT_PRECISION_TWELVE_HOUR) then
				if(style == TIME_FORMAT_STYLE_COLONS) then
					return "12 hour"
				else
					return "Descriptive 12 hour"
				end
			elseif(precision == TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR) then
				if(style == TIME_FORMAT_STYLE_COLONS) then
					return "24 hour"
				else
					return "Descriptive 24 hour"
				end
			else
				return "Largest unit"
			end
		end,
		setFunc = function(var)
			ThiefsAssistant.savedVars.window["timeFormatPrecision"] = var[1]
			ThiefsAssistant.savedVars.window["timeFormatStyle"] = var[2]
			ThiefsAssistant.UpdateAllTimers()
		end,
	},
}

ThiefsAssistant.setUpMenu = function()
	local LAM2 = LibStub:GetLibrary("LibAddonMenu-2.0")
	LAM2:RegisterAddonPanel("ThiefsAssistantOptions", panelData)
	LAM2:RegisterOptionControls("ThiefsAssistantOptions", optionsData)
end