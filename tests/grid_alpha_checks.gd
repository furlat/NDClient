extends SceneTree
const Grid=preload("res://grid_renderer.gd")
const Placement=preload("res://placement.gd")
var world: Node
var failures=0
func _initialize() -> void:run.call_deferred()
func capture() -> Image:
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    world=load("res://demo.tscn").instantiate();root.add_child(world)
    world.capturing=true;world.set_process_unhandled_input(false)
    world.exploration_ui.visible=false
    world.lamp.visible=false
    for entry in world.entries:entry.node.visible=false
    for view in world.gpu_grid.views:view.parent.visible=false
    var source={}
    for row in world.placements:
        if row.get("asset","")=="fantasy.tree.a1":source=row;break
    var slot: int=world.gpu_grid.row_slots[source.id]
    # Same translucent painting, three different tints, at a remote map point.
    # Compare [static prefix, dynamic middle, static suffix] against three
    # independent ordered MeshInstances. This checks actual source-over pixels.
    for q in range(4):
        world.quarter=q
        world.camera_focus=Vector3(81,0,-73);world.camera.size=5;world.position_camera()
        var view: Dictionary=world.gpu_grid.views[q]
        var index=-1
        for i in range(view.rows.size()):
            if view.rows[i]==slot and view.roles[i]==1:index=i;break
        var source_table: Image=load("res://generated/render_cache/instances-"+str(q)+".res").get_image()
        var item=source_table.get_pixel(index%256,index/256)
        var table=Image.create(256,1,false,Image.FORMAT_RGBAF)
        table.set_pixel(0,0,item);table.set_pixel(1,0,item)
        var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true
        multi.mesh=QuadMesh.new();multi.instance_count=2
        var position=world.camera_focus
        for i in range(2):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,position))
        var tints=[[1,0.2,0.2,0.55],[0.2,1,0.2,0.55],[0.2,0.2,1,0.55]]
        multi.set_instance_color(0,Color(1,0.2,0.2,0.55));multi.set_instance_color(1,Color(0.2,0.2,1,0.55))
        multi.custom_aabb=AABB(position-Vector3.ONE*5,Vector3.ONE*10)
        var passes=[]
        for r in range(2):
            var material: ShaderMaterial=view.blocks[0].node.material_override.duplicate()
            material.set_shader_parameter("instances",ImageTexture.create_from_image(table))
            material.set_shader_parameter("block_base",0)
            passes.append(Grid.make_pass(world,multi,material,r,r+1,0,Grid.SORT_SPACING))
        var reference=[]
        for i in range(3):
            var row: Dictionary=source.duplicate(true)
            row.id="alpha-check-"+str(i);row.position=[position.x,position.z];row.base_height_steps=0;row.tint=tints[i]
            var first=world.entries.size()
            world.add_environment_entries(row)
            for e in range(first,world.entries.size()):
                var entry: Dictionary=world.entries[e]
                world.initialize_entry(entry);entry.node.visible=false
                if entry.source_role==1:reference.append(entry.node)
        var physical_depth=(-world.camera.global_basis.z).dot(position)
        reference[1].visible=true
        reference[1].sorting_offset=Grid.SORT_SPACING+physical_depth
        var batched=await capture()
        for node in passes:node.visible=false
        for i in range(3):
            reference[i].visible=true
            reference[i].sorting_offset=i*Grid.SORT_SPACING+physical_depth
        var expected=await capture()
        var sum=0.0;var count=0;var visible=0
        for y in range(160,740,2):
            for x in range(430,1010,2):
                var a=batched.get_pixel(x,y);var b=expected.get_pixel(x,y)
                sum+=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));count+=1
                if b.g>0.08:visible+=1
        print("GRID_ALPHA q=",q," mean_error=",sum/count," painted_samples=",visible)
        if sum/count>0.005 or visible<500:
            failures+=1
            batched.save_png("res://.captures/alpha-batched-"+str(q)+".png")
            expected.save_png("res://.captures/alpha-reference-"+str(q)+".png")
        for node in passes:node.queue_free()
        for node in reference:node.visible=false
    print("GRID_ALPHA_CHECKS failures=",failures)
    quit(1 if failures else 0)
