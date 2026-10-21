extends SceneTree
## Native fold fixtures are the Python reference's full canonical state after every original vector step.
const Reducer=preload("res://sdk/reducer.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const Audience=preload("res://sdk/audience.gd")
const ROOT="res://tests/fixtures/schema16/fold/"
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
    if value:passed+=1
    else:failures.append(message);print("FAIL "+message)
static func difference(actual:Variant,expected:Variant,path:String="$")->String:
    if actual is Dictionary and expected is Dictionary:
        for key in expected:
            if not actual.has(key):return path+" missing "+str(key)
            var child=difference(actual[key],expected[key],path+"."+str(key))
            if not child.is_empty():return child
        for key in actual:
            if not expected.has(key):return path+" extra "+str(key)
        return ""
    if actual is Array and expected is Array:
        if actual.size()!=expected.size():return path+" size "+str(actual.size())+" expected "+str(expected.size())
        for i in range(actual.size()):
            var child=difference(actual[i],expected[i],path+"["+str(i)+"]")
            if not child.is_empty():return child
        return ""
    return "" if actual==expected else path+" actual "+JSON.stringify(actual)+" expected "+JSON.stringify(expected)
func fold(state:Dictionary,input:Dictionary)->Dictionary:
    if input.has("update"):
        # Preserve the previous full-store diff as an independent test oracle.
        # Only this oracle copies/scans retained stores; production records the
        # exact row references at its existing mutation sites.
        var prior_tiles:Dictionary=state.tiles.duplicate();var prior_objects:Dictionary=state.objects.duplicate()
        var disclosed:Dictionary={};var result:Dictionary=Reducer.apply_world_update(state,input.update,disclosed)
        if result.ok:
            var expected:Dictionary={"tiles":{},"objects":{},"tiles_removed":[],"objects_removed":[]}
            for key in state.tiles:
                if not prior_tiles.has(key) or not is_same(prior_tiles[key],state.tiles[key]):expected.tiles[key]=state.tiles[key]
            for key in prior_tiles:
                if not state.tiles.has(key):expected.tiles_removed.append(key)
            for identity in state.objects:
                if not prior_objects.has(identity) or not is_same(prior_objects[identity],state.objects[identity]):expected.objects[identity]=state.objects[identity]
            for identity in prior_objects:
                if not state.objects.has(identity):expected.objects_removed.append(identity)
            check(disclosed.tiles==expected.tiles and disclosed.objects==expected.objects,"Sparse disclosure equals the previous full-store diff")
            for family in ["tiles_removed","objects_removed"]:
                var actual:Array=disclosed[family].duplicate();actual.sort();expected[family].sort()
                check(actual==expected[family],"Sparse "+family+" equals the exact removed-key set")
            var changed:Array=disclosed.changes.duplicate();changed.sort()
            var expected_changed:Array=expected.tiles.keys();expected_changed.sort()
            check(changed==expected_changed,"Sparse changed tile keys equal the full-store diff")
            for family in ["tiles","objects"]:
                var prior:Dictionary=prior_tiles if family=="tiles" else prior_objects
                var inserted:Array=disclosed[family].keys().filter(func(key):return not prior.has(key))
                var expected_inserted:Array=expected[family].keys().filter(func(key):return not prior.has(key))
                check(inserted==expected_inserted,"Sparse "+family+" insertion order preserves the actual canonical mutation order")
                for key in expected[family]:check(is_same(disclosed[family][key],state[family][key]),"Disclosure owns the exact final "+family+" row reference")
        return result
    if input.has("sensory_rows"):
        var composed=Audience.composed_values(input.sensory_rows)
        return composed if not composed.ok else Audience.fold(state,input.fact,composed.value)
    if input.has("body"):return Reducer.enter_body(state,input.body)
    if input.has("change"):return Reducer.apply_actor_change_fact(state,input.change)
    if input.has("spatial"):return Reducer.apply_player_fact(state,input.spatial)
    if input.has("group"):return Reducer.reduce_lineage(state,input.group)
    var seen:Dictionary=input.seen;var visible=Cells.mask(seen.visible);var contacts={}
    for identity in seen.contacts:contacts[identity]={"position":seen.contacts[identity].position,"visual":seen.contacts[identity].visual,"special_senses":[]}
    state.senses={"position":[0,0],"visible":visible,"seen":visible,"entities":contacts,"objects":{},"effective_light_levels":Cells.values([],{}),"hazardous_cells":Cells.values([],{}),"spatial_effects":{},"paths_dirty":false,"passive_perception":10,"sense_modes_key":[],"sense_modes":[],"visual_access":1,"light_sources":{},"light_source_removals":{}}
    Reducer.clear_unseen_positions(state)
    for identity in contacts:
        if contacts[identity].visual and state.actors.has(identity) and state.actors[identity].present:
            var actor:Dictionary=state.actors[identity].duplicate();actor.last_visual_position=contacts[identity].position;state.actors[identity]=actor
    return Reducer.success(state)
func _document(prefix:String,family:String="")->Dictionary:
    for name in DirAccess.get_files_at(ROOT):
        if name.begins_with(prefix):
            var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+name))
            if family.is_empty() or document.family==family:return document
    return {}
func error_cases()->void:
    var vector=_document("w1_");var initial:Dictionary=vector.initial.duplicate(true);initial.audience.observers.append("00000000-0000-4000-8000-00000000000b")
    check(not Reducer.apply_world_update(initial,vector.steps[0].input.update).ok,"Multi-observer object rows require members")
    var missing=vector.initial.duplicate(true)
    check(not Reducer.apply_world_update(missing,{"occurrence":0,"tile_changes":[{"position":[9,9],"changes":{"walking_cost":2}}]}).ok,"Keyed tile change requires held tile")
    check(not Reducer.apply_world_update(vector.initial.duplicate(true),{"occurrence":0,"objects_removed":[vector.steps[0].input.update.objects.item_uuids[0]]}).ok,"Object removal requires held object")
    var without:Dictionary=vector.steps[0].input.update.duplicate(true);without.object_looks=[]
    check(not Reducer.apply_world_update(vector.initial.duplicate(true),without).ok,"First object requires look")
    var sensory=_document("v8_","sensory");var multi:Dictionary=sensory.initial.duplicate(true);multi.audience.observers.append("00000000-0000-4000-8000-00000000000b")
    check(not fold(multi,sensory.steps[0].input).ok,"Multi-observer contacts require members")
    var apparent=_document("v4_","sensory");var state:Dictionary=apparent.initial.duplicate(true)
    state=fold(state,apparent.steps[0].input).value
    var duplicate:Dictionary=apparent.steps[0].input.duplicate(true);duplicate.fact.initial=false
    check(not fold(state.duplicate(true),duplicate).ok,"Entering an already perceived effect is refused")
    for i in [1,2,3]:state=fold(state,apparent.steps[i].input).value
    check(not fold(state.duplicate(true),apparent.steps[3].input).ok,"Removing an effect twice is refused")
    check(not Cells.row_indices({"start":0,"bits":"Ag=="},1).ok,"Out-of-table RowBits refused")
func transition_cases()->void:
    var document=_document("v1_a_first_record");var state:Dictionary=document.initial.duplicate(true)
    state=fold(state,document.steps[0].input).value
    var actor_id:String=state.actors.keys()[0];var identity="00000000-0000-4000-8000-00000000c001";var member={"condition_uuid":identity,"name":"Test held member","category":"buff","behavior_id":"condition.test","state":null}
    var node={"occurrence":0,"phase":"effect","fact":{"kind":"actor_change","actors":[{"actor_uuid":actor_id,"rows":[{"field":"condition","condition_uuid":identity,"member":member},{"field":"condition","condition_uuid":identity,"consumed":true},{"field":"condition","condition_uuid":identity,"member":member}]}]}}
    var operation={"generation":state.generation,"observer_uuid":state.observer_uuid,"lineages":[{"lineage":0,"root":0,"events":[node],"version_rows":{"occurrences":[0],"lineages":[0]},"start_cursor":0,"end_cursor":1}],"hud":null,"content_additions":[],"combat_log_appends":[]}
    var before:Dictionary=state.duplicate(true);var reduced=Reducer._reduce_operation_retained(state,operation,true)
    check(reduced.ok,"Native condition-row operation folds")
    if not reduced.ok:return
    var rows:Array=reduced.transitions.lineages[0].events[0].condition_rows
    check(rows.size()==3 and rows[0].before==null and rows[0].after==member and rows[1].before==member and rows[1].after==null and rows[2].before==null,"Ordered pre-row members preserve transient removal/reapplication")
    check(state==before,"Retained fold leaves prior state unchanged")
    var next:Dictionary=operation.duplicate(true);next.lineages[0].start_cursor=1;next.lineages[0].end_cursor=2;next.lineages[0].events[0].occurrence=1;next.lineages[0].version_rows={"occurrences":[1],"lineages":[1]};next.lineages[0].events[0].fact.actors[0].rows=[{"field":"condition_duration","key":identity,"duration":null}]
    var duration=Reducer._reduce_operation_retained(reduced.value,next,true)
    check(duration.ok and duration.transitions.lineages[0].events[0].condition_rows.is_empty(),"Duration-only change does not emit application")
    next.lineages[0].events[0].fact.actors.append({"actor_uuid":"not-held","rows":[]})
    var frozen=reduced.value.duplicate(true)
    check(not Reducer._reduce_operation_retained(reduced.value,next,true).ok and reduced.value==frozen,"Rejected multi-actor operation leaves committed state unchanged")
func sparse_disclosure_cases()->void:
    # Private API controls reuse original complete object rows, not new records.
    var vector:Dictionary=_document("w3_")
    var initial_update:Dictionary=vector.steps[0].input.update
    var state:Dictionary=fold(vector.initial.duplicate(true),vector.steps[0].input).value
    var identity:String=initial_update.objects.item_uuids[0]
    var held:Dictionary=state.objects[identity]
    var frozen:PackedByteArray=var_to_bytes(held)
    var replacement:Dictionary={"occurrence":1,"objects_removed":[identity],"objects":initial_update.objects,"contents":initial_update.contents}
    var replaced:Dictionary=fold(state,{"update":replacement})
    check(replaced.ok and not is_same(replaced.value.objects[identity],held),"Same-update object removal/re-add retains the final replacement row")
    check(var_to_bytes(held)==frozen,"Repeated object/container replacements leave the original retained row immutable")
    var disclosed:Dictionary={"sentinel":"unchanged"}
    var refused:Dictionary=Reducer.apply_world_update(state,{"occurrence":2,"objects_removed":[identity,"not-held"]},disclosed)
    check(not refused.ok and disclosed=={"sentinel":"unchanged"},"A refused update does not publish a partial sparse disclosure")

func attack_source_cases()->void:
    var document:Dictionary=_document("v1_a_first_record")
    var state:Dictionary=fold(document.initial.duplicate(true),document.steps[0].input).value
    var actor:String=state.actors.keys()[0]
    for sample in [["equipped","MELEE_MAIN","melee"],["equipped","RANGED_OFF","ranged"],["natural","MELEE_MAIN","none"],["unarmed","MELEE_OFF","none"]]:
        var fact:Dictionary={"kind":"attack","source_entity_uuid":actor,"target_entity_uuid":actor,"weapon_slot":sample[1],"attack_source_kind":sample[0]}
        var result:Dictionary=Reducer.apply_player_fact(state,fact)
        check(result.ok and result.value.actors[actor].visual_loadout.active_weapon_set==sample[2],"Actual AttackFact source selects reference stance without a synthetic weapon_set field: "+sample[0]+" "+sample[1])

func run()->void:
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"index.json"));check(index.fixtures.size()==32,"All 32 reference vector files are included")
    for name in index.fixtures:
        var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+name));var state:Dictionary=document.initial.duplicate(true)
        for i in range(document.steps.size()):
            var step:Dictionary=document.steps[i];var prior=state.duplicate(true);var result=fold(state,step.input)
            check(result.ok,name+" step "+str(i)+" folds "+str(result.get("error",{})))
            if not result.ok:break
            state=result.value;var issue=difference(state,step.expected)
            check(issue.is_empty(),name+" step "+str(i)+" "+issue)
            if step.input.has("group"):
                var group:Dictionary=step.input.group;var branch=Reducer.lineage_branch(group,group.events[group.root]);check(branch.ok and branch.value.events.size()>0,name+" chronological branch preserved")
    error_cases();transition_cases();attack_source_cases();sparse_disclosure_cases()
    var report={"passed":passed,"failures":failures,"vectors":index.fixtures.size()};print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
