-- This code runs once and replaces any sounds that the swap_future_sounds.lua file can't get (because the sounds were created before it was running).

LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Sounds.SoundManager"], "ReloadSounds")
LuaUserData.MakePropertyAccessible(Descriptors["Barotrauma.SoundPrefab"], "Sound")
LuaUserData.RegisterType("Barotrauma.SoundPrefab")

local soundsToRemove = {}
for _, sound in ipairs(Game.SoundManager.LoadedSounds) do
    local filename = sound.Filename
    local filenameShort = filename:match("Barotrauma/.*")

    -- Search dictionary for replacement sound.
    local newFilename = Resound.SoundPairs[filenameShort]

    -- If a match is found, replace the vanilla version in the loadedSounds list.
    if newFilename then
        local newSound = Game.SoundManager.LoadSound(sound.XElement, sound.Stream, newFilename)
        print(string.format("Debug: swap_past_sounds.lua - Replacing sound file %s with %s", filenameShort, newFilename))
        table.insert(soundsToRemove, sound)

        -- So far I have only had to do this process for Prefabs, but it's possible other collections, like affliction sounds or comp sounds might need their own manual replacement too.
        for soundPrefab in SoundPrefab.Prefabs do
            if soundPrefab.Sound and soundPrefab.Sound.Filename == filename then
                soundPrefab.Sound = newSound
            end
        end
    end
end

-- Prevent memeory leak from sounds building up in the loadedSounds list.
for sound in soundsToRemove do
    Game.SoundManager.RemoveSound(sound)
end

Game.SoundManager.ReloadSounds() -- TODO Unsure if necessary.