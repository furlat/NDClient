extends Control
const Recording = preload("res://studio/recording.gd")
const RecordingMedia = preload("res://studio/recording_media.gd")
const Play = preload("res://play.gd")
const TimelineView = preload("res://studio/timeline_view.gd")
const SourceInventory=preload("res://studio/source_inventory.gd")
const LightTracks=preload("res://studio/light_tracks.gd")
const LightLevels=preload("res://studio/light_levels.gd")
const CaseLibrary=preload("res://studio/case_library.gd")
const StudyLibrary=preload("res://studio/study_library.gd")
const ViewportLayout=preload("res://studio/viewport_layout.gd")
const ReplayPanes=preload("res://studio/replay_panes.gd")
const BackgroundRelease=preload("res://presentation/background_release.gd")
const ConditionCoverage=preload("res://presentation/condition_coverage.gd")
const Effects=preload("res://presentation/effect_package.gd")
const CapabilityReport=preload("res://studio/capability_report.gd")
## Inspect menu ids of the "Effect version" choices (Effects.KINDS order).
const EFFECT_VERSION_IDS:={16:"recorded",17:"gpu",18:"native"}
var world: Node3D
var viewport: SubViewport
var preview: TextureRect
var preview_row:HBoxContainer
var pane_label:Label
var fps_label:Label
var fps_update_ms=0
var replay_budget_bytes=0
var replay_plan:Dictionary={}
var replay_wait_frames=0
var replay_publications=0
var split: VSplitContainer
var tracks: Control
var candidate_tracks:Control
var candidate_preview_errors:Array=[]
var candidate_preview_pending=0
var timeline_split:HSplitContainer
var status: Label
var clock_label: Label
var play_button: Button
var rate_picker:OptionButton
var case_picker: OptionButton
var capability_picker:OptionButton
var interaction_picker:OptionButton
var perspective_picker:OptionButton
var case_records:Array=[]
var browser_cases:Array=[]
var active_case:Dictionary={}
var active_perspective=""
var case_bundle:Dictionary={}
var pending_bundle:Dictionary={}
var pending_perspective=""
var pending_perspective_navigation:Dictionary={}
var pending_case_request:Dictionary={}
var pending_selected_id=""
var retained_view_anchor:Dictionary={}
var diagnostic_menu: PopupMenu
var source_inventory:Window
var study_library:Window
var study_capability:Dictionary={}
var study_scenario:Dictionary={}
var pending_study_selection:Dictionary={}
var pending_autoplay=false
var pending_authoring_reload=false
var study_panel:VBoxContainer
var study_tree:Tree
var study_title:Label
var study_button:Button
var inspector: Window
var inspector_text: TextEdit
var inspected_row:Dictionary={}
var inspector_row_text=""
var inspector_update_usec=0
var file_dialog: FileDialog
var index: Dictionary = {}
var loader: Thread
var seeker: Thread
var requested_seek = -1.0
var seek_generation = 0
var worker_generation = 0
var installing = false
var installation_generation = -1
var resume_after_install = false
var active_directory = ""
var pending_directory = ""
var selected_row: Dictionary = {}
var loop_enabled = true
var follow_tracks=true
var follow_actor_id=""
var initial_view_size=0.0
var loop_button:CheckButton
var follow_button:CheckButton
var preparing_loop=false
var prepared_loop_range=Vector2.ZERO
var transport_measurements:Array=[]
var startup_receipt:Dictionary={}
var startup_setup:Dictionary={}
var opened_usec=Time.get_ticks_usec()
var preparation_measurement:Dictionary={}
var frozen_candidate_viewports:Array=[]
var spare_viewport:SubViewport
var spare_world:Node3D
var spare_index:Dictionary={}
var frozen_spare_viewports:Array=[]
var scrub_target=-1.0
var loop_start = 0.0
var loop_end = 0.0
var last_drag = Vector2.ZERO
var case_paths: Array = []
var last_status = ""
var loader_token: Dictionary={}
var seeker_token: Dictionary={}
var pending_index: Dictionary={}
var candidate_world: Node3D
var candidate_viewport: SubViewport
var candidate_index: Dictionary={}
var candidate_budget=0
var bottom: VBoxContainer
var divider_ratio=.5
var maximized=false
var markers: Control
var light_levels:Control
var light_levels_button:CheckButton
var inspector_mode="row"
var inspector_log_revision=-1
const CONFIG="user://studio_layout.cfg"
const WINDOW_TITLE="Neurodragon Studio · Presentation studies"

class MarkerOverlay extends Control:
    var host: Node
    func _draw()->void:
        if host==null or host.world==null:return
        var row: Dictionary=host.selected_row
        var data: Dictionary=row.get("track",row.get("component",{}))
        for id in [data.get("actor_uuid"),data.get("target_uuid")]:
            var actor: Dictionary=host.world.visual_actors.get(id,{})
            if actor.is_empty():continue
            var point=host.world.camera.unproject_position(Play.Placement.contact(actor.row))
            draw_arc(point,10,0,TAU,24,Color("f3be66"),2)
            draw_line(point-Vector2(15,0),point+Vector2(15,0),Color("f3be66"))
            draw_line(point-Vector2(0,15),point+Vector2(0,15),Color("f3be66"))

func _ready() -> void:
    var ready_started=Time.get_ticks_usec()
    # Paint controls after the single Play child has advanced its recorded frame.
    process_priority=10
    DisplayServer.window_set_title(WINDOW_TITLE)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop = ColorRect.new(); backdrop.color=Color("101722"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)
    var layout = VBoxContainer.new(); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layout.add_theme_constant_override("separation",2); add_child(layout)
    var header = HBoxContainer.new(); layout.add_child(header)
    _button(header,"Library",_show_study_library).tooltip_text="Authored capabilities, current cases and presentation gaps"
    capability_picker=_picker(header,"Capability",160);capability_picker.item_selected.connect(_choose_capability)
    interaction_picker=_picker(header,"Interaction",150);interaction_picker.item_selected.connect(_choose_interaction)
    case_picker=_picker(header,"Recorded case",150);case_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;case_picker.item_selected.connect(_choose_case)
    perspective_picker=_picker(header,"Recorded faction / audience",86);perspective_picker.disabled=true
    perspective_picker.item_selected.connect(func(i):select_perspective(str(perspective_picker.get_item_metadata(i))))
    _button(header,"Open",func():file_dialog.popup_centered_ratio(.7)).tooltip_text="Open a recorded journal"
    _button(header,"Reload",_reload_authoring).tooltip_text="Reload external authoring and freshly baked native sources"
    _button(header,"Q / E",func():_rotate(1)).tooltip_text="Rotate preview"
    var menu=MenuButton.new();menu.text="Inspect";header.add_child(menu)
    for label in ["Inspector","Displayed log","Coverage","Copy report","Maximize preview","Toggle markers"]:menu.get_popup().add_item(label)
    menu.get_popup().add_check_item("Show metadata",6)
    diagnostic_menu=menu.get_popup()
    diagnostic_menu.add_check_item("Mute selected component",7)
    diagnostic_menu.add_check_item("Solo selected component",8)
    diagnostic_menu.add_item("Clear component diagnostics",9)
    diagnostic_menu.add_item("Authored sources / missing work",10)
    diagnostic_menu.add_item("Study sequence / expectations",11)
    diagnostic_menu.add_check_item("Full spell hit material",12)
    diagnostic_menu.add_check_item("Follow active track",13)
    diagnostic_menu.add_check_item("Follow selected actor",14)
    diagnostic_menu.add_check_item("Lighting tracks",15)
    for id in EFFECT_VERSION_IDS:diagnostic_menu.add_radio_check_item("Effect version: "+Effects.LABELS[EFFECT_VERSION_IDS[id]],id)
    diagnostic_menu.about_to_popup.connect(_diagnostic_menu_state)
    menu.get_popup().id_pressed.connect(func(id):
        if id==13:
            _set_follow_tracks(not follow_tracks)
            return
        if id==15:
            tracks.show_lighting_tracks=not tracks.show_lighting_tracks;tracks.rebuild_rows()
            menu.get_popup().set_item_checked(15,tracks.show_lighting_tracks)
            return
        if id==14:
            follow_actor_id="" if not follow_actor_id.is_empty() else _actor_for_row(selected_row)
            return
        if EFFECT_VERSION_IDS.has(id):
            set_effect_version(EFFECT_VERSION_IDS[id])
            return
        _menu_selected(id)
        if id==6:menu.get_popup().set_item_checked(6,tracks.show_metadata))
    split=VSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; layout.add_child(split)
    preview_row=HBoxContainer.new();preview_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview_row.add_theme_constant_override("separation",3);split.add_child(preview_row)
    preview=TextureRect.new();preview.clip_contents=true;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_SCALE
    preview.custom_minimum_size=Vector2(240,160);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview.focus_mode=Control.FOCUS_ALL;preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview_row.add_child(preview)
    viewport=_viewport();add_child(viewport);preview.texture=viewport.get_texture();viewport.audio_listener_enable_3d=true
    var play_started=Time.get_ticks_usec()
    world=Play.new(); world.external_playback=true; world.native_startup_plan=[]; viewport.add_child(world);_listener(world)
    startup_setup.play_ready_ms=(Time.get_ticks_usec()-play_started)/1000.0
    replay_budget_bytes=world.media_warmup.budget_bytes
    preview.gui_input.connect(_preview_input)
    pane_label=_pane_label(preview)
    light_levels=LightLevels.new();light_levels.host=self;light_levels.visible=false
    light_levels.level_source=_light_marker_level;light_levels.legend_label="Perceived light"
    preview.add_child(light_levels)
    markers=MarkerOverlay.new();markers.host=self;markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.add_child(markers)
    bottom=VBoxContainer.new(); bottom.custom_minimum_size.y=180; bottom.size_flags_vertical=Control.SIZE_EXPAND_FILL; split.add_child(bottom)
    var transport=HBoxContainer.new(); bottom.add_child(transport)
    play_button=_button(transport,"Play",_toggle_play)
    study_button=_button(transport,"Study",func():study_panel.visible=not study_panel.visible)
    study_button.disabled=true;study_button.tooltip_text="Expected phases and participants for the selected study"
    _button(transport,"|◀",_play_study).tooltip_text="Play the complete study from its initial state"
    _button(transport,"‹ sample",func(): _step(-1))
    _button(transport,"sample ›",func(): _step(1))
    rate_picker=OptionButton.new(); transport.add_child(rate_picker)
    for value in [.25,.5,1.0,2.0,4.0]:rate_picker.add_item(str(value)+"×")
    rate_picker.select(2);rate_picker.item_selected.connect(func(i):world.playback_speed=[.25,.5,1.0,2.0,4.0][i])
    loop_button=CheckButton.new();loop_button.text="Loop";loop_button.button_pressed=loop_enabled;transport.add_child(loop_button);loop_button.toggled.connect(func(value):loop_enabled=value)
    _add_follow_control(transport)
    _button(transport,"In",func(): loop_start=world.timeline.display_ms)
    _button(transport,"Out",func(): loop_end=world.timeline.display_ms)
    clock_label=Label.new(); clock_label.custom_minimum_size.x=160; transport.add_child(clock_label)
    light_levels_button=CheckButton.new();light_levels_button.text="Light levels";transport.add_child(light_levels_button)
    light_levels_button.tooltip_text="Current faction perception; includes darkvision. Not inferred from rendered brightness."
    light_levels_button.toggled.connect(func(value):light_levels.visible=value)
    _button(transport,"Fit",func(): tracks.fit())
    _button(transport,"−",func(): tracks.fit_enabled=false;tracks.pixels_per_second=maxf(8,tracks.pixels_per_second/1.4); tracks.queue_redraw())
    _button(transport,"+",func(): tracks.fit_enabled=false;tracks.pixels_per_second=minf(1600,tracks.pixels_per_second*1.4); tracks.queue_redraw())
    var search=LineEdit.new(); search.placeholder_text="Filter tracks"; search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; transport.add_child(search)
    search.text_changed.connect(func(value): tracks.filter=value; tracks.rebuild_rows())
    timeline_split=HSplitContainer.new();timeline_split.size_flags_vertical=Control.SIZE_EXPAND_FILL;bottom.add_child(timeline_split)
    tracks=TimelineView.new(); tracks.size_flags_vertical=Control.SIZE_EXPAND_FILL;tracks.size_flags_horizontal=Control.SIZE_EXPAND_FILL;timeline_split.add_child(tracks)
    study_panel=VBoxContainer.new();study_panel.custom_minimum_size.x=300;study_panel.visible=false;timeline_split.add_child(study_panel)
    var study_header=HBoxContainer.new();study_panel.add_child(study_header)
    study_title=Label.new();study_title.clip_text=true;study_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;study_header.add_child(study_title)
    _button(study_header,"…",_show_study_library).tooltip_text="Full sequence, sources and recording gaps"
    _button(study_header,"×",func():study_panel.hide()).tooltip_text="Hide study expectations"
    study_tree=Tree.new();study_tree.hide_root=true;study_tree.size_flags_vertical=Control.SIZE_EXPAND_FILL;study_panel.add_child(study_tree)
    study_tree.item_selected.connect(_inspect_study_expectation)
    _connect_tracks(tracks)
    var status_row=HBoxContainer.new();layout.add_child(status_row)
    status=Label.new();status.clip_text=true;status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    status.text="Choose a current SDK recording.";status_row.add_child(status)
    fps_label=Label.new();fps_label.name="FrameRate";fps_label.text="— FPS · — ms"
    fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;fps_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    fps_label.add_theme_font_size_override("font_size",20)
    fps_label.add_theme_color_override("font_color",Color.WHITE)
    fps_label.add_theme_color_override("font_outline_color",Color(0,0,0,.95))
    fps_label.add_theme_constant_override("outline_size",5)
    preview.add_child(fps_label);fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    fps_label.offset_left=-235;fps_label.offset_right=-12;fps_label.offset_top=10;fps_label.offset_bottom=40
    fps_label.z_index=10
    inspector=Window.new(); inspector.visible=false; inspector.title="Presentation inspector"; inspector.size=Vector2i(780,540); inspector.close_requested.connect(func(): inspector.hide()); add_child(inspector)
    inspector_text=TextEdit.new(); inspector_text.editable=false; inspector_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); inspector.add_child(inspector_text)
    file_dialog=FileDialog.new(); file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR; file_dialog.access=FileDialog.ACCESS_FILESYSTEM; add_child(file_dialog); file_dialog.dir_selected.connect(_load)
    split.dragged.connect(func(_offset):
        if not maximized:divider_ratio=clampf(preview.size.y/maxf(1,split.size.y),.15,.85);_save_layout())
    resized.connect(func():_apply_layout.call_deferred())
    var config=ConfigFile.new()
    if config.load(CONFIG)==OK:divider_ratio=clampf(config.get_value("layout","divider",.5),.15,.85)
    _apply_layout.call_deferred()
    var discovery_started=Time.get_ticks_usec()
    _discover_cases()
    startup_setup.case_discovery_ms=(Time.get_ticks_usec()-discovery_started)/1000.0
    var args=OS.get_cmdline_user_args()
    if "--follow-tracks" in args:_set_follow_tracks(true)
    var directory=""
    for i in args.size():
        if args[i].begins_with("--recording="):directory=args[i].trim_prefix("--recording=")
        elif args[i]=="--recording" and i+1<args.size(): directory=args[i+1]
        elif args[i].begins_with("--follow-actor="):follow_actor_id=args[i].trim_prefix("--follow-actor=")
        elif args[i].begins_with("--view-size="):
            var value=args[i].trim_prefix("--view-size=")
            if value.is_valid_float():initial_view_size=clampf(value.to_float(),3,100)
    if directory.is_empty() and not case_paths.is_empty(): directory=case_paths[0]
    if not directory.is_empty():
        _select_browser_path(directory)
        _load(directory,{},"--autoplay" in args)
    if "--library" in args:_show_study_library.call_deferred()
    startup_setup.ready_ms=(Time.get_ticks_usec()-ready_started)/1000.0
    # The embedded Play scene sets its own title during _ready.
    DisplayServer.window_set_title(WINDOW_TITLE)

func _add_follow_control(transport:HBoxContainer)->void:
    follow_button=CheckButton.new();follow_button.text="Follow"
    follow_button.tooltip_text="Keep the active recorded track visible during playback"
    transport.add_child(follow_button);follow_button.toggled.connect(_set_follow_tracks)
    _set_follow_tracks(follow_tracks)

func _set_follow_tracks(value:bool)->void:
    follow_tracks=value
    if follow_button!=null:follow_button.set_pressed_no_signal(value)
    if diagnostic_menu!=null:diagnostic_menu.set_item_checked(diagnostic_menu.get_item_index(13),value)

func _follow_displayed_track()->void:
    if not follow_tracks or scrub_target>=0 or tracks.drag_playhead:return
    # Preparing a hidden loop candidate does not stop the displayed world.
    # Explicit seeks retain the selected row until their new frame publishes.
    if installing and not preparing_loop and world.timeline.paused:return
    tracks.follow_at(world.timeline.display_ms)

func _connect_tracks(view:Control)->void:
    view.preparation_admission=world.preparation_admission
    view.process_priority=process_priority+1
    view.seek_requested.connect(_seek);view.selected.connect(_select_row)
    view.scrub_requested.connect(_scrub);view.clip_requested.connect(_play_clip)
    view.perspective_requested.connect(func(row):selected_row=row;select_perspective(str(row.source_perspective)))

func _stage_tracks(source:Dictionary)->void:
    if is_same(source,index):return
    candidate_preview_errors=[]
    candidate_tracks=TimelineView.new();candidate_tracks.preparation_admission=world.preparation_admission;candidate_tracks.hide()
    candidate_tracks.size_flags_vertical=Control.SIZE_EXPAND_FILL
    candidate_tracks.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    timeline_split.add_child(candidate_tracks);candidate_tracks.size=tracks.size
    candidate_tracks.gutter=tracks.gutter;candidate_tracks.quarter=world.quarter
    candidate_tracks.filter=tracks.filter;candidate_tracks.show_metadata=tracks.show_metadata
    candidate_tracks.show_lighting_tracks=tracks.show_lighting_tracks
    candidate_tracks.set_index(source)
    for row in source.rows:
        if row.id==pending_selected_id:candidate_tracks.reveal(row.id);break
    _connect_tracks(candidate_tracks)

var _light_marker_input:Dictionary={}
var _light_marker_values:Dictionary={}

func _light_marker_level(_tile:Dictionary,cell:String,state:Dictionary)->Variant:
    # The SDK supplies the current faction aggregate, including darkvision.
    # Tile.resolved_light may be an older observation; never substitute it.
    var senses:Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    var values:Dictionary=senses.get("effective_light_levels",{})
    if not is_same(values,_light_marker_input):
        _light_marker_input=values
        _light_marker_values=preload("res://sdk/fold_cells.gd").values_map(values)
    return _light_marker_values.get(cell)

func _button(parent: Node, label: String, action: Callable) -> Button:
    var button=Button.new(); button.text=label; button.pressed.connect(action); parent.add_child(button); return button

func _menu_selected(id: int)->void:
    match id:
        0:_show_inspector(selected_row)
        1:_show_log()
        2:_show_coverage()
        3:_copy_report()
        4:_maximize()
        5:markers.visible=not markers.visible
        6:tracks.show_metadata=not tracks.show_metadata;tracks.rebuild_rows()
        7,8:
            var component_id=_diagnostic_id()
            if component_id.is_empty():return
            var owner=_row_world(selected_row)
            var values:Dictionary=owner.presentation_mutes if id==7 else owner.presentation_solo
            if values.has(component_id):values.erase(component_id)
            else:values[component_id]=true
            _diagnostic_menu_state()
        9:
            world.presentation_mutes.clear();world.presentation_solo.clear()
            _diagnostic_menu_state()
        10:_show_source_inventory()
        11:_show_study_library()
        12:
            world.set_native_spell_hit_material(not world.native_spell_hit_material)

func _show_study_library()->void:
    if study_library==null:
        study_library=StudyLibrary.new();add_child(study_library)
        study_library.recording_selected.connect(_open_study_recording)
        study_library.recording_unavailable.connect(_cancel_case_selection)
        study_library.failed_prefix_selected.connect(_inspect_failed_prefix)
    world.timeline.paused=true
    study_library.open(index.get("cache",{}),case_records,study_capability.get("key",study_capability.get("id","")),study_scenario.get("id",""))

func _open_study_recording(capability:Dictionary,scenario:Dictionary,record:Dictionary)->void:
    select_case(record,"",{"capability":capability,"scenario":scenario})

func _inspect_failed_prefix(capability:Dictionary,scenario:Dictionary,record:Dictionary,perspective_id:String)->void:
    if record.get("ready",false) or record.get("scenario_status") not in ["failed","stale"]:return
    for perspective in record.get("perspectives",[]):
        if str(perspective.id)==perspective_id:
            _load(perspective.journal,{"capability":capability,"scenario":scenario},false);return
    # The selected initialization may have appeared after the catalog was
    # read. failed_prefix validated that original journal-derived candidate;
    # the ordinary reader still admits the complete current prefix.
    var journal:String=str(record.get("journals",{}).get(perspective_id,""))
    if not journal.is_empty():_load(journal,{"capability":capability,"scenario":scenario},false)

func _show_study_expectations()->void:
    study_tree.clear();var root_item=study_tree.create_item()
    var moments:Array=index.get("moments",[])
    study_button.disabled=study_scenario.is_empty() and moments.is_empty();study_panel.hide()
    study_title.text=study_scenario.get("label","");study_title.tooltip_text=study_title.text
    if not moments.is_empty():
        var group=study_tree.create_item(root_item);group.set_text(0,"Recorded moments");group.set_selectable(0,false)
        for moment in moments:
            if not moment.get("available",false):continue
            var item=study_tree.create_item(group);item.set_text(0,str(moment.get("label",moment.get("kind","Event"))))
            item.set_selectable(0,moment.get("available",false));item.set_tooltip_text(0,moment.get("reason","Jump to the actual recorded event"))
            var metadata:Dictionary=moment.duplicate();metadata.recorded_moment=true;item.set_metadata(0,metadata)
    var phases={}
    for expected in study_scenario.get("expectations",[]):
        var phase:String=expected.get("phase","")
        if not phases.has(phase):
            var group=study_tree.create_item(root_item);group.set_text(0,phase.capitalize()+" · expected");group.set_selectable(0,false);phases[phase]=group
        var item=study_tree.create_item(phases[phase]);item.set_text(0,str(expected.label))
        item.set_tooltip_text(0,", ".join(expected.get("participants",[]))+"\n"+str(expected.label)+"\nExpected presentation; not a claim of implementation or recorded timing.")
        item.set_metadata(0,expected)

func _inspect_study_expectation()->void:
    var item=study_tree.get_selected()
    if item==null:return
    var expected:Dictionary=item.get_metadata(0)
    if expected.get("recorded_moment",false):
        if expected.get("available",false):_seek(expected.at_ms);tracks.reveal(expected.row_id)
        return
    inspector_mode="study"
    inspector.title="Study expectation · "+str(expected.label)
    var lines:Array[String]=[str(expected.label),"Phase: "+str(expected.get("phase","")),"Participants: "+", ".join(expected.get("participants",[])),"", "This is an expected observation. Recording presence, authoring assignment and rendered qualification are separate.",""]
    for pointer in expected.get("authoring_sources",[])+expected.get("rule_sources",[]):lines.append(str(pointer))
    inspector_text.text="\n".join(lines);inspector.popup_centered()

static func _actor_for_row(row:Dictionary)->String:
    for value in [row.get("recipient_uuid"),row.get("actor_uuid"),row.get("track",{}).get("actor_uuid")]:
        if value!=null and not str(value).is_empty():return str(value)
    var component:Dictionary=row.get("component",{})
    if not str(component.get("native_cue",{}).get("attachment","")).begins_with("caster") and component.get("target_uuid")!=null:
        return str(component.target_uuid)
    return str(component.actor_uuid) if component.get("actor_uuid")!=null else ""

func _diagnostic_id()->String:
    if selected_row.get("kind") not in ["native_effect","native_material","native_light","sprite_layer","material_flash","damage_number","audio","condition_material"]:return ""
    var component:Dictionary=selected_row.get("component",{})
    # Actual inspection channels can belong to either a spell occurrence or
    # a native-hit material presenter; native_spell is not their eligibility.
    if selected_row.get("kind") in ["native_light","native_material"] and component.get("kind")==selected_row.kind:
        return str(component.get("parent_id",""))
    if component.get("kind") not in ["native_effect","sprite_layer","material_flash","damage_number","audio","condition"] and not component.get("native_spell",false):return ""
    # Direct presenters retain their own draw ID even when parented by an event.
    return str(component.get("id",""))

func _diagnostic_menu_state()->void:
    var id=_diagnostic_id()
    var owner=_row_world(selected_row)
    diagnostic_menu.set_item_disabled(7,id.is_empty());diagnostic_menu.set_item_disabled(8,id.is_empty())
    diagnostic_menu.set_item_checked(7,not id.is_empty() and owner.presentation_mutes.has(id))
    diagnostic_menu.set_item_checked(8,not id.is_empty() and owner.presentation_solo.has(id))
    var cleared=world.presentation_mutes.is_empty() and world.presentation_solo.is_empty()
    diagnostic_menu.set_item_disabled(9,cleared)
    diagnostic_menu.set_item_checked(12,world.native_spell_hit_material)
    diagnostic_menu.set_item_checked(15,tracks.show_lighting_tracks)
    diagnostic_menu.set_item_checked(13,follow_tracks)
    diagnostic_menu.set_item_checked(14,not follow_actor_id.is_empty())
    diagnostic_menu.set_item_disabled(14,follow_actor_id.is_empty() and _actor_for_row(selected_row).is_empty())
    for version in EFFECT_VERSION_IDS:diagnostic_menu.set_item_checked(diagnostic_menu.get_item_index(version),EFFECT_VERSION_IDS[version]==(Effects.requested if not Effects.requested.is_empty() else "recorded"))

## Plays every spell effect from this approach kind where its clip has one
## (others fall back, see the effect row). The displayed occurrences are
## rebuilt at the current playhead by an ordinary prepared seek.
func set_effect_version(kind:String)->void:
    if kind==(Effects.requested if not Effects.requested.is_empty() else "recorded"):return
    Effects.set_requested(kind)
    if not index.is_empty():_seek(world.timeline.display_ms,false,false,true)

func _follow_position(owner:Node3D,fallback:Vector3)->Vector3:
    if follow_actor_id.is_empty():return fallback
    var actor:Dictionary=owner.visual_actors.get(follow_actor_id,{})
    # A retained actor can be undisclosed in this audience. Never track its
    # remembered location or borrow a position from the other replay pane.
    for entry in actor.get("entries",[]):
        if entry.role!="shadow" and entry.node.visible:
            return Play.Placement.contact(actor.row)
    return fallback

func _viewport() -> SubViewport:
    return ReplayPanes.viewport()

func _pane_label(parent:Control)->Label:
    var label=Label.new();label.position=Vector2(8,6);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
    parent.add_child(label);return label

func _perspective_label(id:String)->String:
    for value in case_bundle.get("perspectives",[]):
        if str(value.id)==id:return str(value.label)
    return id

func _sync_audio()->void:
    viewport.audio_listener_enable_3d=true
    world.component_renderer.audio.set_enabled(true)
    pane_label.text=_perspective_label(active_perspective)

func _row_world(_row:Dictionary)->Node3D:
    return world

func _cancel_replay_advance()->void:
    replay_plan={}
    world.timeline.replay_cancel_preparation()

func advance_review_to(target_ms:float)->bool:
    # Offline capture prepares and publishes a bounded target through the
    # recorded reducer; it cannot assign its display clock directly.
    world.external_clock=true
    world.timeline.paused=true
    _advance_replay_owners(minf(target_ms,index.presentation_end_ms))
    return is_equal_approx(world.timeline.display_ms,target_ms)

func _advance_replay_owners(target:float)->void:
    if replay_plan.is_empty():replay_plan=world.timeline.replay_plan(target)
    if not world.timeline.replay_prepare(replay_plan):
        replay_wait_frames+=1;return
    if not world.can_publish_replay_advance(replay_plan):
        _cancel_replay_advance();return
    world.publish_replay_advance(replay_plan)
    replay_plan={};replay_publications+=1

func replay_diagnostics()->Dictionary:
    return {"comparison":false,"panes":[{"perspective_id":active_perspective,"time_ms":world.timeline.display_ms,
        "sequence":world.timeline.sequence,"world_revision":world.timeline.world_revision,
        "audio_enabled":world.component_renderer.audio.enabled,"session_active":world.session!=null,
        "media_budget_bytes":world.media_warmup.budget_bytes}],"listening_perspective":active_perspective,
        "waiting":not replay_plan.is_empty(),"wait_frames":replay_wait_frames,"publications":replay_publications,
        "candidate_panes":1 if candidate_world!=null else 0,"spare_panes":1 if spare_world!=null else 0}

func _listener(owner: Node3D)->void:
    # Isometric camera distance controls framing, not listening distance.
    var listener=AudioListener3D.new();listener.name="StudioAudioListener"
    owner.add_child(listener);listener.make_current()
    _sync_listener(owner)

func _sync_listener(owner:Node3D)->void:
    var listener:AudioListener3D=owner.get_node("StudioAudioListener")
    listener.position=owner.camera_focus+Vector3.UP
    listener.basis=owner.camera.basis

func _save_layout()->void:
    var config=ConfigFile.new();config.set_value("layout","divider",divider_ratio);config.save(CONFIG)

func _apply_layout()->void:
    if split==null or maximized:return
    split.split_offset=int((divider_ratio-.5)*split.size.y)

func _maximize()->void:
    maximized=not maximized;bottom.visible=not maximized
    if not maximized:_apply_layout.call_deferred()

func _picker(parent:Node,hint:String,width:float)->OptionButton:
    var picker=OptionButton.new();picker.clip_text=true;picker.fit_to_longest_item=false;picker.custom_minimum_size.x=width;picker.allow_reselect=true
    picker.tooltip_text=hint;parent.add_child(picker);return picker

func _discover_cases() -> void:
    case_records=CaseLibrary.read(false);case_paths.clear()
    for row in case_records:
        if not row.get("ready",false):continue
        for perspective in row.perspectives:case_paths.append(perspective.journal)
    for capability in CaseLibrary.CAPABILITIES:
        var present=case_records.any(func(row):return row.capability==capability)
        capability_picker.add_item(capability+(" · unrecorded" if not present else ""))
    _populate_capability(0)

func _choose_capability(choice:int)->void:
    capability_picker.select(choice)
    _populate_capability(choice)
    _open_browser_selection()

func _populate_capability(choice:int)->void:
    interaction_picker.clear()
    var capability:String=CaseLibrary.CAPABILITIES[choice]
    for row in case_records:
        if row.capability==capability and not range(interaction_picker.item_count).any(func(i):return interaction_picker.get_item_text(i)==row.interaction):interaction_picker.add_item(row.interaction)
    if interaction_picker.item_count==0:
        interaction_picker.add_item("No recorded interaction");interaction_picker.disabled=true
    else:interaction_picker.disabled=false
    interaction_picker.add_item("Browse authoring…");interaction_picker.set_item_metadata(interaction_picker.item_count-1,"library")
    interaction_picker.disabled=false
    _populate_interaction(0)

func _choose_interaction(choice:int)->void:
    if interaction_picker.get_item_metadata(choice)=="library":
        _show_study_library();return
    interaction_picker.select(choice)
    _populate_interaction(choice)
    _open_browser_selection()

func _populate_interaction(choice:int)->void:
    case_picker.clear();browser_cases.clear()
    var capability:String=CaseLibrary.CAPABILITIES[capability_picker.selected]
    var interaction=interaction_picker.get_item_text(choice)
    for row in case_records:
        if row.capability==capability and row.interaction==interaction:browser_cases.append(row)
    case_picker.add_item("Choose case…" if not browser_cases.is_empty() else "Required · not recorded")
    case_picker.set_item_disabled(0,true)
    for row in browser_cases:
        case_picker.add_item(row.label+(" · "+row.scenario_status.replace("_"," ") if not row.ready else ""))
        case_picker.set_item_disabled(case_picker.item_count-1,not row.ready)
    case_picker.disabled=browser_cases.is_empty()

func _open_browser_selection()->void:
    for i in range(browser_cases.size()):
        if browser_cases[i].get("ready",false):case_picker.select(i+1);select_case(browser_cases[i]);return
    _cancel_case_selection()

func _cancel_case_selection()->void:
    # An unavailable study is still the latest navigation intent. Never let a
    # previously requested recording replace it after its worker completes.
    Recording.cancel(loader_token);Recording.cancel(seeker_token)
    _cancel_loop_preparation();_discard_candidate()
    seek_generation+=1;requested_seek=-1;scrub_target=-1
    pending_directory="";pending_case_request={};pending_index={};pending_bundle={};pending_perspective_navigation={}
    pending_study_selection={};pending_perspective="";pending_selected_id="";pending_autoplay=false
    pending_authoring_reload=false
    world.timeline.paused=true
    status.text="No recording for this interaction; current preview retained."
    _set_perspectives(active_perspective)

func _choose_case(choice: int) -> void:
    if choice>0 and choice<=browser_cases.size():select_case(browser_cases[choice-1])

func select_case(record:Dictionary,perspective_id:String="",study:Dictionary={})->void:
    if not record.get("ready",false) or record.get("perspectives",[]).is_empty():_cancel_case_selection();return
    if perspective_id.is_empty():perspective_id=str(record.perspectives[0].id)
    for perspective in record.perspectives:
        if str(perspective.id)==perspective_id:
            _load(perspective.journal,study,true);return

func _set_perspectives(selected_id:String)->void:
    perspective_picker.clear();active_perspective=selected_id
    for perspective in active_case.get("perspectives",[]):
        perspective_picker.add_item(perspective.label)
        var i=perspective_picker.item_count-1
        perspective_picker.set_item_metadata(i,str(perspective.id))
        if str(perspective.id)==selected_id:perspective_picker.select(i)
    perspective_picker.tooltip_text="Recorded faction / audience"
    perspective_picker.disabled=case_bundle.is_empty() or perspective_picker.item_count<2 or loader!=null or (installing and not preparing_loop)

func select_perspective(perspective_id:String)->void:
    if case_bundle.is_empty() or perspective_id==active_perspective or loader!=null:return
    var anchor=_navigation_anchor(index,world.timeline.display_ms,selected_row,retained_view_anchor)
    var resume=not world.timeline.paused
    if not case_bundle.views.has(perspective_id):
        for perspective in active_case.perspectives:
            if str(perspective.id)!=perspective_id:continue
            # Keep the current image until this independent journal and its
            # exact media are admitted by the existing loader/seek workers.
            _load(perspective.journal,{"capability":study_capability,"scenario":study_scenario})
            pending_perspective_navigation={"anchor":anchor,"resume":resume}
            return
        status.text="Unknown recorded faction: "+perspective_id
        return
    var target=_inspection_index(case_bundle,perspective_id)
    if not target.get("ok",false):status.text=target.get("error","Unknown recorded faction");return
    pending_authoring_reload=false
    var at=Recording.anchor_time(target,anchor)
    anchor.mapped_time_ms=at;retained_view_anchor=anchor
    pending_bundle=case_bundle;pending_perspective=perspective_id
    pending_selected_id=_anchored_row(target,anchor)
    pending_index=target
    _discard_spare()
    _seek(at,resume,true)
    perspective_picker.disabled=true

static func _navigation_anchor(source:Dictionary,time_ms:float,selected:Dictionary,previous:Dictionary)->Dictionary:
    # An undisclosed audience may have no selectable counterpart. Returning
    # without changing its held moment must retain the original causal anchor.
    if selected.is_empty() and not previous.is_empty() and is_equal_approx(time_ms,previous.get("mapped_time_ms",-1.0)):
        return previous.duplicate()
    return Recording.navigation_anchor(source,time_ms,selected,previous)

static func _anchored_row(source:Dictionary,anchor:Dictionary)->String:
    for row in source.rows:
        if Recording._row_key(row)==anchor.row_key:return row.id
    return ""

func _select_row(row:Dictionary)->void:
    selected_row=row
    if inspector.visible:_show_inspector(row)

func _scrub(time_ms:float,finished:bool)->void:
    world.timeline.paused=true;_cancel_loop_preparation()
    scrub_target=time_ms
    # Mouse motion owns only the requested cursor. One final restore owns the
    # actual scene; hundreds of pointer events must not rebuild/cancel worlds.
    if finished:_seek(time_ms)

func _play_clip(row:Dictionary)->void:
    if row.get("timing_status") in ["unresolved","other_perspective"] or not row.get("visible_here",true):return
    var end:float=row.end_ms
    if row.kind=="event":
        var children={};var pending=[row.id]
        for dependent in index.rows:
            if not children.has(dependent.parent):children[dependent.parent]=[]
            children[dependent.parent].append(dependent)
        # Include actual dependent reaction/effect tails, not unrelated operations.
        while not pending.is_empty():
            for dependent in children.get(pending.pop_back(),[]):
                if not dependent.get("visible_here",true):continue
                pending.append(dependent.id);end=maxf(end,dependent.end_ms)
    if end<=row.start_ms:
        _seek(row.start_ms)
        return
    # Existing context margins show admission/restoration around a real clip;
    # they never retime its source, commit or independent recipient outcomes.
    loop_start=maxf(0.,float(row.start_ms)-Recording.PREVIEW_LEAD_IN_MS)
    loop_end=minf(float(index.get("presentation_end_ms",index.duration_ms)),end+Recording.PREVIEW_OPERATION_GAP_MS)
    loop_enabled=true;loop_button.set_pressed_no_signal(true)
    _seek(loop_start,true)

static func _read_selection(directory:String,record:Dictionary,perspective_id:String,token:Dictionary)->Dictionary:
    var started=Time.get_ticks_usec()
    if not record.is_empty():
        if perspective_id.is_empty():perspective_id=str(record.perspectives[0].id)
        var matches=record.perspectives.filter(func(view):return str(view.id)==perspective_id)
        if matches.is_empty():return {"ok":false,"error":"Unknown recorded faction: "+perspective_id}
        directory=matches[0].journal
    var selected=Recording.read(directory,token)
    var stages={"selected_read_ms":(Time.get_ticks_usec()-started)/1000.0,"audiences_read":1,"comparison_ms":0.0}
    if not selected.get("ok",false):return selected
    selected.moments=CaseLibrary.resolve_moments(selected,record.get("moments",[]),perspective_id)
    var native_started=Time.get_ticks_usec()
    selected.native_startup_plan=Play.NativeStartup.recording_plan(selected.rows)
    stages.native_plan_ms=(Time.get_ticks_usec()-native_started)/1000.0
    var media_started=Time.get_ticks_usec()
    _prepare_recording_sources(selected)
    stages.final_media_ms={perspective_id if not perspective_id.is_empty() else "recorded":(Time.get_ticks_usec()-media_started)/1000.0}
    if record.is_empty():
        stages.total_ms=(Time.get_ticks_usec()-started)/1000.0;selected.loading_ms=stages
        return selected
    selected.perspective_id=perspective_id;selected.case_id=record.id
    var bundle={"ok":true,"case_id":record.id,"perspectives":record.perspectives,
        "views":{perspective_id:selected},"default_perspective_id":perspective_id,"comparison":false}
    var inspection_started=Time.get_ticks_usec()
    var inspected=_inspection_index(bundle,perspective_id)
    stages.inspection_ms=(Time.get_ticks_usec()-inspection_started)/1000.0
    stages.total_ms=(Time.get_ticks_usec()-started)/1000.0;inspected.loading_ms=stages
    return {"ok":true,"index":inspected,"bundle":bundle,"perspective_id":perspective_id}

static func _inspection_index(bundle:Dictionary,perspective_id:String)->Dictionary:
    if not bundle.get("views",{}).has(perspective_id):return {"ok":false,"error":"Recorded faction has not been loaded: "+perspective_id}
    # Studio has one independent renderer. Other original journals remain in
    # its picker; no peer schedule or peer inspection rows retime this view.
    var selected=bundle.duplicate();selected.comparison=false
    selected.views={perspective_id:bundle.views[perspective_id]}
    selected.perspectives=bundle.perspectives.filter(func(view):return str(view.id)==perspective_id)
    return Recording.view_index(selected,perspective_id)

static func _retain_recorded_views(result:Dictionary,previous:Dictionary)->Dictionary:
    if previous.is_empty():return result
    if result.bundle.case_id!=previous.case_id:return {"ok":false,"error":"Faction selection belongs to another recorded case"}
    var expected:Dictionary=previous.views.values()[0].identity
    var incoming:Dictionary=result.bundle.views[result.perspective_id].identity
    if expected.game_id!=incoming.game_id or expected.game_epoch!=incoming.game_epoch:
        return {"ok":false,"error":"Faction views must belong to the same recorded encounter epoch"}
    var retained:Dictionary=result.bundle.duplicate()
    retained.views=previous.views.duplicate();retained.views.merge(result.bundle.views,true)
    var selected=result.duplicate();selected.bundle=retained
    return selected

static func _prepare_recording_sources(source:Dictionary)->void:
    source.media_preload=RecordingMedia.plan(source)
    Play.Catalog.adopt_snapshot(source.cache,source.media_preload.source_files)

func _select_browser_path(path:String)->bool:
    var absolute=ProjectSettings.globalize_path(path).replace("\\","/")
    for record in case_records:
        for perspective in record.perspectives:
            if ProjectSettings.globalize_path(perspective.journal).replace("\\","/")!=absolute:continue
            var cap=CaseLibrary.CAPABILITIES.find(record.capability);capability_picker.select(cap);_populate_capability(cap)
            for i in interaction_picker.item_count:
                if interaction_picker.get_item_text(i)==record.interaction:interaction_picker.select(i);_populate_interaction(i);break
            case_picker.select(browser_cases.find(record)+1);active_case=record;_set_perspectives(str(perspective.id));return true
    return false

static func _restore_selection(source:Dictionary,target:float,token:Dictionary)->Dictionary:
    var restored=Recording.restore(source,target,token)
    if restored==null:return {}
    var result={"primary":restored}
    return result

## A retired preview, its tracks and a replaced recording index keep their
## ordinary teardown; their data is dropped on a worker, not in a frame.
func _retire(node:Node,data:Array=[])->void:
    BackgroundRelease.release_after_exit(node,data);node.queue_free()

func _discard_spare()->void:
    if spare_viewport!=null:_retire(spare_viewport,[spare_index])
    spare_viewport=null;spare_world=null;spare_index={};frozen_spare_viewports=[]

func _discard_candidate()->void:
    if world!=null:world.native_startup_background=true
    if candidate_tracks!=null:_retire(candidate_tracks);candidate_tracks=null
    candidate_preview_errors=[]
    frozen_candidate_viewports=[]
    if candidate_viewport!=null:_retire(candidate_viewport,[candidate_index])
    candidate_viewport=null;candidate_world=null;candidate_index={};installing=false;tracks.thumbnails.suspended=false

func _reload_authoring()->void:
    _load(active_directory,{},false,true)

func _load(directory: String,study:Dictionary={},autoplay:bool=false,reload_authoring:bool=false) -> void:
    if reload_authoring:Play.Catalog.invalidate_source_indexes()
    if directory.is_empty():return
    pending_authoring_reload=reload_authoring
    pending_perspective_navigation={}
    study_panel.hide()
    scrub_target=-1.0
    _cancel_loop_preparation()
    pending_study_selection=study if not study.is_empty() else ({"capability":study_capability,"scenario":study_scenario} if directory==active_directory else {"capability":{},"scenario":{}})
    pending_autoplay=autoplay
    _discard_spare()
    pending_directory=directory;pending_case_request={};retained_view_anchor={}
    var absolute=ProjectSettings.globalize_path(directory).replace("\\","/")
    for record in case_records:
        for perspective in record.perspectives:
            if ProjectSettings.globalize_path(perspective.journal).replace("\\","/")==absolute:
                pending_case_request={"case":record,"perspective_id":str(perspective.id)};break
        if not pending_case_request.is_empty():break
    pending_bundle={};pending_perspective="";pending_selected_id=str(selected_row.get("id","")) if directory==active_directory else ""
    Recording.cancel(loader_token);Recording.cancel(seeker_token)
    seek_generation+=1;requested_seek=-1;_discard_candidate();pending_index={}
    world.timeline.paused=true;_cancel_replay_advance()
    status.text="Indexing exact SDK recording… current preview retained."
    if loader==null:_start_load()

func _start_load()->void:
    startup_setup.loader_started_ms=(Time.get_ticks_usec()-opened_usec)/1000.0
    loader_token=Recording.cancellation();loader=Thread.new()
    var error:Error=loader.start(_read_selection.bind(pending_directory,pending_case_request.get("case",{}),pending_case_request.get("perspective_id",""),loader_token))
    pending_directory="";pending_case_request={}
    if error!=OK:
        loader=null;pending_study_selection={};pending_autoplay=false
        status.text="Cannot start recording reader; previous preview retained: "+error_string(error)
        _set_perspectives(active_perspective);return
    perspective_picker.disabled=true

func _seek(time_ms: float, resume: bool=false, keep_view_anchor:bool=false, rebuild:bool=false) -> void:
    var source:Dictionary=pending_index if not pending_index.is_empty() else index
    if source.is_empty() or loader!=null:return
    _cancel_loop_preparation()
    var target=clampf(time_ms,0,source.get("presentation_end_ms",source.duration_ms))
    if not tracks.drag_playhead and not is_equal_approx(target,scrub_target):scrub_target=-1.0
    # Even a same-frame seek is a new explicit navigation intent. Only an
    # actual audience switch asks to preserve an undisclosed causal anchor.
    if not keep_view_anchor:retained_view_anchor={}
    if not rebuild and is_same(source,index) and not installing and seeker==null and requested_seek<0 and is_equal_approx(target,world.timeline.display_ms):
        scrub_target=-1.0
        tracks.prepare_visible()
        world.timeline.paused=not resume
        return
    world.timeline.paused=true;_cancel_replay_advance();Recording.cancel(seeker_token)
    seek_generation+=1;_discard_candidate()
    requested_seek=target
    preparation_measurement={"target_ms":target,"loop":false,"requested_usec":Time.get_ticks_usec()}
    resume_after_install=resume
    status.text="Preparing %.3f s… previous clock and scene retained."%(requested_seek/1000)

func _prepare_candidate(restored: Dictionary, source: Dictionary)->void:
    var started=Time.get_ticks_usec()
    preparation_measurement.restore_wait_ms=(started-int(preparation_measurement.get("requested_usec",started)))/1000.0
    candidate_index=source;_stage_tracks(source)
    candidate_budget=replay_budget_bytes
    var spare={"viewport":spare_viewport,"world":spare_world,"index":spare_index,"frozen":frozen_spare_viewports} if spare_world!=null else {}
    spare_viewport=null;spare_world=null;spare_index={};frozen_spare_viewports=[]
    var shared=not pending_authoring_reload and (is_same(source,index) or (not case_bundle.is_empty() and is_same(pending_bundle,case_bundle)))
    var prepared=ReplayPanes.prepare(self,restored.primary,source,world,spare,candidate_budget,shared,not index.is_empty())
    candidate_world=prepared.world;candidate_viewport=prepared.viewport
    candidate_world.publishes_receiving=false
    # The retained preview cannot spend the shared native warmup draw before
    # this candidate admits its actual requested sources.
    world.native_startup_background=false
    candidate_world.native_startup_background=true
    if pending_authoring_reload:
        pending_authoring_reload=false
        # Wait for the freshly indexed authoring before invalidating sources.
        # Otherwise the retained old Play host could seed startup from its old
        # cache while this recording is still loading. Existing instances keep
        # their own resources until ordinary candidate publication retires them.
        Play.NativeStartup.reset()
        Play.NativeStartup.Effects.invalidate()
        candidate_world._step_native_startup()
    if index.is_empty() and initial_view_size>0:candidate_world.camera.size=initial_view_size
    if not prepared.reused:_listener(candidate_world)
    preparation_measurement.reused_spare=prepared.reused
    installing=true;installation_generation=worker_generation
    preparation_measurement.create_ms=(Time.get_ticks_usec()-started)/1000.0
    preparation_measurement.created_usec=Time.get_ticks_usec()

func _publish_candidate()->void:
    # Restore the paused displayed texture before its ordinary retirement/spare
    # capture; a thumbnail must not leave disabled update modes in that spare.
    tracks.thumbnails._release_composed_receiving()
    if candidate_tracks!=null:candidate_tracks.thumbnails._release_composed_receiving()
    var first_publication=index.is_empty()
    _freeze_loop_candidate(false)
    preparation_measurement.publish_ms=(Time.get_ticks_usec()-int(preparation_measurement.get("requested_usec",Time.get_ticks_usec())))/1000.0
    transport_measurements.append(preparation_measurement.duplicate());preparation_measurement={}
    if transport_measurements.size()>32:transport_measurements.pop_front()
    var previous=viewport
    var previous_world=world
    var previous_data:Array=[index,case_bundle]
    _cancel_replay_advance()
    var changed=not is_same(index,candidate_index)
    viewport=candidate_viewport;world=candidate_world
    tracks.thumbnails.set_displayed_world(world)
    if candidate_tracks!=null:candidate_tracks.thumbnails.set_displayed_world(world)
    if is_instance_valid(previous_world) and previous_world!=world:previous_world.publishes_receiving=false
    world.claim_receiving()
    world.native_startup_background=true
    if is_equal_approx(world.timeline.display_ms,scrub_target):scrub_target=-1.0
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    preparing_loop=false
    candidate_viewport=null;candidate_world=null;installing=false;tracks.thumbnails.suspended=false
    # A renderer's _exit_tree owns teardown. Reparenting its viewport would
    # trigger that teardown even if it reentered immediately, so only the
    # displayed texture changes; both viewport owners keep stable parents.
    previous.audio_listener_enable_3d=false;previous_world.component_renderer.audio.set_enabled(false)
    viewport.audio_listener_enable_3d=true
    preview.texture=viewport.get_texture()
    if changed:_retire(previous);_discard_spare()
    else:
        _discard_spare()
        spare_viewport=previous;spare_world=previous_world;spare_index=index
        spare_world.timeline.paused=true;spare_world.process_mode=Node.PROCESS_MODE_DISABLED
        var held:Array=[spare_viewport]
        held.append_array(spare_viewport.find_children("*","SubViewport",true,false))
        for child in held:
            frozen_spare_viewports.append([child,child.render_target_update_mode])
            child.render_target_update_mode=SubViewport.UPDATE_DISABLED
    index=candidate_index;candidate_index={};pending_index={};active_directory=index.directory
    if not pending_study_selection.is_empty():
        study_capability=pending_study_selection.capability;study_scenario=pending_study_selection.scenario;pending_study_selection={}
    _show_study_expectations()
    if changed:
        var previous_tracks=tracks
        tracks=candidate_tracks;candidate_tracks=null
        previous_tracks.hide();timeline_split.move_child(tracks,0);tracks.show();_retire(previous_tracks,previous_data)
        selected_row={};loop_start=0;loop_end=index.get("presentation_end_ms",index.duration_ms)
        for row in index.rows:
            if row.id==pending_selected_id:selected_row=row;tracks.reveal(row.id);break
    pending_selected_id=""
    if not pending_bundle.is_empty():
        case_bundle=pending_bundle;pending_bundle={};active_perspective=pending_perspective;pending_perspective=""
        for record in case_records:
            if record.id==case_bundle.case_id:active_case=record;break
        _set_perspectives(active_perspective)
    elif changed:
        case_bundle={};active_case={};active_perspective="";perspective_picker.clear();perspective_picker.disabled=true
    if changed and not _select_browser_path(active_directory):
        capability_picker.select(-1)
        interaction_picker.clear();interaction_picker.add_item("External recording");interaction_picker.disabled=true
        browser_cases.clear();case_picker.clear();case_picker.add_item(active_directory.get_base_dir().get_file());case_picker.disabled=true
    world.timeline.paused=not resume_after_install
    _sync_audio()
    world.media_warmup.budget_bytes=candidate_budget
    world.media_plan_key=[] # normal optional demand may resume after publication
    if inspector.visible:
        if inspector_mode=="log":inspector_text.text=JSON.stringify(world.timeline.event_log(),"  ")
        elif inspector_mode=="row":_refresh_row_inspector(selected_row)
    status.text="Ready · Q/E view · wheel zoom · middle-drag pan · Space play · G grid · Z walls" if candidate_preview_errors.is_empty() else "Source preview unavailable · Inspect for details"
    if study_scenario.get("inspection_mode")=="failed_prefix":
        var scope:String="Historical recording original" if study_scenario.get("recording_status")=="stale" else "Failed recording prefix"
        status.text=scope+" · "+str(study_scenario.get("recording_failure",""))+" · "+status.text
    candidate_preview_errors=[]
    _set_perspectives(active_perspective)
    DisplayServer.window_set_title(WINDOW_TITLE)
    _report_publication(first_publication)
    print("STUDIO_FRAME_READY: %.3f s, sequence %d, world %d"%[world.timeline.display_ms/1000,world.timeline.sequence,world.world_revision])

func _sync_candidate_view()->bool:
    var changed=false
    if candidate_world.native_spell_hit_material!=world.native_spell_hit_material:
        # This is already the user's accepted preference. Do not persist it
        # again; invalidate the candidate frame so it draws before publication.
        candidate_world.native_spell_hit_material=world.native_spell_hit_material;changed=true
    if candidate_world.playback_speed!=world.playback_speed:
        candidate_world.playback_speed=world.playback_speed;changed=true
    if candidate_index.directory==active_directory:
        if candidate_world.presentation_mutes!=world.presentation_mutes or candidate_world.presentation_solo!=world.presentation_solo:
            candidate_world.presentation_mutes=world.presentation_mutes.duplicate()
            candidate_world.presentation_solo=world.presentation_solo.duplicate();changed=true
    var quarter: int=world.requested_quarter if world.rotation_pending() else world.quarter
    var candidate_quarter: int=candidate_world.requested_quarter if candidate_world.rotation_pending() else candidate_world.quarter
    if quarter!=candidate_quarter:candidate_world.request_view(quarter);changed=true
    if candidate_world.wall_mode!=world.wall_mode:
        candidate_world.wall_mode=world.wall_mode;candidate_world.update_wall_visibility();changed=true
    if candidate_world.grid_visible!=world.grid_visible:candidate_world.grid_visible=world.grid_visible;changed=true
    var extent=1 if world.camera.keep_aspect==Camera3D.KEEP_HEIGHT else 0
    var candidate_zoom=world.camera.size*float(candidate_viewport.size[extent])/maxi(1,viewport.size[extent])
    var desired_focus=_follow_position(candidate_world,world.camera_focus)
    var zoom_changed=not index.is_empty() and not is_equal_approx(candidate_world.camera.size,candidate_zoom)
    if (not index.is_empty() or not follow_actor_id.is_empty()) and (zoom_changed or candidate_world.camera_focus!=desired_focus):
        if not index.is_empty():candidate_world.camera.size=candidate_zoom
        candidate_world.camera_focus=desired_focus;candidate_world.initial_focus=true;candidate_world.position_camera();changed=true
    return changed

func _process(_delta: float) -> void:
    if Time.get_ticks_msec()>=fps_update_ms:
        var fps=Engine.get_frames_per_second()
        fps_label.text="%d FPS · %.1f ms"%[fps,1000.0/fps] if fps>0 else "— FPS · — ms"
        fps_update_ms=Time.get_ticks_msec()+500
    # A seek's required world sources outrank optional thumbnail work. Visible
    # thumbnail requests remain active, including the staged candidate's rows.
    var preparing_sources=installing and not preparation_measurement.has("ready_ms")
    var desired_focus=_follow_position(world,world.camera_focus)
    if world.camera_focus!=desired_focus:
        world.camera_focus=desired_focus;world.position_camera()
    if preparing_loop and (not loop_enabled or world.timeline.paused or prepared_loop_range!=Vector2(loop_start,loop_end)):_cancel_loop_preparation()
    ViewportLayout.resize(viewport,world.camera,preview.size)
    _sync_listener(world)
    if loader!=null and not loader.is_alive():
        var result=loader.wait_to_finish();loader=null
        if not pending_perspective_navigation.is_empty() and result is Dictionary and result.get("ok",false):
            result=_retain_recorded_views(result,case_bundle)
        if not pending_directory.is_empty():_start_load()
        elif Recording.canceled(loader_token):_set_perspectives(active_perspective)
        elif result is Dictionary and result.get("ok",false):
            pending_index=result.get("index",result)
            pending_bundle=result.get("bundle",{});pending_perspective=result.get("perspective_id","")
            if not pending_perspective_navigation.is_empty():
                var navigation:Dictionary=pending_perspective_navigation;pending_perspective_navigation={}
                var at=Recording.anchor_time(pending_index,navigation.anchor)
                navigation.anchor.mapped_time_ms=at;retained_view_anchor=navigation.anchor
                pending_selected_id=_anchored_row(pending_index,navigation.anchor)
                _seek(at,navigation.resume,true)
            else:
                # Explicit Library navigation starts the selected study at its
                # beginning, even if another study uses this same recording.
                var keep_clock=not pending_autoplay and active_directory==pending_index.directory
                _seek(minf(world.timeline.display_ms,pending_index.get("presentation_end_ms",pending_index.duration_ms)) if keep_clock else 0,pending_autoplay)
            if not pending_index.is_empty():print("STUDIO_INDEX_READY: %d operations, %d rows, %.3fs, %.1fms compile"%[pending_index.operations,pending_index.rows.size(),pending_index.duration_ms/1000,pending_index.compile_ms])
        elif not (result is Dictionary and result.get("canceled",false)):
            scrub_target=-1.0
            pending_study_selection={}
            pending_authoring_reload=false;pending_perspective_navigation={}
            status.text="Recording rejected; previous preview kept: "+str(result.get("error","Invalid source") if result is Dictionary else "Authoring/recording compile failed")
            _set_perspectives(active_perspective)
    if seeker!=null and not seeker.is_alive():
        var restored=seeker.wait_to_finish();seeker=null
        if restored is Dictionary and not restored.is_empty() and worker_generation==seek_generation:_prepare_candidate(restored,pending_index if not pending_index.is_empty() else index)
    if seeker==null and requested_seek>=0 and loader==null:
        worker_generation=seek_generation;seeker_token=Recording.cancellation()
        var target=requested_seek;requested_seek=-1
        var source=pending_index if not pending_index.is_empty() else index
        seeker=Thread.new()
        var error:Error=seeker.start(_restore_selection.bind(source,target,seeker_token))
        if error!=OK:
            seeker=null;scrub_target=-1.;pending_study_selection={}
            status.text="Cannot start recording seek; previous preview retained: "+error_string(error)
    if installing and installation_generation==seek_generation:
        var candidate_size=preview_row.size
        var size_changed=ViewportLayout.resize(candidate_viewport,candidate_world.camera,candidate_size)
        var view_changed=_sync_candidate_view() or size_changed
        _sync_listener(candidate_world)
        if candidate_tracks!=null:
            candidate_tracks.size=tracks.size
            candidate_tracks.quarter=candidate_world.quarter
            candidate_tracks.set_light_context({"light_strength":candidate_world.light_strength,"fire_light_flicker":candidate_world.fire_light_flicker},candidate_world.fixture_clips)
            candidate_tracks.thumbnails.reference_world=candidate_world
            var prepared:Dictionary=candidate_tracks.prepare_visible()
            candidate_tracks.thumbnails.seed_source_images(candidate_world.source_images)
            candidate_preview_pending=prepared.pending
            candidate_preview_errors=prepared.errors
        else:
            # A same-recording seek can follow a filter/expand selection. Keep
            # its visible previews preparing without holding the exact scene.
            # Pending cells and source errors remain inspectable in the tracks.
            tracks.thumbnails.reference_world=candidate_world
            var prepared:Dictionary=tracks.prepare_visible()
            tracks.thumbnails.seed_source_images(candidate_world.source_images)
            candidate_preview_pending=prepared.pending
            candidate_preview_errors=prepared.errors
        if view_changed:_freeze_loop_candidate(false)
        if not candidate_world.presentation_errors.is_empty() or not candidate_world.media_issue.is_empty():
            scrub_target=-1.0
            pending_study_selection={}
            status.text="Candidate rejected; previous preview retained: "+str(candidate_world.presentation_errors)+candidate_world.media_issue
            if preparing_loop:_cancel_loop_preparation();world.timeline.paused=true
            _discard_candidate();pending_index={};pending_bundle={};pending_perspective="";_set_perspectives(active_perspective)
        elif _candidate_frame_ready(view_changed):
            if not preparation_measurement.has("ready_ms"):preparation_measurement.ready_ms=(Time.get_ticks_usec()-int(preparation_measurement.get("created_usec",Time.get_ticks_usec())))/1000.0
            if not preparing_loop or world.timeline.display_ms>=loop_end:_publish_candidate()
            else:_freeze_loop_candidate(true)
    if not index.is_empty():
        if not installing:tracks.thumbnails.reference_world=world
        if not world.timeline.paused and not installing:
            if loop_enabled and loop_end>loop_start and world.timeline.display_ms>=loop_end and not preparing_loop:
                _seek(loop_start,true)
            elif world.timeline.display_ms>=index.get("presentation_end_ms",index.duration_ms) and not world.timeline.busy():
                world.timeline.paused=true
        tracks.set_light_context({"light_strength":world.light_strength,"fire_light_flicker":world.fire_light_flicker},world.fixture_clips)
    play_button.text="Play" if world.timeline.paused else "Pause"
    if not index.is_empty():
        world.playback_end_ms=minf(loop_end,index.presentation_end_ms) if loop_enabled and loop_end>loop_start else index.presentation_end_ms
        _prepare_loop()
    if not index.is_empty():
        # Follow and paint the displayed recorded clock.
        tracks.playhead_ms=scrub_target if scrub_target>=0 else world.timeline.display_ms;tracks.quarter=world.quarter;tracks.queue_redraw()
        _follow_displayed_track()
        clock_label.text="%.3f / %.3f s%s"%[world.timeline.display_ms/1000,index.get("presentation_end_ms",index.duration_ms)/1000," · event end" if world.timeline.display_ms>=index.duration_ms else ""]
    # Optional swatches must not compete with actual recorded playback. The
    # visible rows still request and publish through the ordinary cache path.
    var suspend_optional=preparing_sources or not world.timeline.paused
    tracks.thumbnails.set_displayed_world(world)
    tracks.thumbnails.prewarm_suspended=suspend_optional
    if candidate_tracks!=null:
        candidate_tracks.thumbnails.set_displayed_world(world)
        candidate_tracks.thumbnails.prewarm_suspended=suspend_optional
    markers.queue_redraw()
    if inspector.visible and inspector_mode=="log" and inspector_log_revision!=world.timeline.revision:
        inspector_log_revision=world.timeline.revision
        inspector_text.text=JSON.stringify(world.timeline.event_log(),"  ")
    if inspector.visible and inspector_mode=="row" and inspected_row.get("kind")=="light" and Time.get_ticks_usec()-inspector_update_usec>=200000:
        _refresh_light_inspector()
    if inspector.visible and inspector_mode=="row" and inspected_row.get("kind")=="audio" and Time.get_ticks_usec()-inspector_update_usec>=200000:_refresh_audio_inspector()
    if inspector.visible and inspector_mode=="row" and inspected_row.get("component",{}).get("native_spell",false) and Time.get_ticks_usec()-inspector_update_usec>=200000:_refresh_native_inspector()
    if not world.presentation_errors.is_empty() and str(world.presentation_errors)!=last_status:
        last_status=str(world.presentation_errors);print("STUDIO_RENDER_ISSUES: "+last_status)

func _candidate_frame_ready(view_changed:bool)->bool:
    # Only the exact renderer frame gates publication. Recording-wide optional
    # media and source thumbnails continue through their existing bounded work.
    return not view_changed and not candidate_world.rotation_pending() and candidate_world.playback_prepared()

func _report_publication(first:bool)->void:
    var media:Dictionary=world.media_warmup
    var required:Dictionary=world.media_plan.get("required",{}).duplicate()
    required.merge(world.media_environment_required);required.merge(media.boot_paths)
    var required_ready=0;var upcoming_count=0;var upcoming_ready=0;var optional_count=0;var optional_ready=0
    for path in required:
        if media.ready_paths.has(path) and not media.failed.has(path):required_ready+=1
    for path in media.wanted:
        if required.has(path):continue
        upcoming_count+=1
        if media.ready_paths.has(path) and not media.failed.has(path):upcoming_ready+=1
    var sources:Dictionary=Play.MediaWarmup.physical(media)
    for path in sources.preload_selected:
        if media.wanted.has(path):continue
        optional_count+=1
        if sources.selected_ready.has(path) and not sources.failed.has(path):optional_ready+=1
    var receipt={"first":first,"process_uptime_ms":Time.get_ticks_usec()/1000.0,
        "studio_elapsed_ms":(Time.get_ticks_usec()-opened_usec)/1000.0,
        "directory":active_directory,"display_ms":world.timeline.display_ms,
        "studio_setup_ms":startup_setup.duplicate(),"recording_ms":index.get("loading_ms",{}),
        "required_sources":required.size(),"required_ready":required_ready,
        "upcoming_sources":upcoming_count,"upcoming_ready":upcoming_ready,
        "optional_sources":optional_count,"optional_ready":optional_ready,
        "thumbnail_pending":candidate_preview_pending,
        "native_warmup_ms":world.native_startup.get("elapsed_ms",0.0),
        "native_warmup_completed":world.native_startup.get("completed",0),
        "native_warmup_total":world.native_startup.get("total",0),
        "native_required_total":world.native_startup.get("required_total",0),
        "native_required_pending":world.native_startup.get("pending",0),
        "native_background_pending":world.native_startup.get("background_pending",0),
        "transport":transport_measurements.back() if not transport_measurements.is_empty() else {}}
    if first:startup_receipt=receipt
    print("STUDIO_PUBLICATION: ",JSON.stringify(receipt))

func _prepare_loop()->void:
    if not loop_enabled or loop_end<=loop_start or world.timeline.paused or preparing_loop:return
    if loader!=null or seeker!=null or installing or requested_seek>=0 or not pending_index.is_empty():return
    # Prepare the next exact authoritative prefix while this iteration plays.
    # The hidden candidate cannot publish state, audio or its image before Out.
    preparing_loop=true;prepared_loop_range=Vector2(loop_start,loop_end)
    preparation_measurement={"target_ms":loop_start,"loop":true,"requested_usec":Time.get_ticks_usec()}
    seeker_token=Recording.cancellation();worker_generation=seek_generation;resume_after_install=true
    seeker=Thread.new()
    var error:Error=seeker.start(_restore_selection.bind(index,loop_start,seeker_token))
    if error!=OK:
        seeker=null;preparing_loop=false;loop_enabled=false;loop_button.set_pressed_no_signal(false)
        status.text="Cannot prepare recorded loop: "+error_string(error)

func _cancel_loop_preparation()->void:
    if not preparing_loop:return
    preparing_loop=false;Recording.cancel(seeker_token);seek_generation+=1;_discard_candidate()

func _freeze_loop_candidate(freeze:bool)->void:
    if candidate_viewport==null:return
    world.native_startup_background=freeze
    if freeze:
        if not frozen_candidate_viewports.is_empty():return
        var viewports:Array=[candidate_viewport]
        viewports.append_array(candidate_viewport.find_children("*","SubViewport",true,false))
        for child in viewports:
            frozen_candidate_viewports.append([child,child.render_target_update_mode])
            child.render_target_update_mode=SubViewport.UPDATE_DISABLED
        candidate_world.process_mode=Node.PROCESS_MODE_DISABLED
    else:
        if frozen_candidate_viewports.is_empty():return
        candidate_world.process_mode=Node.PROCESS_MODE_INHERIT
        for pair in frozen_candidate_viewports:
            if is_instance_valid(pair[0]):pair[0].render_target_update_mode=pair[1]
        frozen_candidate_viewports=[]

func _toggle_play() -> void:
    if loader!=null or ((installing or seeker!=null) and not preparing_loop):return
    if world.timeline.paused and not index.is_empty() and world.timeline.display_ms>=index.get("presentation_end_ms",index.duration_ms):
        _seek(loop_start if loop_enabled else 0.0,true)
        return
    world.timeline.paused=not world.timeline.paused
    if world.timeline.paused:
        _cancel_loop_preparation();_cancel_replay_advance()

func _play_study()->void:
    if index.is_empty():return
    loop_start=0;loop_end=index.presentation_end_ms
    _seek(0,true)

func _step(direction: int) -> void:
    if index.is_empty(): return
    _seek(Recording.step_time(index,selected_row,world.timeline.display_ms,direction))

func _rotate(direction: int) -> void:
    world.request_view((world.requested_quarter if world.rotation_pending() else world.quarter)+direction)

func _preview_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        preview.grab_focus()
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            world.camera.size=clampf(world.camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),3,100)
            world.position_camera(); accept_event()
    elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
        follow_actor_id=""
        var factor=world.camera.size/maxf(1,preview.size.y)
        world.camera_focus -= (world.camera.basis.x*event.relative.x-world.camera.basis.y*event.relative.y)*factor
        world.position_camera(); accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo: return
    var focus=get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit: return
    if event.physical_keycode in [KEY_Q,KEY_E,KEY_G,KEY_Z] and focus!=preview:return
    match event.physical_keycode:
        KEY_SPACE: _toggle_play()
        KEY_LEFT: _step(-1)
        KEY_RIGHT: _step(1)
        KEY_Q: _rotate(-1)
        KEY_E: _rotate(1)
        KEY_G: world.grid_visible=not world.grid_visible
        KEY_Z:
            world.wall_mode=world.WALL_MODES[(world.WALL_MODES.find(world.wall_mode)+1)%world.WALL_MODES.size()]
            world.update_wall_visibility()
        KEY_ESCAPE: inspector.hide()
        _: return
    get_viewport().set_input_as_handled()

## Which approach of the package clip plays, and why when it is not the
## requested kind; the staged clip id when the package renamed it.
static func effect_lines(component:Dictionary)->Array[String]:
    var lines:Array[String]=[]
    var clip:Dictionary=Effects.occurrence_clip(component) if not component.get("native_clip",{}).is_empty() else {}
    if clip.is_empty():
        lines.append("Effect: no package clip ("+str(component.get("reason",""))+")");return lines
    var chosen:Dictionary=Effects.choice(clip)
    var kinds:Array=[]
    for approach in clip.get("approaches",[]):
        if not Effects.LABELS[approach.kind] in kinds:kinds.append(Effects.LABELS[approach.kind])
    lines.append("Effect version: "+Effects.LABELS.get(chosen.kind,"none")+(" ("+chosen.reason+")" if not chosen.reason.is_empty() else "")+" · package has "+", ".join(kinds))
    var staged:String=str(component.get("native_cue",{}).get("staged_clip",clip.id))
    if component.has("lifecycle_phases"):
        # Conditions are native-only in the package: the row says so instead of failing.
        lines.append("Condition lifecycle: "+str(component.lifecycle_key)+" · one occurrence plays application, sustain and removal on the owner's clock")
        for phase in ["application","sustain","removal"]:lines.append(phase.capitalize()+" clip: "+str(component.lifecycle_phases[phase].id))
    elif clip.get("source_kind")=="standalone_phase":lines.append("Standalone PhaseResource: "+str(clip.id)+" · explicit source assignment (not an indexed clip)")
    else:lines.append("Package clip: "+str(clip.id)+(" (staged as "+staged+")" if staged!=str(clip.id) else ""))
    for approach in chosen.approaches.slice(0,1):
        lines.append("Approach: "+str(approach.get("id",""))+" · "+str(approach.path))
        if not str(approach.get("source_phase","")).is_empty():lines.append("Source phase: "+str(approach.source_phase))
        if not approach.get("gaps",[]).is_empty():lines.append("Recording gaps (Factory): "+", ".join(approach.gaps))
    var method:Dictionary=CapabilityReport.native_method(component)
    if not str(method.authoring.get("source","")).is_empty():lines.append("Authoring use: "+str(method.authoring.source))
    if not method.authoring.get("lifecycle",{}).is_empty():lines.append("Authored lifecycle: "+JSON.stringify(method.authoring.lifecycle))
    if method.authoring.has("axis_scale"):lines.append("Source-coordinate axis calibration: "+JSON.stringify(method.authoring.axis_scale)+"; uniform artistic scale remains separate.")
    lines.append("Declared source channels: "+", ".join(method.required_channels))
    if not method.authoring.get("input_policies",{}).is_empty():lines.append("Authored channel policies: "+JSON.stringify(method.authoring.input_policies))
    if not method.constructor.is_empty():
        lines.append("Constructor projection: "+str(method.constructor.get("kind",""))+(" / "+str(method.constructor.projection) if method.constructor.has("projection") else ""))
    var destination:Dictionary=method.destination_admission
    if not destination.is_empty():
        var admissions:Array[String]=["source occurrence "+str(destination.source_occurrence)]
        if destination.has("creation_occurrence"):admissions.append("creation "+str(destination.creation_occurrence))
        if destination.has("birth_occurrence"):admissions.append("birth "+str(destination.birth_occurrence))
        if destination.has("body_occurrence"):admissions.append("body disclosure "+str(destination.body_occurrence))
        admissions.append("public admission "+str(destination.admission_occurrence))
        admissions.append("publication "+str(component.source_event_uuid)+" at %.1f ms"%float(destination.publication_ms))
        lines.append("Destination admission: "+{"spatial_creation":"created spatial anchor","actor_birth":"born actor ground"}.get(str(destination.kind),str(destination.kind))+" · "+" · ".join(admissions))
    if not method.projected_channels.is_empty():lines.append("Recorded result channels: "+", ".join(method.projected_channels))
    if not method.constructor_gaps.is_empty():lines.append("Unavailable constructor channels: "+", ".join(method.constructor_gaps))
    if not method.input_gaps.is_empty():lines.append("Unavailable inputs: "+", ".join(method.input_gaps))
    return lines

static func provenance_lines(row:Dictionary)->Array[String]:
    var lines:Array[String]=[]
    if row.is_empty():return lines
    var event:Dictionary=row.get("event",{})
    var requirement:Dictionary=row.get("requirement",{})
    var data:Dictionary=row.get("track",row.get("component",{}))
    if not event.is_empty():
        lines.append("Origin: recorded server event; its visual choices and display timing are authored separately.")
    elif row.get("owner",{}).has("grant"):
        lines.append("Origin: recorded temporary-HP grant membership; its UUID/source/recipient remain distinct from conditions.")
    elif row.get("kind") in ["condition","condition_state"]:
        lines.append("Origin: recorded condition state/lifetime; its visible mechanisms are separate authored child tracks.")
    elif row.get("kind") in ["spatial_effect","world_animation"]:
        lines.append("Origin: recorded spatial-owner state and its actual public source cut; the resource selects its rendering program.")
    elif row.get("kind")=="perspective":
        lines.append("Origin: an independently recorded audience view of the same occurrence, not an additional gameplay event.")
    elif requirement.has("authority_source"):
        lines.append("Origin: disclosed server state needs a renderer; this row is an expected feature, not a rendered effect.")
        lines.append("Server field: "+str(requirement.authority_source))
    elif not requirement.is_empty():
        lines.append("Origin: declared presentation requirement from the event contract or authoring; this row does not create a server event.")
    else:
        lines.append("Origin: authored presentation of a recorded event or state; the server does not select this clip, effect or sound.")
    var event_id:String=event.get("event_uuid",row.get("source_event_uuid",data.get("source_event_uuid","")))
    if not event_id.is_empty():lines.append("Recorded event: "+event_id)
    if data.get("native_spell",false):lines.append_array(effect_lines(data))
    if TimelineView.Thumbnails._composed_row(row):
        lines.append("Composed source preview: exact restored recording, recipient pose, source clock and receiving light/ground cut through the production pane. Requested while playback is paused; the displayed pane is frozen only for the source draw. This thumbnail is not a rendering receipt or artwork approval.")
    if row.get("owner",{}).has("grant"):
        var owner:Dictionary=row.owner
        lines.append("Recorded temporary-HP grant: "+str(owner.id)+" · source "+str(owner.grant.source_id)+" · recipient "+str(owner.actor_uuid))
        if row.get("admission_kind")=="initial":lines.append("Grant already present at initialization; no application is invented.")
        elif row.get("admission_kind")=="reveal":lines.append("Grant first disclosed after its onset; the recorded hold starts here without inventing its hidden age.")
        if not is_inf(float(owner.end_ms)):lines.append("Canonical grant retirement: %.1f ms"%float(owner.end_ms))
    elif row.has("owner"):
        lines.append(("Recorded spatial owner: " if row.owner.has("effect") else "Recorded condition: ")+str(row.owner.id)+(" (already active at initialization)" if row.owner.get("initial",false) else ""))
    if row.has("render_method"):
        var method:Dictionary=row.render_method
        lines.append("Rendering operation: "+str(method.get("label",method.get("node","")))+" on "+str(method.get("surface",""))+" · "+str(row.get("recipient_name",row.get("actor_name",""))))
        lines.append("Renderer: "+str(method.get("renderer","")))
        if method.has("shader"):lines.append("Shader: "+str(method.shader))
        if method.has("program"):
            var program:Dictionary=method.program
            lines.append("World source program: "+str(program.get("kind",""))+" · state field "+str(program.get("state_field",""))+" · "+str(program.get("fps","per-role"))+" fps")
            if program.has("activation_frames"):lines.append("Activation frames: "+JSON.stringify(program.activation_frames)+"; source contact frame "+str(program.get("contact_frame","undisclosed")))
            if program.has("projectile"):lines.append("Projectile source: "+JSON.stringify(program.projectile))
            var occurrence:Dictionary=method.get("occurrence",{})
            if occurrence.has("source_cut"):lines.append("Actual support/source cut: "+JSON.stringify(occurrence.source_cut))
            if occurrence.has("contact_ms"):lines.append("Compiled group contact: %.1f ms (authored launch plus actual endpoint travel)."%float(occurrence.contact_ms))
            if occurrence.has("source_rows"):lines.append("Actual projected world rows: "+str(occurrence.source_rows.size())+"; unavailable: "+JSON.stringify(occurrence.get("unavailable",[])))
            lines.append("Inspect this source in the existing scene replay. Prepared resources and rendered output remain separate evidence.")
        elif method.has("residue_id"):
            lines.append("Release source: "+str(method.get("release_id",""))+" → "+str(method.residue_id)+" · "+str(method.get("asset_id",""))+" · primitive "+str(method.get("primitive","")))
            lines.append("Actual receiving regions: "+str(method.get("receiving_region_count",0))+"; changed residue tiles: "+str(method.get("revealed_tile_count",0))+". Authored polygons/palette and the existing landing clock own the appearance.")
        elif row.get("kind")=="light":
            lines.append("Source membership and property keys use actual displayed commits. Position follows compiled actor motion; flicker follows the prepared fixture source. No added fade.")
        elif row.get("kind")=="condition_restore":
            lines.append("Recorded removal restores the composed pose/material selected by the remaining state. This inspection track creates no additional effect.")
            lines.append("Before → after: "+JSON.stringify(row.get("transition",{})))
        elif row.get("kind")=="native_light":
            lines.append("Keys come from the selected native AnimationPlayer. Its source clock is mapped onto the parent spell phase; optical colour/strength overrides remain visible in the component.")
        elif row.get("kind")=="native_material":
            lines.append(str(row.get("preview_reason",data.get("preview_reason",""))))
            if data.has("native_hit"):lines.append("Inspect → Full spell hit material switches the replay between this source and Colour treatment. The dedicated source thumbnail shows the selected native material.")
        else:
            lines.append("Resolved parameters: "+JSON.stringify(row.get("operations",{})))
            lines.append("Preview: composed actor. Mute/solo applies to the owning condition.")
    if data.has("body_release"):
        var explanation="The airborne source is an authored response; it creates no ground residue."
        if data.get("kind")=="residue_deposit":explanation="Server regions and tile after-values own the stain. Authored particles and kernels control its landing presentation."
        lines.append("Server field: DamageResultFact.body_release ("+str(data.body_release.get("release_id",""))+"). "+explanation)
    if data.has("assignment_source"):lines.append("Visual/audio assignment: "+str(data.assignment_source))
    if data.get("kind")=="audio" and data.has("contact_ms"):
        lines.append("Sound contact: %s at %.3f s; source sync point %.3f s into the selected recording."%[data.get("source_marker",""),(float(row.get("group_start_ms",0))+data.contact_ms)/1000.0,float(data.get("source_sync_s",0))])
        if data.has("timing_source"):lines.append("Timing authoring: "+str(data.timing_source))
    if data.has("movement_metrics"):
        var movement:Dictionary=data.movement_metrics
        lines.append("Movement playback: %.2f tiles/s × %.2f = %.2f tiles/s."%[movement.base_tiles_per_second,movement.speed_multiplier,movement.tiles_per_second])
        lines.append("Rate sources: "+movement.duration_source+" and "+movement.speed_source+"; movement allowance is a separate server resource.")
    if row.has("movement_allowance"):
        var allowance:Dictionary=row.movement_allowance
        lines.append("Recorded operation movement allowance: "+str(allowance)+" (operation boundary values, not inferred per-step spending).")
    var source:String=row.get("source",data.get("source",""))
    if not source.is_empty():lines.append("Selected source / required field: "+source)
    var gap:String=requirement.get("gap_kind",row.get("missing_category",""))
    if gap in ["authoring_assignment","authoring_review","authoring"]:
        lines.append("Gap: authored assignment or ownership decision is missing.")
    elif gap in ["renderer","implementation"]:
        lines.append("Gap: required renderer is missing; no completed visual is claimed.")
    elif gap=="inspection":
        lines.append("Gap: the renderer has this operation, but Studio does not yet project its full track.")
    elif gap=="unassessed":
        lines.append("Gap: renderer support has not been assessed; this is not proof of missing or completed rendering.")
    elif row.get("status")=="missing":
        lines.append("Gap: presentation is unavailable; inspect the reason and source below.")
    else:
        lines.append("Source/component availability is not proof that this occurrence has been rendered or visually qualified.")
    return lines

func _show_inspector(row: Dictionary) -> void:
    inspector_mode="row"
    inspector.title="Source / resolved presentation"
    _refresh_row_inspector(row)
    inspector.popup_centered()

func _refresh_row_inspector(row:Dictionary)->void:
    inspected_row=row
    var shown=row.duplicate()
    shown.erase("preview_states");shown.erase("preview_tracks")
    var issues=[]
    for key in tracks.thumbnails.errors:
        if ":"+str(row.get("id",""))+":" in key:issues.append(tracks.thumbnails.errors[key])
    if not issues.is_empty():shown.preview_errors=issues
    inspector_row_text="\n".join(provenance_lines(row))+"\n\nDetails\n"+JSON.stringify(shown,"  ") if not row.is_empty() else "Select an occurrence, component or sample on the timeline."
    if row.get("kind")=="light":_refresh_light_inspector()
    elif row.get("kind")=="audio":_refresh_audio_inspector()
    elif row.get("component",{}).get("native_spell",false):_refresh_native_inspector()
    else:inspector_text.text=inspector_row_text

func _refresh_native_inspector()->void:
    inspector_update_usec=Time.get_ticks_usec()
    var owner:Node3D=_row_world(inspected_row)
    var component:Dictionary=inspected_row.get("component",{})
    var occurrence_id:String=str(component.get("id",""))
    if component.get("kind") in ["native_light","native_material"]:
        occurrence_id=str(component.get("parent_id",occurrence_id))
    var sample:Dictionary=owner.component_renderer.native_spells.diagnostics.get(occurrence_id,{})
    var channel_note:String=""
    if component.get("kind")=="native_light":
        channel_note="\nLight channel %s belongs to occurrence %s. This is the source occurrence's submission/input status; per-light sampling, illumination and framebuffer evidence remain separate."%[str(component.get("id","")),occurrence_id]
    inspector_text.text="At playhead %.3f s · current native submission/input diagnostics; framebuffer evidence remains separate.%s\n%s\n\n%s"%[
        owner.timeline.display_ms/1000.0,channel_note,JSON.stringify(sample if not sample.is_empty() else {"status":"not_sampled_at_playhead"},"  "),inspector_row_text]

func _refresh_audio_inspector()->void:
    inspector_update_usec=Time.get_ticks_usec()
    var owner=_row_world(inspected_row)
    var component:Dictionary=inspected_row.get("component",{})
    var sample=owner.component_renderer.audio.diagnostics(str(component.get("id","")))
    inspector_text.text="Native playback status (not a claim of speaker output)\n"+JSON.stringify(sample,"  ")+"\n\n"+inspector_row_text

func _refresh_light_inspector()->void:
    inspector_update_usec=Time.get_ticks_usec()
    var sample=LightTracks.sample(inspected_row,world.timeline.display_ms,{"light_strength":world.light_strength,"fire_light_flicker":world.fire_light_flicker},world.fixture_clips)
    inspector_text.text="At playhead %.3f s\n%s\n\n%s"%[world.timeline.display_ms/1000,JSON.stringify(sample,"  "),inspector_row_text]

func _show_log() -> void:
    inspector_mode="log"
    inspector.title="Combat log · displayed commits only"
    inspector_text.text=JSON.stringify(world.timeline.event_log(),"  ")
    inspector.popup_centered()

func _show_source_inventory()->void:
    if source_inventory==null:
        source_inventory=SourceInventory.new();add_child(source_inventory)
    source_inventory.open(world.catalog_cache,index.get("rows",[]),CaseLibrary.CAPABILITIES[capability_picker.selected])

func _show_coverage() -> void:
    inspector_mode="coverage"
    inspector.title="Component coverage · available is not witnessed"
    var lines: Array[String]=[]
    for row in index.get("rows",[]):
        if row.kind!="event": continue
        for component in row.event.components:
            lines.append("%s / %s: %s — %s" % [row.label,component.kind,component.status,component.reason])
    lines.append("")
    var recorded:Array=[]
    for original in index.get("rows",[]):
        var row:Dictionary=original.duplicate();row.recording=active_directory;recorded.append(row)
    var coverage=ConditionCoverage.build(world.catalog_cache,recorded)
    lines.append("Condition catalog — %s entries, %s requirements"%[coverage.totals.entries,coverage.totals.requirements])
    lines.append(coverage.scope)
    for entry in coverage.entries:
        lines.append("\n%s · %s · %s"%[entry.label,entry.status,entry.source])
        for requirement in entry.requirements:
            lines.append("  %s / %s: implementation %s; source %s; recorded %s; native qualification separate"%[requirement.phase,requirement.mechanism,requirement.implementation,requirement.availability,requirement.evidence.size()])
            if not requirement.reason.is_empty():lines.append("    "+requirement.reason)
            lines.append("    "+requirement.source)
    inspector_text.text="\n".join(lines); inspector.popup_centered()

func _copy_report() -> void:
    DisplayServer.clipboard_set(JSON.stringify({"recording":active_directory,"display_ms":world.timeline.display_ms,"sequence":world.timeline.sequence,"selected":selected_row,"render_errors":world.presentation_errors,"trace":world.timeline.event_trace()},"  "))
    status.text="Copied recording position, selected component and displayed event witnesses."

func _exit_tree() -> void:
    Recording.cancel(loader_token);Recording.cancel(seeker_token)
    if loader!=null:loader.wait_to_finish()
    if seeker!=null:seeker.wait_to_finish()
    BackgroundRelease.join()
