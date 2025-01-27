-- This code replaces any new vanilla sound that is loaded mid-round, after the initial Lua scripts run.
Hook.Patch(
    "Barotrauma.Sounds.OggSound",
    ".ctor",
    function(instance, ptable)
        -- Disable this constructor when updating (re-creating) all the sounds to avoid unintended filename changes when they pass through.
        if Resound.IsUpdatingSounds then return end

        local original_filename = ptable["filename"]
        original_filename = string.gsub(original_filename, "\\", "/")
        local new_filename = Resound.OriginalToCustomMap[original_filename]

        if new_filename then
            ptable["filename"] = new_filename

            local fields = Resound.CustomSoundParams[original_filename]
            local gain, near, far = fields.gain, fields.near, fields.far
            instance.BaseGain = gain or instance.BaseGain
            instance.BaseNear = near or instance.BaseNear
            instance.BaseFar = far or instance.BaseFar
        end
    end,
Hook.HookMethodType.Before)


Hook.Patch(
    "Barotrauma.Sounds.OggSound",
    ".ctor",
    function(instance, ptable)
        -- Disable this constructor when updating (re-creating) all the sounds to avoid unintended filename changes when they pass through.
        if Resound.IsUpdatingSounds then return end
        local new_sound = instance
        local new_filename = string.gsub(new_sound.Filename, "\\", "/")

        local sound_group_id = Resound.SoundPathToGroupID[new_filename]
        local sound_group = Resound.SoundGroups[sound_group_id]
        if sound_group and sound_group.sounds_to_load[new_filename] and new_sound then
            table.insert(sound_group.sounds, new_sound)
            sound_group.sounds_to_load[new_filename] = false
        end
    end,
Hook.HookMethodType.After)