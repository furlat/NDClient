extends RefCounted
## Explicit current producer only. Native Variant parsing retains integer types.
## The trusted producer owns JSON grammar; no second syntax validation runs here.
## Small .0/.5 decimals are exact; other numeric/escape forms use StrictJSON.
const StrictJSON = preload("res://sdk/strict_json.gd")
const UNSUPPORTED_SCALAR = (
    "\"(?:[^\"\\\\\\x00-\\x1f]++|\\\\[\"\\\\bfnrt])*+\"(*SKIP)(*F)|" +
    "(?<![0-9.eE+\\-])-?(?:(?:0|[1-9][0-9]{0,7})\\.[05]|(?:0|[1-9][0-9]{0,17}))(?![0-9.eE+\\-])(*SKIP)(*F)|" +
    "[0-9\\\\]")
var _unsupported_scalar = RegEx.create_from_string(UNSUPPORTED_SCALAR)

func parse(text: String,profile:bool=false) -> Dictionary:
    var started:int=Time.get_ticks_usec() if profile else 0
    var compatible:bool=_unsupported_scalar.search(text)==null
    var guarded_at:int=Time.get_ticks_usec() if profile else 0
    if not compatible:
        var fallback:Dictionary=StrictJSON.new().parse(text)
        if profile:fallback.parser_phases_ms={"regex":(guarded_at-started)/1000.0,"variant":0.0,"strict_fallback":(Time.get_ticks_usec()-guarded_at)/1000.0}
        return fallback
    var value: Variant = str_to_var(text)
    var parsed_at:int=Time.get_ticks_usec() if profile else 0
    var result:Dictionary=StrictJSON.new().parse(text) if not value is Dictionary and not value is Array else {"ok":true,"value":value}
    if profile:result.parser_phases_ms={"regex":(guarded_at-started)/1000.0,"variant":(parsed_at-guarded_at)/1000.0,"strict_fallback":(Time.get_ticks_usec()-parsed_at)/1000.0 if not value is Dictionary and not value is Array else 0.0}
    return result
