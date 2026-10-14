extends "res://tests/basic_condition_render_checks.gd"
## Same native Studio fixture boundary; source is the actual captured Frenzy occurrence.
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Use --recording=<actual Frenzy journal>");quit(2);return
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var rows=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("source_id")=="class.frenzy.ground")
    check(rows.size()==1,"Actual Frenzy has one owned native ground row")
    if rows.is_empty():await finish(studio);return
    var row:Dictionary=rows[0]
    var at:float=row.start_ms+400
    if not await seek(studio,at):await finish(studio);return
    studio.selected_row=row
    var original=studio.world.timeline.state.duplicate(true)
    for quarter in 4:
        if quarter!=studio.world.quarter:studio.world.request_view(quarter)
        if not await settle(studio):break
        var label="frenzy-q"+str(quarter)
        check(studio.world.component_renderer.handles.has(row.component.id),"Actual Frenzy native source prepared "+label)
        if not studio.world.component_renderer.handles.has(row.component.id):continue
        var handle:Dictionary=studio.world.component_renderer.handles[row.component.id]
        check(handle.node.record.palette.colors==["#78262b","#da393f","#f07b68"] and handle.node.record.properties.kind=="ground","Actual native source uses original Frenzy palette/ground mechanism "+label)
        var shown=await capture(studio,label+"-shown")
        studio._menu_selected(7)
        var plain=await capture(studio,label+"-muted")
        var changed=difference(shown,plain)
        check(changed>0,"Original native ground effect changes actual scene pixels "+label)
        studio._menu_selected(7)
        if not await settle(studio):break
        check(difference(shown,await capture(studio,label+"-restored"))==0,"Native source restores exact same-clock pixels "+label)
        check(studio.world.timeline.state==original and is_equal_approx(studio.world.timeline.display_ms,at),"Visual diagnostics do not mutate authoritative state/clock "+label)
        evidence.append({"quarter":quarter,"at_ms":at,"changed_pixels":changed,"source":row.source,"component_id":row.component.id})
    if await seek(studio,row.start_ms-.01):
        check(not studio.world.component_renderer.handles.has(row.component.id),"No ground effect before original100ms offset")
    if await seek(studio,row.end_ms+.01):
        check(not studio.world.component_renderer.handles.has(row.component.id),"No ground effect after original950ms occurrence lifetime")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Frenzy ground occurrence, existing original native ClassComponents, original Frenzy palette/timing, four-view pixels and exact mute restoration; no new source artwork."}
    FileAccess.open("res://generated/frenzy_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FRENZY_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
