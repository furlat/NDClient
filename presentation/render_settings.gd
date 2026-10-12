extends RefCounted
# Local display preferences only; no gameplay or replication state is persisted.
const PATH = "user://rendering_settings.cfg"
const DEFAULT_PROFILE = "reference"
const PROFILES = {"original":"Original", "gentle":"Gentle", "reference":"Reference"}

static func read(path: String = PATH) -> Dictionary:
    var config = ConfigFile.new()
    var error = config.load(path)
    if error == ERR_FILE_NOT_FOUND: return {"profile":DEFAULT_PROFILE,"error":OK}
    if error != OK: return {"profile":DEFAULT_PROFILE,"error":error}
    var profile = str(config.get_value("rendering","character_light_profile",DEFAULT_PROFILE))
    return {"profile":profile if PROFILES.has(profile) else DEFAULT_PROFILE,"error":OK}

static func write(profile: String, path: String = PATH) -> Error:
    if not PROFILES.has(profile): return ERR_INVALID_PARAMETER
    var config = ConfigFile.new()
    var error = config.load(path)
    if error != OK and error != ERR_FILE_NOT_FOUND: return error
    config.set_value("rendering","character_light_profile",profile)
    return config.save(path)
