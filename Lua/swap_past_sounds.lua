LuaUserData.RegisterType("Barotrauma.StatusEffect")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.StatusEffect"], "ActiveLoopingSounds") 
LuaUserData.RegisterType("Barotrauma.SoundPrefab")
LuaUserData.MakePropertyAccessible(Descriptors["Barotrauma.SoundPrefab"], "Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.SoundPrefab"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.DamageSound"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.BackgroundMusic"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.GUISound"], "set_Sound")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "playingChannels")


--[[
This code is responsible for loading new sound objects and replacing the previous ones.
It is used to transition between original and custom sound sets without restarting the game.

Note to self: 
We run this once at the start of the round since many sounds are loaded before the swap_future_sounds.lua script can run, so we have to go back and reload them.
With some modifications, we could probably just reload the same sounds, do nothing, and the "swap_future_sounds.lua" script would take care of the rest. Currently that script is disabled when this one is running (using the Resound.IsUpdatingSounds var), but they were born to work together. Maybe one day...
]]


-- Replaced sounds to be removed from the LoadedSounds list and disposed.
local sounds_to_remove = {}

-- Creates a copy of the old Sound with the only difference being a new filename.
local function get_new_sound(old_sound, new_filename)
    local new_sound = nil
    local fields = Resound.CustomSoundParams[old_sound.Filename]
    local gain, near, far
    if fields then
        gain, near, far = fields.gain, fields.near, fields.far
    end

    if old_sound.XElement then
        new_sound = Game.SoundManager.LoadSound(old_sound.XElement, old_sound.Stream, new_filename)
    else
        new_sound = Game.SoundManager.LoadSound(new_filename, old_sound.Stream)
    end

    new_sound.BaseGain = gain or new_sound.BaseGain
    new_sound.BaseNear = near or new_sound.BaseNear
    new_sound.BaseFar = far or new_sound.BaseFar

    return new_sound
end

local function update_sound_pool(filename, sound)
    -- Add sound to group it belongs to.
    local sound_group_id = Resound.SoundPathToGroupID[filename]
    local sound_group = Resound.SoundGroups[sound_group_id]
    if sound_group and sound_group.sounds_to_load[filename] then
        table.insert(sound_group.sounds, sound)
        sound_group.sounds_to_load[filename] = false
    end
end

-- Indentation hell. Goes through all component sounds and swaps them out for their replacement.
local function update_component_sounds(sound_pairs)
    for item in Item.ItemList do
        for itemComponent in item.Components do
            LuaUserData.MakeFieldAccessible(Descriptors[tostring(itemComponent)], "sounds")
            for action_type, sounds in pairs(itemComponent.sounds) do
                -- Stop sounds or the game crashes.
                itemComponent.StopSounds(action_type)
                for itemSound in sounds do
                    local old_sound = itemSound.RoundSound.Sound
                    local filename = old_sound.Filename
                    filename = string.gsub(filename, "\\", "/")
                    local new_filename = sound_pairs[filename] or sound_pairs[old_sound.GetHashCode()]

                    if not new_filename then
                        update_sound_pool(filename, old_sound)
                    else
                        local new_sound = get_new_sound(old_sound, new_filename)
                        itemSound.RoundSound.Sound = new_sound
                        Resound.HashToOriginalMap[new_sound.GetHashCode()] = filename
                        table.insert(sounds_to_remove, old_sound)
                        update_sound_pool(filename, new_sound)
                    end
                end
            end
        end
    end
end

-- Goes through all the loaded status effect sounds and swaps them out for their replacement.
local function update_affliction_sounds(sound_pairs)
    for status_effect in StatusEffect.ActiveLoopingSounds do
        for round_sound in status_effect.Sounds do

            local old_sound = round_sound.Sound
            local filename = old_sound.Filename
            filename = string.gsub(filename, "\\", "/")
            local new_filename = sound_pairs[filename] or sound_pairs[old_sound.GetHashCode()]

            if not new_filename then
                update_sound_pool(filename, old_sound)
            else
                local new_sound = get_new_sound(old_sound, new_filename)
                round_sound.Sound = new_sound
                Resound.HashToOriginalMap[new_sound.GetHashCode()] = filename
                table.insert(sounds_to_remove, old_sound)
                update_sound_pool(filename, new_sound)
            end
        end
    end
end

-- Goes through all the sound prefabs and swaps them out for their replacement.
local function update_sound_prefabs(sound_pairs)
    for sound_prefab in SoundPrefab.Prefabs do
        local old_sound = sound_prefab.Sound
        local filename = old_sound.Filename
        filename = string.gsub(filename, "\\", "/")
        local new_filename = sound_pairs[filename] or sound_pairs[old_sound.GetHashCode()]

        if not new_filename then
            update_sound_pool(filename, old_sound)
        else
            local new_sound = get_new_sound(old_sound, new_filename)
            sound_prefab.set_Sound(new_sound)
            Resound.HashToOriginalMap[new_sound.GetHashCode()] = filename
            table.insert(sounds_to_remove, old_sound)
            update_sound_pool(filename, new_sound)
        end
    end
end

-- Removes sounds from the internal LoadedSounds list for behavioral consistency.
local function remove_sounds(sounds_to_remove)
    for sound in sounds_to_remove do
        Game.SoundManager.RemoveSound(sound)
        sound.Dispose()
    end
end

local function unload_additional_sounds()
    for group_id, group in pairs(Resound.SoundGroups) do
        for sound in group.sounds do
            table.insert(sounds_to_remove, sound)
        end
        Resound.SoundGroups[group_id] = nil
    end

    remove_sounds(sounds_to_remove)
end

local function update_all_sounds(sound_pairs)
    Resound.IsUpdatingSounds = true

    update_sound_prefabs(sound_pairs)
    update_component_sounds(sound_pairs)
    update_affliction_sounds(sound_pairs)

    remove_sounds(sounds_to_remove)

    Resound.IsUpdatingSounds = false
end

function Resound.StopMod()
    unload_additional_sounds()

    update_all_sounds(Resound.HashToOriginalMap)

    -- Stop any playing channels.
    for side in Game.SoundManager.playingChannels do
        for channel in side do
            channel.FadeOutAndDispose()
        end
    end
end

function Resound.RestartMod()
    Resound.StopMod()
    dofile(Resound.PATH .. "/Lua/start_mod.lua")
end

Hook.Add("stop", "resound_stop", function()
    if GUI.GUI.PauseMenuOpen then
        GUI.GUI.TogglePauseMenu()
    end

    if Resound.Config.Enabled then
        Resound.StopMod()
    end
end)

-- Run once on startup.
update_all_sounds(Resound.OriginalToCustomMap)