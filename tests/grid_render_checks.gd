extends SceneTree
# Compare the native instanced source packets against the original single-sprite
# shader at the actual pixels, including packed depth/normal receiving light.
const Placement=preload("res://placement.gd")
var world: Node
var failures=0
var comparisons=[]
func _initialize() -> void:run.call_deferred()
func capture() -> Image:
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    world=load("res://demo.tscn").instantiate();root.add_child(world)
    world.capturing=true;world.set_process_unhandled_input(false)
    world.exploration_ui.visible=false
    for entry in world.entries:entry.node.visible=false
    for view in world.gpu_grid.views:
        view.parent.visible=false
        for block in view.blocks:
            block.node.visible=false
            for node in block.slices:node.visible=false
    world.lamp.visible=true
    for child in world.lamp.get_children():child.visible=false
    var targets=[]
    for asset in ["fantasy.wall.a2","fantasy.ground.g16","fantasy.chest.a3","fantasy.tree.a1"]:
        for row in world.placements:
            if row.get("asset","")==asset:targets.append(row);break
    for q in range(4):
        world.quarter=q
        var view: Dictionary=world.gpu_grid.views[q]
        view.parent.visible=true
        for row in targets:
            world.camera_focus=Placement.contact(row);world.camera.size=5
            world.position_camera()
            world.lamp.position=world.camera_focus+Vector3(-1.1,1.7,0.7)
            var slot: int=world.gpu_grid.row_slots[row.id]
            var index=-1
            for i in range(view.rows.size()):
                if view.rows[i]==slot and view.roles[i]==1:index=i;break
            assert(index>=0)
            var block: Dictionary=view.blocks[index/int(world.gpu_grid.manifest.block_size)]
            var local=index-block.base
            block.node.material_override.set_shader_parameter("range_start",local)
            block.node.material_override.set_shader_parameter("range_end",local+1)
            block.node.visible=true
            var batched=await capture()
            block.node.visible=false
            var first=world.entries.size()
            world.add_environment_entries(row)
            for i in range(first,world.entries.size()):
                world.initialize_entry(world.entries[i])
                world.entries[i].node.visible=world.entries[i].source_role==1
            var reference=await capture()
            var sum=0.0;var changed=0;var pixels=0;var largest=0.0
            for y in range(160,740,2):
                for x in range(430,1010,2):
                    var a=batched.get_pixel(x,y);var b=reference.get_pixel(x,y)
                    var error=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
                    sum+=error;pixels+=1;largest=maxf(largest,error)
                    if error>0.025:changed+=1
            var result={"asset":row.asset,"quarter":q,"mean_error":sum/pixels,"pixels_over_0.025":changed,"samples":pixels,"maximum":largest}
            comparisons.append(result)
            print("GRID_REFERENCE ",JSON.stringify(result))
            if sum/pixels>0.005 or changed>pixels*0.01:
                failures+=1
                batched.save_png("res://.captures/grid-difference-"+str(q)+"-"+row.asset+".png")
                reference.save_png("res://.captures/reference-difference-"+str(q)+"-"+row.asset+".png")
            for i in range(world.entries.size()-1,first-1,-1):
                world.entries[i].node.queue_free();world.entries.remove_at(i)
        view.parent.visible=false
    var file=FileAccess.open("res://generated/grid-reference-checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"comparisons":comparisons},"  "))
    print("GRID_RENDER_CHECKS failures=",failures)
    quit(1 if failures else 0)
