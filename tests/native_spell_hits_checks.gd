extends SceneTree
## Renderer-boundary qualification using the selected real Factory materials.
## Event eligibility/ordering is covered separately by native_spell_event_checks.
const Hits=preload("res://presentation/native_spell_hits.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Conditions=preload("res://presentation/conditions.gd")
const REPORT="res://.runtime/native-spell-hits-checks.json"
const CAPTURES="res://.captures/native-spell-hits"
var checks=0
var failures:Array=[]
var observations:Array=[]

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);push_error(label)

func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    create_timer(90).timeout.connect(func():push_error("Native hit service exceeded its finite budget");quit(1))
    run.call_deferred()

func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func component(id:String,actor:String,hit:Dictionary,age_ms:float)->Dictionary:
    return {"id":id,"kind":"material_flash","actor_uuid":actor,"source_event_uuid":id,
        "start_ms":200.0,"duration_ms":150.0,"age_ms":age_ms,"color":"#fb632d",
        "material":{"holdMs":50.0,"envelope":"hold_fade"},"native_hit":hit}

func prepare(service:RefCounted,world:Node3D,components:Array,cache:Dictionary)->Dictionary:
    var result:Dictionary={}
    var deadline=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline:
        result=service.prepare(world,components,cache)
        if result.ready or not result.issues.is_empty():return result
        await frame()
    check(false,"Selected native source preparation finishes")
    return result

func material_stats(image:Image)->Dictionary:
    var coloured=0;var minimum=INF;var maximum=0.0
    for y in image.get_height():
        for x in image.get_width():
            var pixel=image.get_pixel(x,y)
            var value=maxf(pixel.r,maxf(pixel.g,pixel.b))
            if value>0:coloured+=1
            minimum=minf(minimum,value);maximum=maxf(maximum,value)
    return {"rgb_nonzero_pixels":coloured,"minimum":minimum,"maximum":maximum}

func clean_sample(sample:Dictionary)->Dictionary:
    var result=sample.duplicate(true)
    for field in ["native_surface","native_ramp","native_finishing"]:result.erase(field)
    return result

func legacy_surface(world:Node3D,hit:Dictionary)->Dictionary:
    # Frozen old sandbox material/quad boundary, independent of the new helper.
    var handle=Factory.make(world,hit.clip.duplicate(true))
    var mesh:MeshInstance3D=handle.root.get_node(hit.definition.node)
    var source:Material=mesh.get_active_material(int(hit.definition.surface)).duplicate(true)
    for key in hit.definition.get("parameter_overrides",{}):source.set_shader_parameter(key,hit.definition.parameter_overrides[key])
    var viewport=SubViewport.new();viewport.size=Vector2i(256,256)
    viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;world.add_child(viewport)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color.WHITE;viewport.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2;camera.position.z=1;viewport.add_child(camera)
    var quad=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2)
    quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    quad.material_override=source.duplicate(true);viewport.add_child(quad)
    Factory.close(handle)
    return {"viewport":viewport,"material":quad.material_override}

func run()->void:
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var world=Node3D.new();root.add_child(world)
    var cache:Dictionary={}
    var fire=Authoring.hit("spell.fire_bolt",cache)
    var missile=Authoring.hit("spell.magic_missile",cache)
    check(fire.has("clip") and missile.has("clip"),"Two migrated spells select their real source materials")
    var original_fire=fire.duplicate(true);var original_missile=missile.duplicate(true)
    var rows=[component("event-a","recipient-a",fire,20),component("event-b","recipient-a",fire,120),
        component("event-a","recipient-b",fire,20),component("event-future","recipient-a",missile,70)]
    var unchanged=rows.duplicate(true)
    var service=Hits.new()
    var waiting=service.decorate(world,[rows[0].duplicate(true)])
    check(not waiting.ready and waiting.pending==1 and waiting.issues.is_empty(),"A real replay occurrence before preparation is pending, never a permanent missing-source error")
    check(waiting.pending_occurrences.size()==1 and waiting.pending_occurrences[0].status=="pending","Unprepared occurrence has an explicit readiness diagnostic")
    var loaded=await prepare(service,world,rows,cache)
    check(loaded.ready and loaded.issues.is_empty(),"Actual Factory sources and their initial material frames become ready")
    check(rows==unchanged,"Preparation does not publish samples or mutate admitted component data")
    check(fire==original_fire and missile==original_missile,"Factory construction leaves admitted clip and finishing data immutable")
    if not loaded.ready:
        service.close();world.queue_free();await process_frame;finish();return
    var displayed:Array=rows.slice(0,3).duplicate(true)
    var result=service.decorate(world,displayed,true,true)
    check(result.ready and result.issues.is_empty(),"Prepared actual occurrences decorate without a new readiness stall")
    check(displayed.size()==3 and displayed.all(func(row):return row.id!="event-future"),"Future preparation never adds a future flash to displayed samples")
    for i in displayed.size():check(clean_sample(displayed[i])==unchanged[i],"Decorating preserves actual event, recipient, duration, envelope and colour %d"%i)
    check(displayed[0].native_surface!=displayed[1].native_surface,"Two overlapping hits on one recipient have separate native surfaces")
    check(displayed[0].native_surface!=displayed[2].native_surface,"One occurrence on two recipients has separate native surfaces")
    await frame()
    var first:Image=displayed[0].native_surface.get_image()
    var late:Image=displayed[1].native_surface.get_image()
    check(first.get_data()!=late.get_data(),"Independent Fire Bolt occurrence ages produce different animated material pixels")
    check(first.get_data()==displayed[2].native_surface.get_image().get_data(),"Equal source/age on separate recipients produces identical source pixels")
    var stats=material_stats(first)
    check(stats.rgb_nonzero_pixels>0 and stats.maximum>stats.minimum,"Actual selected native material has nonblank varying pixels")
    first.save_png(CAPTURES+"/fire-bolt-age20.png");late.save_png(CAPTURES+"/fire-bolt-age120.png")
    observations.append({"source":"fire_bolt","ages_ms":[20,120],"pixels":stats})
    var reference=legacy_surface(world,fire)
    reference.material.set_shader_parameter(fire.definition.clock_parameter,.02)
    await frame()
    check(reference.viewport.get_texture().get_image().get_data()==first.get_data(),"Shared material helper is byte-identical to the original sandbox quad path")
    reference.viewport.queue_free()
    var peer_world=Node3D.new();root.add_child(peer_world)
    var peer=Hits.new();var peer_rows=[rows[0].duplicate(true)]
    check((await prepare(peer,peer_world,peer_rows,cache)).ready,"A second replay pane prepares independently")
    peer_rows[0].age_ms=120;peer.decorate(peer_world,peer_rows)
    await frame()
    check(peer_rows[0].native_surface!=displayed[0].native_surface,"Replay panes never share the mutable native surface")
    check(peer_rows[0].native_surface.get_image().get_data()==late.get_data(),"Second pane samples its own age")
    check(displayed[0].native_surface.get_image().get_data()==first.get_data(),"Second pane clock leaves first pane pixels unchanged")
    peer.decorate(peer_world,[],true);peer.prepare(peer_world,[],cache);peer.close();peer_world.queue_free()
    var original_texture=displayed[0].native_surface
    check(service.decorate(world,displayed,false).ready,"Colour-only mode remains ready")
    check(displayed.all(func(row):return not row.has("native_surface") and not row.has("native_ramp")),"Switching the same sampled array to colour clears every native binding")
    service.decorate(world,displayed,true,false)
    check(displayed[0].native_surface==original_texture and not displayed[0].has("native_ramp"),"Full source mode reuses the prepared occurrence with finishing disabled")
    service.decorate(world,displayed,true,true)
    check(fire.finish_profile.ramp.is_empty() and not displayed[0].has("native_ramp"),"Fire Bolt's intentionally empty finishing ramp preserves the original native material")
    var future=[rows[3].duplicate(true)]
    service.decorate(world,future)
    await frame()
    var static_image:Image=future[0].native_surface.get_image()
    future[0].age_ms=120
    check(service.decorate(world,future).ready,"Static Magic Missile material does not stall as its occurrence advances")
    await frame()
    check(static_image.get_data()==future[0].native_surface.get_image().get_data(),"Unclocked native Magic Missile material stays source-static")
    check(future[0].has("native_ramp") and not displayed[0].has("native_ramp") and future[0].native_finishing==missile.finish_profile,"Magic Missile finishing is not shared with the native-colour Fire Bolt appearance")
    var overlap=[displayed[0],future[0]]
    check(service.decorate(world,overlap).ready,"Overlapping Fire Bolt and Magic Missile remain independently ready on the same recipient")
    check(Conditions.material("recipient-a",overlap).flash.native_surface==future[0].native_surface,"Existing last-active-flash selection owns overlap; service adds no arbitration")
    service.decorate(world,[displayed[0]])
    check(Conditions.material("recipient-a",[displayed[0]]).flash.native_surface==original_texture,"Removing the later hit restores the surviving original occurrence")
    service.decorate(world,future)
    static_image.save_png(CAPTURES+"/magic-missile-native.png")
    check(service.prepare(world,[],cache).ready,"Retiring the admitted list retains the currently displayed hit")
    check(service.decorate(world,future).ready,"An active tail remains available beyond its preparation group")
    service.decorate(world,[])
    await frame()
    check(world.get_children().filter(func(node):return node is SubViewport).is_empty(),"Expired admitted and active occurrences release their native viewports")
    var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/body_materials.json")).spells
    var unsupported:Array=[]
    for id in ["burning_hands","chill_touch","poison_spray","shocking_grasp"]:
        unsupported.append(component(id,"recipient-a",{"spell_id":id,"definition":definitions[id]},25))
    var fallback=service.prepare(world,unsupported,cache)
    check(fallback.ready and fallback.issues.size()==4,"Four explicitly unsupported sources permit the existing colour fallback")
    check(service.decorate(world,unsupported).ready,"Unsupported full materials do not stall the existing feedback")
    for row in unsupported:check(not row.has("native_surface") and row.color=="#fb632d","Unsupported "+row.id+" retains colour with no fabricated native surface")
    service.close()
    for failure in ["node","surface","clock"]:
        var invalid=fire.duplicate(true)
        if failure=="node":invalid.definition.node="travel/Absent"
        elif failure=="surface":invalid.definition.surface=999
        else:invalid.definition.clock_parameter="missing_source_clock"
        var invalid_rows=[component("invalid-"+failure,"recipient-a",invalid,20)]
        var rejected=await prepare(service,world,invalid_rows,cache)
        check(not rejected.ready and rejected.issues.size()==1 and rejected.issues[0].status=="missing","Invalid selected "+failure+" remains an explicit missing source")
        check(not service.decorate(world,invalid_rows).ready and not invalid_rows[0].has("native_surface"),"Invalid selected "+failure+" cannot qualify a native flash")
        service.close()
    # Cancel immediately after submission, before the first material draw.
    service.prepare(world,[rows[0]],cache);service.close();service.close()
    await frame()
    check(world.get_children().is_empty(),"Cancellation and repeated close release nodes, including a pending first draw")
    check(fire==original_fire and missile==original_missile,"Failure, retirement and cancellation leave source snapshots unchanged")
    world.queue_free();await process_frame
    finish()

func finish()->void:
    var report={"checks":checks,"passed":checks-failures.size(),"failed":failures.size(),"failures":failures,
        "renderer":RenderingServer.get_current_rendering_method(),"observations":observations,
        "scope":"Selected real Fire Bolt/Magic Missile native material pixels, isolated occurrence/recipient/pane clocks, old sandbox surface parity, preparation/publication/retirement, mode and explicit fallback/error boundaries. This does not substitute for recorded-event eligibility or full actor-scene qualification."}
    FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_HITS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
