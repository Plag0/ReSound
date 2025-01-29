LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "playingChannels")

function StopMod()
    UnloadAdditionalSounds()

    UpdateAllSounds(Resound.HashToOriginalMap)

    -- Stop any playing channels.
    for side in Game.SoundManager.playingChannels do
        for channel in side do
            channel.FadeOutAndDispose()
        end
    end
end

function RestartMod()
    StopMod()
    dofile(Resound.PATH .. "/Lua/start_mod.lua")
end

Hook.Add("stop", "resound_stop", function()
    if GUI.GUI.PauseMenuOpen then
        GUI.GUI.TogglePauseMenu()
    end

    if Resound.Config.Enabled then
        StopMod()
    end
end)