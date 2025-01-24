-- This code runs once at the start of a round and replaces any loaded sounds that the swap_future_sounds.lua file can't get (because the sounds were created before it was running).

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
local function update_component_sounds()
    for item in Item.ItemList do
        for itemComponent in item.Components do
            LuaUserData.MakeFieldAccessible(Descriptors[tostring(itemComponent)], "sounds")
            for action_type, sounds in pairs(itemComponent.sounds) do
                for itemSound in sounds do
                    local old_sound = itemSound.RoundSound.Sound
                    local filename = old_sound.Filename
                    filename = string.gsub(filename, "\\", "/")
                    local new_filename = Resound.SoundPairs[filename]

                    if new_filename then
                        local new_sound = get_new_sound(old_sound, new_filename)
                        table.insert(sounds_to_remove, old_sound)
                        itemSound.RoundSound.Sound = new_sound
                        itemComponent.PlaySound(action_type)
                    end
                end
            end
        end
    end
end

-- Goes through all the loaded status effect sounds and swaps them out for their replacement.
local function update_affliction_sounds()
    for status_effect in StatusEffect.ActiveLoopingSounds do
        for round_sound in status_effect.Sounds do

            local old_sound = round_sound.Sound
            local filename = old_sound.Filename
            filename = string.gsub(filename, "\\", "/")
            local new_filename = Resound.SoundPairs[filename]

            if new_filename then
                local new_sound = get_new_sound(old_sound, new_filename)
                table.insert(sounds_to_remove, old_sound)
                round_sound.Sound = new_sound
            end
        end
    end
end

-- Goes through all the sound prefabs and swaps them out for their replacement.
local function update_sound_prefabs()
    for sound_prefab in SoundPrefab.Prefabs do
        local old_sound = sound_prefab.Sound
        local filename = old_sound.Filename
        filename = string.gsub(filename, "\\", "/")
        local new_filename = Resound.SoundPairs[filename]

        if new_filename then
            local new_sound = get_new_sound(old_sound, new_filename)
            table.insert(sounds_to_remove, old_sound)
            sound_prefab.set_Sound(new_sound)
        end
    end
end

-- These functions go through all the places (that I know of) where Sound objects need to be replaced and swaps in the new sounds.
update_sound_prefabs()
update_component_sounds()
update_affliction_sounds()

-- Removes the now irrelevant replaced sound from the LoadedSounds list.
for sound in sounds_to_remove do
    Game.SoundManager.RemoveSound(sound)
end

--Game.SoundManager.ReloadSounds() -- TODO Unsure if necessary. Seems fine without it.