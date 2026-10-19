extends RefCounted
## Response-local compact lookups. Admitted rows/domains are borrowed read-only;
## no helper expands target trees or installs defaults into the wire value.
const FAMILIES = ["entity_actions","position_actions","self_actions","object_actions"]
const SAFE_INTEGER = 9007199254740991

static func all_actions(choices: Dictionary) -> Array:
    var result: Array = []
    for family in FAMILIES: result.append_array(choices.get(family,[]))
    return result

static func action_options(choices: Dictionary, action: Dictionary) -> Array:
    return choices.get("target_sets",[])[int(action.target_set)]

static func binding_subject(domains: Dictionary, binding: Dictionary) -> Variant:
    return domains.get("subjects",[])[int(binding.subject)] if binding.kind=="subject" else null

static func binding_position(domains: Dictionary, binding: Dictionary) -> Variant:
    if binding.kind=="self" or binding.get("position")==null: return null
    return domains.get("positions",[])[int(binding.position)]

static func binding_value(binding: Dictionary, field: String) -> Variant:
    if binding.has(field): return binding[field]
    if field=="is_path_hazardous": return false
    if field in ["opportunity_attack_exposures","safe_path_opportunity_attack_exposures"]: return []
    return null

static func binding_path(domains: Dictionary, binding: Dictionary, safe: bool=false) -> Variant:
    var refs = binding_value(binding,"safe_path" if safe else "path")
    if refs==null: return null
    var result: Array = []
    for reference in refs: result.append(domains.get("positions",[])[int(reference)])
    return result

static func secondary_options(choices: Dictionary, action: Dictionary, primary: Dictionary) -> Array:
    var reference = primary.get("secondary_set")
    return action_options(choices,action) if reference==null else choices.get("target_sets",[])[int(reference)]

static func next_options(preview: Dictionary) -> Array:
    return preview.get("target_sets",[])[int(preview.next_target_set)]

static func preview_positions(preview: Dictionary, affected: bool=false) -> Array:
    var result: Array = []
    for reference in preview.get("affected_positions" if affected else "next_positions",[]):
        result.append(preview.get("positions",[])[int(reference)])
    return result

static func selection_for(action: Dictionary, targets: Array, extra_target_positions: Array=[], prefer_safe: bool=true, cast_at_level: Variant=null) -> Dictionary:
    var indices: Array = []
    for binding in targets: indices.append(int(binding.index))
    var positions: Array = []
    for position in extra_target_positions: positions.append(position.duplicate())
    var selection={"action_index":int(action.get("discovery_index",0)),"target_indices":indices,
        "extra_target_positions":positions,"prefer_safe":prefer_safe}
    if cast_at_level!=null:selection.cast_at_level=int(cast_at_level)
    return selection

static func position_eligibility(choices: Dictionary) -> Dictionary:
    var result = {}
    for action in all_actions(choices):
        for binding in action_options(choices,action):
            var position = binding_position(choices,binding)
            if position==null: continue
            var key = "%d,%d" % [position[0],position[1]]
            if not result.has(key): result[key] = []
            result[key].append({"action":action,"binding":binding})
    return result

static func _integer(value: Variant, native_numbers: bool=false) -> bool:
    # Only the explicit native-JSON admission accepts integral floats. The strict
    # public path preserves the Python SDK's integer-token reference contract.
    return (typeof(value)==TYPE_INT or (native_numbers and typeof(value)==TYPE_FLOAT)) and is_finite(float(value)) and value>=0 and value<=SAFE_INTEGER and value==floor(value)

static func _reference(values: Array, reference: Variant, field: String, native_numbers: bool) -> String:
    if not _integer(reference,native_numbers) or reference>=values.size(): return field+": reference is out of range"
    return ""

# These checks follow structural schema admission. Each shared set is visited
# once for indices/references, then once for its secondary relation constraints.
static func _check_domains(domains: Dictionary, native_numbers: bool) -> String:
    var positions: Array = domains.get("positions",[])
    var subjects: Array = domains.get("subjects",[])
    var sets: Array = domains.get("target_sets",[])
    var indices: Array = []
    var secondary_sets = {}
    for targets in sets:
        var seen = {}
        for binding in targets:
            if not _integer(binding.index,native_numbers) or seen.has(int(binding.index)): return "Invalid or duplicate target index within a target set"
            seen[int(binding.index)] = true
            var issue = ""
            if binding.kind=="subject": issue = _reference(subjects,binding.subject,"subject",native_numbers)
            if not issue.is_empty(): return issue
            if binding.kind!="self" and binding.get("position")!=null: issue = _reference(positions,binding.position,"position",native_numbers)
            if not issue.is_empty(): return issue
            for field in ["path","safe_path"]:
                var path = binding.get(field)
                if path==null: continue
                for reference in path:
                    issue = _reference(positions,reference,field,native_numbers)
                    if not issue.is_empty(): return issue
            for field in ["opportunity_attack_exposures","safe_path_opportunity_attack_exposures"]:
                for exposure in binding.get(field,[]):
                    issue = _reference(positions,exposure.from_position,field,native_numbers)
                    if not issue.is_empty(): return issue
                    issue = _reference(positions,exposure.to_position,field,native_numbers)
                    if not issue.is_empty(): return issue
            var reference = binding.get("secondary_set")
            if reference!=null:
                issue = _reference(sets,reference,"secondary_set",native_numbers)
                if not issue.is_empty(): return issue
                secondary_sets[int(reference)] = true
        indices.append(seen)
    for reference in secondary_sets:
        for binding in sets[reference]:
            if binding.get("secondary_set")!=null: return "Secondary options cannot contain secondary overrides"
    for targets in sets:
        for primary in targets:
            var reference = primary.get("secondary_set")
            if reference!=null and indices[int(reference)].has(int(primary.index)): return "Secondary target index collides with its primary"
    return ""

static func check_choices(choices: Dictionary, native_numbers: bool=false) -> String:
    var issue = _check_domains(choices,native_numbers)
    if not issue.is_empty(): return issue
    var sets: Array = choices.get("target_sets",[])
    var ordinal = 0
    for family in FAMILIES:
        for action in choices.get(family,[]):
            var index = action.get("discovery_index",0)
            if not _integer(index,native_numbers) or index!=ordinal: return "Discovery action index does not match its ordinal"
            ordinal += 1
            if action.get("discovery_generation",0)!=choices.get("discovery_generation",0): return "Action belongs to a different discovery generation"
            issue = _reference(sets,action.target_set,"target_set",native_numbers)
            if not issue.is_empty(): return issue
            if (action.availability_status=="source_unaffordable")==action.can_afford: return "Contradictory source affordability"
            if action.get("position_region")==null and (action.availability_status=="available")!= (not sets[int(action.target_set)].is_empty()): return "Contradictory action availability and target set"
    return ""

static func check_preview(preview: Dictionary, native_numbers: bool=false) -> String:
    var issue = _check_domains(preview,native_numbers)
    if not issue.is_empty(): return issue
    issue = _reference(preview.get("target_sets",[]),preview.next_target_set,"next_target_set",native_numbers)
    if not issue.is_empty(): return issue
    for field in ["next_positions","affected_positions"]:
        for reference in preview.get(field,[]):
            issue = _reference(preview.get("positions",[]),reference,field,native_numbers)
            if not issue.is_empty(): return issue
    return ""
