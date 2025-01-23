-- If we wanted to avoid loading the original sound, we could replace the static Load method from this class, but we would need to replace the whole thing since modifying the ptable on that method isn't sufficient. This process would be best done in C#.

-- This code replaces any new sound that is loaded while playing the game.
Hook.Patch(
    "Barotrauma.Sounds.Sound",
    ".ctor",
    function(instance, ptable)
        local filename = ptable["filename"]
        local filenameShort = filename:match("Barotrauma/.*")

        local newSoundName = Resound.SoundPairs[filenameShort]

        if newSoundName then
            ptable["filename"] = newSoundName
            print(string.format("Debug: swap_future_sounds.lua - Replaced sound %s", newSoundName))
        end
    end,
Hook.HookMethodType.Before)