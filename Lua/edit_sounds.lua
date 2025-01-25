-- This allows for additional sounds to be played and for all sounds to have their volume and range values tweaked.

Hook.Patch(
    "Barotrauma.Sounds.SoundChannel",
    ".ctor",
    function(instance, ptable)
        local sound = ptable["sound"]
        local gain = ptable["gain"]
        local near = ptable["near"]
        local far = ptable["far"]
        local filename = sound.Filename
        filename = string.gsub(filename, "\\", "/")

        -- Remove any number and .ogg from the end of the filename to check for additional sounds for that group.
        local sound_group = string.gsub(filename, "(%d*)%.ogg$", "")

        local additional_sounds = Resound.SoundGroups[sound_group]
        local sound_fields = Resound.SoundFields[filename]

        if additional_sounds and math.random(100) <= additional_sounds.chance_of_playing then
            local random_index = math.random(#additional_sounds.sounds)
            ptable["sound"] = additional_sounds.sounds[random_index]
            ptable["gain"] = additional_sounds.sound_fields[random_index].gain or Single(gain)
            ptable["near"] = additional_sounds.sound_fields[random_index].near or Single(near)
            ptable["far"] = additional_sounds.sound_fields[random_index].far or Single(far)
        end

        if sound_fields then
            ptable["gain"] = sound_fields.gain or Single(gain)
            ptable["near"] = sound_fields.near or Single(near)
            ptable["far"] = sound_fields.far or Single(far)
        end
    end,
Hook.HookMethodType.Before)