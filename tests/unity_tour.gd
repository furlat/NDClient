extends SceneTree
var world: Node
var failures=0
func _initialize() -> void: run.call_deferred()
func run() -> void:
    world=load("res://demo.tscn").instantiate();root.add_child(world)
    world.capturing=true;world.set_process_unhandled_input(false)
    var selected=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--area="):selected=arg.trim_prefix("--area=")
    for area in [["camp",Vector2(-15,-4.75),2],["western-village",Vector2(-30,-11),2],["northern-terraces",Vector2(5.5,7.5),2],["southern-woodline",Vector2(15,-34.25),0],["eastern-terrace",Vector2(45.5,-23.5),0]]:
        if not selected.is_empty() and area[0]!=selected:continue
        var centre: Vector2=area[1];var height: float=area[2]
        world.camera_focus=Vector3(centre.x-2*centre.y+height,height*world.Placement.HEIGHT_UNIT,-centre.x-2*centre.y+height)
        world.camera.size=17 if area[0]=="camp" else 26
        for q in [0,1,2,3]:
            world.quarter=q;world.update_camera(true,true)
            while world.view_pending:await process_frame
            for i in range(120):await process_frame
            if not world.unresolved.is_empty():failures+=1
            await world.save_capture("tour-"+area[0]+"-q"+str(q))
    print("UNITY_TOUR failures=",failures)
    quit(1 if failures else 0)
