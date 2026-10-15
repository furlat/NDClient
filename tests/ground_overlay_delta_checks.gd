extends SceneTree
# Dense preview boundary: native transforms, not an FPS or gameplay claim.
const Overlay=preload("res://presentation/ground_overlay.gd")
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("GROUND_DELTA_FAIL ",label)
func _initialize()->void:run.call_deferred()
func marks(offset:int)->Dictionary:
    var result={}
    for x in range(40):
        for y in range(30):
            var affected=x>=10+offset and x<17+offset and y>=10 and y<17
            result["%d,%d"%[x,y]]={"colour":Color(.9,.7,.3,.8) if affected else Color(.4,.8,.7,.45),"width":2.0,"fill_colour":Color(.9,.6,.2,.2) if affected else Color.TRANSPARENT}
    return result
func actual_positions(entry:Dictionary)->Dictionary:
    var result={}
    var multimesh:MultiMesh=entry.node.multimesh
    for i in range(multimesh.visible_instance_count):result[multimesh.get_instance_transform(i).origin]=true
    return result
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    var owner=Node3D.new();root.add_child(owner)
    var tiles={}
    for x in range(40):
        for y in range(30):tiles["%d,%d"%[x,y]]={"position":[x,y],"elevation_steps":0}
    var overlay=Overlay.new()
    overlay.set_preview(marks(0));overlay.sync(owner,tiles,1,false,0,true)
    var original_order:Array=overlay.ordered
    var original_allocations=overlay.buffer_allocations
    var writes=overlay.transform_writes
    overlay.set_preview(marks(1));overlay.sync(owner,tiles,1,false,0,true)
    check(not overlay.changed and is_same(overlay.ordered,original_order),"Changing positions within existing styles preserves painter order")
    check(overlay.buffer_allocations==original_allocations,"Moving49affectedcells reuses native buffers")
    check(overlay.transform_writes-writes<=28,"Moving a seven-cell edge writes at most28transforms, not1200")
    for entry in overlay.mark_batches.values() if DisplayServer.get_name()!="headless" else []:
        var positions=actual_positions(entry)
        check(positions.size()==entry.node.multimesh.visible_instance_count,"No stale or duplicate native instances are drawn")
        var filled:bool=entry.material.get_shader_parameter("fill_colour").a>0
        var expected={}
        for x in range(40):
            for y in range(30):
                if (x>=11 and x<18 and y>=10 and y<17)==filled:expected[Vector3(x,0,y)]=true
        check(positions==expected,"Native visible transforms exactly match that authored style's cells")
    var legal=marks(0)
    for style in legal.values():style.colour=Color(.4,.8,.7,.45);style.fill_colour=Color.TRANSPARENT
    overlay.set_preview(legal);overlay.sync(owner,tiles,1,false,0,true)
    check(not overlay.changed and is_same(overlay.ordered,original_order),"Temporarily empty affected style retains zero-instance painter slot")
    check(overlay.mark_batches.values().any(func(entry):return entry.node.multimesh.visible_instance_count==0),"Empty retained style draws zero native instances")
    overlay.set_preview(marks(0));overlay.sync(owner,tiles,1,false,0,true)
    check(not overlay.changed and overlay.buffer_allocations==original_allocations,"Restored affected style reuses reserved slot and capacity")
    var samples=[]
    var before_writes=overlay.transform_writes
    for i in range(100):
        var value=marks(i%2)
        overlay.set_preview(value)
        var began=Time.get_ticks_usec();overlay.sync(owner,tiles,1,false,0,true)
        samples.append((Time.get_ticks_usec()-began)/1000.)
    var prior=[]
    var oracle=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--before="):oracle=argument.trim_prefix("--before=")
    if not oracle.is_empty():
        var previous=load(oracle).new()
        previous.set_preview(marks(0));previous.sync(owner,tiles,1,false,0,true)
        for i in range(100):
            previous.set_preview(marks(i%2))
            var began=Time.get_ticks_usec();previous.sync(owner,tiles,1,false,0,true)
            prior.append((Time.get_ticks_usec()-began)/1000.)
        previous.close()
    overlay.set_preview({});overlay.sync(owner,tiles,1,false,0,true)
    check(overlay.mark_batches.is_empty() and overlay.ordered.is_empty(),"Clearing all marks retires retained style slots")
    var report={"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless","changed_transforms":overlay.transform_writes-before_writes,"full_rewrite_transforms":99*1200,"sync_ms":Profile.distribution(samples),"before_sync_ms":Profile.distribution(prior),"scope":"Isolated1200cell/49affected-cell synchronization; exact visible native transforms and bounded writes; not live FPS"}
    overlay.close();owner.free()
    FileAccess.open("res://.runtime/ground-overlay-delta-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("GROUND_OVERLAY_DELTA_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
