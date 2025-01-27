LuaUserData.RegisterType("Barotrauma.IO.Path")
local Path = LuaUserData.CreateStatic("Barotrauma.IO.Path", true)

LuaUserData.RegisterType("Barotrauma.SaveUtil")
local SaveUtil = LuaUserData.CreateStatic("Barotrauma.SaveUtil", true)

LuaUserData.RegisterType('Barotrauma.LuaCsLogger')
local LuaCsLogger = LuaUserData.CreateStatic('Barotrauma.LuaCsLogger')

LuaUserData.RegisterType('Microsoft.Xna.Framework.Color')
local Color = LuaUserData.CreateStatic('Microsoft.Xna.Framework.Color')

-- TODO might not need this anymore with the way gain etc is applied
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

    local fields = {gain=gain, near=near, far=far}

    -- Remove everything after the first comma (including the comma itself)
    local cleaned_string = input:gsub(",.*", "")

    return cleaned_string, fields
end

local function add_sound(sound_info)
    -- Make sure the group_id is clean, no numbers or file extensions.
    local sound_group_id = sound_info.vanilla_sound_path
    sound_group_id = sound_group_id:gsub("%.ogg$", "")
    sound_group_id = sound_group_id:gsub("%d+$", "")

    local custom_sound_path = sound_info.custom_sound_path
    local gain, near, far = sound_info.fields.gain, sound_info.fields.near, sound_info.fields.far
    local mod_name = sound_info.mod_name

    -- Check if the custom sound file exists and skip the sound if not.
    if not File.Exists(custom_sound_path) then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, mod_name, custom_sound_path))
        return
    end

    -- Debugging: Print sound_group_id and Resound.SoundGroups
    print("sound_group_id:", sound_group_id)
    print("Resound.SoundGroups:", Resound.SoundGroups)

    -- Adding an additional sound to an existing sound group.
    if Resound.SoundGroups[sound_group_id] then
        print("adding successive additional sounds")
        -- TODO Should I check if the sound has been loaded correctly
        local custom_sound = Game.SoundManager.LoadSound(custom_sound_path)
        custom_sound.BaseGain = gain or custom_sound.BaseGain
        custom_sound.BaseNear = near or custom_sound.BaseNear
        custom_sound.BaseFar = far or custom_sound.BaseFar
        table.insert(Resound.SoundGroups[sound_group_id].sounds, custom_sound)
        Resound.SoundPathToGroupID[custom_sound_path] = sound_group_id
     
        --TODO new log message here
        --LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_group").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group)), Color.Green)
        return
    end

    local num_sounds_in_group = 0
    local sounds_to_load = {}
    local postfix = ".ogg"
    for i = 1, 100 do -- Max of 100 iterations for safety.
        local filename = sound_group_id .. postfix
        if File.Exists(filename) then
            Resound.SoundPathToGroupID[filename] = sound_group_id
            sounds_to_load[filename] = true
            num_sounds_in_group = num_sounds_in_group + 1
        end
        postfix = tostring(i) .. ".ogg"
        -- Exit the loop when we run out of numbered sound variants or if there's none.
        if (i - 2 >= num_sounds_in_group) then
            break
        end
    end

    if num_sounds_in_group <= 0 then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_group_failed").Value, mod_name, Path.GetFileName(custom_sound_path), sound_group_id))
    else
        Resound.SoundGroups[sound_group_id] = {
            sounds_to_load = sounds_to_load, -- Keeps track of what sounds have been loaded in a dict formatted filename:true
            sounds = {} -- Sounds are added as they are loaded elsewhere
        }
        print("adding first additional sound")
        local custom_sound = Game.SoundManager.LoadSound(custom_sound_path)
        custom_sound.BaseGain = gain or custom_sound.BaseGain
        custom_sound.BaseNear = near or custom_sound.BaseNear
        custom_sound.BaseFar = far or custom_sound.BaseFar
        table.insert(Resound.SoundGroups[sound_group_id].sounds, custom_sound)
        Resound.SoundPathToGroupID[custom_sound_path] = sound_group_id
        --TODO new log message here
        --LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_group").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group_id)), Color.Green)
    end
end

-- Functionality for subtracting sounds from a group of existing vanilla or modded sound(s).
local function subtract_sound(sound_info)
    local vanilla_sound_path = sound_info.vanilla_sound_path
    local mod_name = sound_info.mod_name

    -- Check if the vanilla sound file exists and skip the sound if not.
    if not File.Exists(vanilla_sound_path) then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_vanilla_sound_failed").Value, mod_name, vanilla_sound_path))
        return
    end

    local sound_group_id = Resound.SoundPathToGroupID[vanilla_sound_path]
    if not sound_group_id then
        sound_group_id = sound_info.vanilla_sound_path
        sound_group_id = sound_group_id:gsub("%.ogg$", "")
        sound_group_id = sound_group_id:gsub("%d+$", "")
    end

    -- Adding another additional sound to the same sound group.
    if Resound.SoundGroups[sound_group_id] then
        Resound.SoundGroups[sound_group_id].sounds_to_load[vanilla_sound_path] = false

        -- Remove any sounds that may have been loaded by the add_sound() function (custom sounds from this mod or others)
        for i = #Resound.SoundGroups[sound_group_id].sounds, 1, -1 do
            if vanilla_sound_path == Resound.SoundGroups[sound_group_id].sounds[i].Filename then
                table.remove(Resound.SoundGroups[sound_group_id].sounds, i)
            end
        end

        -- TODO print subtraction registered log
        return
    end

    local num_sounds_in_group = 0
    local sounds_to_load = {}
    local postfix = ".ogg" -- TODO are other file types even supported?
    for i = 1, 100 do -- Max of 100 iterations for safety.
        local filename = sound_group_id .. postfix
        if File.Exists(filename) then
            Resound.SoundPathToGroupID[filename] = sound_group_id
            if not (filename == vanilla_sound_path) then
                sounds_to_load[filename] = true
                num_sounds_in_group = num_sounds_in_group + 1
            end
        end
        postfix = tostring(i) .. ".ogg"
        -- Exit the loop when we run out of numbered sound variants or if there's none.
        if (i - 2 >= num_sounds_in_group) then
            break
        end
    end

    if num_sounds_in_group <= 0 then
        -- TODO Log error for failing to find group with subtracted sound in it
        --LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_group_failed").Value, mod_name, Path.GetFileName(custom_sound_path), sound_group_id))
    else
        Resound.SoundGroups[sound_group_id] = {
            sounds_to_load = sounds_to_load, -- Keeps track of what sounds have been loaded in a dict formatted filename:true
            sounds = {} -- Sounds are added as they are loaded elsewhere
        }

        -- TODO print subtraction registered log
        --LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_group").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group_id)), Color.Green)
    end
end

local function override_sound(sound_info)
    local vanilla_sound_path = sound_info.vanilla_sound_path
    local custom_sound_path = sound_info.custom_sound_path
    local mod_name = sound_info.mod_name
    local sound_group_id = nil
    local sound_group = nil

    -- Check if another ReSound mod has already replaced this vanilla sound.
    local is_already_replaced = Resound.OriginalToCustomMap[vanilla_sound_path] -- or Resound.SoundGroups[Resound.SoundPathToGroupID[vanilla_sound_path]] if filename matches with any sounds
    
    -- Check if the custom sound file exists and skip the sound if not.
    if not File.Exists(custom_sound_path) then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, mod_name, custom_sound_path))
        goto continue
    end

    -- Check if the vanilla sound file exists and skip the sound if not.
    if not File.Exists(vanilla_sound_path) then
        LuaCsLogger.LogError(string.format(TextManager.Get("resound_find_vanilla_sound_failed").Value, mod_name, vanilla_sound_path))
        goto continue
    end
    
    -- Warn user if a mod is replacing another mods sounds.
    if is_already_replaced then
        LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_override_warning").Value, mod_name, Path.GetFileName(is_already_replaced), Path.GetFileName(custom_sound_path)), Color.Yellow)
    else
        LuaCsLogger.LogMessage(string.format(TextManager.Get("resound_registered_sound").Value, Path.GetFileName(vanilla_sound_path), Path.GetFileName(custom_sound_path)), Color.Green)
    end

    Resound.OriginalToCustomMap[vanilla_sound_path] = custom_sound_path
    Resound.CustomToOriginalMap[custom_sound_path] = vanilla_sound_path
    Resound.CustomSoundParams[vanilla_sound_path] = sound_info.fields

    sound_group_id = Resound.SoundPathToGroupID[vanilla_sound_path]
    print("sound_group_id for: ", vanilla_sound_path, "   :   ", sound_group_id or "nil")
    sound_group = Resound.SoundGroups[sound_group_id]
    if sound_group then
        Resound.SoundPathToGroupID[vanilla_sound_path] = nil
        Resound.SoundPathToGroupID[custom_sound_path] = sound_group_id

        -- Override additional sounds that have been loaded by this mod or others.
        for i = #sound_group.sounds, 1, -1 do
            if vanilla_sound_path == sound_group.sounds[i].Filename then
                table.remove(sound_group.sounds, i)
                table.insert(sound_group.sounds, Game.SoundManager.LoadSound(custom_sound_path))
            end
        end

        if sound_group.sounds_to_load[vanilla_sound_path] then
            sound_group.sounds_to_load[custom_sound_path] = true
            sound_group.sounds_to_load[vanilla_sound_path] = false
        end
    end

    ::continue::
end

local number_of_mods_read = 0
local sounds_to_override = {}
local sounds_to_subtract = {}
local sounds_to_add = {}

-- Check packages in reverse order for intuitive load order overriding.
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
        local value, fields = extract_extra_fields(value)
        local is_additional_sound = string.sub(key, 1, 1) == "+"
        local is_subtracted_sound = string.sub(key, 1, 1) == "-"

        -- Remove the "+" or "-" from subtracted or added sounds.
        if is_additional_sound then
            key = string.gsub(key, "^%+Content", "Content")
            key = string.gsub(key, "^%+WorkshopMods", "WorkshopMods")
        elseif is_subtracted_sound then
            key = string.gsub(key, "^%-Content", "Content")
            key = string.gsub(key, "^%-WorkshopMods", "WorkshopMods")
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

        -- Add entries into separate tables so they can be executed in a specific order later.
        if is_subtracted_sound then
            table.insert(sounds_to_subtract, {vanilla_sound_path=vanilla_sound_path, mod_name=package.Name})
        elseif is_additional_sound then
            table.insert(sounds_to_add, {vanilla_sound_path=vanilla_sound_path, custom_sound_path=custom_sound_path, fields=fields, mod_name=package.Name})
        else
            table.insert(sounds_to_override, {vanilla_sound_path=vanilla_sound_path, custom_sound_path=custom_sound_path, fields=fields, mod_name=package.Name})
        end
    end
end

-- Add additional sounds
for sound_info in sounds_to_add do
    add_sound(sound_info)
end

-- Subtract sounds
for sound_info in sounds_to_subtract do
    subtract_sound(sound_info)
end

-- Override sounds
for sound_info in sounds_to_override do
    override_sound(sound_info)
end

-- Tell user how many sounds were loaded, if zero sounds were loaded despite reading a file, display a failed message.
local override_count = 0
for _ in Resound.OriginalToCustomMap do
    override_count = override_count + 1
end
local added_count = 0
-- get added count
local subtracted_count = 0
-- get subtracted_count
if (override_count > 0) or (added_count > 0) then
    LuaCsLogger.LogMessage(string.format("ReSound | " .. TextManager.Get("resound_reading_finished").Value, number_of_mods_read, override_count, added_count), Color.Green)
elseif number_of_mods_read > 0 and override_count <= 0 and added_count <= 0 then
    LuaCsLogger.LogError(string.format("ReSound | " .. TextManager.Get("resound_reading_finished_failed").Value, number_of_mods_read))
end