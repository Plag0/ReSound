-- Stops all sounds when exiting to the main menu.
-- This isn't really relevant to this project tbh.

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "playingChannels")
Hook.Add("stop", "resound_stop", function()
    for side in Game.SoundManager.playingChannels do
        for channel in side do
            channel.FadeOutAndDispose()
        end
    end
end)