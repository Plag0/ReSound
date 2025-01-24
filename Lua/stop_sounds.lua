LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "playingChannels")
Hook.Add("stop", "resound_stop", function()

    -- Unload additional sounds.
    for sound_group in Resound.SoundGroups do
        for sound in sound_group.sounds do
            Game.SoundManager.RemoveSound(sound)
        end
    end

    -- Stop any playing channels.
    for side in Game.SoundManager.playingChannels do
        for channel in side do
            channel.FadeOutAndDispose()
        end
    end
end)