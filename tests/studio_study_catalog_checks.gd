extends SceneTree
## Catalog-visible capabilities and authored expectations precede any recording.
const Study=preload("res://studio/study_catalog.gd")
const Cases=preload("res://studio/case_library.gd")
const Audit=preload("res://studio/authoring_audit.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
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
            check(not requirement.source.is_empty(),"Expected requirement has an inspectable source: "+capability.id+" / "+str(requirement))
        for scenario in capability.scenarios:
            check(not scenario.sequence.is_empty() and not scenario.expectations.is_empty(),"Authored study has a sequence and expected consequences")
            for binding in scenario.recordings:
                check(binding.available==records.any(func(record):return record.id==binding.case_id),"Only actual case IDs become openable evidence")
                check(binding.has("record")==binding.available,"Unavailable recording is not fabricated")
                check(binding.ready==records.any(func(record):return record.id==binding.case_id and record.ready),"Referenced but failed/stale originals do not become playable studies")
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
    # The active Studio library joins current capabilities with original journals
    # under their exact current or archived producer contract. Old generated
    # native-spell-* IDs are not a second playback library or recording fallback.
    var current:Dictionary=Cases.catalog()
    var original_records:PackedByteArray=var_to_bytes(current.records)
    Study.join_library(current,built)
    check(var_to_bytes(current.records)==original_records,"Joining authored methods/studies does not change recording readiness, provenance or output witnesses")
    check(current.by_key["action:action.attack"].scenarios.any(func(scenario):return scenario.id=="base.AT01" \
        and scenario.label=="Nonlethal melee hit" and scenario.recordings.any(func(binding):return binding.case_id=="action.class.fighter.action_surge/extra_attacks" and binding.ready)),
        "The main Library exposes the exact authored nonlethal Attack study and its original first-attack binding")
    check(not current.by_key["action:action.class.fighter.action_surge"].scenarios.any(func(scenario):return scenario.id=="base.AT01"),
        "An original containing later Action Surge does not give its ordinary first-attack study extra-attack coverage")
    check(current.by_key["action:action.move"].scenarios.any(func(scenario):return scenario.id=="base.MV01" and scenario.recordings.any(func(binding):return binding.case_id=="walk_diagonal-seed3-v2" and not binding.available and not binding.ready)),"Absent historical movement originals stay named and unavailable beside current actual cases")
    check(not current.by_key["spell:spell.fireball"].requirements.is_empty() \
        and current.by_key["spell:spell.fireball"].requirements.all(func(requirement):return not requirement.rendered),"Current selected spell methods are visible in the main Library without rendered promotion")
    var goblin:Dictionary=current.by_key["creature:creature.goblin"]
    check(goblin.requirements.any(func(requirement):return requirement.source==goblin.source_path),"An actual creature's existing owner-prefixed methods join through its exact selected Resource")
    var wire_fields:Array=["protocol_version","player_schema_version","schema_digest"]
    var supported_contracts:Array=[Cases._read("res://sdk/protocol-identity.json")]
    for paths in Cases.Journal.Protocol.RECORDED_CONTRACTS:supported_contracts.append(Cases._read(paths[1]))
    for id in NATIVE_SPELLS:
        var key:String="spell:spell."+id
        check(current.by_key.has(key),"Native recording retains the actual current spell capability: "+id)
        if not current.by_key.has(key):continue
        var capability:Dictionary=current.by_key[key]
        var sequences:Array=capability.cases.filter(func(row):return "spell."+id in row.subjects.get("spell",[]) and row.ready)
        check(not sequences.is_empty(),"Each previously selected spell retains an openable real study under an admitted producer contract: "+id)
        var identities:Dictionary={}
        for record in sequences:
            check(not identities.has(record.id),"Real study identity appears once for its exact capability: "+id)
            identities[record.id]=true
            var original:Dictionary=Cases._read(record.descriptor)
            var expected_seats:Array=["party"] if original.has("player_builds_source") else ["amber","blue"]
            check(record.perspectives.map(func(view):return view.id)==expected_seats,"Every actual independent recorded seat remains selectable: "+id+" / "+record.id)
            for view in record.perspectives:
                var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(view.journal.path_join("0000000000000000.json")))
                check(wire_fields.all(func(field):return packet.protocol.has(field) \
                    and packet.protocol[field]==record.capture_engine.get(field)),"Original initialization matches its recorded producer contract: "+id+" / "+record.id+" / "+view.id)
                check(supported_contracts.any(func(identity):return wire_fields.all(func(field):return packet.protocol.has(field) \
                    and packet.protocol[field]==identity.get(field))),"Original study uses an exact supported current or archived contract: "+id+" / "+record.id+" / "+view.id)
        check(sequences.any(func(record):return record.perspectives.map(func(view):return view.id)==["amber","blue"]),"An original independent Amber/Blue spell study remains selectable: "+id)
        check(capability.scenario_status=="recorded","Real admitted spell study reports its scenario coverage: "+id)
        if capability.cases.all(func(row):return row.get("presentation",{}).is_empty()):
            var witnessed:bool=not capability.get("output_witnesses",[]).is_empty()
            check(capability.presentation_status==("evidence_available" if witnessed else "not_assessed"),"Recording and saved output witnesses remain distinct coverage facts: "+id)
            check(capability.presentation_status not in ["passed","accepted"],"Saved witness presence cannot qualify current output or approve art: "+id)
    for id in ["aid","bless","false_life","sacred_flame"]:
        var capability:Dictionary=current.by_key.get("spell:spell."+id,{})
        check(not capability.is_empty() and capability.scenario_status=="recorded","Formerly deferred spell remains recorded and discoverable: "+id)
        check(capability.approval_status=="needs_review","An available real recording cannot approve current artwork: "+id)
    var expected_fields={}
    for id in ["action.move","action.jump"]:
        for requirement in index[id].requirements:
            if requirement.has("when_conditions"):expected_fields[requirement.source]=true
    check(expected_fields.size()==12,"All twelve authored conditional movement source fields remain discoverable")
    var dash:Dictionary=index["condition.dashing"]
    check(dash.indicator_assignments.size()==6,"Dash condition follows its actual conditional movement owners")
    check(not dash.requirements.any(func(row):return row.get("reason")=="persistent_visual_assignment_missing"),"Existing Dash trail is not mislabeled missing authoring")
    var dash_movement:Array=dash.requirements.filter(func(row):return row.get("phase")=="movement")
    check(dash_movement.size()==6 and dash_movement.all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered and not row.get("native_sources",[]).is_empty()),"All six declared Dash trails have selected shared native movement sources without claiming rendered output")
    var jumper={"conditions":[{"behavior_id":"condition.spell.jump"}]}
    check(Movement.selected(jumper,"connector_transfer",cache).is_empty() and Movement.selected(jumper,"forced",cache).is_empty(),"Non-jump transfers do not inherit jump expectations")
    for phase in [{"from":0.0,"to":.25},{"from":.25,"to":.5},{"from":.75,"to":1.0}]:
        var selected=Movement.selected(jumper,"direct_arc",cache,phase)
        check(selected.filter(func(row):return row.media.role=="takeoff").size()==(2 if phase.from==0 else 0),"Takeoff belongs only to first disclosed jump edge")
        check(selected.filter(func(row):return row.media.role=="landing").size()==(2 if phase.to==1 else 0),"Landing belongs only to final disclosed jump edge")
        check(selected.filter(func(row):return row.media.role=="source_vfx").size()==2,"Flight expectation remains during each admitted airborne edge")
    var journal=Fixtures.read("dash")
    check(journal.ok,"Actual server Dash journal still admits after tooling changes")
    var missing:Array=[];var native_movement:Array=[]
    if journal.ok:
        for item in journal.groups:
            for component in item.group.components:
                if component.get("reason")=="authored_movement_media_not_implemented":missing.append(component)
                if not component.get("native_cue",{}).get("movement",{}).is_empty():native_movement.append(component)
        check(missing.is_empty(),"Actual Dash no longer reports the retired unimplemented trail adapter")
        check(not native_movement.is_empty(),"Actual Dash emits selected native movement occurrences")
        for component in native_movement:
            check("condition.dashing" in component.native_cue.movement.when_conditions and not component.authored_media.is_empty(),"Actual native movement retains the authored Dash predicate and legacy media delegation")
            check(not component.body_track_id.is_empty() and component.source_track.actor_uuid==component.actor_uuid and component.source_track.get("motion",false),"Native movement follows the same actual scheduled body track and owner")
    var without_records=Study.build(cache,[])
    check(without_records.capabilities.size()==built.capabilities.size(),"Removing all recordings cannot remove any capability")
    check(without_records.counts.scenarios==built.counts.scenarios,"Removing recording files cannot remove the authored study sequences")
    check(without_records.counts.recorded_scenarios==0 and without_records.counts.partial_scenarios==0,"Unrecorded authored studies stay visible without claiming coverage")
    check(without_records.capabilities.all(func(capability):return capability.scenarios.all(func(scenario):return scenario.recordings.all(func(binding):return not binding.available))),"No implicit CaseLibrary lookup bypasses the supplied recording boundary")
    var result={"checks":checks,"failures":failures,"counts":built.counts,"build_ms":elapsed,"actual_dash_missing_components":missing.size(),"actual_dash_native_components":native_movement.size(),"scope":built.scope}
    FileAccess.open("res://generated/studio_study_catalog_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_STUDY_CATALOG ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
