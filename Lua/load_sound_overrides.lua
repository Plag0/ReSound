LuaUserData.RegisterType("Barotrauma.IO.Path")
local Path = LuaUserData.CreateStatic("Barotrauma.IO.Path", true)

LuaUserData.RegisterType("Barotrauma.SaveUtil")
local SaveUtil = LuaUserData.CreateStatic("Barotrauma.SaveUtil", true)

LuaUserData.RegisterType('Barotrauma.LuaCsLogger')
local LuaCsLogger = LuaUserData.CreateStatic('Barotrauma.LuaCsLogger')

LuaUserData.RegisterType('Microsoft.Xna.Framework.Color')
local Color = LuaUserData.CreateStatic('Microsoft.Xna.Framework.Color')

-- Get any extra fields from a custom sound path, like volume and range.
local function extract_extra_fields(input)
    -- Extract values after each comma (ignoring spaces)
    local custom_fields = {}
    for field in input:gmatch(",%s*([^,]+)") do
        table.insert(custom_fields, field)
    end

    -- Store the extracted values in variables (if they exist)
    local gain = custom_fields[1]
    local near = custom_fields[2]
    local far = custom_fields[3]

    -- Remove everything after the first comma (including the comma itself)
    local cleaned_string = input:gsub(",.*", "")

    return cleaned_string, gain, near, far
end

-- Functionality for adding additional sounds instead of just replacing the ones that exist.
local function add_additional_sound(sound_group, custom_sound_path, gain, near, far)
    -- Remove the "+".
    sound_group = string.gsub(sound_group, "/%+Content/", "/Content/")
    sound_group = string.gsub(sound_group, "/%+WorkshopMods/", "/WorkshopMods/")

    -- Adding another additional sound to the same sound group.
    if Resound.SoundGroups[sound_group] then
        -- TODO Should I check if the sound has been loaded correctly?
        table.insert(Resound.SoundGroups[sound_group].sounds, Game.SoundManager.LoadSound(custom_sound_path))
        table.insert(Resound.SoundGroups[sound_group].sound_fields, {gain=gain, near=near, far=far})

        local total_num_of_sounds = Resound.SoundGroups[sound_group].total_num_of_sounds
        Resound.SoundGroups[sound_group].total_num_of_sounds = total_num_of_sounds + 1
        Resound.SoundGroups[sound_group].chance_of_playing = 100 / total_num_of_sounds + 1

        return
    end

    local num_sounds_in_group = 0
    local postfix = ".ogg"
    local i = 0
    while true do
        if File.Exists(sound_group .. postfix) then
            num_sounds_in_group = num_sounds_in_group + 1
        end
        i = i + 1
        postfix = tostring(i) .. ".ogg"

        -- Exit the loop when we run out of numbered sound variants or if there's none.
        if (i - 2 >= num_sounds_in_group) then
            break
        end
    end

    if num_sounds_in_group <= 0 then
        print(string.format("Error: Could not find a group of sounds under name %s", sound_group))
    else
        local info = {}
        info.total_num_of_sounds = num_sounds_in_group + 1
        info.chance_of_playing = 100 / info.total_num_of_sounds
        info.sounds = {Game.SoundManager.LoadSound(custom_sound_path)}
        info.sound_fields = {{gain=gain, near=near, far=far}}
        Resound.SoundGroups[sound_group] = info
    end
end

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
        local value, gain, near, far = extract_extra_fields(value)
        local vanilla_sound_path = Path.Combine(Path.GetFullPath(key))
        local custom_sound_path = Path.Combine(package.Dir, value)
        local is_already_replaced = nil

        -- Different path for replacing workshop sounds.
        if string.find(key, "^WorkshopMods/Installed/") then
            vanilla_sound_path = Path.Combine(SaveUtil.DefaultSaveFolder, key)
        end

        -- Normalise slashes
        vanilla_sound_path = string.gsub(vanilla_sound_path, "\\", "/")
        custom_sound_path = string.gsub(custom_sound_path, "\\", "/")

        -- Check if another mod has already replaced this vanilla sound.
        is_already_replaced = Resound.SoundPairs[vanilla_sound_path]
        
        -- Check if the custom sound exists and skip the sound if not.
        if not File.Exists(custom_sound_path) then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, package.Name, custom_sound_path))
            goto continue
        end

        -- Check for additional sounds after we know the custom sound exists and before we check the vanilla path (it won't be a valid file in this context because you don't include "x.ogg" when adding a sound)
        if string.sub(key, 1, 1) == "+" then
            add_additional_sound(vanilla_sound_path, custom_sound_path, gain, near, far)
            goto continue
        end

        -- Check if the vanilla sound exists and skip the sound if not.
        if not File.Exists(vanilla_sound_path) then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_vanilla_sound_failed").Value, package.Name, vanilla_sound_path))
            goto continue
        end
        
        -- Both paths are guaranteed to be valid at this point.

        if is_already_replaced then -- Warn user a mod is replacing another mods sounds.
            LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_override_warning").Value, package.Name, Path.GetFileName(is_already_replaced), Path.GetFileName(custom_sound_path), Color.Yellow))
        else -- Temporary logging.
            --LuaCsLogger.LogMessage(string.format("DEBUG: " .. TextManager.Get("resound_registered_sound").Value, Path.GetFileName(vanilla_sound_path), Path.GetFileName(custom_sound_path), Color.Green))
        end

        Resound.SoundPairs[vanilla_sound_path] = custom_sound_path
        Resound.SoundFields[vanilla_sound_path] = {gain=gain, near=near, far=far}

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