LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "ReloadSounds")
LuaUserData.RegisterType("Barotrauma.SoundPrefab")
LuaUserData.RegisterType("Barotrauma.StatusEffect")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.StatusEffect"], "ActiveLoopingSounds") 
LuaUserData.MakePropertyAccessible(Descriptors["Barotrauma.SoundPrefab"], "Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.SoundPrefab"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.DamageSound"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.BackgroundMusic"], "set_Sound")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.GUISound"], "set_Sound")

local sounds_to_remove = {}

-- Creates a copy of the old Sound with a path to the new replacement file.
local function get_new_sound(old_sound, new_filename)
    local new_sound = nil

    if old_sound.XElement then
        new_sound = Game.SoundManager.LoadSound(old_sound.XElement, old_sound.Stream, new_filename)
    else
        new_sound = Game.SoundManager.LoadSound(new_filename, old_sound.Stream)
    end

    return new_sound
end

-- Indentation hell. Goes through all component sounds and swaps them out for their replacement.
local function update_component_sounds(sound_pairs)
    for item in Item.ItemList do
        for itemComponent in item.Components do
            LuaUserData.MakeFieldAccessible(Descriptors[tostring(itemComponent)], "sounds")
            for action_type, sounds in pairs(itemComponent.sounds) do
                for itemSound in sounds do
                    local old_sound = itemSound.RoundSound.Sound
                    local filename = old_sound.Filename
                    filename = string.gsub(filename, "\\", "/")
                    local new_filename = sound_pairs[filename]

                    if new_filename then
                        local new_sound = get_new_sound(old_sound, new_filename)
                        table.insert(sounds_to_remove, old_sound)
                        itemSound.RoundSound.Sound = new_sound
                        
                        -- For some wacky reason, every 2nd or 3rd time, itemComponent can become nil mid-loop if this function (update_component_sounds) is called inside the stop hook???
                        -- By the way, the game crashes if we don't at least try to call PlaySound here.
                        pcall(itemComponent.PlaySound, action_type)
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
            local new_filename = sound_pairs[filename]

            if new_filename then
                local new_sound = get_new_sound(old_sound, new_filename)
                table.insert(sounds_to_remove, old_sound)
                round_sound.Sound = new_sound
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

        local new_filename = sound_pairs[filename]

        if new_filename then
            local new_sound = get_new_sound(old_sound, new_filename)
            table.insert(sounds_to_remove, old_sound)
            sound_prefab.set_Sound(new_sound)
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

function UnloadAdditionalSounds()
    for sound_group in Resound.SoundGroups do
        for sound in sound_group.sounds do
            table.insert(sounds_to_remove, sound)
        end
    end

    remove_sounds(sounds_to_remove)
end

function UpdateAllSounds(sound_pairs)
    Resound.IsUpdatingSounds = true

    update_sound_prefabs(sound_pairs)
    update_component_sounds(sound_pairs)
    update_affliction_sounds(sound_pairs)

    remove_sounds(sounds_to_remove)

    --Game.SoundManager.ReloadSounds() -- TODO Unsure if necessary. Seems fine without it.
    Resound.IsUpdatingSounds = false
end