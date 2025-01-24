LuaUserData.RegisterType("Barotrauma.IO.Path")
local Path = LuaUserData.CreateStatic("Barotrauma.IO.Path", true)

LuaUserData.RegisterType("Barotrauma.SaveUtil")
local SaveUtil = LuaUserData.CreateStatic("Barotrauma.SaveUtil", true)

LuaUserData.RegisterType('Barotrauma.LuaCsLogger')
local LuaCsLogger = LuaUserData.CreateStatic('Barotrauma.LuaCsLogger')

LuaUserData.RegisterType('Microsoft.Xna.Framework.Color')
local Color = LuaUserData.CreateStatic('Microsoft.Xna.Framework.Color')

local number_of_mods_read = 0
for package in ContentPackageManager.EnabledPackages.All do
    local sound_overrides_file = Path.Combine(package.Dir, "resound_overrides.json")
    local sound_overrides = {}
    
    if File.Exists(sound_overrides_file) then
        local success, result = pcall(json.parse, File.Read(sound_overrides_file))
        if success then
            sound_overrides = result
            LuaCsLogger.LogMessage(string.format("ReSound | " .. TextManager.Get("resound_reading_from_mod").Value, package.Name), Color.Green)
        else
            LuaCsLogger.LogError(string.format("ReSound | " .. TextManager.Get("resound_reading_from_mod_failed").Value, package.Name, vanilla_sound_path))
        end
        number_of_mods_read = number_of_mods_read + 1
    end

    for key, value in pairs(sound_overrides) do

        local custom_sound_path = Path.Combine(package.Dir, value)
        local vanilla_sound_path = Path.Combine(Path.GetFullPath(key))

        -- Different path for replacing workshop sounds.
        if string.find(key, "^WorkshopMods/Installed/") then
            vanilla_sound_path = Path.Combine(SaveUtil.DefaultSaveFolder, key)
        end

        -- Normalise slashes
        custom_sound_path = string.gsub(custom_sound_path, "\\", "/")
        vanilla_sound_path = string.gsub(vanilla_sound_path, "\\", "/")

        -- Check if another mod has already replaced this vanilla sound.
        local is_already_replaced = Resound.SoundPairs[vanilla_sound_path]
        
        -- Helpful feedback on whether the sound files exist or not.
        local found_vanilla_sound = File.Exists(vanilla_sound_path)
        local found_custom_sound = File.Exists(custom_sound_path)
        
        if not found_custom_sound then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, package.Name, custom_sound_path))
        end
        if not found_vanilla_sound then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_vanilla_sound_failed").Value, package.Name, vanilla_sound_path))
        end 
        if not found_custom_sound or not found_vanilla_sound then
            goto continue
        end
        
        -- Both paths are guaranteed to be valid at this point.

        if is_already_replaced then -- Warn user a mod is replacing another mods sounds.
            LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_override_warning").Value, package.Name, Path.GetFileName(is_already_replaced), Path.GetFileName(custom_sound_path), Color.Yellow))
        else -- Temporary logging.
            --LuaCsLogger.LogMessage(string.format("DEBUG: " .. TextManager.Get("resound_registered_sound").Value, Path.GetFileName(vanilla_sound_path), Path.GetFileName(custom_sound_path), Color.Green))
        end

        Resound.SoundPairs[vanilla_sound_path] = custom_sound_path

        ::continue::
    end
end

-- Additional user feedback.
local count = 0
for _ in Resound.SoundPairs do
    count = count + 1
end
if count > 0 then
    LuaCsLogger.LogMessage(string.format("ReSound | " .. TextManager.Get("resound_reading_finished").Value, count, Color.Green))
elseif count <= 0 and number_of_mods_read > 0 then
    LuaCsLogger.LogError("ReSound | " .. TextManager.Get("resound_reading_finished_failed").Value)
end