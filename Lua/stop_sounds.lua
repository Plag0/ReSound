LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "playingChannels")

Hook.Add("stop", "resound_stop", function()

    UnloadAdditionalSounds()

    UpdateAllSounds(Resound.HashToOriginalMap)

    -- Stop any playing channels.
    for side in Game.SoundManager.playingChannels do
        for channel in side do
            channel.FadeOutAndDispose()
        end
    end
end)