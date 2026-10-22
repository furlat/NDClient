extends SceneTree
## Native condition sampling preserves exact owner/lifecycle output while one
## resolved phase description supplies fade timing and occurrence construction.
const Conditions=preload("res://presentation/conditions.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const NativeInputs=preload("res://presentation/native_inputs.gd")
var checks=0
var failures:Array=[]
var cache:Dictionary={}
var oracle:Script
var oracle_cache:Dictionary={}
var native_ids:Array=[]
var timing:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("CONDITION_RESOLUTION_FAIL ",label)

func owner(behavior:String,id:String="one",initial:bool=false)->Dictionary:
    return {"id":id,"actor_uuid":"actor","condition":{"condition_uuid":id,"behavior_id":behavior,"state":{}},
        "start_ms":100.0,"end_ms":INF,"initial":initial,"life_state":"alive"}

func sample_case(owners:Dictionary,at:float,label:String)->Array:
    var actual_owners=owners.duplicate(true)
    var actual=Conditions.samples(actual_owners,at,cache)
    var native_owners=owners.duplicate(true)
    var native=Conditions.native_samples(native_owners,at,cache)
    # Display shows a marker group at a time; preparation holds every candidate.
    check(actual.filter(func(row):return row.get("native_spell",false)).all(func(row):return native.has(row)),label+" displayed native rows are exactly prepared rows")
    check(native.all(func(row):return row.get("native_spell",false)),label+" preparation selects only native rows")
    check(native_owners==actual_owners,label+" native-only sampling preserves retirement")
    if oracle!=null:
        var expected_owners=owners.duplicate(true)
        var expected=oracle.samples(expected_owners,at,oracle_cache)
        check(actual==expected,label+" exact original sampled rows")
        check(actual_owners==expected_owners,label+" exact original owner retirement")
    check(owners.values().all(func(value):return not value.has("native_cue")),label+" source owners remain data without visual cue mutation")
    return actual

## This one independent source is intentionally unavailable: a partial
## missing-anchor refusal is not a delegated output owner or state-only art.
func missing_arcane_anchor(authored:Resource)->void:
    check(authored.id=="condition.spell.arcane_sword" and not authored.play_package_lifecycle \
        and authored.status=="partial" and authored.disposition!="state_only" \
        and authored.lifecycle_selections.is_empty() and authored.effects.is_empty() and authored.responses.is_empty(),
        "Arcane Sword explicitly refuses its unbound independent anchor without claiming a substitute lifecycle owner")
    var live:Dictionary=owner(authored.id);var owners:Dictionary={live.id:live}
    var original:PackedByteArray=var_to_bytes(owners)
    check(Conditions.NativePersistent.lifecycles(live.condition,cache).is_empty() \
        and Conditions.native_samples(owners,300.0,cache).is_empty() and var_to_bytes(owners)==original,
        "Missing Arcane anchor emits no owner lifecycle while preserving the actual condition UUID and clock")
    var selected:Dictionary=Conditions.NativePersistent.Spells.selection("spell.arcane_sword",cache)
    var cues:Array=selected.get("staging",{}).get("cues",[])
    check(selected.get("excluded_cue_indices",[])==[0] and cues.size()==1 \
        and Conditions.NativePersistent.Spells.event_cues(selected).is_empty() \
        and Conditions.NativePersistent.Spells.effect_clips(selected).is_empty(),
        "The finite independent blade cue is explicitly excluded beside the refused owner lifecycle")
    if cues.size()!=1:return
    var refusal:Dictionary=NativeInputs.new().endpoint_packet(null,{}, {"native_cue":cues[0]}, {}, {})
    check(refusal.rows.is_empty() and refusal.reason=="review_endpoint_position_not_bound",
        "Its retained review trajectory cannot supply an actual independent blade endpoint")

func phase_isolation(behavior:String)->void:
    var selections:Array=Conditions.NativePersistent.Effects.conditions(behavior)
    var original=selections.duplicate(true)
    if selections.is_empty():
        var root_source:Resource=load("res://authoring/abilities.tres")
        var authored:Resource=load(root_source.sections.conditions[behavior])
        if behavior=="condition.spell.arcane_sword":
            missing_arcane_anchor(authored);return
        check(not authored.play_package_lifecycle and (authored.disposition=="state_only" or not authored.effects.is_empty() or not authored.responses.is_empty()),behavior+" explicitly delegates package lifecycles to its exact item/finite/native owner")
        return
    var common={"id":"condition:one","actor_uuid":"actor","condition":{"behavior_id":behavior,"state":{}},"start_ms":100.0,"absolute_start_ms":100.0,
        "duration_ms":900.0,"age_ms":200.0,"removal_age_ms":null,"initial":false}
    var first=Conditions.NativePersistent.lifecycle_samples(common,selections,cache)
    var later=common.duplicate();later.id="condition:two";later.actor_uuid="other";later.age_ms=500.0;later.initial=true
    var second=Conditions.NativePersistent.lifecycle_samples(later,selections,cache)
    check(not first.is_empty() and first.size()==second.size(),behavior+" both owner lifetimes yield its package lifecycles")
    check(selections==original,behavior+" occurrence construction leaves the package selections unchanged")
    if first.is_empty() or second.is_empty():return
    check(first[0].id!=second[0].id and first[0].actor_uuid!=second[0].actor_uuid,behavior+" recipients retain independent occurrence identities")
    first[0].native_cue.scale=123.0
    check(second[0].native_cue.scale!=123.0 and selections==original,behavior+" cue mutation cannot alter another owner or the package selection")
    check(Conditions.NativePersistent.lifecycle_state(first[0],.95).phase=="removal" and Conditions.NativePersistent.lifecycle_state(second[0],.4).phase=="sustain",behavior+" each owner's own clock selects its phase")

func actual_shield()->void:
    var index=Fixtures.read("shield","blue")
    check(index.ok,"Actual Blue Shield journal admits")
    if not index.ok:return
    var owners:Dictionary={}
    var witnessed=false
    for item in index.groups:
        for commit in item.group.get("commits",[]):
            var at:float=item.start_ms+commit.at_ms
            Conditions.observe(owners,commit.delta.get("actors",{}),at)
            if not owners.values().any(func(value):return value.condition.behavior_id=="condition.spell.shield"):continue
            var sampled=sample_case(owners,at,"Real Shield after-value at "+str(at))
            witnessed=witnessed or sampled.any(func(value):return value.get("native_spell",false))
    check(witnessed,"Real reaction condition supplies native output through application and removal")

func compare_timing(owners:Dictionary)->void:
    if oracle==null:return
    var old:Array=[];var current:Array=[]
    for iteration in 20:
        var left=owners.duplicate(true);var right=owners.duplicate(true)
        var began=Time.get_ticks_usec();oracle.samples(left,300.0,oracle_cache);old.append(Time.get_ticks_usec()-began)
        began=Time.get_ticks_usec();Conditions.samples(right,300.0,cache);current.append(Time.get_ticks_usec()-began)
    old.sort();current.sort()
    timing={"owners":owners.size(),"iterations":20,"original_median_usec":old[10],"current_median_usec":current[10],
        "scope":"Isolated headless sample construction only; not a native frame-time claim."}

func run()->void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle=load(argument.trim_prefix("--oracle="))
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Conditions.NativePersistent.Effects.INDEX))
    for selection in index.selections:
        for id in selection.get("condition",{}).get("owner_ids",[]):
            if id not in native_ids:native_ids.append(id)
    check(native_ids.size()>=40 and "condition.spell.command.halt" in native_ids and "condition.spell.shield" in native_ids,"Every condition id the package's lifecycles name is covered, including three Command outcomes")
    var mixed:Dictionary={}
    for behavior in native_ids+["condition.hidden","condition.blinded"]:
        var base=owner(behavior)
        var fade=Conditions.fade_ms(base.condition,cache)
        if oracle!=null:check(fade==oracle.fade_ms(base.condition,oracle_cache),behavior+" exact original native/legacy removal duration")
        for at in [100.0,300.0,1900.0]:sample_case({base.id:base},at,behavior+" active "+str(at))
        var initial=base.duplicate(true);initial.initial=true
        sample_case({initial.id:initial},300.0,behavior+" already active")
        var hidden=base.duplicate(true);hidden.condition.state.suppression_provider_uuids=["actual-suppression-owner"]
        check(sample_case({hidden.id:hidden},300.0,behavior+" suppressed").is_empty(),behavior+" suppression emits no condition visuals")
        base.end_ms=1000.0
        for at in [1000.0,1000.0+fade*.5,1000.0+fade]:sample_case({base.id:base},at,behavior+" removal "+str(at))
        var replacement=owner(behavior,"replacement")
        sample_case({base.id:base,replacement.id:replacement},1000.0,behavior+" replaced owner overlaps close")
        mixed[behavior]=owner(behavior,behavior)
        if behavior in native_ids:phase_isolation(behavior)
    sample_case(mixed,300.0,"Mixed native and legacy condition composition")
    compare_timing(mixed)
    actual_shield()
    var report={"checks":checks,"failures":failures,"native_conditions":native_ids,"original_oracle":oracle!=null,"timing":timing,
        "scope":"Exact sampled rows/owner retirement, suppression, apply/hold/remove, replacement, independent native cues and real recorded Shield; no rendering claim."}
    FileAccess.open("res://.runtime/condition-native-resolution-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_NATIVE_RESOLUTION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
