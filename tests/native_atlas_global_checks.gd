extends "res://tests/native_atlas_staged_checks.gd"
# Render options and view basis are private inputs until the same atlas adopts
# their complete candidate. The reference keeps the independent full planner.
class GlobalHost extends Node3D:
    var timeline:Dictionary={"initialization_revision":1}
    var world_generation:int=1
    var actor_entries:Array=[]
    var camera:Camera3D

func global_host(side:Dictionary)->GlobalHost:
    var host=GlobalHost.new();side.world.add_child(host)
    host.camera=side.world.camera;host.actor_entries=side.world.actor_entries
    return host

func add_global_consumers(side:Dictionary)->void:
    var actor:Dictionary=prepared_dynamic_actor(side,false);actor.node.show()
    side.world.entries.append(actor);side.world.actor_entries=[actor]
    var water:Dictionary=single(side.world,side.texture,20)
    water.material=ShaderMaterial.new();water.material.shader=WaterSource
    water.node.material_override=water.material;water.role="terrain"
    water.placement={"id":"global-water","kind":"terrain","material":"water","position":[0,2],"base_height_steps":0}
    SourceMaterial.initialize(water)
    SourceMaterial.apply(water,{"mask_texture":side.texture,"ripple_texture":side.texture,"cell":Vector2(512,512),"image_scale":1.0,
        "shallow_color":Color(.2,.4,.6,1),"deep_color":Color(.1,.2,.4,1),"tint":Color.WHITE,
        "uv_scale":1.0,"ripple_pan":Vector2(.5,0),"ripple_tiling":1.0,"ripple_amount":.3,
        "overall_alpha":1.0,"alpha_cutoff":.001,"sheen_sharpness":2.0,"sheen_strength":.2,"displayed_time_seconds":.7})
    side.world.entries.append(water)

func complete_global(side:Dictionary,host:GlobalHost,target:Node,options:Dictionary,entries:Array=[])->Dictionary:
    var work:Dictionary=Atlas.Delta.begin_global(side.atlas,host,target,side.world.entries if entries.is_empty() else entries,options)
    var deadline:int=Time.get_ticks_msec()+10000
    while work.phase not in ["ready","failed"] and Time.get_ticks_msec()<deadline:
        Atlas.Delta.step_global(side.atlas,work,1500)
        if work.phase=="worker":await process_frame
    check(work.phase=="ready","Global candidate finishes every capture, worker and private native binding: "+str(work.get("error","")))
    return work

func drain_global(work:Dictionary)->void:
    var cleanup={"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}
    Atlas.Delta.retire_global(work,cleanup)
    while not Atlas.Delta.retire_candidate_step(cleanup).get("done",false):await process_frame

func publish_global(side:Dictionary,work:Dictionary)->void:
    var cleanup={"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}
    side.atlas.publish_render_options(work.options)
    Atlas.Delta.publish_global(side.atlas,work,cleanup)
    var base:int=side.serial;side.serial+=1
    var receipt={"base":base,"serial":side.serial,"full":true,"upserts":work.upserts,"removed":work.removed.keys()}
    side.atlas.sync(side.world,[side.serial],[side.serial],receipt,true)
    side.atlas.sync_output(side.world,[side.serial],true)
    check(not cleanup.blocked,"Published global candidate releases its private retirement ownership")
    while not Atlas.Delta.retire_candidate_step(cleanup).get("done",false):pass

func global_case()->void:
    var a=make_side(pair_source(),false,false);var b:Dictionary={}
    if DisplayServer.get_name()!="headless":b=make_side(pair_source(),false,false)
    for side in [a] if b.is_empty() else [a,b]:
        add_global_consumers(side)
        publish(side,true,side.world.entries)
    a.atlas.require_prepared_publication=true
    var host:GlobalHost=global_host(a)
    var target=World.new();a.view.add_child(target);target.source_images=a.world.source_images
    target.camera=Camera3D.new();target.add_child(target.camera)
    target.camera.transform=a.world.camera.transform;target.camera.size=a.world.camera.size
    var options_list=[{"light_cap":1.0,"normals_visible":false},
        {"light_cap":1.0,"normals_visible":true},{"light_cap":0.0,"normals_visible":false}]
    for index in options_list.size():
        var options:Dictionary=options_list[index]
        if index==2:target.camera.rotate_y(.18)
        var old_token:Array=Atlas.Delta.token(a.atlas);var old_positions:Dictionary=positions(a.atlas)
        var old_output:ShaderMaterial=a.floor.received_material
        var old_buffer:PackedFloat32Array=a.floor.ground_buffer.duplicate()
        var work:Dictionary=await complete_global(a,host,target,options)
        if work.phase!="ready":await drain_global(work);break
        check(Atlas.Delta.token(a.atlas)==old_token and positions(a.atlas)==old_positions
            and a.floor.received_material==old_output and a.floor.ground_buffer==old_buffer,
            "Global preparation leaves displayed options, addresses, outputs and floor packets untouched")
        check(Atlas.Delta.global_base_matches(a.atlas,work),"Future view/options preflight matches their separate displayed base")
        SourceMaterial.set_parameter(a.world.actor_entries[0],"highlighted",index==0)
        check(Atlas.Delta.global_base_matches(a.atlas,work),"Continuous hover remains a current sample while global resources prepare")
        a.world.camera.transform=target.camera.transform
        publish_global(a,work)
        check(a.atlas.errors.is_empty() and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
            "Global publication consumes its exact candidate without live complete planning")
        check(a.atlas.light_cap==options.light_cap and a.atlas.normals_visible==options.normals_visible,
            "Adoption changes the requested cap/Normals mode together")
        check(positions(a.atlas)==old_positions,"View/options retain every fitting integer atlas reservation")
        if not b.is_empty():
            b.world.camera.transform=target.camera.transform
            b.atlas.set_light_cap(options.light_cap);b.atlas.set_normals_visible(options.normals_visible)
            SourceMaterial.set_parameter(b.world.actor_entries[0],"highlighted",index==0)
            publish(b,true,b.world.entries)
            await first_draw(a,b,"global-mode-"+str(index))
    # A future structural cell change shares no mutable source row with the
    # displayed entry. Its crop no longer fits the old reservation; both paths
    # must run the real complete planner, with original source insertion order.
    var future:Array=a.world.entries.duplicate()
    future[1]=future[1].duplicate();future[1].cell=Vector2(256,512)
    var rebase:Dictionary=await complete_global(a,host,target,{"light_cap":0.0,"normals_visible":false},future)
    if rebase.phase=="ready":
        check(rebase.prefix.get("rebased",false),"Changed cell crop uses genuine complete layout during preparation")
        check(a.world.entries[1].cell==Vector2(512,512),"Rebase keeps the displayed source dimensions until adoption")
        var repacks:int=a.atlas.repack_count
        a.world.entries=future;publish_global(a,rebase)
        check(a.atlas.repack_count==repacks+1 and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
            "Complete prepared rebase advances packing ownership without a publication fallback")
        if not b.is_empty():
            # A fresh complete source render has no old same-node projection
            # cache. In-place cell-size mutation is not the original author's
            # resource replacement path and cannot serve as this pixel oracle.
            b.atlas.close();b.view.queue_free()
            b=make_side(pair_source(),false,false)
            add_global_consumers(b)
            b.world.camera.transform=target.camera.transform
            b.world.entries[1].cell=Vector2(256,512);publish(b,true,b.world.entries)
            check(positions(a.atlas)==positions(b.atlas),"Prepared complete rebase keeps independent planner insertion order and integer reservations")
            await first_draw(a,b,"global-rebase")
    else:await drain_global(rebase)
    a.view.size=Vector2i(480,1200)
    var old_height:int=a.atlas.viewport.size.y
    var resized:Dictionary=await complete_global(a,host,target,{"light_cap":0.0,"normals_visible":false})
    if resized.phase=="ready":
        check(a.atlas.viewport.size.y==old_height and resized.prefix.plan.next_height>=1200,
            "Viewport enlargement is prepared while the old receiving target remains displayed")
        publish_global(a,resized)
        check(a.atlas.viewport.size.y>=1200 and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
            "Enlarged receiving height adopts its prepared regions without complete fallback")
        if not b.is_empty():
            b.view.size=Vector2i(480,1200);publish(b,true,b.world.entries)
            await first_draw(a,b,"global-resize-water")
    else:await drain_global(resized)
    var cancelled:Dictionary=await complete_global(a,host,target,{"light_cap":1.0,"normals_visible":false})
    if cancelled.phase=="ready":
        var entry:Dictionary=a.world.entries[1]
        SourceMaterial.set_parameter(entry,"colour_rect",Vector4(0,0,256,512),true)
        check(not Atlas.Delta.global_base_matches(a.atlas,cancelled),"Structural source change rejects a stale global candidate before display mutation")
    var token_before:Array=Atlas.Delta.token(a.atlas);var positions_before:Dictionary=positions(a.atlas)
    await drain_global(cancelled)
    check(Atlas.Delta.token(a.atlas)==token_before and positions(a.atlas)==positions_before,
        "Cancelled global bindings retire without changing the displayed atlas")
    a.atlas.close();a.view.queue_free()
    if not b.is_empty():b.atlas.close();b.view.queue_free()
    await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    await global_case()
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Prepared mode/view changes in the existing atlas owner, structural rejection, cancellation, unchanged fitting reservations. Native runs compare first receiver pixels and final frame with independent full planning; no latency claim."}
    var file=FileAccess.open("res://generated/native_atlas_global_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("NATIVE_ATLAS_GLOBAL_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
