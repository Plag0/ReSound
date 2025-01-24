-- This code replaces any new sound that is loaded while playing the game.
Hook.Patch(
    "Barotrauma.Sounds.Sound",
    ".ctor",
    function(instance, ptable)
        local filename = ptable["filename"]
        local filename = string.gsub(filename, "\\", "/")
        local newFilename = Resound.SoundPairs[filename]
        if newFilename then
            ptable["filename"] = newFilename
            --print(string.format("Debug: swap_future_sounds.lua - Replaced sound %s", newFilename))
        end
    end,
Hook.HookMethodType.Before)