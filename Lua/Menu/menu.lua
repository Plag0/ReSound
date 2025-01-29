local config_path = Resound.ConfigPath
local easySettings = dofile(Resound.PATH .. "/Lua/Menu/easy_settings.lua")
local old_menu = nil

local function open_new_menu()
    if not GUI.GUI.PauseMenuOpen then
        GUI.GUI.TogglePauseMenu()
    end

    if old_menu then
        old_menu.FadeOut(0, true, 0, nil, true)
    end

    old_menu = GUI.GUI.PauseMenu
    for key, value in pairs(easySettings.Settings) do
        value.OnOpen(old_menu)
    end
end

easySettings.AddMenu(TextManager.Get("resound_settings").Value, function (parent)
    local list = easySettings.BasicList(parent)

    easySettings.TextBlock(list, TextManager.Get("resound_generalsettings").Value, nil, 0.1, 1.3, Color.LightYellow)

    local tick = easySettings.TickBox(list.Content, TextManager.Get("resound_enabled").Value, function (state)
        Resound.Config.Enabled = state
        easySettings.SaveTable(config_path, Resound.Config)
        if Resound.Config.Enabled then
            StartMod()
            open_new_menu()
        else
            StopMod()
        end
    end, Resound.Config.Enabled)
    tick.ToolTip = TextManager.Get("resound_enabled_tooltip").Value

    local tick = easySettings.TickBox(list.Content, TextManager.Get("resound_importantlogs").Value, function (state)
        Resound.Config.ImportantLogs = state
        easySettings.SaveTable(config_path, Resound.Config)
    end, Resound.Config.ImportantLogs)
    tick.ToolTip = TextManager.Get("resound_importantlogs_tooltip").Value

    local tick = easySettings.TickBox(list.Content, TextManager.Get("resound_otherlogs").Value, function (state)
        Resound.Config.OtherLogs = state
        easySettings.SaveTable(config_path, Resound.Config)
    end, Resound.Config.OtherLogs)
    tick.ToolTip = TextManager.Get("resound_otherlogs_tooltip").Value

    local loaded_packages = Resound.LoadedPackages
    if #loaded_packages > 0 then
        easySettings.TextBlock(list, TextManager.Get("resound_modsettings").Value, nil, 0.1, 1.3, Color.LightYellow)
    end

    local j = 1
    for i = #loaded_packages, 1, -1 do
        local package = loaded_packages[i]
        local tick = easySettings.TickBox(list.Content, string.format("%d. %s", j, package.Name), function (state)
            Resound.Config.IgnoredPackages[package.Dir] = not state
            easySettings.SaveTable(config_path, Resound.Config)
            if Resound.Config.Enabled then
                RestartMod()
            end
        end, not Resound.Config.IgnoredPackages[package.Dir])
        tick.ToolTip = string.format(TextManager.Get("resound_enablepackage_tooltip").Value, package.Name)
        j = j + 1
    end
end, nil)

Game.AddCommand("resound", "Opens the menu for ReSound", function(parent)
    open_new_menu()
end)
