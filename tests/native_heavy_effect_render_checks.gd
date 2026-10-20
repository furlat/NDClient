extends "res://tests/studio_spell_batch_checks.gd"
## The ordinary Studio/Play inspection path, with five explicit production
## selections. The Factory's isolated smoke is not gameplay evidence.
const HEAVY_APPROACH="runtime-prepared-heavy-effects-20261020"
const HEAVY_SPELLS=["conjure_elemental","summon_dragon","planar_ally","ice_storm","acid_arrow"]
const HEAVY_CLIPS=["high-level-22/summon-manifestation/air_elemental/admitted","high-level-22/summon-manifestation/draconic_spirit/admitted",
    "high-level-22/summon-manifestation/deva/admitted","assembled/ice_storm_native","bg3-36/acid-arrow/delivery"]
var actual_sources:Array=[]
var qualified_clips:Array=HEAVY_CLIPS

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only-case="):only_case=argument.trim_prefix("--only-case=")
    if not only_case.is_empty():
        var selected:int=HEAVY_SPELLS.find(only_case.get_slice("/",0).trim_prefix("spell."))
        qualified_clips=[HEAVY_CLIPS[selected]] if selected>=0 else []
    source_filter=HEAVY_CLIPS
    sample_fractions=[.10,.35,.65,.10] # Real backward reconstruction and loop.
    check(DisplayServer.get_name()!="headless","Heavy consumer gate requires actual Forward+ output")
    if DisplayServer.get_name()=="headless":finish();return
    var records:Array=Library.read()
    for spell in HEAVY_SPELLS:
        var id:String="spell."+spell+"/baseline"
        if not only_case.is_empty() and only_case!=id:continue
        var matches:Array=records.filter(func(record):return record.id==id)
        check(matches.size()==1,"One existing original for "+id)
        if matches.size()!=1:continue
        var record:Dictionary=matches[0]
        check(record.ready and record.perspectives.size()==2,id+": two independent original streams are available")
        if not record.ready:continue
        selected_cases.append(id)
        for perspective in record.perspectives:await inspect_case(record,perspective,"spell."+spell)
    check(selected_cases.size()==(HEAVY_SPELLS.size() if only_case.is_empty() else 1),"Every requested production consumer was exercised")
    check(not qualified_clips.is_empty() and qualified_clips.all(func(id):return actual_sources.any(func(row):return row.clip_id==id)),"Every selected source was actually constructed through Play")
    finish()

func readiness_diagnostic(world:Node,component_id:String)->Dictionary:
    var result:Dictionary=super.readiness_diagnostic(world,component_id)
    var native:RefCounted=world.component_renderer.native_spells
    result.preparation_budget=world.preparation_admission.duplicate(true)
    result.presenters=world.component_renderer.numbers.keys()
    result.native_required=native._required_ids.keys()
    result.native_handles=native.handles.keys()
    return result

func settle(world:Node,component_id:String="")->bool:
    if not await super.settle(world,component_id):return false
    if component_id.is_empty():return true
    var native:RefCounted=world.component_renderer.native_spells
    var handle:Dictionary=native.handles.get(component_id,{})
    if handle.is_empty():return true # The inherited inspector asserts ownership.
    if str(handle.clip.id) not in HEAVY_CLIPS:return true
    var actual:Dictionary=Effects.occurrence_clip(handle.component)
    var source:Dictionary=Effects.choice(actual).approaches[0]
    check(handle.effect_approach_id==HEAVY_APPROACH and handle.effect_approach_path==source.path \
        and handle.effect_source_phase==source.source_phase,"Actual private source uses the exact selected heavy constructor and phase")
    check(not handle.seekable and not source.seekable,"Source retains its delivered chronological simulation policy")
    var phase:Resource=load(source.source_phase)
    check(is_equal_approx(float(handle.occurrence.handle.clip.simulation_hz),float(phase.to_clip().simulation_hz)),"Actual sampler retains the source phase simulation rate")
    actual_sources.append({"clip_id":handle.clip.id,"component_id":component_id,"source_event_uuid":handle.component.source_event_uuid,
        "at_ms":world.timeline.display_ms,"approach":handle.effect_approach_id,"phase":handle.effect_source_phase,
        "simulation_hz":handle.occurrence.handle.clip.simulation_hz,"construction_ms":handle.construction_phases})
    return true

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"selected_cases":selected_cases,
        "cases":evidence,"actual_sources":actual_sources,"qualified_clip_ids":qualified_clips,
        "scope":"Five explicit heavy-source selections through existing original two-seat Studio journals and ordinary Play: canonical commit ordering/ownership, actual constructor, declared source-rate chronology, seek reconstruction, native framebuffer output and teardown. Other sources are outside this gate. The three Conjure assemblies still need their actual born-recipient binding and compatible source-phase ownership. This is neither a live-command responsiveness certificate nor human art approval."}
    FileAccess.open("res://.runtime/native-heavy-effects-render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_HEAVY_EFFECT_RENDER ",JSON.stringify({"checks":checks,"failures":failures,"selected_cases":selected_cases}));quit(0 if failures.is_empty() else 1)
