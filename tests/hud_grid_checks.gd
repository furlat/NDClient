extends SceneTree
## Native pixel regression through Play's real painter merge: ground UI must be
## visible on support and covered by opaque wall/character pixels in every view.
const Placement = preload("res://placement.gd")
class Probe extends "res://play.gd":
    func _ready() -> void:
        set_process(false)
        set_process_unhandled_input(false)
        camera = Camera3D.new()
        camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        camera.size = 3.0
        add_child(camera)
        camera.current = true
        add_child(context_menu)
    func _process(_delta: float) -> void: pass
var checks = 0
var failures: Array = []
var scene: Node
var shader: Shader
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); printerr("GROUND_OVERLAY_FAIL ",label)
func entry(kind: String, role: String, colour: Color, height: float) -> Dictionary:
    var node = MeshInstance3D.new()
    node.sorting_use_aabb_center = false
    var material = ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("colour",colour)
    node.material_override = material
    var row = {"id":kind,"kind":kind,"position":[0,0],"base_height_steps":height,"layer":0,"boundaries":[]}
    if kind == "terrain":
        node.mesh = PlaneMesh.new()
        node.mesh.size = Vector2.ONE
    else:
        node.mesh = QuadMesh.new()
        node.mesh.size = Vector2(1.1,1.1)
        node.basis = scene.camera.basis
        node.position = scene.camera.basis.y*.35
    node.position += Placement.contact(row)
    scene.add_child(node)
    return {"id":kind,"placement":row,"role":role,"layer":0,"node":node,"material":material}
func capture() -> Image:
    scene._sort_draws()
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func compare_pixels(off: Image, on: Image, label: String) -> void:
    var exposed = 0
    var blocked = 0
    var leaked = 0
    for y in range(on.get_height()):
        for x in range(on.get_width()):
            var a = off.get_pixel(x,y)
            var b = on.get_pixel(x,y)
            var delta = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
            if a.g > .4 and a.g > a.r*2.0:
                blocked += 1
                if delta > .005: leaked += 1
            elif delta > .005: exposed += 1
    check(exposed > 10,label+": grid is visibly above floor")
    check(blocked > 100,label+": real opaque blocker pixels are present")
    check(leaked == 0,label+": grid never paints over opaque blocker pixels")
func filled_interior(off: Image, on: Image, height: float) -> bool:
    # Sample actual cell interior away from every outline; source occlusion
    # remains authoritative, so skip pixels already covered by the blocker.
    for x in [-.3,-.15,0.0,.15,.3]:
        for z in [-.3,-.15,0.0,.15,.3]:
            var p = Vector2i(scene.camera.unproject_position(Vector3(x,height*Placement.HEIGHT_UNIT,z)))
            var a = off.get_pixelv(p)
            var b = on.get_pixelv(p)
            if a.g>.4 and a.g>a.r*2.0: continue
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.01: return true
    return false
func run() -> void:
    if DisplayServer.get_name() == "headless": printerr("Native pixels required"); quit(2); return
    root.unfocusable = true
    root.position = Vector2i(-16000,-16000)
    root.size = Vector2i(320,240)
    shader = Shader.new()
    shader.code = "shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never,depth_test_disabled; uniform vec4 colour:source_color; uniform vec4 frame_uv=vec4(0.,0.,1.,1.); void fragment(){ALBEDO=colour.rgb;ALPHA=colour.a;}"
    scene = Probe.new()
    root.add_child(scene)
    for height in [0.0,2.0]:
        for q in range(4):
            scene.quarter = q
            scene.camera_focus = Vector3(0,height*Placement.HEIGHT_UNIT,0)
            scene.position_camera()
            scene.timeline.state = {"tiles":{"0,0":{"position":[0,0],"elevation_steps":height}}}
            scene.timeline.world_revision += 1
            # Exercise the actual caller, not just overlay geometry/pixel output.
            # Height zero uses the background MultiMesh; raised support uses its
            # per-cell PlaneMesh. Neither may become a subject or block picking.
            scene.grid_visible = false
            scene._sort_draws()
            var pointer = scene.camera.unproject_position(Vector3(.49,height*Placement.HEIGHT_UNIT,0))
            var ground_hit = scene.pick_world(pointer)
            check(ground_hit.get("kind")=="ground" and ground_hit.get("position")==[0,0],"Grid-only scene has disclosed ground hit with G hidden")
            scene.grid_visible = true
            scene._sort_draws()
            check(scene.pick_world(pointer)==ground_hit,"G-visible background/raised overlay does not intercept actual pick_world")
            check(scene.pick_actor(pointer).is_empty(),"Ground overlay is never an actor pick")
            scene.ground_overlay.set_preview({"0,0":{"colour":Color(.8,.4,.8,.8),"width":2.0}})
            scene.grid_visible = false
            scene._sort_draws()
            check(scene.pick_world(pointer)==ground_hit,"Preview cell mark with G hidden preserves actual ground hit")
            scene.ground_overlay.set_preview({})
            for kind in ["wall","actor"]:
                var floor_entry = entry("terrain","terrain",Color(.1,.12,.15),height)
                var blocker = entry(kind,"body",Color(.1,.8,.15),height)
                scene.static_entries = [floor_entry] if kind == "actor" else [floor_entry,blocker]
                scene.actor_entries = [blocker] if kind == "actor" else []
                scene.static_order_dirty = true
                scene.draw_order_dirty = true
                scene.grid_visible = false
                var off = await capture()
                scene.grid_visible = true
                var on = await capture()
                compare_pixels(off,on,"height %s quarter %d %s" % [height,q,kind])
                scene.grid_visible = false
                var hidden = await capture()
                check(hidden.get_data()==off.get_data(),"G hide restores original pixels")
                scene.timeline.state.tiles["1,0"] = {"position":[1,0],"elevation_steps":height+1}
                scene.timeline.world_revision += 1
                var neighbour = entry("terrain","terrain",Color(.1,.12,.15),height+1)
                neighbour.id = "neighbour"
                neighbour.placement.id = "neighbour"
                neighbour.placement.position = [1,0]
                neighbour.node.position = Placement.contact(neighbour.placement)
                scene.static_entries.append(neighbour)
                scene.static_order_dirty = true
                var preview_off = await capture()
                var marks = {"0,0":{"colour":Color(.8,.4,.8,.8),"width":2.0,"fill_colour":Color(.8,.4,.8,.2)}}
                var outline_marks = marks.duplicate(true)
                outline_marks["0,0"].erase("fill_colour")
                scene.ground_overlay.set_preview(outline_marks,[[0,0],[1,0]],Color(.8,.4,.8))
                var outlines = await capture()
                scene.ground_overlay.set_preview(marks,[[0,0],[1,0]],Color(.8,.4,.8))
                var preview = await capture()
                compare_pixels(preview_off,preview,"preview with G hidden, height %s quarter %d %s" % [height,q,kind])
                check(filled_interior(outlines,preview,height),"Affected cell visibly fills interior beyond identical outline/path pixels")
                var held = await capture()
                check(held.get_data()==preview.get_data(),"Unchanged paused preview retains exact native pixels")
                var held_order: Array = scene.ground_overlay.ordered
                scene.timeline.state.tiles["0,0"].resolved_light = 4
                scene.timeline.state.tiles["1,0"].resolved_light = 0
                scene.timeline.world_revision += 1
                var relit = await capture()
                check(relit.get_data()==preview.get_data(),"Light-only support after-values preserve grid, fill and route pixels")
                check(is_same(held_order,scene.ground_overlay.ordered),"Light-only world revision reuses ground geometry and painter order")
                check(scene.actor_entries.size()==(1 if kind=="actor" else 0),"Ground UI does not enter actor ownership")
                scene.ground_overlay.set_preview({})
                scene.timeline.state.tiles.erase("1,0")
                scene.timeline.world_revision += 1
                var cleared = await capture()
                check(cleared.get_data()==preview_off.get_data(),"Clearing preview restores original wall/body/floor pixels")
                neighbour.node.free()
                floor_entry.node.free()
                blocker.node.free()
                scene.static_entries = []
                scene.actor_entries = []
                scene.static_order_dirty = true
                scene.draw_order_dirty = true
    # Optional before/after native witness against the frozen implementation.
    # The caller provides its local source snapshot; ordinary regression runs
    # retain no dependency on that temporary evidence directory.
    var before_path = ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--compare-before="): before_path = argument.trim_prefix("--compare-before=")
    if not before_path.is_empty():
        # Adapt only the added optional ledger argument/profile fields. The
        # frozen painter/geometry body remains the original pixel oracle.
        var before_script = GDScript.new()
        before_script.source_code = FileAccess.get_file_as_string(before_path).replace("background: bool) -> Array:","background: bool, _proof: Dictionary = {}) -> Array:")+"\nvar support_check_us = 0\nvar mark_update_us = 0\n"
        check(before_script.reload()==OK,"Frozen pixel oracle accepts passive optional support proof")
        var current_script = scene.ground_overlay.get_script()
        for q in range(4):
            scene.quarter=q;scene.camera_focus=Vector3.ZERO;scene.position_camera()
            var tiles={}
            var adjacent_marks={}
            var floors=[]
            for x in range(-1,2):
                for z in range(-1,2):
                    var key="%d,%d" % [x,z]
                    tiles[key]={"position":[x,z],"elevation_steps":0}
                    var colour=Color(.8,.4,.8,.8) if (x+z)%2==0 else Color(.4,.8,.6,.8)
                    adjacent_marks[key]={"colour":colour,"width":2.0,"fill_colour":Color(colour,.2)}
                    var floor_entry=entry("terrain","terrain",Color(.1,.12,.15),0)
                    floor_entry.id="floor:"+key;floor_entry.placement.id=floor_entry.id;floor_entry.placement.position=[x,z]
                    floor_entry.node.position=Placement.contact(floor_entry.placement);floors.append(floor_entry)
                    # This fixture draws ground planes, like the native ground
                    # batch, rather than pickable source-colour QuadMesh art.
                    floor_entry.batch_rows=[floor_entry.placement]
            var blocker=entry("actor","body",Color(.1,.8,.15),0)
            # Picking uses the same source-alpha/frame contract as actual art;
            # the opaque procedural blocker supplies a one-pixel colour source.
            blocker.texture_path="fixture:opaque-blocker"
            blocker.material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
            var opaque=Image.create(1,1,false,Image.FORMAT_RGBA8);opaque.fill(Color.WHITE)
            scene.source_images[blocker.texture_path]=opaque
            scene.actor_rows=[blocker.placement]
            scene.timeline.state={"tiles":tiles,"actors":{"actor":{"name":"Fixture actor"}},"objects":{}};scene.timeline.world_revision+=1
            scene.static_entries=floors;scene.actor_entries=[blocker];scene.grid_visible=true
            scene.ground_overlay.close();scene.ground_overlay=before_script.new()
            scene.ground_overlay.set_preview(adjacent_marks)
            scene.static_order_dirty=true;scene.draw_order_dirty=true
            var before=await capture()
            var single_style=adjacent_marks.duplicate(true)
            for style in single_style.values():
                style.colour=Color(.8,.4,.8,.8);style.fill_colour=Color(.8,.4,.8,.2)
            scene.ground_overlay.set_preview(single_style)
            var before_single_style=await capture()
            scene.ground_overlay.close();scene.ground_overlay=current_script.new()
            scene.ground_overlay.set_preview(adjacent_marks)
            scene.static_order_dirty=true;scene.draw_order_dirty=true
            var after=await capture()
            check(before.get_data()==after.get_data(),"Adjacent alternating-style fills preserve exact original native pixels in quarter %d" % q)
            check(scene.ground_overlay.mark_batches.size()==2,"Identical background styles share two batches in quarter %d" % q)
            var reserved_order:Array=scene.ground_overlay.ordered
            scene.ground_overlay.set_preview(single_style)
            var emptied=await capture()
            check(emptied.get_data()==before_single_style.get_data() and is_same(reserved_order,scene.ground_overlay.ordered),"Empty retained style preserves exact original pixels and painter ranks in quarter %d" % q)
            scene.ground_overlay.set_preview(adjacent_marks)
            var restored=await capture()
            check(restored.get_data()==before.get_data() and is_same(reserved_order,scene.ground_overlay.ordered),"Restored style preserves exact original pixels without world reordering in quarter %d" % q)
            var candidate=scene.ground_overlay
            # Keep this actual overlay alive across every sparse publication.
            # A fresh frozen renderer supplies the full-snapshot pixel oracle.
            for transition in ["remove","insert","raise","lower","remove","insert_two"]:
                var base_revision:int=scene.timeline.world_revision
                var changed_tiles={"1,1":true}
                if transition=="remove":tiles.erase("1,1")
                elif transition=="insert" or transition=="insert_two":
                    tiles["1,1"]={"position":[1,1],"elevation_steps":0}
                    if transition=="insert_two":
                        tiles["2,0"]={"position":[2,0],"elevation_steps":0};changed_tiles["2,0"]=true
                else:tiles["1,1"].elevation_steps=2 if transition=="raise" else 0
                scene.timeline.world_revision+=1
                scene.world_changes={"base_revision":base_revision,"revision":scene.timeline.world_revision,"tiles":changed_tiles,"full":false}
                scene.static_order_dirty=true;scene.draw_order_dirty=true
                var sparse_image=await capture()
                var expected_contacts=0 if transition=="remove" else (2 if transition=="insert_two" else 1)
                check(candidate.support_contact_updates==expected_contacts,"Sparse %s calculates only changed contacts in quarter %d"%[transition,q])
                var target=Vector3(1,2*Placement.HEIGHT_UNIT if transition=="raise" else 0,1) if transition!="remove" else Vector3(1,0,0)
                var mouse=scene.camera.unproject_position(target)
                var sparse_pick=scene.pick_world(mouse)
                var cell=scene.pick_cell(mouse)
                check(cell.get("position")==([1,0] if transition=="remove" else [1,1]) and cell.get("height")== (2 if transition=="raise" else 0),"Sparse %s keeps actual disclosed cell picking in quarter %d"%[transition,q])
                candidate.root.visible=false
                var full=before_script.new();scene.ground_overlay=full
                full.set_preview(adjacent_marks)
                scene.static_order_dirty=true;scene.draw_order_dirty=true
                var full_image=await capture()
                check(sparse_image.get_data()==full_image.get_data(),"Sparse %s matches original full-snapshot pixels in quarter %d"%[transition,q])
                check(scene.pick_world(mouse)==sparse_pick,"Sparse %s preserves original painter/picking ownership in quarter %d"%[transition,q])
                full.close();scene.ground_overlay=candidate;candidate.root.visible=true
                scene.static_order_dirty=true;scene.draw_order_dirty=true
            for floor_entry in floors:floor_entry.node.free()
            blocker.node.free();scene.static_entries=[];scene.actor_entries=[];scene.actor_rows=[]
            scene.static_order_dirty=true;scene.draw_order_dirty=true
    scene.timeline.state = {"tiles":{}}
    scene.timeline.world_revision += 1
    await capture()
    check(scene.ground_overlay.cells.is_empty() and scene.ground_overlay.routes.is_empty() and scene.ground_overlay.mark_batches.is_empty(),"Removed disclosed supports retire individual and batched overlays")
    scene.free()
    var report = {"checks":checks,"failures":failures,"ok":failures.is_empty(),"boundary":"native floor/grid/wall/body occlusion and actual pick_world/pick_actor, 4 camera quarters and 2 elevations"}
    var file = FileAccess.open("res://generated/hud_grid_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    file.close()
    print(JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
