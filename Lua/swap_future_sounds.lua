-- This code replaces any new sound that is loaded after Lua.
Hook.Patch(
    "Barotrauma.Sounds.Sound",
    ".ctor",
    function(instance, ptable)
        local filename = ptable["filename"]
        local filename = string.gsub(filename, "\\", "/")
        local newFilename = Resound.SoundPairs[filename]
        if newFilename then
            ptable["filename"] = newFilename
        end
    end,
Hook.HookMethodType.Before)