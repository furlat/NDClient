extends SceneTree
# Isolated Control validation using unchanged combat text extracted from a real
# saved journal. No Player, backend, scene rendering or synthetic combat events.
const History = preload("res://ui/history_panel.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
class DisplayFeed extends RefCounted:
    var state = {"displayed":true}
    var queue: Array = []
    var trace_revision = 0
    var entries: Array = []
    func event_log(_limit: int) -> Dictionary: return {"entries":entries}
    func event_trace(_limit: int,_id: String = "",_filter: String = "") -> Dictionary:
        return {"events":[],"counts":{},"queued_events":0}
class Host extends Control:
    var world: Dictionary
var checks = 0
var failures: Array = []
var panel: PanelContainer
var feed = DisplayFeed.new()
var native_logs: Array = []
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
    checks += 1
    if not value: failures.append(message); push_error(message)
func collect(value: Variant) -> void:
    if value is Dictionary:
        if value.get("combat_log") != null: native_logs.append(value.combat_log)
        for child in value.values(): collect(child)
    elif value is Array:
        for child in value: collect(child)
func settle() -> void:
    await process_frame
    await process_frame
    await process_frame
func run() -> void:
    var args = OS.get_cmdline_user_args()
    var journal:String=Fixtures.journal("gallery") if args.is_empty() else args[0]
    var directory = DirAccess.open(journal)
    if directory == null: push_error("Journal not found"); quit(2); return
    var names = directory.get_files()
    names.sort()
    for name in names:
        if name.ends_with(".json"): collect(JSON.parse_string(FileAccess.get_file_as_string(journal.path_join(name))))
    if native_logs.is_empty(): push_error("Journal has no actual combat text"); quit(2); return
    root.size = Vector2i(1280,720)
    var host = Host.new()
    host.world = {"timeline":feed,"media_issue":"","session":{"issue":{},"latest_sequence":0},"notice_text":""}
    root.add_child(host)
    panel = History.new()
    panel.hud = host
    host.add_child(panel)
    panel.layout_in(Vector2(1280,720),634)
    panel.show_panel()
    await settle()
    check(panel.find_children("*","RichTextLabel",true,false).is_empty(),"Log has no separate bottom detail pane")
    check(not panel.summary.visible,"Ordinary combat view has no instructional header")
    var small_height = panel.size.y
    var count = mini(18,native_logs.size())
    for index in count:
        feed.entries.append({"id":str(index),"parent_id":"","depth":0,"entry":native_logs[index],"sequence":index,"source_index":index})
    feed.trace_revision += 1
    panel.refresh()
    await settle()
    check(panel.size.x<=370,"Default combat log stays narrow")
    check(is_equal_approx(panel.size.y,small_height) and panel.size.y>500,"Tall log geometry is independent of entry count")
    check(absf(panel.get_rect().end.y-634)<1,"Panel remains anchored above End Turn")
    check(panel.position.y>=17,"Tall log respects top screen margin")
    var copied = panel.copy_text()
    var selected = {}
    for row in feed.entries:
        if panel.detail_items.has(row.id): selected = row; break
    check(not selected.is_empty(),"Real recording supplies authored detailed roll text")
    if not selected.is_empty():
        var own = selected.entry.duplicate()
        own.sub_entries = []
        var inline_item: TreeItem = panel.detail_items[selected.id]
        check(inline_item.get_parent()==panel.items[selected.id],"Authored details are inline beneath their own event")
        check(inline_item.get_text(0)==panel._combat_text(own),"Inline detail preserves exact authored roll/math text")
        check(panel.items[selected.id].collapsed,"Detailed events start folded")
        panel.items[selected.id].select(0)
        await settle()
        check(not panel.items[selected.id].collapsed,"Selecting an event expands its inline math")
        var detail_rect = panel.tree.get_item_area_rect(inline_item,0)
        check(detail_rect.position.y>=0 and detail_rect.end.y<=panel.tree.size.y,"Expanded authored math is brought fully into view")
        check(panel.copy_text()==copied,"Expansion preserves full copied combat text")
        var one: TreeItem = panel.items[selected.id]
        check(one.get_text(0)==panel.plain_text(str(selected.entry.get("compact",selected.entry.get("verbose","")))),"Wrapped header preserves original compact text")
        var previous_height = panel.size.y
        one.collapsed = true
        await settle()
        check(one.collapsed,"Follow does not reopen a folded entry")
        one.collapsed = false
        await settle()
        check(is_equal_approx(panel.size.y,previous_height),"Expanding details never moves the fixed log")
    panel.layout_in(Vector2(360,340),220)
    await settle()
    check(Rect2(Vector2.ZERO,Vector2(360,340)).encloses(panel.get_rect()),"Small viewport bounds contain log and details")
    panel.selected_id = ""
    panel._details()
    panel.layout_in(Vector2(1280,720),634)
    await settle()
    var start_width = panel.size.x
    var press = InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
    press.position = panel.position+Vector2(3,panel.size.y/2)
    root.push_input(press,true)
    var motion = InputEventMouseMotion.new()
    motion.position = press.position-Vector2(80,0)
    root.push_input(motion,true)
    var release = press.duplicate()
    release.pressed = false; release.position = motion.position
    root.push_input(release,true)
    await settle()
    check(panel.size.x>start_width+50,"Native edge drag resizes anchored log")
    check(panel.copy_text()==copied,"Resizing preserves exact combat copy")
    panel.tabs.current_tab = 1
    await settle()
    check(panel.tree.columns==2 and panel.missing_only.visible,"Event diagnostics remain accessible")
    panel.tabs.current_tab = 0
    panel.preferred_width = 360
    panel.preferred_height = 0
    panel.selected_id = ""
    panel.revision = -1
    panel.refresh()
    panel.layout_in(Vector2(1280,720),634)
    await settle()
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.runtime/ui/history-panel-compact.png")
        for row in feed.entries:
            if row.entry.entry_type in ["attack","spell_save","spell_damage"]:
                panel.items[row.id].select(0)
                panel.tree.scroll_to_item(panel.items[row.id])
                break
        await settle()
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.runtime/ui/history-panel-selected.png")
    print(JSON.stringify({"checks":checks,"failures":failures,"native_logs":native_logs.size(),"rect":str(panel.get_rect()),"ok":failures.is_empty()}))
    quit(0 if failures.is_empty() else 1)
