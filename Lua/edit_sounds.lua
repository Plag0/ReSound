-- This allows for additional sounds to be played or removed and for all sounds to have their volume and range values tweaked.

local DEFAULT_BASE_GAIN = 1
local DEFAULT_BASE_NEAR = 100
local DEFAULT_BASE_FAR = 200

Hook.Patch(
    "Barotrauma.Sounds.SoundChannel",
    ".ctor",
    function(instance, ptable)
        local sound = ptable["sound"]
        local filename = sound.Filename
        filename = string.gsub(filename, "\\", "/")

        local sound_group_id = Resound.SoundPathToGroupID[filename]
        local sound_group = Resound.SoundGroups[sound_group_id]
        

        if sound_group then
            for sound in sound_group.sounds do
                print("Sound in group: " .. sound.Filename)
            end
            print("There are " .. #sound_group.sounds .. " sounds in the group.")
            if #sound_group.sounds > 0 then
                sound = sound_group.sounds[math.random(#sound_group.sounds)]
                ptable["sound"] = sound
                
            else -- All sounds have been removed from the group so we just set the volume to zero.
                ptable["gain"] = Single(0)
                return
            end
            
            -- If the default base values are modified, that means the sound has custom values.
            if sound.BaseGain ~= DEFAULT_BASE_GAIN then
                ptable["gain"] = Single(sound.BaseGain)
            end
            if sound.BaseNear ~= DEFAULT_BASE_NEAR then
                ptable["near"] = Single(sound.BaseNear)
            end
            if sound.BaseFar ~= DEFAULT_BASE_FAR then
                ptable["far"] = Single(sound.BaseFar)
            end
        end
    end,
Hook.HookMethodType.Before)