LuaUserData.RegisterType("Barotrauma.DebugConsole")
local DebugConsole = LuaUserData.CreateStatic("Barotrauma.DebugConsole")

-- Technically this mod could work without this class since we could just use relative paths to load sounds,
-- but it's so convenient, it's worth breaking the sandbox for. This pcall makes it clear to the user they need C# scripting.
local Path
local success, result = pcall(function()
    LuaUserData.RegisterType("Barotrauma.IO.Path")
    Path = LuaUserData.CreateStatic("Barotrauma.IO.Path", true)
end)
if not success then
    DebugConsole.LogError(TextManager.Get("resound_luauserdataerror").Value)
    return
end

-- Alternative to using SaveUtil.DefaultSaveFolder, which requires registering the class with C# scripting enabled.
local WorkshopModsParentDir = ContentPackage.WorkshopModsDir:match("(.*)WorkshopMods.*")

local function safe_single(value)
    -- Try to convert to a number, return nil if it fails
    local number = tonumber(value)
    if number then
        return Single(number)
    else
        return nil
    end
end

-- Get any extra params from a custom sound path, like volume and range.
local function extract_extra_fields(input)
    -- Extract values after each comma (ignoring spaces)
    local fields = {}
    for field in input:gmatch(",%s*([^,]+)") do
        table.insert(fields, field)
    end
    -- Remove everything after the first comma (including the comma itself)
    local cleaned_string = input:gsub(",.*", "")

    return cleaned_string, { gain=safe_single(fields[1]), near=safe_single(fields[2]), far=safe_single(fields[3]) }
end

-- Adds an additional sound to a group of existing vanilla or modded sound.
local function add_sound(sound_info)
    -- Make sure the group_id is clean, no numbers or file extensions.
    local sound_group_id = sound_info.original_sound_path
    sound_group_id = sound_group_id:gsub("%.ogg$", "")
    sound_group_id = sound_group_id:gsub("%d+$", "")

    local custom_sound_path = sound_info.custom_sound_path
    local gain, near, far = sound_info.fields.gain, sound_info.fields.near, sound_info.fields.far
    local mod_name = sound_info.mod_name
    local num_sounds_in_group = 0

    -- Check if the custom sound file exists and skip the sound if not.
    if not File.Exists(custom_sound_path) then
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, mod_name, custom_sound_path))
        end
        return
    end

    -- Adding an additional sound to an existing sound group.
    if Resound.SoundGroups[sound_group_id] then
        local custom_sound = Game.SoundManager.LoadSound(custom_sound_path)
        custom_sound.BaseGain = gain or custom_sound.BaseGain
        custom_sound.BaseNear = near or custom_sound.BaseNear
        custom_sound.BaseFar = far or custom_sound.BaseFar
        local sounds = Resound.SoundGroups[sound_group_id].sounds
        table.insert(sounds, custom_sound)
        Resound.SoundPathToGroupID[custom_sound_path] = sound_group_id

        num_sounds_in_group = #sounds
        for _ in Resound.SoundGroups[sound_group_id].sounds_to_load do
            num_sounds_in_group = num_sounds_in_group + 1
        end
        if Resound.Config.OtherLogs then
            DebugConsole.NewMessage(string.format(TextManager.Get("resound_registered_group_add").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group_id), num_sounds_in_group, 100 / num_sounds_in_group), Color.Green)
        end
        return
    end

    -- Figures out how many sounds are in the group.
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
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_group_failed_add").Value, mod_name, sound_group_id, Path.GetFileName(custom_sound_path)))
        end
        return
    end

    Resound.SoundGroups[sound_group_id] = {
        sounds_to_load = sounds_to_load, -- Keeps track of what sounds have been loaded in a dict formatted filename:true
        sounds = {} -- Sounds are added as they are loaded elsewhere
    }
    local custom_sound = Game.SoundManager.LoadSound(custom_sound_path)
    custom_sound.BaseGain = gain or custom_sound.BaseGain
    custom_sound.BaseNear = near or custom_sound.BaseNear
    custom_sound.BaseFar = far or custom_sound.BaseFar
    local sounds = Resound.SoundGroups[sound_group_id].sounds
    table.insert(sounds, custom_sound)
    Resound.SoundPathToGroupID[custom_sound_path] = sound_group_id

    num_sounds_in_group = num_sounds_in_group + #sounds
    if Resound.Config.OtherLogs then
        DebugConsole.NewMessage(string.format(TextManager.Get("resound_registered_group_add").Value, Path.GetFileName(custom_sound_path), Path.GetFileName(sound_group_id), num_sounds_in_group, 100 / num_sounds_in_group), Color.Green)
    end
end

-- Functionality for subtracting sounds from a group of existing vanilla or modded sound(s).
local subtracted_count = 0
local function subtract_sound(sound_info)
    local target_sound_path = sound_info.original_sound_path
    local mod_name = sound_info.mod_name
    local num_remaining_sounds = 0

    -- Check if the original sound file exists and skip the sound if not.
    if not File.Exists(target_sound_path) then
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_original_sound_failed").Value, mod_name, target_sound_path))
        end
        return
    end

    -- Get the group id.
    local sound_group_id = Resound.SoundPathToGroupID[target_sound_path]
    if not sound_group_id then
        sound_group_id = target_sound_path:gsub("%.ogg$", "")
        sound_group_id = sound_group_id:gsub("%d+$", "")
    end

    local sound_group = Resound.SoundGroups[sound_group_id]
    -- If a group has already been created that includes this sound, subtract it from the group.
    if sound_group then
        -- Prevent the sound from being loaded in the future.
        if sound_group.sounds_to_load[target_sound_path] then
            sound_group.sounds_to_load[target_sound_path] = false
            subtracted_count = subtracted_count + 1
        end

        -- Remove any sounds that may have been already been loaded (only additional sounds are loaded this early).
        local sounds = sound_group.sounds
        for i = #sounds, 1, -1 do
            if target_sound_path == sounds[i].Filename then
                table.remove(sounds, i)
                Game.SoundManager.RemoveSound(sounds[i])
                sounds[i].Dispose()
                subtracted_count = subtracted_count + 1
            end
        end

        for needs_loading in sound_group.sounds_to_load do
            if needs_loading then
                num_remaining_sounds = num_remaining_sounds + 1
            end
        end
        num_remaining_sounds = num_remaining_sounds + #sounds
        if Resound.Config.OtherLogs then
            DebugConsole.NewMessage(string.format(TextManager.Get("resound_registered_group_sub").Value, Path.GetFileName(target_sound_path), Path.GetFileName(sound_group_id), num_remaining_sounds, Path.GetFileName(sound_group_id)), Color.Green)
        end
        return
    end

    -- Create a new group for the subtracted sound.
    local num_discovered_sounds = 0
    local sounds_to_load = {}
    local postfix = ".ogg"
    for i = 1, 100 do -- Max of 100 iterations for safety.
        local filename = sound_group_id .. postfix
        if File.Exists(filename) then
            -- Link the subtracted sound to this group ID.
            Resound.SoundPathToGroupID[filename] = sound_group_id
            num_discovered_sounds = num_discovered_sounds + 1

            if filename == target_sound_path then
                subtracted_count = subtracted_count + 1
            else
                sounds_to_load[filename] = true
                num_remaining_sounds = num_remaining_sounds + 1
            end
        end
        postfix = tostring(i) .. ".ogg"
        -- Exit the loop when we run out of numbered sound variants or if there's none.
        if (i - 2 >= num_discovered_sounds) then
            break
        end
    end

    if num_discovered_sounds <= 0 then
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_group_failed_sub").Value, mod_name, sound_group_id, Path.GetFileName(target_sound_path)))
        end
        return
    end

    Resound.SoundGroups[sound_group_id] = {
        sounds_to_load = sounds_to_load, -- Keeps track of what sounds have been loaded in a dict formatted filename:true
        sounds = {} -- Sounds are added as they are loaded elsewhere
    }
    if Resound.Config.OtherLogs then
        DebugConsole.NewMessage(string.format(TextManager.Get("resound_registered_group_sub").Value, Path.GetFileName(target_sound_path), Path.GetFileName(sound_group_id), num_remaining_sounds, Path.GetFileName(sound_group_id)), Color.Green)
    end
end

local function override_sound(sound_info)
    local original_sound_path = sound_info.original_sound_path
    local custom_sound_path = sound_info.custom_sound_path
    local mod_name = sound_info.mod_name
    local sound_group_id = nil
    local sound_group = nil

    -- Check if another ReSound mod has already replaced this vanilla sound.
    local is_already_replaced = Resound.OriginalToCustomMap[original_sound_path]
    
    -- Check if the custom sound file exists and skip the sound if not.
    if not File.Exists(custom_sound_path) then
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_custom_sound_failed").Value, mod_name, custom_sound_path))
        end
        goto continue
    end

    -- Check if the vanilla sound file exists and skip the sound if not.
    if not File.Exists(original_sound_path) then
        if Resound.Config.ImportantLogs then
            DebugConsole.LogError(string.format(TextManager.Get("resound_find_original_sound_failed").Value, mod_name, original_sound_path))
        end
        goto continue
    end
    
    -- Warn user if a mod is replacing another mods sounds.
    if is_already_replaced then
        if Resound.Config.ImportantLogs then
            DebugConsole.NewMessage(string.format(TextManager.Get("resound_override_warning").Value, mod_name, Path.GetFileName(is_already_replaced), Path.GetFileName(custom_sound_path)), Color.Yellow)
        end
    else
        if Resound.Config.OtherLogs then
            DebugConsole.NewMessage(string.format(TextManager.Get("resound_registered_sound").Value, Path.GetFileName(original_sound_path), Path.GetFileName(custom_sound_path)), Color.Green)
        end
    end

    Resound.OriginalToCustomMap[original_sound_path] = custom_sound_path
    Resound.CustomSoundParams[original_sound_path] = sound_info.fields

    sound_group_id = Resound.SoundPathToGroupID[original_sound_path]
    sound_group = Resound.SoundGroups[sound_group_id]
    if sound_group then
        -- Override additional sounds that have been loaded by this mod or others.
        for i = #sound_group.sounds, 1, -1 do
            if original_sound_path == sound_group.sounds[i].Filename then
                table.remove(sound_group.sounds, i)
                table.insert(sound_group.sounds, Game.SoundManager.LoadSound(custom_sound_path))
            end
        end
    end

    ::continue::
end

local number_of_mods_read = 0

-- Check packages in reverse order for intuitive load order overriding.
Resound.LoadedPackages = {}
local packages = {}
for package in ContentPackageManager.EnabledPackages.All do
    table.insert(packages, package)
end
for i = #packages, 1, -1 do
    local package = packages[i]
    local sound_data_file = Path.Combine(package.Dir, "resound_overrides.json")
    local sound_data = {}
    local sounds_to_override = {}
    local sounds_to_subtract = {}
    local sounds_to_add = {}
    
    -- Check if mod has the "resound_overrides.json" file and try to load it into the sound_data variable.
    if File.Exists(sound_data_file) then
        table.insert(Resound.LoadedPackages, package)
        local success, result = pcall(json.parse, File.Read(sound_data_file))
        number_of_mods_read = number_of_mods_read + 1
        if not success then
            if Resound.Config.ImportantLogs then
                DebugConsole.LogError(string.format(TextManager.Get("resound_reading_from_mod_failed").Value, package.Name))
            end
        else
            if Resound.Config.IgnoredPackages[package.Dir] then
                number_of_mods_read = number_of_mods_read - 1
            else
                sound_data = result
                if Resound.Config.ImportantLogs then
                    DebugConsole.NewMessage(string.format(TextManager.Get("resound_reading_from_mod").Value, package.Name), Color.White)
                end
            end
        end
    end

    -- Extract info, clean, and assemble the correct file paths.
    for key, value in pairs(sound_data) do
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
        local custom_sound_path = value
        if (string.find(custom_sound_path, "^WorkshopMods")) then
            -- The custom sound is in a different package (WorkshopMods).
            custom_sound_path = Path.Combine(WorkshopModsParentDir, value)
        else
            -- The custom sound is in the current package (LocalMods or WorkshopMods).
            custom_sound_path = Path.GetFullPath(Path.Combine(package.Dir, value))
        end

        -- Assemble the complete directory for the vanilla sound.
        local original_sound_path = key
        if string.find(key, "^Content") then
            -- The original sound is in the vanilla game.
            original_sound_path = Path.GetFullPath(key)
        elseif string.find(key, "^WorkshopMods") then
            -- The original sound is in a different package (WorkshopMods).
            original_sound_path = Path.Combine(WorkshopModsParentDir, key)
        end

        -- Normalise slashes.
        original_sound_path = string.gsub(original_sound_path, "\\", "/")
        custom_sound_path = string.gsub(custom_sound_path, "\\", "/")

        -- Add entries into separate tables so they can be executed in a specific order.
        if is_subtracted_sound then
            table.insert(sounds_to_subtract, {original_sound_path=original_sound_path, mod_name=package.Name})
        elseif is_additional_sound then
            table.insert(sounds_to_add, {original_sound_path=original_sound_path, custom_sound_path=custom_sound_path, fields=fields, mod_name=package.Name})
        else
            table.insert(sounds_to_override, {original_sound_path=original_sound_path, custom_sound_path=custom_sound_path, fields=fields, mod_name=package.Name})
        end
    end

    -- Add additional sounds
    for sound_info in sounds_to_add do
        add_sound(sound_info)
    end

    -- Subtract sounds. Important to do this after adding sounds.
    for sound_info in sounds_to_subtract do
        subtract_sound(sound_info)
    end

    -- Override sounds - Important to do this last.
    for sound_info in sounds_to_override do
        override_sound(sound_info)
    end
end

-- Count totals.
local override_count = 0
for _ in Resound.OriginalToCustomMap do
    override_count = override_count + 1
end
local added_count = 0
for sound_group in Resound.SoundGroups do
    added_count = added_count + #sound_group.sounds
end

-- Tell user how many sounds were loaded, if zero sounds were loaded despite reading a file, display a failed message.
if Resound.Config.ImportantLogs then
    if (override_count > 0) or (added_count > 0) or (subtracted_count > 0) then
        DebugConsole.NewMessage(string.format(TextManager.Get("resound_reading_finished").Value, number_of_mods_read, override_count, added_count, subtracted_count), Color.Green)
    elseif (number_of_mods_read > 0) and (override_count <= 0) and (added_count <= 0) and (subtracted_count <= 0) then
        DebugConsole.NewMessage(string.format(TextManager.Get("resound_reading_finished_failed").Value, number_of_mods_read), Color.Yellow)
    end
end