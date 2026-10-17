extends SceneTree
## Real recorded condition through the shared Studio renderer; no state injection.
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_CONDITION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var end=Time.get_ticks_msec()+120000
    while not ready(studio) and Time.get_ticks_msec()<end:await process_frame
    check(ready(studio),"Actual requested production view becomes ready")
    return ready(studio)
func capture(studio:Control,label:String)->PackedByteArray:
    await process_frame;await RenderingServer.frame_post_draw
    var image=studio.viewport.get_texture().get_image()
    image.save_png("res://.captures/studio/conditions/"+label+".png")
    return image.get_data()
func difference(a:PackedByteArray,b:PackedByteArray)->int:
    if a.size()!=b.size():return -1
    var changed=0
    for i in range(0,a.size(),4):
        if a[i]!=b[i] or a[i+1]!=b[i+1] or a[i+2]!=b[i+2] or a[i+3]!=b[i+3]:changed+=1
    return changed
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Usage: --recording=<actual journal with an initially active authored condition>");quit(2);return
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/conditions")
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var materials=studio.index.rows.filter(func(row):return row.kind=="condition_material" and row.start_ms==0)
    check(not materials.is_empty(),"Actual recording has an initial material condition component")
    if materials.is_empty():await finish(studio);return
    var row:Dictionary=materials[0]
    studio.selected_row=row
    var id:String=row.component.id
    var before=studio.world.timeline.state.duplicate(true)
    for quarter in 4:
        if quarter!=studio.world.quarter:studio.world.request_view(quarter)
        if not await settle(studio):break
        for capped in [false,true]:
            # In-memory cap, published as the light_cap global on the next
            # processed frame; avoid changing the human's persisted preference.
            studio.world.light_cap_enabled=capped
            studio.world.set_normals_visible(false)
            var label="q%s-cap%s"%[quarter,int(capped)]
            var coloured=await capture(studio,label+"-condition")
            studio._menu_selected(7)
            var plain=await capture(studio,label+"-muted")
            var visible=difference(coloured,plain)
            check(visible>0,"Recorded condition visibly changes lit body "+label)
            studio._menu_selected(7)
            check(difference(coloured,await capture(studio,label+"-restored"))==0,"Condition restoration preserves exact native pixels "+label)
            studio.world.set_normals_visible(true)
            var normals=await capture(studio,label+"-normals")
            studio._menu_selected(7)
            check(difference(normals,await capture(studio,label+"-normals-muted"))==0,"Condition material does not change receiving normal pixels "+label)
            studio._menu_selected(7)
            evidence.append({"quarter":quarter,"capped":capped,"changed_lit_pixels":visible,"condition_uuid":row.owner.id,"source":row.source})
    check(studio.world.timeline.state==before and studio.world.timeline.display_ms==0,"Diagnostic views retain original authoritative state and clock")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual initial recorded condition, four views and cap modes; native normal invariance, lit material response and exact restoration. Does not qualify every condition recipe."}
    FileAccess.open("res://generated/studio_condition_preview_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_CONDITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
