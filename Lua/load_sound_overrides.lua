LuaUserData.RegisterType("Barotrauma.IO.Path")
local Path = LuaUserData.CreateStatic("Barotrauma.IO.Path", true)

LuaUserData.RegisterType("Barotrauma.SaveUtil")
local SaveUtil = LuaUserData.CreateStatic("Barotrauma.SaveUtil", true)

LuaUserData.RegisterType('Barotrauma.LuaCsLogger')
local LuaCsLogger = LuaUserData.CreateStatic('Barotrauma.LuaCsLogger')

LuaUserData.RegisterType('Microsoft.Xna.Framework.Color')
local Color = LuaUserData.CreateStatic('Microsoft.Xna.Framework.Color')

local function safe_single(value)
    -- Try to convert to a number, return nil if it fails
    local number = tonumber(value)
    if number then
        return Single(number)
    else
        return nil
    end
end

-- Get any extra fields from a custom sound path, like volume and range.
local function extract_extra_fields(input)
    -- Extract values after each comma (ignoring spaces)
    local custom_fields = {}
    for field in input:gmatch(",%s*([^,]+)") do
        table.insert(custom_fields, field)
    end

    local gain = safe_single(custom_fields[1])
    local near = safe_single(custom_fields[2])
    local far = safe_single(custom_fields[3])

    -- Remove everything after the first comma (including the comma itself)
    local cleaned_string = input:gsub(",.*", "")

    return cleaned_string, gain, near, far
end

-- Functionality for adding additional sounds into a group of existing sound(s) instead of just replacing the ones that exist.
local function add_additional_sound(sound_group, custom_sound_path, gain, near, far, mod_name)

    -- Adding another additional sound to the same sound group.
    if Resound.SoundGroups[sound_group] then
        -- TODO Should I check if the sound has been loaded correctly?
        table.insert(Resound.SoundGroups[sound_group].sounds, Game.SoundManager.LoadSound(custom_sound_path))
        table.insert(Resound.SoundGroups[sound_group].sound_fields, {gain=gain, near=near, far=far})
        local total_num_of_sounds = Resound.SoundGroups[sound_group].total_num_of_sounds + 1
        local chance_of_playing = 100 / total_num_of_sounds
        Resound.SoundGroups[sound_group].total_num_of_sounds = total_num_of_sounds
        Resound.SoundGroups[sound_group].chance_of_playing = chance_of_playing
        LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_group").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group), total_num_of_sounds, chance_of_playing), Color.Green)
        return
    end

    local num_sounds_in_group = 0
    local postfix = ".ogg"
    for i = 1, 100 do -- Max of 100 iterations for safety.
        if File.Exists(sound_group .. postfix) then
            num_sounds_in_group = num_sounds_in_group + 1
        end
        postfix = tostring(i) .. ".ogg"
        -- Exit the loop when we run out of numbered sound variants or if there's none.
        if (i - 2 >= num_sounds_in_group) then
            break
        end
    end

    if num_sounds_in_group <= 0 then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_group_failed").Value, mod_name, Path.GetFileName(custom_sound_path), sound_group))
    else
        local info = {}
        info.total_num_of_sounds = num_sounds_in_group + 1
        info.chance_of_playing = 100 / info.total_num_of_sounds
        info.sounds = {Game.SoundManager.LoadSound(custom_sound_path)}
        info.sound_fields = {{gain=gain, near=near, far=far}}
        Resound.SoundGroups[sound_group] = info
        LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_group").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group), info.total_num_of_sounds, info.chance_of_playing), Color.Green)
    end
end

local number_of_mods_read = 0

local packages = {}
for package in ContentPackageManager.EnabledPackages.All do
    table.insert(packages, package)
end

for i = #packages, 1, -1 do
    local package = packages[i]
    local sound_overrides_file = Path.Combine(package.Dir, "resound_overrides.json")
    local sound_overrides = {}
    
    -- Check if mod has the "resound_overrides.json" file and try to load it into the sound_overrides variable.
    if File.Exists(sound_overrides_file) then
        local success, result = pcall(json.parse, File.Read(sound_overrides_file))
        number_of_mods_read = number_of_mods_read + 1
        if success then
            sound_overrides = result
            LuaCsLogger.LogMessage(string.format("ReSound | " .. TextManager.Get("resound_reading_from_mod").Value, package.Name), Color.Green)
        else
            LuaCsLogger.LogError(string.format("ReSound | " .. TextManager.Get("resound_reading_from_mod_failed").Value, package.Name))
        end
    end

    -- Go through and verify each sound, 
    for key, value in pairs(sound_overrides) do
        local value, gain, near, far = extract_extra_fields(value)
        local is_additional_sound = string.sub(key, 1, 1) == "+"

        -- Remove the "+" from additional sounds.
        if is_additional_sound then
            key = string.gsub(key, "^%+Content", "Content")
            key = string.gsub(key, "^%+WorkshopMods", "WorkshopMods")
        end

        -- Assemble the complete directory for the custom sound.
        local custom_sound_path = Path.Combine(package.Dir, value)
        if (string.find(custom_sound_path, "^LocalMods")) then
            custom_sound_path = Path.GetFullPath(custom_sound_path)
        elseif (string.find(custom_sound_path, "^WorkshopMods")) then
            custom_sound_path = Path.Combine(SaveUtil.DefaultSaveFolder, custom_sound_path)
        end

        -- Assemble the complete directory for the vanilla sound.
        local vanilla_sound_path = key
        if string.find(key, "^Content") then
            vanilla_sound_path = Path.GetFullPath(key)
        elseif string.find(key, "^WorkshopMods") then
            vanilla_sound_path = Path.Combine(SaveUtil.DefaultSaveFolder, key)
        end

        -- Normalise slashes
        vanilla_sound_path = string.gsub(vanilla_sound_path, "\\", "/")
        custom_sound_path = string.gsub(custom_sound_path, "\\", "/")

        -- Check if another ReSound mod has already replaced this vanilla sound.
        local is_already_replaced = Resound.SoundPairs[vanilla_sound_path]
        
        -- Check if the custom sound file exists and skip the sound if not.
        if not File.Exists(custom_sound_path) then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, package.Name, custom_sound_path))
            goto continue
        end

        -- Add additional sounds after we know the custom sound file exists and before we check the vanilla path, which won't be a valid file in this context because "(number).ogg" is not included when adding a sound group.
        if is_additional_sound then
            add_additional_sound(vanilla_sound_path, custom_sound_path, gain, near, far, package.Name)
            goto continue
        end

        -- Check if the vanilla sound file exists and skip the sound if not.
        if not File.Exists(vanilla_sound_path) then
            LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_vanilla_sound_failed").Value, package.Name, vanilla_sound_path))
            goto continue
        end
        
        -- Warn user if a mod is replacing another mods sounds.
        if is_already_replaced then
            LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_override_warning").Value, package.Name, Path.GetFileName(is_already_replaced), Path.GetFileName(custom_sound_path)), Color.Yellow)
        else
            LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_sound").Value, Path.GetFileName(vanilla_sound_path), Path.GetFileName(custom_sound_path)), Color.Green)
        end

        Resound.SoundPairs[vanilla_sound_path] = custom_sound_path
        Resound.SoundPairsInverted[custom_sound_path] = vanilla_sound_path
        Resound.SoundFields[custom_sound_path] = {gain=gain, near=near, far=far}

        ::continue::
    end
end

-- Tell user how many sounds were loaded, if zero sounds were loaded despite reading a file, display a failed message.
local override_count = 0
for _ in Resound.SoundPairs do
    override_count = override_count + 1
end

local added_count = 0
for sound_group in Resound.SoundGroups do
    for _ in sound_group.sounds do
        added_count = added_count + 1
    end
end

if (override_count > 0) or (added_count > 0) then
    LuaCsLogger.LogMessage(string.format("ReSound | " .. TextManager.Get("resound_reading_finished").Value, number_of_mods_read, override_count, added_count), Color.Green)
elseif number_of_mods_read > 0 and override_count <= 0 and added_count <= 0 then
    LuaCsLogger.LogError(string.format("ReSound | " .. TextManager.Get("resound_reading_finished_failed").Value, number_of_mods_read))
end