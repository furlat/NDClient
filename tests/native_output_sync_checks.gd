extends "res://tests/native_atlas_lifecycle_checks.gd"
# Exact final output state and pixels versus the previous exhaustive copier.
func original_output(world:World)->void:
    for entry in world.entries:
        if not entry.has("received_material") or not is_instance_valid(entry.node):continue
        var output:ShaderMaterial=entry.received_material
        output.render_priority=entry.material.render_priority
        if entry.has("wall_source"):
            for name in ["wall_opacity","wall_mask_enabled","wall_mask_id","wall_mask_texture"]:
                output.set_shader_parameter(name,entry.material.get_shader_parameter(name))
func output_state(entry:Dictionary)->Array:
    var output:ShaderMaterial=entry.received_material
    var result:Array=[output.render_priority]
    for name in ["wall_opacity","wall_mask_enabled","wall_mask_id","wall_mask_texture"]:
        result.append(output.get_shader_parameter(name))
    return result
func compare_output(atlas:RefCounted,world:World,entry:Dictionary,stamp:Array,label:String)->void:
    atlas.sync_output(world,stamp,true)
    var state=output_state(entry)
    var image=await capture(world.get_viewport())
    original_output(world)
    check(state==output_state(entry),label+": final priority/opacity/mask state equals exhaustive copier")
    check(image.get_data()==(await capture(world.get_viewport())).get_data(),label+": first final framebuffer equals exhaustive copier byte-exactly")
func run()->void:
    tracked_receivers=true
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    var view=SubViewport.new();view.size=Vector2i(320,240);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=World.new();view.add_child(world)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.5;camera.position=Vector3(0,0,10);world.add_child(camera);world.camera=camera
    var source=Image.create(64,64,false,Image.FORMAT_RGBA8)
    for y in range(12,44):
        for x in range(6,58):source.set_pixel(x,y,Color8(74+x,81+y,153,[1,63,194,255][(x-6)/13]))
    world.source_images.fixture=source
    var entry=floor_entry(world,source);entry.wall_source={"id":"output-wall"};world.entries=[entry]
    var atlas=Atlas.new();atlas.attach(world);sync_scene(atlas,world,true)
    var stamp:Array=[world_generation,0,scenery_revision,"solid",atlas.revision]
    await compare_output(atlas,world,entry,stamp,"Tracked initialization")
    # Same published world/geometry, different wall output. No visibility toggle.
    entry.material.set_shader_parameter("wall_opacity",.28);entry.material.render_priority=7
    atlas.output_changed(entry)
    await compare_output(atlas,world,entry,stamp,"Same-stamp visible wall opacity and priority")
    var mask=Image.create(320,240,false,Image.FORMAT_RGBA8);mask.fill(Color8(2,0,0,255))
    entry.material.set_shader_parameter("wall_mask_texture",ImageTexture.create_from_image(mask))
    entry.material.set_shader_parameter("wall_mask_id",1);entry.material.set_shader_parameter("wall_mask_enabled",true)
    atlas.output_changed(entry)
    await compare_output(atlas,world,entry,stamp,"Post-sort ownership mask writes")
    entry.material.set_shader_parameter("wall_mask_id",3);atlas.output_changed(entry)
    entry.material.set_shader_parameter("wall_mask_enabled",false);atlas.output_changed(entry)
    await compare_output(atlas,world,entry,stamp,"Multiple late writes keep final source state")
    for mode in ["cap","normals","off"]:
        atlas.set_light_cap(1.0 if mode!="off" else 0.0);atlas.set_normals_visible(mode=="normals")
        sync_scene(atlas,world)
        stamp[4]=atlas.revision
        await compare_output(atlas,world,entry,stamp,"Output mode "+mode)
    var replaced=entry.duplicate();replaced.material=entry.material.duplicate();replaced.material.render_priority=12
    replaced.material.set_shader_parameter("wall_opacity",.65);replaced.erase("received_material");world.entries[0]=replaced
    atlas.output_changed(replaced)
    # Before acceptance this is a different owner around the same native node.
    atlas.sync_output(world,stamp,true)
    sync_scene(atlas,world,true,false,sparse([replaced],[entry.node.get_instance_id()]))
    entry=replaced;stamp=[world_generation,0,scenery_revision,"solid",atlas.revision]
    await compare_output(atlas,world,entry,stamp,"Replacement output after initially unadmitted owner")
    entry.material.render_priority=19;entry.material.set_shader_parameter("wall_opacity",.43)
    stamp[1]=1
    await compare_output(atlas,world,entry,stamp,"Quarter fallback copies unnotified native source state")
    entry.material.render_priority=23;stamp[0]+=1
    atlas.sync_output(world,stamp)
    check(entry.received_material.render_priority==23,"Untracked changed-stamp caller retains exhaustive external-mutation fallback")
    atlas.output_changed(entry);entry.node.queue_free();world.entries=[]
    atlas.sync_output(world,stamp,true);await process_frame;atlas.sync_output(world,stamp,true)
    check(atlas.last_reconcile_phases.output_entries_checked==0,"Retired native entry safely clears queued output work")
    atlas.close();await process_frame
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Native final output state and exact framebuffer against copied previous exhaustive copier; same-stamp late opacity/mask/priority writes, cap/Normals restoration, material-owner replacement and rejected-owner retention, quarter/untracked fallback, deleted entry."}
    FileAccess.open("res://generated/native_output_sync_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_OUTPUT_SYNC ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
