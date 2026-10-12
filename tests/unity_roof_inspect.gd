extends SceneTree
var w: Node
func _initialize() -> void: run.call_deferred()
func run() -> void:
    w=load("res://demo.tscn").instantiate();root.add_child(w)
    w.capturing=true;w.set_process_unhandled_input(false)
    w.camera_focus=Vector3(-5.5,0,24.5);w.update_camera(true,true)
    while w.view_pending:await process_frame
    for i in range(w.draw_order.size()):
        var e: Dictionary=w.draw_order[i]
        if e.placement.get("source_layer","")=="Roof2" or (e.placement.get("asset","").begins_with("fantasy.wall.c") and e.placement.position[1]>15):
            print("PIECE ",i," ",e.placement,"\nRECORD ",e.record.get("path")," pivot ",e.pivot," scale ",e.scale," node ",e.node.position," view ",w.camera.unproject_position(e.node.position)," sort ",e.node.sorting_offset)
        if not e.placement.get("roof",false):e.node.visible=false
    for batch in w.terrain_batches:batch.visible=false
    await w.save_capture("unity-roof-only")
    quit()
