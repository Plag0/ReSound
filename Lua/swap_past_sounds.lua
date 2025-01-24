-- This code runs once and replaces any sounds that the swap_future_sounds.lua file can't get (because the sounds were created before it was running).

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

local function get_new_sound(old_sound, new_filename)
    local new_sound = nil

    if old_sound.XElement then
        new_sound = Game.SoundManager.LoadSound(old_sound.XElement, old_sound.Stream, new_filename)
    else
        new_sound = Game.SoundManager.LoadSound(new_filename, old_sound.Stream)
    end

    return new_sound
end

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
                print(string.format("replacing status effect sound for %s", old_sound.Filename))
                round_sound.Sound = new_sound
            end
        end
    end
end

local function update_sound_prefabs()
    for sound_prefab in SoundPrefab.Prefabs do
        local old_sound = sound_prefab.Sound
        local filename = old_sound.Filename
        filename = string.gsub(filename, "\\", "/")
        local new_filename = Resound.SoundPairs[filename]

        if new_filename then
            local new_sound = get_new_sound(old_sound, new_filename)
            table.insert(sounds_to_remove, old_sound)
            print(string.format("replacing prefab sound for %s", old_sound.Filename))
            sound_prefab.set_Sound(new_sound)
        end
    end
end

update_sound_prefabs()
update_component_sounds()
update_affliction_sounds()

for sound in sounds_to_remove do
    Game.SoundManager.RemoveSound(sound)
end

--Game.SoundManager.ReloadSounds() -- TODO Unsure if necessary.