local ADDON_NAME = ThiefsAssistant.name

local DIRECTION_HORIZONTAL = 0
local DIRECTION_VERTICAL = 1

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
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[2] = {
		type = "checkbox",
		name = "Show remaining launders",
		getFunc = function() return ThiefsAssistant.savedVars.window["showLaunders"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showLaunders"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[3] = {
		type = "checkbox",
		name = "Show time remaining until fence resets",
		getFunc = function() return ThiefsAssistant.savedVars.window["showFenceResetTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showFenceResetTimer"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[4] = {
		type = "checkbox",
		name = "Show time remaining until bounty expires",
		getFunc = function() return ThiefsAssistant.savedVars.window["showBountyTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showBountyTimer"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[5] = {
		type = "checkbox",
		name = "Only display bounty timer if you have a bounty",
		getFunc = function() return ThiefsAssistant.savedVars.window["needBountyForTimer"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["needBountyForTimer"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
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
	[9] = {
		type = "dropdown",
		name = "Chat notifications on picking up rare items",
		choices = {"Do not notify", "Normal", "Fine", "Superior", "Epic", "Legendary"},
		choicesValues = {ITEM_QUALITY_TRASH, ITEM_QUALITY_NORMAL, ITEM_QUALITY_MAGIC, ITEM_QUALITY_ARCANE, ITEM_QUALITY_ARTIFACT, ITEM_QUALITY_LEGENDARY},
		getFunc = function() return ThiefsAssistant.savedVars.window["minQualityNotify"] end,
		setFunc = function(var) ThiefsAssistant.savedVars.window["minQualityNotify"] = var end,
		choicesTooltips = {"", "White items", "Green items", "Blue items", "Purple items", "Gold items"},
	},
	[10] = {
		type = "slider",
		name = "Background alpha",
		getFunc = function() return ThiefsAssistant.savedVars.window["alphaBg"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["alphaBg"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
		min = 0,
		max = 1,
		step = 0.01,
		decimals = 2,
	},
	[11] = {
		type = "slider",
		name = "Text alpha",
		getFunc = function() return ThiefsAssistant.savedVars.window["alphaText"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["alphaText"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
		min = 0,
		max = 1,
		step = 0.01,
		decimals = 2,
	},
	[12] = {
		type = "checkbox",
		name = "Display value of stolen treasures",
		getFunc = function() return ThiefsAssistant.savedVars.window["showInvValue"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showInvValue"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[13] = {
		type = "checkbox",
		name = "Display number of stolen items in inventory",
		getFunc = function() return ThiefsAssistant.savedVars.window["showInvNumItems"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["showInvNumItems"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[14] = {
		type = "checkbox",
		name = "Show descriptions of stats",
		getFunc = function() return ThiefsAssistant.savedVars.window["displayTitles"] end,
		setFunc = function(value)
			ThiefsAssistant.savedVars.window["displayTitles"] = value
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[15] = {
		type = "dropdown",
		name = "Direction of window",
		choices = {"Horizontal", "Vertical"},
		choicesValues = {DIRECTION_HORIZONTAL, DIRECTION_VERTICAL},
		getFunc = function() return ThiefsAssistant.savedVars.window["direction"] end,
		setFunc = function(var)
			ThiefsAssistant.savedVars.window["direction"] = var
			ThiefsAssistant:UpdateWindowFromSettings()
		end,
	},
	[16] = {
		type = "submenu",
		name = "Stolen Items Manager",
		controls = {
			[1] = {
				type = "description",
				text = "BY ENABLING DESTRUCTION OF ITEMS YOU MAY LOSE ITEMS UNINTENTIONALLY!\nDestruction of items will not be enabled until you reload the UI so that you can modify the settings to your preference first.",
				title = "|c800000|t30:30:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds:inheritcolor|tWARNING|t30:30:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds:inheritcolor|t|r"
			},
			[2] = {
				type = "divider",
			},
			[3] = {
				type = "checkbox",
				name = "|c800000Destroy unwanted items|r",
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
				setFunc = function(value) ThiefsAssistant.savedVars.itemManager["allowDestruction"] = value end,
				requiresReload = true,
			},
			[4] = {
				type = "checkbox",
				name = "Destroy stolen ingredients",
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["destroyIngredients"] end,
				setFunc = function(value) ThiefsAssistant.savedVars.itemManager["destroyIngredients"] = value end,
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[5] = {
				type = "checkbox",
				name = "Destroy stolen food",
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["destroyFood"] end,
				setFunc = function(value) ThiefsAssistant.savedVars.itemManager["destroyFood"] = value end,
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[6] = {
				type = "checkbox",
				name = "Destroy stolen recipes only if they are known",
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["destroyKnownRecipes"] end,
				setFunc = function(value) ThiefsAssistant.savedVars.itemManager["destroyKnownRecipes"] = value end,
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[7] = {
				type = "dropdown",
				name = "Destroy stolen recipes of this quality or less",
				choices = {"Do not destroy", "Normal", "Fine", "Superior", "Epic", "Legendary"},
				choicesValues = {ITEM_QUALITY_TRASH, ITEM_QUALITY_NORMAL, ITEM_QUALITY_MAGIC, ITEM_QUALITY_ARCANE, ITEM_QUALITY_ARTIFACT, ITEM_QUALITY_LEGENDARY},
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["destroyRecipesOfRarity"] end,
				setFunc = function(var) ThiefsAssistant.savedVars.itemManager["destroyRecipesOfRarity"] = var end,
				tooltip = "If known recipes only is enabled, this will only destroy known recipes",
				choicesTooltips = {"", "White items", "Green items", "Blue items", "Purple items", "Gold items"},
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[8] = {
				type = "slider",
				name = "Destroy gear worth less than",
				getFunc = function() return ThiefsAssistant.savedVars["destroyGearUnderValue"] end,
				setFunc = function(value) ThiefsAssistant.savedVars["destroyGearUnderValue"] = value end,
				min = 0,
				max = 1000,
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[9] = {
				type = "dropdown",
				name = "Destroy stolen treasures of this quality or less",
				choices = {"Do not destroy", "Normal", "Fine", "Superior", "Epic"},
				choicesValues = {ITEM_QUALITY_TRASH, ITEM_QUALITY_NORMAL, ITEM_QUALITY_MAGIC, ITEM_QUALITY_ARCANE, ITEM_QUALITY_ARTIFACT},
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["destroyTreasuresOfRarity"] end,
				setFunc = function(var) ThiefsAssistant.savedVars.itemManager["destroyTreasuresOfRarity"] = var end,
				choicesTooltips = {"", "White items (40)", "Green items (100)", "Blue items (250)", "Purple items (1500)"},
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			},
			[10] = {
				type = "checkbox",
				name = "Chat notification on destruction",
				getFunc = function() return ThiefsAssistant.savedVars.itemManager["notifyOnDestroy"] end,
				setFunc = function(value) ThiefsAssistant.savedVars.itemManager["notifyOnDestroy"] = value end,
				disabled = function() return not ThiefsAssistant.savedVars.itemManager["allowDestruction"] end,
			}
		},
	},
}

ThiefsAssistant.setUpMenu = function()
	local LAM2 = LibStub:GetLibrary("LibAddonMenu-2.0")
	LAM2:RegisterAddonPanel("ThiefsAssistantOptions", panelData)
	LAM2:RegisterOptionControls("ThiefsAssistantOptions", optionsData)
end