local default_config = {}
local new_config = {}
local config_path = Resound.ConfigPath
default_config.Enabled = true
default_config.ImportantLogs = true
default_config.OtherLogs = false
default_config.IgnoredPackages = {}

-- If there's no config file, create a new one with default values.
if not File.Exists(config_path) then
    new_config = default_config
    File.Write(config_path, json.serialize(new_config))

-- Otherise, load the existing config.
else
    new_config = json.parse(File.Read(config_path))

    -- Add any missing values.
    for key, value in pairs(default_config) do
        if new_config[key] == nil then
            new_config[key] = value
        end
    end
end

return new_config