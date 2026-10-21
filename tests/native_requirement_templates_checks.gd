extends SceneTree
## Imported descriptions are passive source operands. Applicability and each
## diagnostic component remain occurrence-owned; no source loads are hidden here.
const Requirements=preload("res://presentation/requirements.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Catalog=preload("res://source_catalog.gd")
const Definition=preload("res://presentation/resources/native_spell.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REQUIREMENT_TEMPLATE_FAIL ",label)
func _initialize()->void:run.call_deferred()

## The frozen extractor remains the independent oracle for every unchanged
## field. Only the explicitly implemented damage-policy descriptions changed;
## assert their new semantics independently, without regenerating the oracle.
func frozen_contract(actual:Array,frozen:Array,selected:Dictionary)->bool:
    if actual.size()!=frozen.size():return false
    var definitions:Dictionary={"damage_flash":"hitFlash","damage_number":"floatingNumber","damage_death":"death"}
    for index in actual.size():
        var current:Dictionary=actual[index];var previous:Dictionary=frozen[index]
        if current==previous and not definitions.has(previous.kind):continue
        if not definitions.has(previous.kind) or current.kind!=previous.kind:return false
        var policy:Variant=selected.get("damage",{}).get(definitions[previous.kind])
        if not policy is Dictionary:return false
        var left:Dictionary=current.duplicate();var right:Dictionary=previous.duplicate()
        for field in ["implementation","inspection","gap_kind","status","reason","next_step","authored_policy","execution_owner","unused_legacy_fields"]:
            left.erase(field);right.erase(field)
        if left!=right:return false
        var supported:bool=current.kind!="damage_death" or policy.get("enabled",true)
        if current.implementation!=("implemented" if supported else "unassessed") \
            or current.inspection!=("projected" if supported else "missing") \
            or current.gap_kind!=("unexercised" if supported else "unassessed") \
            or current.status!=("unexercised" if supported else "missing") \
            or current.get("authored_policy")!=policy or current.authored_enabled!=policy.get("enabled",true) \
            or current.disposition!="parent_owned" or current.rendered \
            or str(current.reason).is_empty() or str(current.next_step).is_empty():return false
        if current.kind=="damage_death":
            if current.get("execution_owner")!="fact:life" or current.get("unused_legacy_fields")!=(["frame"] if policy.has("frame") else []):return false
        elif current.has("execution_owner") or current.has("unused_legacy_fields"):return false
    return true

## Removing only the admitted template owner forces the current extractor.
## Keep all other source operands, and preserve the production cache untouched.
func uncached_occurrence(event:Dictionary,selected:Dictionary,source:String,cache:Dictionary)->Array:
    var private_cache:Dictionary=cache.duplicate();private_cache.erase(Sources.CACHE_KEY)
    return Requirements.occurrence(event,selected,source,private_cache)
func run()->void:
    var oracle_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
    if oracle_path.is_empty():printerr("Requires --oracle=<frozen pre-change requirements extractor>");quit(2);return
    var oracle:Script=load(oracle_path)
    var cache:Dictionary={}
    var index:Resource=Sources.admission(cache).index
    check(index!=null,"Existing native presentation revision admits")
    if index==null:quit(1);return
    var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    var kinds:Dictionary=schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping
    check(index.fact_requirements.size()==kinds.size(),"Offline contract templates cover every current discriminator")
    for kind in kinds:
        var actual:Dictionary=Requirements.fact(kind,cache)
        if kind=="actor_change":
            # This canonical container's row policy intentionally supersedes
            # the frozen pre-cache extractor's generic unassessed demand.
            # actor_row_requirement_checks qualifies every ordered field.
            check(actual.kind=="fact:actor_change" and actual.participant=="container" \
                and actual.get("disposition")=="ordered_rows" and actual.implementation=="implemented" \
                and actual.inspection=="projected" and actual.status=="unexercised" and not actual.rendered \
                and actual.event_kinds==["actor_change"] and actual.source.ends_with("/mapping/actor_change"),
                "Canonical ActorChange template delegates ordered rows without claiming body/render coverage")
        elif kind in ["mechanism_activation","portal_transfer"]:
            check(actual.kind=="fact:"+kind and actual.implementation=="implemented" \
                and actual.inspection=="projected" and actual.status=="unexercised" and not actual.rendered \
                and actual.event_kinds==[kind] and actual.source.ends_with("/mapping/"+kind),
                "Current shared world consumer remains projected and unexercised: "+kind)
        else:check(actual==oracle.fact(kind),"Exact contract description: "+kind)
        check(is_same(actual,index.fact_requirements[kind]),"Contract description borrows its admitted revision: "+kind)
    var rows:int=0;var conditional:int=0
    for behavior in index.spells:
        var record:Resource=Sources.find(behavior,cache)
        check(record!=null,"Selected source admits: "+behavior)
        if record==null:continue
        var expected:Array=oracle.recipe(record.recipe,record.requirement_source,["spell"],cache)
        check(record.requirements==Requirements.recipe(record.recipe,record.requirement_source,["spell"],cache),"Exact current uncached/offline recipe/source/event descriptions: "+behavior)
        check(frozen_contract(record.requirements,expected,record.recipe),"Frozen unchanged descriptions and explicit current feedback policy: "+behavior)
        var held:PackedByteArray=var_to_bytes(record.requirements)
        var event={"kind":"spell","behavior_id":behavior}
        var actual:Array=Requirements.occurrence(event,record.recipe,record.requirement_source,cache)
        check(actual==uncached_occurrence(event,record.recipe,record.requirement_source,cache),"Exact current cached/uncached occurrence requirements: "+behavior)
        check(frozen_contract(actual,oracle.occurrence(event,record.recipe,record.requirement_source,cache),record.recipe),"Frozen unchanged occurrence fields and current feedback policy: "+behavior)
        for i in record.requirements.size():
            rows+=1
            if record.requirements[i].status=="missing" and (not record.requirements[i].get("outcome_selectors",{}).is_empty() or record.requirements[i].kind in ["cancellationMedia","childAttack"]):
                conditional+=1
                check(not is_same(actual[i],record.requirements[i]),"Conditional applicability has a private row")
            else:check(is_same(actual[i],record.requirements[i]),"Unchanged requirement retains source operand")
        check(var_to_bytes(record.requirements)==held,"Occurrence cannot mutate admitted descriptions: "+behavior)
    var record:Resource=Sources.find("spell.fireball",cache)
    var worker:Dictionary=Catalog.source_snapshot(cache)
    check(is_same(Requirements.fact("damage",worker),Requirements.fact("damage",cache)),"Workers retain exact source contract operands")
    check(is_same(Sources.find("spell.fireball",worker).requirements,record.requirements),"Workers retain exact recipe template owner")
    var custom:Dictionary=record.recipe.duplicate(true)
    custom.bodyMaterials=[{"id":"custom","enabled":true}]
    var custom_event={"kind":"spell","behavior_id":"spell.fireball"}
    var custom_rows:Array=Requirements.occurrence(custom_event,custom,record.requirement_source,cache)
    check(custom_rows==uncached_occurrence(custom_event,custom,record.requirement_source,cache) \
        and frozen_contract(custom_rows,oracle.occurrence(custom_event,custom,record.requirement_source,cache),custom),"Changed recipe with same behavior/source cannot reuse prior revision")
    var custom_source_rows:Array=Requirements.occurrence(custom_event,record.recipe,"custom-source:",cache)
    check(custom_source_rows==uncached_occurrence(custom_event,record.recipe,"custom-source:",cache) \
        and frozen_contract(custom_source_rows,oracle.occurrence(custom_event,record.recipe,"custom-source:",cache),record.recipe),"Changed source pointer cannot reuse imported pointers")
    var replacement=Definition.new()
    replacement.recipe={"bodyMaterials":[{"id":"conditional","requiredSaveSuccess":true}]}
    replacement.requirement_source=record.requirement_source
    replacement.requirements=Requirements.recipe(replacement.recipe,replacement.requirement_source,["spell"])
    var replacement_cache={Sources.CACHE_KEY:Sources.make_admission(index,{"spell.fireball":replacement})}
    var before:PackedByteArray=var_to_bytes(replacement.requirements)
    var first:Array=Requirements.occurrence(custom_event,replacement.recipe,replacement.requirement_source,replacement_cache)
    var second:Array=Requirements.occurrence(custom_event,replacement.recipe,replacement.requirement_source,replacement_cache)
    check(first==oracle.occurrence(custom_event,replacement.recipe,replacement.requirement_source,replacement_cache),"New source owner gets its own exact applicability")
    check(not is_same(first[0],second[0]) and not is_same(first[0],replacement.requirements[0]),"Separate conditional occurrences never share mutable row state")
    first[0].reason="occurrence-local reason"
    check(second[0].reason!=first[0].reason and var_to_bytes(replacement.requirements)==before,"Occurrence edits cannot affect siblings or retained native source")
    var retained_rows:Array=Requirements.occurrence(custom_event,record.recipe,record.requirement_source,cache)
    check(retained_rows==uncached_occurrence(custom_event,record.recipe,record.requirement_source,cache) \
        and frozen_contract(retained_rows,oracle.occurrence(custom_event,record.recipe,record.requirement_source,cache),record.recipe),"Old source owner remains valid beside replacement")
    var absent:Dictionary={}
    check(Requirements.occurrence({"kind":"saving_throw"},{},"custom:",absent)==oracle.occurrence({"kind":"saving_throw"},{},"custom:",{}),"Unadmitted custom source keeps exact extraction")
    check(absent.is_empty(),"Requirement lookup never admits a source or opens source data")
    check(Requirements.fact("future_visual_fact",cache)==oracle.fact("future_visual_fact"),"Unknown fact remains explicitly classified")
    var report={"checks":checks,"failures":failures,"spells":index.spells.size(),"fact_templates":kinds.size(),"recipe_rows":rows,"conditional_rows":conditional,"scope":"Exact offline descriptions, immutable revision identity, lookup-only worker sharing and private occurrence applicability; no rendering or live latency claim."}
    FileAccess.open("res://.runtime/native-requirement-templates-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_REQUIREMENT_TEMPLATES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
