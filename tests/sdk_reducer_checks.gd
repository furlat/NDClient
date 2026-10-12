extends SceneTree
const Reducer = preload("res://sdk/reducer.gd")
const Audience = preload("res://sdk/audience.gd")
const StrictJSON = preload("res://sdk/strict_json.gd")

func invoke(method: String, args: Array) -> Dictionary:
    match method:
        "reduce_initialization": return Reducer.reduce_initialization(args[0], args[1])
        "reduce_operation": return Reducer.reduce_operation(args[0], args[1])
        "reduce_lineage": return Reducer.reduce_lineage(args[0], args[1])
        "reduce_nodes": return Reducer.reduce_nodes(args[0], args[1], args[2], args[3], args[4])
        "stage_lineage": return Reducer.stage_lineage(args[0], args[1])
        "stage_actors": return Reducer.stage_actors(args[0], args[1])
        "observe_actors": return Reducer.observe_actors(args[0], args[1])
        "state_before_event": return Reducer.state_before_event(args[0], args[1], args[2])
        "lineage_branch": return Reducer.lineage_branch(args[0], args[1])
        "index_player_lineage": return Reducer.index_player_lineage(args[0])
        "audience_observe": return Audience.observe(args[0], args[1], args[2], args[3])
        "audience_view": return Reducer.success(Audience.view(args[0], args[1]))
        "reduce_senses": return Audience.reduce_senses(args[0], args[1], args[2])
        "resolve_audience": return Audience.resolve(args[0], args[1])
    return Reducer.failure("Unknown oracle method " + method)

func difference(expected: Variant, actual: Variant, path: String = "$") -> String:
    if expected is Dictionary and actual is Dictionary:
        for key in expected:
            if not actual.has(key): return path + "." + key + " is missing"
            var detail = difference(expected[key], actual[key], path + "." + key)
            if not detail.is_empty(): return detail
        for key in actual:
            if not expected.has(key): return path + "." + key + " is unexpected"
        return ""
    if expected is Array and actual is Array:
        if expected.size() != actual.size(): return "%s length expected %d, actual %d" % [path, expected.size(), actual.size()]
        for i in range(expected.size()):
            var detail = difference(expected[i], actual[i], path + "[%d]" % i)
            if not detail.is_empty(): return detail
        return ""
    return "" if expected == actual else "%s expected %s, actual %s" % [path, JSON.stringify(expected), JSON.stringify(actual)]

func _initialize() -> void:
    var path = "res://.runtime/sdk-study/reducer-oracle.json"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--cases="): path = argument.trim_prefix("--cases=")
    if not FileAccess.file_exists(path):
        push_error("Oracle cases missing: " + path); quit(1); return
    var decoded = StrictJSON.new().parse(FileAccess.get_file_as_string(path))
    if not decoded.ok:
        push_error("Cannot decode oracle cases: " + str(decoded.error)); quit(1); return
    var suite: Variant = decoded.value
    if not suite is Dictionary or not suite.has("cases"):
        push_error("Invalid oracle cases: " + path); quit(1); return
    var failures = 0
    for case in suite.cases:
        var original: Array = case.arguments.duplicate(true)
        var actual = invoke(case.method, case.arguments)
        var detail = difference(original, case.arguments)
        if not detail.is_empty():
            failures += 1; print("SDK_REDUCER_FAIL ", case.name, " input mutated: ", detail)
        if actual.ok != case.expected.ok:
            failures += 1; print("SDK_REDUCER_FAIL ", case.name, " status expected ", case.expected, " actual ", actual)
        elif actual.ok:
            detail = difference(case.expected.value, actual.value)
            if not detail.is_empty():
                failures += 1; print("SDK_REDUCER_FAIL ", case.name, " ", detail)
    print("SDK_REDUCER_CHECKS cases=", suite.cases.size(), " failures=", failures)
    quit(1 if failures else 0)
