extends SceneTree
## Actual production Miss selection and authored optical endpoint placement.
## Original journals retain their canonical target, outcome and source owners.
const Play=preload("res://play.gd")
const Recording=preload("res://studio/recording.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ID="spell.ray_of_sickness"
const PATH="res://authoring/abilities/spells/spell.ray_of_sickness.tres"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var plan_only:bool=false
var only_variant:String=""
var current_case:String=""
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
        var prepared:bool=world.playback_prepared()
        var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        if prepared and (component_id.is_empty() or not bindings.is_empty() and bindings.unavailable.is_empty()):
            await frame()
            # View publication can request a new recipient surface projection
            # in that frame. Admit only the current source's ready bindings.
            prepared=world.playback_prepared()
            bindings=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
            if prepared and (component_id.is_empty() or not bindings.is_empty() and bindings.unavailable.is_empty()):return true
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
func positive_timing()->void:
    for spec in [{"directory":"root-target-save/ray-of-sickness","impact":"bg3-36/ray-of-sickness/impact","delay":.38},
        {"directory":"projectile-variants/acid_arrow--dodge_seed_3","impact":"bg3-36/acid-arrow/impact","delay":.5}]:
        for seat in ["amber","blue"]:
            var directory:String="res://tests/fixtures/schema16/"+spec.directory+"/"+seat+"/journal"
            if not FileAccess.file_exists(directory.path_join("0000000000000000.json")):directory=directory.get_base_dir()
            var index:Dictionary=Recording.read(directory)
            check(index.ok,seat+" positive original admits for authored impact/HP timing")
            if not index.ok:continue
            var by_id:Dictionary={}
            for row in index.rows:by_id[row.id]=row
            var impacts:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_clip",{}).get("id")==spec.impact)
            check(not impacts.is_empty(),seat+" positive original includes its actual authored impact source")
            for impact in impacts:
                var matched:int=0
                for flash in index.rows:
                    if flash.kind!="material_flash" or flash.component.actor_uuid!=impact.component.target_uuid or flash.group_id!=impact.group_id:continue
                    var ancestor:String=flash.parent
                    while by_id.has(ancestor) and ancestor!=impact.parent:ancestor=by_id[ancestor].parent
                    if ancestor!=impact.parent:continue
                    matched+=1
                    check(is_equal_approx(flash.start_ms,impact.start_ms),seat+" actual positive damage flash aligns with this source's authored impact")
                    var damage:Dictionary=by_id[flash.parent]
                    check(damage.get("markers",[]).any(func(marker):return marker.kind=="commit" and is_equal_approx(float(marker.at_ms),float(impact.start_ms))),seat+" actual HP after-value publishes at that same source impact")
                    evidence.append({"kind":"positive_impact_timing","directory":directory,"impact_clip":spec.impact,"impact_ms":impact.start_ms,"flash_ms":flash.start_ms,"damage_event":damage.id,"commit_markers":damage.get("markers",[])})
                check(matched>0,seat+" positive impact has its exact causal recipient damage witness")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    for argument in OS.get_cmdline_user_args():
        if argument=="--plan-only":plan_only=true
        if argument.begins_with("--only-variant="):only_variant=argument.trim_prefix("--only-variant=")
    if only_variant.is_empty():positive_timing()
    for sample in [{"variant":"ray_of_sickness_miss_native","folder":"typed-variants-miss", "clips":["bg3-36/ray-of-sickness/miss"]},
        {"variant":"acid_arrow_miss_native","folder":"projectile-variants/acid_arrow--dodge_seed_5", "clips":["bg3-36/acid-arrow/miss-delivery","bg3-36/acid-arrow/miss-splash"]}]:
        if not only_variant.is_empty() and sample.variant!=only_variant:continue
        current_case=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/"+sample.folder+"/scenario.json")).id
        for seat in ["amber","blue"]:
            var directory:String="res://tests/fixtures/schema16/"+sample.folder+"/"+seat+"/journal"
            var index:Dictionary=Recording.read(directory,{},{},{})
            check(index.ok,seat+" genuine original independently reduces/compiles")
            if not index.ok:continue
            var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_variant",{}).get("id")==sample.variant)
            var clips:Array=rows.map(func(row):return row.component.native_clip.id);clips.sort();var expected:Array=sample.clips.duplicate();expected.sort()
            check(clips==expected,seat+" actual disclosed Miss selects its exact production finite delivery/splash")
            if rows.is_empty():continue
            check(not index.rows.any(func(row):return row.get("component",{}).get("native_cast_id")==rows[0].component.native_cast_id and str(row.get("component",{}).get("native_clip",{}).get("id","")).ends_with("/impact")),seat+" Miss has no duplicate body impact")
            for row in rows:
                if plan_only:
                    evidence.append({"directory":directory,"clip":row.component.native_clip.id,"start_ms":row.start_ms,"end_ms":row.end_ms,"cue":row.component.native_cue,"selected_source":Effects.choice(row.component.native_clip)})
                    continue
                for quarter in 4:await inspect(index,row,seat+" "+sample.variant+" view "+str(quarter),quarter)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"factory_version":JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json")).version,"scope":"Actual production Ray of Sickness and Acid Arrow Miss art, original two-seat outcomes, four views, optical endpoint binding, source pixels, independent canonical prefixes, seek/loop and cleanup. No user approval or final performance claim."}
    if plan_only:report.scope="Actual original row/selected-source/phase-clock plan only; no GPU, rendered pixels, audio or visual acceptance."
    FileAccess.open("res://.runtime/native-spell-variant-plan.json" if plan_only else "res://.runtime/native-spell-variant-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_VARIANT_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func inspect(index:Dictionary,row:Dictionary,seat:String,quarter:int)->void:
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
        world.request_view(quarter)
        var view_deadline:int=Time.get_ticks_msec()+15000
        while world.rotation_pending() and Time.get_ticks_msec()<view_deadline:await frame()
        check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,seat+" actual requested/published camera quarter agrees")
        if not await settle(world,component.id):break
        check(renderer.handles.has(component.id),seat+" selected actual component owns a native source")
        if not renderer.handles.has(component.id):break
        var handle:Dictionary=renderer.handles[component.id]
        check(handle.clip.id==component.native_clip.id and component.native_variant.id in ["ray_of_sickness_miss_native","acid_arrow_miss_native"],seat+" actual selected source identity is retained through renderer admission")
        var bindings:Dictionary=renderer.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(bindings.unavailable.is_empty(),seat+" selected source has no unresolved required inputs")
        check(component.actor_uuid!=component.target_uuid and component.to_position==[6,7],seat+" original rule caster and actual target endpoints remain distinct")
        world.camera_focus=Play.Placement.contact({"position":[4.5,7],"base_height_steps":0})
        world.camera.size=6;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var visible:Image=viewport.get_texture().get_image();Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(visible,viewport.get_texture().get_image())
        check(pixels>0,seat+" exact selected native delivery contributes actual framebuffer pixels")
        var observed:Dictionary={}
        var source:Node3D=handle.occurrence.handle.components.effect
        check(source.endpoints.size()>=2 and source.endpoints[1].get("actor_uuid")==component.target_uuid,seat+" actual source target endpoint names the recorded recipient")
        if component.native_variant.id=="acid_arrow_miss_native":
            observed=source.capture_observation()
            observed.launch_seconds=source.launch_seconds;observed.travel_seconds=source.travel_seconds
            if "recipient_geometry" in component.native_clip.inputs:
                check(source.recipient_geometry.get("actor_uuid")==component.target_uuid and not source.recipient_geometry.get("points",[]).is_empty(),seat+" supplied receiving geometry belongs to the exact target body")
                observed.recipient_geometry_actor_uuid=source.recipient_geometry.get("actor_uuid")
        evidence.append({"case":current_case,"seat":seat,"at_ms":at,"variant":component.native_variant,"source_event_uuid":component.source_event_uuid,"native_cast_id":component.native_cast_id,"clip":component.native_clip.id,"pixels":pixels,"actor":component.actor_uuid,"target":component.target_uuid,
            "requested_quarter":quarter,"published_quarter":world.world_quarter,"source_age":handle.age,"component_age_ms":at-row.start_ms,"delivery_timing":handle.get("delivery_input"),"observation":observed,"input_bindings":bindings,"root_transform":handle.root.global_transform,"selected_source":Effects.choice(component.native_clip)})
        previous=weakref(handle.root);handle.root.show();world.set_process(true)
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),seat+" all private alternative source owners close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" no source/resource errors across actual seeks/loop")
    viewport.queue_free();await frame();await frame()
