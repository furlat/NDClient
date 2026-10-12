extends RefCounted
# Local display preferences only; no gameplay or replication state is persisted.
const PATH = "user://rendering_settings.cfg"
const DEFAULT_PROFILE = "reference"
const DEFAULT_FIRE_LIGHT_FLICKER = false
const DEFAULT_LIGHT_STRENGTH = 1.0
const MAX_LIGHT_STRENGTH = 1.5
const PROFILES = {"original":"Original", "gentle":"Gentle", "reference":"Reference"}

static func read(path: String = PATH) -> Dictionary:
    var config = ConfigFile.new()
    var error = config.load(path)
    if error == ERR_FILE_NOT_FOUND: return {"profile":DEFAULT_PROFILE,"fire_light_flicker":DEFAULT_FIRE_LIGHT_FLICKER,"light_strength":DEFAULT_LIGHT_STRENGTH,"error":OK}
    if error != OK: return {"profile":DEFAULT_PROFILE,"fire_light_flicker":DEFAULT_FIRE_LIGHT_FLICKER,"light_strength":DEFAULT_LIGHT_STRENGTH,"error":error}
    var profile = str(config.get_value("rendering","character_light_profile",DEFAULT_PROFILE))
    var strength = float(config.get_value("rendering","light_strength",DEFAULT_LIGHT_STRENGTH))
    if not is_finite(strength): strength = DEFAULT_LIGHT_STRENGTH
    return {"profile":profile if PROFILES.has(profile) else DEFAULT_PROFILE,"fire_light_flicker":bool(config.get_value("rendering","fire_light_flicker",DEFAULT_FIRE_LIGHT_FLICKER)),"light_strength":clampf(strength,0.0,MAX_LIGHT_STRENGTH),"error":OK}

static func write(profile: String, path: String = PATH) -> Error:
    if not PROFILES.has(profile): return ERR_INVALID_PARAMETER
    var config = ConfigFile.new()
    var error = config.load(path)
    if error != OK and error != ERR_FILE_NOT_FOUND: return error
    config.set_value("rendering","character_light_profile",profile)
    return config.save(path)

static func write_fire_light_flicker(enabled: bool, path: String = PATH) -> Error:
    var config = ConfigFile.new()
    var error = config.load(path)
    if error != OK and error != ERR_FILE_NOT_FOUND: return error
    config.set_value("rendering","fire_light_flicker",enabled)
    return config.save(path)

static func write_light_strength(value: float, path: String = PATH) -> Error:
    if not is_finite(value) or value < 0 or value > MAX_LIGHT_STRENGTH: return ERR_INVALID_PARAMETER
    var config = ConfigFile.new()
    var error = config.load(path)
    if error != OK and error != ERR_FILE_NOT_FOUND: return error
    config.set_value("rendering","light_strength",value)
    return config.save(path)
