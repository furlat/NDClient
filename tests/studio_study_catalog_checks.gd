extends SceneTree
## Catalog-visible capabilities and authored expectations precede any recording.
const Study=preload("res://studio/study_catalog.gd")
const Cases=preload("res://studio/case_library.gd")
const Audit=preload("res://studio/authoring_audit.gd")
const Recording=preload("res://studio/recording.gd")
const Movement=preload("res://presentation/movement_media.gd")
const NATIVE_SPELLS=["acid_splash","chill_touch","eldritch_blast","fire_bolt","fireball","guiding_bolt","ice_knife","magic_missile","poison_spray","produce_flame","ray_of_frost","scorching_ray","sleep","web","bane","command","mage_armor","sanctuary","shield","shocking_grasp","burning_hands","thunderwave","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike"]
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDY_CATALOG_FAIL ",label)
func run()->void:
    var cache={}
    var records=Cases.read()
    var started=Time.get_ticks_usec()
    var built=Study.build(cache,records)
    var elapsed=(Time.get_ticks_usec()-started)/1000.0
    check(built.errors.is_empty(),"Actual catalog inputs and authored scenario references are valid: "+str(built.errors))
    var index={}
    for capability in built.capabilities:
        check(not index.has(capability.id),"Capability identity is unique: "+capability.id)
        index[capability.id]=capability
        check(capability.kind in ["Action","Spell","Condition","VFX","Mechanic"],"Capability has a defined study family")
        for requirement in capability.requirements:
            check(not requirement.rendered,"Assignments never become rendering evidence")
            check(not requirement.source.is_empty(),"Expected requirement has an inspectable source")
        for scenario in capability.scenarios:
            check(not scenario.sequence.is_empty() and not scenario.expectations.is_empty(),"Authored study has a sequence and expected consequences")
            for binding in scenario.recordings:
                check(binding.available==records.any(func(record):return record.id==binding.case_id),"Only actual case IDs become openable evidence")
                check(binding.has("record")==binding.available,"Unavailable recording is not fabricated")
                if binding.get("evidence")=="partial":check(not binding.get("gaps",[]).is_empty(),"Partial recording preserves the missing comparison or interaction")
    var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Study.CONTENT))
    for entry in snapshot.entries:
        check(index.has(entry.id),"Unrecorded backend capability remains searchable: "+entry.id)
        check(index[entry.id].kind=={"action":"Action","reaction":"Action","spell":"Spell","condition":"Condition"}[entry.kind],"Backend definition family survives inventory merging: "+entry.id)
    var migration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Study.MIGRATION))
    check(built.counts.vfx==migration.assets.size(),"Every passive VFX identity is present without loading its artwork")
    for asset in migration.assets:check(index.has(asset.asset_id),"Unmapped VFX source remains visible: "+asset.asset_id)
    check(index.has("spell.aegis_spark") and index["spell.aegis_spark"].requirements.any(func(row):return row.status=="missing"),"Spell with missing draft is visible without a replay or render implementation")
    check(index["spell.aegis_spark"].scenarios.is_empty(),"No generic invented study fills an unauthored spell sequence")
    for id in NATIVE_SPELLS:
        var capability:Dictionary=index.get("spell."+id,{})
        check(capability.get("kind")=="Spell","Native recording retains the actual spell capability: "+id)
        var scenarios:Array=capability.get("scenarios",[]).filter(func(row):return row.id=="native-spell-"+id)
        check(scenarios.size()==1,"Exactly one selected real spell sequence is discoverable: "+id)
        if scenarios.size()!=1:continue
        var scenario:Dictionary=scenarios[0]
        check(scenario.source.begins_with(Study.SPELL_CASES+":/cases/"),"Recorded sequence has its actual capture inventory source: "+id)
        check(scenario.recordings.size()==1 and scenario.recordings[0].available,"Spell study has an openable exact recording: "+id)
        if scenario.recordings.size()==1 and scenario.recordings[0].available:
            var record:Dictionary=scenario.recordings[0].record
            check(record.id=="native-spell-"+id and record.spell_id==id,"Open recording cannot fall back to another spell: "+id)
            check(record.perspectives.size()==2,"Both independently recorded factions are selectable: "+id)
        check(scenario.coverage.native_render=="not_assessed_by_this_catalog","Recorded facts do not claim rendered qualification: "+id)
    for id in ["aid","bless","false_life","sacred_flame"]:
        check(index.has("spell."+id),"Deferred spell remains in the capability denominator: "+id)
        check(not index.get("spell."+id,{}).get("scenarios",[]).any(func(row):return row.id=="native-spell-"+id),"Deferred spell receives no new completed batch study: "+id)
    var expected_fields={}
    for id in ["action.move","action.jump"]:
        for requirement in index[id].requirements:
            if requirement.has("when_conditions"):expected_fields[requirement.source]=true
    check(expected_fields.size()==12,"All twelve authored conditional movement source fields remain discoverable")
    var dash:Dictionary=index["condition.dashing"]
    check(dash.indicator_assignments.size()==6,"Dash condition follows its actual conditional movement owners")
    check(not dash.requirements.any(func(row):return row.get("reason")=="persistent_visual_assignment_missing"),"Existing Dash trail is not mislabeled missing authoring")
    check(dash.requirements.any(func(row):return row.get("reason")=="authored_movement_media_not_implemented"),"Unimplemented original trail stays an explicit renderer gap")
    var jumper={"conditions":[{"behavior_id":"condition.spell.jump"}]}
    check(Movement.selected(jumper,"connector_transfer",cache).is_empty() and Movement.selected(jumper,"forced",cache).is_empty(),"Non-jump transfers do not inherit jump expectations")
    for phase in [{"from":0.0,"to":.25},{"from":.25,"to":.5},{"from":.75,"to":1.0}]:
        var selected=Movement.selected(jumper,"direct_arc",cache,phase)
        check(selected.filter(func(row):return row.media.role=="takeoff").size()==(2 if phase.from==0 else 0),"Takeoff belongs only to first disclosed jump edge")
        check(selected.filter(func(row):return row.media.role=="landing").size()==(2 if phase.to==1 else 0),"Landing belongs only to final disclosed jump edge")
        check(selected.filter(func(row):return row.media.role=="source_vfx").size()==2,"Flight expectation remains during each admitted airborne edge")
    var journal=Recording.read("res://.runtime/studio-cases/dash-seed3/amber/journal")
    check(journal.ok,"Actual server Dash journal still admits after tooling changes")
    var missing=[]
    if journal.ok:
        for item in journal.groups:
            for event in item.group.events:
                for component in event.components:
                    if component.get("reason")=="authored_movement_media_not_implemented":missing.append(component)
        check(not missing.is_empty(),"Actual Dash occurrence exposes missing original trails instead of false green")
    var without_records=Study.build(cache,[])
    check(without_records.capabilities.size()==built.capabilities.size(),"Removing all recordings cannot remove any capability")
    check(without_records.counts.scenarios==built.counts.scenarios,"Removing recording files cannot remove the authored study sequences")
    check(without_records.counts.recorded_scenarios==0 and without_records.counts.partial_scenarios==0,"Unrecorded authored studies stay visible without claiming coverage")
    check(without_records.capabilities.all(func(capability):return capability.scenarios.all(func(scenario):return scenario.recordings.all(func(binding):return not binding.available))),"No implicit CaseLibrary lookup bypasses the supplied recording boundary")
    var result={"checks":checks,"failures":failures,"counts":built.counts,"build_ms":elapsed,"actual_dash_missing_components":missing.size(),"scope":built.scope}
    FileAccess.open("res://generated/studio_study_catalog_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_STUDY_CATALOG ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
