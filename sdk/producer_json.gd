extends RefCounted
## Explicit current producer only. Native Variant parsing retains integer types.
## The JSON-only guard excludes Variant constructors and object/resource syntax.
## Small .0/.5 decimals are exact; other numeric/escape forms use StrictJSON.
## The native recursion budget also falls back to its existing 512-depth limit.
const StrictJSON = preload("res://sdk/strict_json.gd")
const JSON_SUBSET = (
    "(*LIMIT_DEPTH=512)\\A(?&ws)(?&value)(?&ws)\\z(?(DEFINE)" +
    "(?<ws>[ \\t\\r\\n]*+)" +
    "(?<value>(?&object)|(?&array)|(?&string)|(?&number)|true|false|null)" +
    "(?<object>\\{(?&ws)(?:(?&string)(?&ws):(?&ws)(?&value)(?:(?&ws),(?&ws)(?&string)(?&ws):(?&ws)(?&value))*+)?(?&ws)\\})" +
    "(?<array>\\[(?&ws)(?:(?&value)(?:(?&ws),(?&ws)(?&value))*+)?(?&ws)\\])" +
    "(?<string>\"(?:[^\"\\\\\\x00-\\x1f]++|\\\\[\"\\\\bfnrt])*+\")" +
    "(?<number>-?(?:(?:0|[1-9][0-9]{0,7})\\.[05]|(?:0|[1-9][0-9]{0,17}))))")
var _syntax = RegEx.create_from_string(JSON_SUBSET)

func parse(text: String) -> Dictionary:
    if _syntax.search(text) == null: return StrictJSON.new().parse(text)
    var value: Variant = str_to_var(text)
    if not value is Dictionary and not value is Array: return StrictJSON.new().parse(text)
    return {"ok":true,"value":value}
