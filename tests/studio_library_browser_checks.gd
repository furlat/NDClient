extends SceneTree
## Capability discovery and case selection over the single authoring/current-recording join.
const Library=preload("res://studio/case_library.gd")
const WindowScript=preload("res://studio/study_library.gd")
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
    if value:passed+=1
    else:failures.append(message);print("FAIL "+message)
func run()->void:
    var identity={"commit":"current","protocol_version":1,"player_schema_version":16,"schema_digest":"current-schema"}
    var snapshot={"header":identity,"ids":{"spell":{"spell.fireball":{"level":3,"school":"evocation"},"spell.false_life":{"level":1,"school":"necromancy"}},"condition":{"condition.hidden":{"family":"core"}},"creature":{"creature.goblin":{}},"damage_type":{"Fire":{}}}}
    var coverage={"coverage":{"spell":{"spell.fireball":"ready","spell.false_life":"partial"},"condition":{"condition.hidden":"missing"}}}
    var records={"version":1,"engine":identity,"cases":[{"id":"fireball/hit","title":"Fireball hit","kind":"spell","subjects":{"spell":["spell.fireball"],"creature":["creature.goblin"]},"journals":{"amber":"res://test/amber","blue":"res://test/blue"},"status":"recorded","studio_checked":false,"errors":[],"moments":[{"sequence":3,"occurrence":5,"label":"impact"}]},{"id":"hide/fail","title":"Hide failed","kind":"condition","subjects":{"condition":["condition.hidden"]},"journals":{},"status":"failed","reason":"Real recorder failure"},{"id":"old","title":"Old False Life","kind":"spell","subjects":{"spell":["spell.false_life"]},"journals":{"amber":"res://test/old"},"status":"recorded","engine":{"commit":"old"}}]}
    var report=Library.build(snapshot,coverage,records,false);var keys={}
    for entry in report.entries:keys[entry.key]=true
    check(report.entries.size()==5 and keys.size()==5,"Every server ID appears once, including rule enums")
    check(report.by_key["spell:spell.fireball"].cases[0].id==report.by_key["creature:creature.goblin"].cases[0].id,"One case is reachable from every subject")
    var fire:Dictionary=report.by_key["spell:spell.fireball"]
    check(fire.scenario_status=="recorded" and fire.source_status=="ready" and fire.presentation_status=="not_assessed" and fire.approval_status=="needs_review","Recording and source presence do not claim provider or visual success")
    check(report.by_key["spell:spell.false_life"].scenario_status=="stale" and report.by_key["spell:spell.false_life"].approval_status=="needs_review","Stale recordings remain explicit and all artwork awaits review")
    check(report.by_key["condition:condition.hidden"].scenario_status=="failed" and report.by_key["condition:condition.hidden"].source_status=="missing","Recorder and art failures remain separate")
    check(report.by_key["damage_type:Fire"].scenario_status=="missing","An ID without a case stays discoverable")
    check(fire.cases[0].perspectives.size()==2 and Library.scenario(fire.cases[0]).moments[0].occurrence==5,"Both original factions and native moments survive browser selection")
    var sources={"spell":{"spell.fireball":{"source_path":"res://authoring/abilities/spells/spell.fireball.tres"}},
        "action":{"action.class.fighter.action_surge":{"source_path":"res://authoring/abilities/actions/action.class.fighter.action_surge.tres"}},
        "class_feature":{"class_feature.fighter.indomitable":{"source_path":"res://authoring/abilities/actions/class_feature.fighter.indomitable.tres"}}}
    var joined=Library.build(snapshot,coverage,records,false,sources)
    check(joined.entries.size()==7 and joined.by_key["spell:spell.fireball"].cases.size()==1,"Typed sources augment the inventory without duplicating listed IDs or their cases")
    var source_only:Dictionary=joined.by_key["action:action.class.fighter.action_surge"]
    check(source_only.inventory_origin=="typed_source" and source_only.engine_inventory=="not_listed" and source_only.runtime_availability=="unknown","A typed class action stays discoverable without claiming server availability or retirement")
    check(source_only.scenario_status=="missing" and source_only.presentation_status=="not_assessed" and source_only.source_path==sources.action[source_only.id].source_path,"Source presence creates neither a recording nor render proof")
    check(joined.by_key["class_feature:class_feature.fighter.indomitable"].category=="Actions","Class feature sources belong in the Actions browser")
    var receipts={"cases":{"fireball/hit":[{"kind":"native_replay","process_exit":0,"process_status":"passed","report":"res://native/actual.json","factory_version":"earlier-package","package_scope":"historical_package","status":"replay_checks_passed","qualifies":"This exact replay only"},{"kind":"audio_playback","process_exit":0,"process_status":"passed","report":"res://native/audio.json","status":"playback_observed","rows":{"footstep":{"starts":1}}}],"old":[{"kind":"recording_reader","report":"res://reader/report.json","status":"passed"}]}}
    var witnessed=Library.build(snapshot,coverage,records,false,{},receipts)
    var witness_fire:Dictionary=witnessed.by_key["spell:spell.fireball"]
    check(witness_fire.presentation_status=="evidence_available" and witness_fire.output_witnesses.size()==2,"Actual native/audio receipts are linked separately from unchecked recorder flags")
    check(not witness_fire.cases[0].studio_checked and witness_fire.approval_status=="needs_review","Saved evidence changes neither recorder qualification nor human visual approval")
    check(witness_fire.witnesses[0].package_scope=="historical_package","A historical native receipt retains its original package scope")
    check(witnessed.by_key["spell:spell.false_life"].presentation_status=="not_assessed","Reader safety alone cannot qualify output")
    check(Library.matches(witness_fire,"Fireball hit","Spells","evidence"),"Search includes actual scenario labels and output filter reaches their capability")
    check(not Library.matches(witness_fire,"","Conditions") and not Library.matches(witness_fire,"","","unwitnessed"),"Category and output-gap filters retain separate facts")
    check(not Library.matches(witnessed.by_key["spell:spell.false_life"],"","","rejected") and Library.matches(witnessed.by_key["spell:spell.false_life"],"","","needs_review") and Library.matches(witnessed.by_key["condition:condition.hidden"],"recorder failure","","recording_failure"),"All current artwork awaits human review independently of actual recorder failures")
    var scoped_receipts={"cases":{"fireball/hit":[
        {"kind":"native_replay","process_exit":0,"process_status":"passed","report":"res://native/current.json","engine":identity,"factory_version":"actual-package","package_scope":"historical_package"},
        {"kind":"native_replay","process_exit":0,"process_status":"passed","report":"res://native/expected-only.json","expected_engine":identity,"factory_version":"actual-package","package_scope":"current_package"},
        {"kind":"native_replay","process_exit":0,"process_status":"passed","report":"res://native/predecessor.json","engine":identity,"factory_version":"predecessor","package_scope":"current_package"},
        {"kind":"audio_playback","process_exit":0,"process_status":"passed","report":"res://native/silent.json","engine":identity,"factory_version":"actual-package","status":"playback_observed","counters":{"started":0},"pcm_frames":0,"pcm_peak":0}]}}
    var scoped:Dictionary=Library.build(snapshot,coverage,records,false,{},scoped_receipts,"actual-package").by_key["spell:spell.fireball"]
    check(scoped.output_witnesses.size()==3 and scoped.audio_witnesses.size()==1 and scoped.audio_witnesses[0].kind=="audio_transport" and scoped.audio_witnesses[0].reported_kind=="audio_playback","Zero-start/no-PCM audio stays inspectable transport rather than output evidence")
    check(scoped.current_output_witnesses.size()==1 and scoped.current_output_witnesses[0].report=="res://native/current.json","Only the actual matching engine and package qualify current evidence scope")
    check(scoped.witnesses[1].engine_scope=="engine_identity_not_recorded" and scoped.witnesses[1].expected_engine==identity,"A declared expected engine cannot become actual capture provenance")
    check(scoped.witnesses[0].package_scope_at_join=="historical_package" and scoped.witnesses[0].package_scope=="current_package" and scoped.witnesses[2].package_scope_at_join=="current_package" and scoped.witnesses[2].package_scope=="historical_package","Browser recomputes current package scope while retaining each original join classification")
    check(scoped.approval_status=="needs_review" and Library.matches(scoped,"","","current_evidence") and Library.matches(scoped,"","","historical_evidence"),"Current and historical evidence remain reachable without approving artwork")
    var payload:Dictionary={"actual-owner":{"actor":"actual-recipient","source":"exact-source-property"}}
    var raw_control:Dictionary={"kind":"native_replay","engine":identity,"factory_version":"actual-package",
        "status":"replay_checks_passed","report":"raw-without-runner.json","observed_grant_sources":payload,
        "observed_body_geometry":payload,"observed_action_bodies":payload}
    var raw_receipts:Dictionary={"cases":{"fireball/hit":[raw_control]}}
    var unqualified:Dictionary=Library.build(snapshot,coverage,records,false,{},raw_receipts,"actual-package").by_key["spell:spell.fireball"]
    check(unqualified.output_witnesses.is_empty() and unqualified.witnesses.size()==1 \
        and unqualified.witnesses[0].observed_grant_sources==payload and unqualified.witnesses[0].observed_body_geometry==payload \
        and unqualified.witnesses[0].observed_action_bodies==payload \
        and unqualified.witnesses[0].status=="process_exit_not_recorded" \
        and unqualified.witnesses[0].reported_status=="replay_checks_passed","Raw positive markers retain exact body/grant/action observations but cannot qualify process output without an actual exit")
    var failed_control:Dictionary=raw_control.duplicate(true);failed_control.process_exit=1;failed_control.process_status="failed"
    raw_receipts.cases["fireball/hit"]=[failed_control]
    var failed_output:Dictionary=Library.build(snapshot,coverage,records,false,{},raw_receipts,"actual-package").by_key["spell:spell.fireball"]
    check(failed_output.output_witnesses.is_empty() and failed_output.witnesses[0].process_exit==1 \
        and failed_output.witnesses[0].status=="process_failed" \
        and failed_output.witnesses[0].reported_status=="replay_checks_passed","A preserved assertion marker cannot erase an actual failed native process")
    var partial_control:Dictionary=raw_control.duplicate(true);partial_control.process_exit=0;partial_control.process_status="passed"
    partial_control.engine={"commit":identity.commit};raw_receipts.cases["fireball/hit"]=[partial_control]
    var partial_output:Dictionary=Library.build(snapshot,coverage,records,false,{},raw_receipts,"actual-package").by_key["spell:spell.fireball"]
    check(partial_output.output_witnesses.size()==1 and partial_output.current_output_witnesses.is_empty() \
        and partial_output.witnesses[0].engine_scope=="partial_engine_identity" \
        and partial_output.witnesses[0].engine=={"commit":identity.commit},"Actual zero exit and producer commit remain partial identity without invented protocol/schema/digest")
    partial_output.witnesses[0].observed_grant_sources.clear()
    check(raw_control.observed_grant_sources==payload and not payload.is_empty(),"Browser inspection cannot mutate the retained raw source payload")
    var predecessor:Dictionary=identity.duplicate();predecessor.commit="predecessor"
    var compatible_records:Dictionary=records.duplicate(true);compatible_records.cases[0].engine=predecessor
    var immutable_compatible:PackedByteArray=var_to_bytes(compatible_records)
    var historical_receipts={"cases":{"fireball/hit":[{"kind":"native_replay","process_exit":0,"process_status":"passed","engine":predecessor,"factory_version":"actual-package","report":"res://native/same-wire-historical.json"}]}}
    var compatible:Dictionary=Library.build(snapshot,coverage,compatible_records,false,{},historical_receipts,"actual-package").by_key["spell:spell.fireball"]
    check(compatible.cases[0].ready and compatible.cases[0].scenario_status=="recorded" and compatible.cases[0].recording_status=="recorded","A genuine successful same-wire predecessor remains eligible for ordinary playback")
    check(compatible.cases[0].capture_engine==predecessor and compatible.cases[0].engine_status=="historical_or_unverified" and var_to_bytes(compatible_records)==immutable_compatible,"Playback eligibility preserves the actual historical engine and original metadata")
    check(compatible.current_output_witnesses.is_empty() and compatible.historical_output_witnesses.size()==1 and compatible.approval_status=="needs_review","Same-wire historical playback cannot qualify current output or approve artwork")
    for mismatch in [{"protocol_version":2},{"player_schema_version":15},{"schema_digest":"foreign"},{"schema_digest":null}]:
        var incompatible:Dictionary=compatible_records.duplicate(true)
        incompatible.cases[0].engine.merge(mismatch,true)
        var refused:Dictionary=Library.build(snapshot,coverage,incompatible,false).by_key["spell:spell.fireball"].cases[0]
        check(not refused.ready and refused.scenario_status=="stale" and refused.capture_engine==incompatible.cases[0].engine,"Different or missing actual wire identity remains refused: "+str(mismatch))
    var failed_compatible:Dictionary=compatible_records.duplicate(true)
    failed_compatible.cases[0].status="failed";failed_compatible.cases[0].reason="Actual failed capture control"
    var failed_same_wire:Dictionary=Library.build(snapshot,coverage,failed_compatible,false).by_key["spell:spell.fireball"].cases[0]
    check(not failed_same_wire.ready and failed_same_wire.scenario_status=="failed" and failed_same_wire.capture_engine==predecessor,"A real same-wire recorder failure never becomes playback-ready")
    var event={"sequence":3,"event_uuid":"5","lineage_uuid":"2","versions":[{"occurrence":4}]}
    var moments=Library.resolve_moments({"rows":[{"id":"3:5","kind":"event","event":event,"start_ms":250}]},[{"sequence":3,"occurrence":5,"lineage":2},{"sequence":3,"occurrence":4,"lineage":2},{"sequence":4,"occurrence":5,"lineage":2},{"sequence":3,"occurrence":5,"lineage":9}])
    check(moments[0].available and moments[0].at_ms==250 and moments[0].row_id=="3:5","A native moment resolves its exact packet occurrence and lineage")
    check(moments[1].available,"A retained occurrence version resolves the same actual event")
    check(not moments[2].available and not moments[3].available,"Missing or wrong-lineage moments never retarget to another event")
    var window=WindowScript.new();root.add_child(window);window.report=report;window._refresh()
    check(window.tree.columns==5 and window.tree.get_column_title(3)=="Output evidence" and window.tree.get_column_title(4)=="Art review","Browser exposes source, scenario, actual output evidence and review as separate visible columns")
    window.report=witnessed;window.status_picker.select(4);window._refresh()
    check(window.summary.text.begins_with("2 / 5 capabilities") and window.summary.text.contains("2 with linked evidence"),"Output filter and compact counts include each multi-subject capability without duplicating IDs")
    window.report=report;window.status_picker.select(0);window._refresh()
    var capability=window.tree.get_root().get_first_child().get_first_child().get_first_child()
    var emitted:Array=[];window.recording_selected.connect(func(entry,scenario,record):emitted.append({"entry":entry.id,"scenario":scenario.id,"record":record.id}))
    # Directly select the actual Fireball tree row by its data, independent of group layout.
    var pending:Array=[window.tree.get_root()]
    while not pending.is_empty():
        var item:TreeItem=pending.pop_back();var data:Variant=item.get_metadata(0)
        if data is Dictionary and data.capability.id=="spell.fireball" and data.case.is_empty():item.select(0);break
        var child=item.get_first_child()
        while child!=null:pending.append(child);child=child.get_next()
    window._selected()
    check(emitted.size()>=1 and emitted[-1].entry=="spell.fireball" and emitted[-1].record=="fireball/hit","Selecting a capability emits its actual recording immediately")
    var variants:Dictionary=records.duplicate(true)
    var alternate:Dictionary=variants.cases[0].duplicate(true);alternate.id="fireball/alternate";alternate.title="Fireball alternate";variants.cases.append(alternate)
    window.report=Library.build(snapshot,coverage,variants,false,sources)
    var emitted_before:int=emitted.size();var unavailable_events:Array=[]
    window.recording_unavailable.connect(func():unavailable_events.append(true))
    window._refresh("spell.fireball","fireball/alternate")
    check(window.tree.get_selected().get_metadata(0).case.id==alternate.id and window.recording_options.size()==1 and window.recording_options[0].id==alternate.id,"Reopening the library restores the exact active scenario rather than the first case")
    check(not window.open_button.disabled and window.detail.text.contains(sources.spell["spell.fireball"].source_path),"Restored selection immediately exposes its real source and playback controls")
    check(emitted.size()==emitted_before and unavailable_events.is_empty(),"Restoring library focus inspects details without playback or cancellation side effects")
    window.search.text="Fireball";window._refresh()
    check(window.tree.get_selected().get_metadata(0).case.id==alternate.id and emitted.size()==emitted_before,"Filtering preserves the exact retained scenario without replaying it")
    var component:Dictionary={"native_clip":{"id":"test.inspector","inputs":[],"input_setters":{},"approaches":[{"id":"recorded-0","kind":"recorded","path":"res://test/default.res"},{"id":"actual-authored","kind":"native","path":"res://test/actual.gd","source_phase":"res://test/actual.tres"}]},"native_cue":{"approach":"actual-authored"}}
    var immutable:PackedByteArray=var_to_bytes(component)
    var lines:Array=Studio.effect_lines(component)
    check(lines.any(func(line):return "actual-authored" in line and "res://test/actual.gd" in line) and lines.has("Source phase: res://test/actual.tres"),"Human source inspector names the exact occurrence approach and phase used by the renderer")
    check(not lines.any(func(line):return "res://test/default.res" in line) and var_to_bytes(component)==immutable,"Inspector cannot describe the default donor or mutate the authored occurrence")
    component.native_cue.approach="absent-authored"
    check(Studio.effect_lines(component).any(func(line):return "no approach absent-authored" in line),"Missing explicit authored approach retains its actual unavailable reason")
    window.free()
    var actual=Library.catalog();var expected=0
    for kind in actual.counts:expected+=actual.counts[kind]
    check(actual.entries.size()>=expected and expected>1000,"Current official catalog is fully discoverable")
    check(actual.by_key.has("action:action.class.fighter.action_surge") and actual.by_key["action:action.class.fighter.action_surge"].inventory_origin=="typed_source","Current dynamic Action Surge source is no longer hidden by snapshot-only discovery")
    check(actual.by_key.has("class_feature:class_feature.fighter.indomitable"),"Current dynamic class-feature sources are discoverable")
    check(actual.by_key["spell:spell.false_life"].source_path=="res://authoring/abilities/spells/spell.false_life.tres","A retained condition alias cannot replace the actual spell's browser source")
    var preserved:Dictionary=Fixtures.failed_original("res://tests/fixtures/schema16/event-families/spell.dragons_breath__fire_grant_exhale_end")
    var failed:Array=[] if preserved.is_empty() else [preserved]
    check(failed.size()==1 and not preserved.ready and preserved.scenario_status=="failed" and preserved.engine_status=="historical_or_unverified","Exact preserved failed Dragon original retains genuine failure and historical capture identity independently of current refresh")
    if failed.size()==1:
        var original:PackedByteArray=var_to_bytes(failed[0])
        var prefix:Dictionary=Library.failed_prefix(failed[0])
        check(prefix.available and prefix.perspectives.size()==2 and prefix.errors.is_empty(),"Both real failed Dragon prefixes have currently admitted initialization")
        check(not failed[0].ready and failed[0].scenario_status=="failed" and var_to_bytes(failed[0])==original,"Prefix admission does not change failure/ready/qualification")
        var missing:Dictionary=failed[0].duplicate(true)
        missing.journals={"amber":"res://.runtime/absent-prefix-control"};missing.perspectives=[]
        var unavailable:Dictionary=Library.failed_prefix(missing)
        check(not unavailable.available and unavailable.errors.size()==1 and str(unavailable.errors[0]).contains("Initialization is unavailable"),"A missing initialization retains its exact unavailable reason")
    print(JSON.stringify({"passed":passed,"failures":failures,"current_ids":expected,"current_cases":actual.records.size()}));quit(0 if failures.is_empty() else 1)
