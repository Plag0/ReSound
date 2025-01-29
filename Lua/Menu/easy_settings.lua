-- This menu code was adapted from EvilFactory's LuaAudioOverhaul mod.
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2868921484

local easySettings = {}
easySettings.Settings = {}

local GUIComponent = LuaUserData.CreateStatic("Barotrauma.GUIComponent")

easySettings.SaveTable = function (path, tbl)
    File.Write(path, json.serialize(tbl))
end
easySettings.LoadTable = function (path)
    if not File.Exists(path) then
        return {}
    end

    return json.parse(File.Read(path))
end

easySettings.AddMenu = function (name, onOpen)
    table.insert(easySettings.Settings, {Name = name, OnOpen = onOpen})
end

easySettings.BasicList = function (parent, size)
    local menuContent = GUI.Frame(GUI.RectTransform(size or Vector2(0.25, 0.38), parent.RectTransform, GUI.Anchor.Center))
    local menuList = GUI.ListBox(GUI.RectTransform(Vector2(0.9, 0.91), menuContent.RectTransform, GUI.Anchor.Center))
    GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.05), menuContent.RectTransform), TextManager.Get("resound_settings"), nil, nil, GUI.Alignment.Center, true)
    easySettings.CloseButton(menuContent)

    return menuList
end

easySettings.TickBox = function (parent, text, onSelected, state)
    if state == nil then state = true end

    local tickBox = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), parent.RectTransform), text)
    tickBox.Selected = state
    tickBox.OnSelected = function ()
        onSelected(tickBox.State == GUIComponent.ComponentState.Selected)
    end
    tickBox.RectTransform.RelativeOffset = Vector2(0.02, 0)

    return tickBox
end

easySettings.TextBlock = function (list, text, x, y, size, color)
    x = x or 1
    y = y or 0.05
    size = size or 1

    local textBlock = GUI.TextBlock(GUI.RectTransform(Vector2(x, y), list.Content.RectTransform), text, color, nil, GUI.Alignment.Center, true)
    textBlock.Enabled = false
    textBlock.OverrideTextColor(textBlock.TextColor)
    textBlock.TextScale = size
    if color then
        textBlock.OverrideTextColor(color)
    end
    return textBlock
end

easySettings.CloseButton = function (parent)
    local button = GUI.Button(GUI.RectTransform(Vector2(0.2, 0.02), parent.RectTransform, GUI.Anchor.BottomCenter), TextManager.Get("close").Value, GUI.Alignment.Center, "GUIButtonSmall")

    button.OnClicked = function ()
        GUI.GUI.TogglePauseMenu()
    end

    return button
end

return easySettings