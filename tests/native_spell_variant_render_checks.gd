extends SceneTree
## Genuine Miss journals with a test-only authored predicate and an existing
## source-compatible delivery. This qualifies dispatch/ownership, not new Miss
## artwork: the imported miss clip's review endpoint remains an explicit gap.
const Play=preload("res://play.gd")
const Recording=preload("res://studio/recording.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const VariantSource=preload("res://presentation/source/abilities/spell_variant.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ID="spell.ray_of_sickness"
const PATH="res://authoring/abilities/spells/spell.ray_of_sickness.tres"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_SPELL_VARIANT_RENDER_FAIL ",label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node,component_id:String="")->bool:
    var until:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<until and world.presentation_errors.is_empty() and world.media_issue.is_empty() and not world.publication_failed:
        var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        if world.playback_prepared() and (component_id.is_empty() or not bindings.is_empty() and bindings.unavailable.is_empty()):
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,"Exact current playback/source readiness: "+str({"component":component_id,"world":world.component_renderer.readiness,"native":world.component_renderer.native_spells.diagnostics,"errors":world.presentation_errors,"media":world.media_issue}))
    return false
func changed(a:Image,b:Image)->int:
    a=a.duplicate();b=b.duplicate();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var count:int=0
    for pixel in a.get_width()*a.get_height():
        var at:int=pixel*4
        if absi(int(left[at])-int(right[at]))+absi(int(left[at+1])-int(right[at+1]))+absi(int(left[at+2])-int(right[at+2]))>3:count+=1
    return count
func cache_for(record:Resource)->Dictionary:
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate();index.spells[ID]=PATH
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    var original:Resource=load(PATH);var immutable:PackedByteArray=var_to_bytes([original.effects[0].extra,original.variants.map(func(row):return [row.id,row.when,row.dispatch_gap])])
    var entry:Resource=original.duplicate(true);var alternative:Resource=VariantSource.new()
    alternative.id="test.recorded_miss";alternative.kind="outcome";alternative.when={"attack_outcome":["Miss","Crit Miss"]}
    alternative.effects.append(entry.effects[0].duplicate(true));entry.variants.assign([alternative])
    var output:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{ID:PATH}})
    for seat in ["amber","blue"]:
        var directory:String="res://tests/fixtures/schema16/typed-variants-miss/"+seat+"/journal"
        var index:Dictionary=Recording.read(directory,{}, {},cache_for(output.native.records[ID]))
        check(index.ok,seat+" genuine original independently reduces/compiles")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_variant",{}).get("id")==alternative.id)
        check(rows.size()==1,seat+" actual disclosed Miss selects one explicit delivery alternative")
        if rows.size()!=1:continue
        await inspect(index,rows[0],seat)
    check(var_to_bytes([original.effects[0].extra,original.variants.map(func(row):return [row.id,row.when,row.dispatch_gap])])==immutable,"Original production source/predicates remain unchanged; no visual alternative silently enabled")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Genuine two-seat Miss facts + explicit test-only predicate, ordinary renderer/independent canonical prefixes/native source admission/pixels/seek/loop. Imported Miss art with a review endpoint and all unpredicated production alternatives remain unqualified. No user acceptance or performance claim."}
    FileAccess.open("res://.runtime/native-spell-variant-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_VARIANT_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func inspect(index:Dictionary,row:Dictionary,seat:String)->void:
    var component:Dictionary=row.component
    var viewport:SubViewport=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true
    viewport.audio_listener_enable_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world:Node=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);viewport.add_child(world)
    var middle:float=float(row.start_ms)+(float(row.end_ms)-float(row.start_ms))*.55
    var previous:WeakRef
    for at in [maxf(0.0,float(row.start_ms)-2.0),middle,minf(index.presentation_end_ms,float(row.end_ms)+2.0),maxf(0.0,float(row.start_ms)-2.0),middle]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==middle else ""):break
        check(world.timeline.display_ms==at and world.timeline.state==Recording.restore(index,at).state,seat+" exact original canonical prefix after seek/loop "+str(at))
        if previous!=null:check(previous.get_ref()==null,seat+" old private selected occurrence releases at replay epoch replacement")
        var renderer:RefCounted=world.component_renderer.native_spells
        if at!=middle:
            check(renderer.witnesses.all(func(witness):return witness.id!=component.id),seat+" no selected finite-source witness outside its interval")
            previous=null;continue
        check(renderer.handles.has(component.id),seat+" selected actual component owns a native source")
        if not renderer.handles.has(component.id):break
        var handle:Dictionary=renderer.handles[component.id]
        check(handle.clip.id==entry_clip(index) and component.native_variant.id=="test.recorded_miss",seat+" actual selected source identity is retained through renderer admission")
        var bindings:Dictionary=renderer.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(bindings.unavailable.is_empty(),seat+" selected source has no unresolved required inputs")
        check(component.actor_uuid!=component.target_uuid and component.to_position==[6,7],seat+" original rule caster and actual target endpoints remain distinct")
        world.camera_focus=Play.Placement.contact({"position":[4.5,7],"base_height_steps":0})
        world.camera.size=6;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var visible:Image=viewport.get_texture().get_image();Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(visible,viewport.get_texture().get_image())
        check(pixels>0,seat+" exact selected native delivery contributes actual framebuffer pixels")
        evidence.append({"seat":seat,"at_ms":at,"variant":component.native_variant,"source_event_uuid":component.source_event_uuid,"native_cast_id":component.native_cast_id,"clip":component.native_clip.id,"pixels":pixels,"actor":component.actor_uuid,"target":component.target_uuid})
        previous=weakref(handle.root);handle.root.show();world.set_process(true)
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),seat+" all private alternative source owners close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" no source/resource errors across actual seeks/loop")
    viewport.queue_free();await frame();await frame()
func entry_clip(index:Dictionary)->String:
    return Sources.find(ID,index.cache).variants[0].selection.staging.cues[0].clip
