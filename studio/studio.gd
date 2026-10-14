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
const ConditionCoverage=preload("res://presentation/condition_coverage.gd")
var world: Node3D
var viewport: SubViewport
var preview: TextureRect
var preview_row:HBoxContainer
var peer_preview:TextureRect
var pane_label:Label
var peer_label:Label
var peer:Dictionary={}
var comparison_enabled=true
var candidate_peer:Dictionary={}
var spare_peer:Dictionary={}
var listening_perspective=""
var replay_budget_bytes=0
var pair_plans:Array=[]
var pair_wait_frames=0
var pair_publications=0
var split: VSplitContainer
var tracks: Control
var candidate_tracks:Control
var candidate_preview_errors:Array=[]
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
var resume_when_tracks_ready=false
var active_directory = ""
var pending_directory = ""
var selected_row: Dictionary = {}
var loop_enabled = true
var loop_button:CheckButton
var preparing_loop=false
var prepared_loop_range=Vector2.ZERO
var transport_measurements:Array=[]
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
    DisplayServer.window_set_title("Neurodragon Studio · Presentation studies")
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop = ColorRect.new(); backdrop.color=Color("101722"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)
    var layout = VBoxContainer.new(); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layout.add_theme_constant_override("separation",2); add_child(layout)
    var header = HBoxContainer.new(); layout.add_child(header)
    _button(header,"Library",_show_study_library).tooltip_text="All capabilities, study sequences, recordings and authoring requirements"
    capability_picker=_picker(header,"Capability",160);capability_picker.item_selected.connect(_choose_capability)
    interaction_picker=_picker(header,"Interaction",150);interaction_picker.item_selected.connect(_choose_interaction)
    case_picker=_picker(header,"Recorded case",150);case_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;case_picker.item_selected.connect(_choose_case)
    perspective_picker=_picker(header,"Recorded faction / audience",86);perspective_picker.disabled=true
    perspective_picker.item_selected.connect(func(i):select_perspective(str(perspective_picker.get_item_metadata(i))))
    _button(header,"Open",func():file_dialog.popup_centered_ratio(.7)).tooltip_text="Open a recorded journal"
    _button(header,"Reload",func():_load(active_directory)).tooltip_text="Reload external authoring"
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
    diagnostic_menu.about_to_popup.connect(_diagnostic_menu_state)
    menu.get_popup().id_pressed.connect(func(id):
        _menu_selected(id)
        if id==6:menu.get_popup().set_item_checked(6,tracks.show_metadata))
    split=VSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; layout.add_child(split)
    preview_row=HBoxContainer.new();preview_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview_row.add_theme_constant_override("separation",3);split.add_child(preview_row)
    preview=TextureRect.new();preview.clip_contents=true;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_SCALE
    preview.custom_minimum_size=Vector2(240,160);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview.focus_mode=Control.FOCUS_ALL;preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview_row.add_child(preview)
    viewport=_viewport();add_child(viewport);preview.texture=viewport.get_texture();viewport.audio_listener_enable_3d=true
    world=Play.new(); world.external_playback=true; viewport.add_child(world);_listener(world)
    replay_budget_bytes=world.media_warmup.budget_bytes
    preview.gui_input.connect(_preview_input)
    pane_label=_pane_label(preview)
    peer_preview=TextureRect.new();peer_preview.clip_contents=true;peer_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;peer_preview.stretch_mode=TextureRect.STRETCH_SCALE
    peer_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;peer_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
    peer_preview.custom_minimum_size=Vector2(240,160);peer_preview.focus_mode=Control.FOCUS_ALL
    preview_row.add_child(peer_preview);peer_preview.hide();peer_label=_pane_label(peer_preview)
    peer_preview.gui_input.connect(_preview_input)
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
    status=Label.new();status.clip_text=true; status.text="Choose a current SDK recording."; layout.add_child(status)
    inspector=Window.new(); inspector.visible=false; inspector.title="Presentation inspector"; inspector.size=Vector2i(780,540); inspector.close_requested.connect(func(): inspector.hide()); add_child(inspector)
    inspector_text=TextEdit.new(); inspector_text.editable=false; inspector_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); inspector.add_child(inspector_text)
    file_dialog=FileDialog.new(); file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR; file_dialog.access=FileDialog.ACCESS_FILESYSTEM; add_child(file_dialog); file_dialog.dir_selected.connect(_load)
    split.dragged.connect(func(_offset):
        if not maximized:divider_ratio=clampf(preview.size.y/maxf(1,split.size.y),.15,.85);_save_layout())
    resized.connect(func():_apply_layout.call_deferred())
    var config=ConfigFile.new()
    if config.load(CONFIG)==OK:divider_ratio=clampf(config.get_value("layout","divider",.5),.15,.85)
    _apply_layout.call_deferred()
    _discover_cases()
    var args=OS.get_cmdline_user_args()
    if "--single-view" in args:comparison_enabled=false
    var directory=""
    for i in args.size():
        if args[i].begins_with("--recording="):directory=args[i].trim_prefix("--recording=")
        elif args[i]=="--recording" and i+1<args.size(): directory=args[i+1]
    if directory.is_empty() and not case_paths.is_empty(): directory=case_paths[0]
    if not directory.is_empty():
        _select_browser_path(directory)
        _load(directory)
    if "--library" in args:_show_study_library.call_deferred()

func _connect_tracks(view:Control)->void:
    view.seek_requested.connect(_seek);view.selected.connect(_select_row)
    view.scrub_requested.connect(_scrub);view.clip_requested.connect(_play_clip)
    view.perspective_requested.connect(func(row):selected_row=row;select_perspective(str(row.source_perspective)))

func _stage_tracks(source:Dictionary)->void:
    if is_same(source,index):return
    candidate_preview_errors=[]
    candidate_tracks=TimelineView.new();candidate_tracks.hide()
    candidate_tracks.size_flags_vertical=Control.SIZE_EXPAND_FILL
    candidate_tracks.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    timeline_split.add_child(candidate_tracks);candidate_tracks.size=tracks.size
    candidate_tracks.gutter=tracks.gutter;candidate_tracks.quarter=world.quarter
    candidate_tracks.filter=tracks.filter;candidate_tracks.show_metadata=tracks.show_metadata
    candidate_tracks.set_index(source)
    for row in source.rows:
        if row.id==pending_selected_id:candidate_tracks.reveal(row.id);break
    _connect_tracks(candidate_tracks)

func _light_marker_level(_tile:Dictionary,cell:String,state:Dictionary)->Variant:
    # The SDK supplies the current faction aggregate, including darkvision.
    # Tile.resolved_light may be an older observation; never substitute it.
    var senses:Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    return senses.get("effective_light_levels",{}).get(cell)

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
            if not peer.is_empty():peer.world.presentation_mutes.clear();peer.world.presentation_solo.clear()
            _diagnostic_menu_state()
        10:_show_source_inventory()
        11:_show_study_library()

func _show_study_library()->void:
    if study_library==null:
        study_library=StudyLibrary.new();add_child(study_library)
        study_library.recording_selected.connect(_open_study_recording)
        study_library.recording_unavailable.connect(_cancel_case_selection)
    world.timeline.paused=true
    study_library.open(index.get("cache",{}),case_records,study_capability.get("id",""),study_scenario.get("id",""))

func _open_study_recording(capability:Dictionary,scenario:Dictionary,record:Dictionary)->void:
    select_case(record,"",{"capability":capability,"scenario":scenario})

func _show_study_expectations()->void:
    study_tree.clear();var root_item=study_tree.create_item()
    study_button.disabled=study_scenario.is_empty();study_panel.hide()
    study_title.text=study_scenario.get("label","");study_title.tooltip_text=study_title.text
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
    inspector_mode="study"
    inspector.title="Study expectation · "+str(expected.label)
    var lines:Array[String]=[str(expected.label),"Phase: "+str(expected.get("phase","")),"Participants: "+", ".join(expected.get("participants",[])),"", "This is an expected observation. Recording presence, authoring assignment and rendered qualification are separate.",""]
    for pointer in expected.get("authoring_sources",[])+expected.get("rule_sources",[]):lines.append(str(pointer))
    inspector_text.text="\n".join(lines);inspector.popup_centered()

func _diagnostic_id()->String:
    if selected_row.get("kind") not in ["native_effect","registered_media","sprite_layer","material_flash","damage_number","audio","condition_material"]:return ""
    var component:Dictionary=selected_row.get("component",{})
    if component.get("kind") not in ["native_effect","registered_media","sprite_layer","material_flash","damage_number","audio","condition"]:return ""
    return component.get("id","")

func _diagnostic_menu_state()->void:
    var id=_diagnostic_id()
    var owner=_row_world(selected_row)
    diagnostic_menu.set_item_disabled(7,id.is_empty());diagnostic_menu.set_item_disabled(8,id.is_empty())
    diagnostic_menu.set_item_checked(7,not id.is_empty() and owner.presentation_mutes.has(id))
    diagnostic_menu.set_item_checked(8,not id.is_empty() and owner.presentation_solo.has(id))
    var cleared=world.presentation_mutes.is_empty() and world.presentation_solo.is_empty()
    if not peer.is_empty():cleared=cleared and peer.world.presentation_mutes.is_empty() and peer.world.presentation_solo.is_empty()
    diagnostic_menu.set_item_disabled(9,cleared)

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
    var primary=peer.is_empty() or listening_perspective==active_perspective
    viewport.audio_listener_enable_3d=primary
    world.component_renderer.audio.set_enabled(primary)
    if not peer.is_empty():
        peer.viewport.audio_listener_enable_3d=not primary
        peer.world.component_renderer.audio.set_enabled(not primary)
    pane_label.text=_perspective_label(active_perspective)+(" · audio" if primary and not peer.is_empty() else "")
    peer_label.text=_perspective_label(str(peer.get("perspective_id","")))+(" · audio" if not primary else "")

func _row_world(row:Dictionary)->Node3D:
    if not peer.is_empty() and row.get("source_perspective",active_perspective)==peer.perspective_id:return peer.world
    return world

func _cancel_pair_advance()->void:
    pair_plans=[]
    world.timeline.replay_cancel_preparation()
    if not peer.is_empty():peer.world.timeline.replay_cancel_preparation()

func _advance_pair(delta:float)->void:
    if peer.is_empty():return
    var other:Node3D=peer.world
    other.timeline.paused=world.timeline.paused
    other.playback_speed=world.playback_speed;other.playback_end_ms=world.playback_end_ms
    if world.timeline.paused:return
    if not is_equal_approx(world.timeline.display_ms,other.timeline.display_ms):
        world.timeline.paused=true;other.timeline.paused=true
        status.text="Replay stopped: faction clocks disagree.";return
    if pair_plans.is_empty():
        var target=minf(world.playback_end_ms,world.timeline.display_ms+maxf(0,delta)*1000.0*world.playback_speed)
        # The shared cut includes every due event in each independent stream.
        # Readiness may hold this exact pair, but cannot publish only one side.
        pair_plans=[world.timeline.replay_plan(target),other.timeline.replay_plan(target)]
    var ready_a=world.timeline.replay_prepare(pair_plans[0])
    var ready_b=other.timeline.replay_prepare(pair_plans[1])
    if not ready_a or not ready_b:pair_wait_frames+=1;return
    # No await or renderer work occurs between validation and publication.
    if not world.can_publish_replay_advance(pair_plans[0]) or not other.can_publish_replay_advance(pair_plans[1]):
        _cancel_pair_advance();return
    world.publish_replay_advance(pair_plans[0]);other.publish_replay_advance(pair_plans[1])
    pair_plans=[];pair_publications+=1

func replay_diagnostics()->Dictionary:
    var panes=[]
    for owner in [{"world":world,"perspective_id":active_perspective}]+([peer] if not peer.is_empty() else []):
        panes.append({"perspective_id":owner.perspective_id,"time_ms":owner.world.timeline.display_ms,
            "sequence":owner.world.timeline.sequence,"world_revision":owner.world.timeline.world_revision,
            "audio_enabled":owner.world.component_renderer.audio.enabled,"session_active":owner.world.session!=null,
            "media_budget_bytes":owner.world.media_warmup.budget_bytes})
    return {"comparison":not peer.is_empty(),"panes":panes,"listening_perspective":listening_perspective,
        "waiting":not pair_plans.is_empty(),"wait_frames":pair_wait_frames,"publications":pair_publications,
        "candidate_panes":(1 if candidate_world!=null else 0)+(1 if not candidate_peer.is_empty() else 0),
        "spare_panes":(1 if spare_world!=null else 0)+(1 if not spare_peer.is_empty() else 0)}

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
    case_records=CaseLibrary.read();case_paths.clear()
    for row in case_records:
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
    interaction_picker.add_item("Authoring / missing sources…");interaction_picker.set_item_metadata(interaction_picker.item_count-1,"inventory")
    interaction_picker.disabled=false
    _populate_interaction(0)

func _choose_interaction(choice:int)->void:
    if interaction_picker.get_item_metadata(choice)=="inventory":
        _show_source_inventory();return
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
    for row in browser_cases:case_picker.add_item(row.label)
    case_picker.disabled=browser_cases.is_empty()

func _open_browser_selection()->void:
    if browser_cases.is_empty():
        _cancel_case_selection()
        return
    case_picker.select(1)
    select_case(browser_cases[0])

func _cancel_case_selection()->void:
    # An unavailable study is still the latest navigation intent. Never let a
    # previously requested recording replace it after its worker completes.
    Recording.cancel(loader_token);Recording.cancel(seeker_token)
    _cancel_loop_preparation();_discard_candidate()
    seek_generation+=1;requested_seek=-1;scrub_target=-1;resume_when_tracks_ready=false
    pending_directory="";pending_case_request={};pending_index={};pending_bundle={}
    pending_study_selection={};pending_perspective="";pending_selected_id="";pending_autoplay=false
    world.timeline.paused=true
    status.text="No recording for this interaction; current preview retained."
    _set_perspectives(active_perspective)

func _choose_case(choice: int) -> void:
    if choice>0 and choice<=browser_cases.size():select_case(browser_cases[choice-1])

func select_case(record:Dictionary,perspective_id:String="",study:Dictionary={})->void:
    if perspective_id.is_empty():perspective_id=str(record.perspectives[0].id)
    for perspective in record.perspectives:
        if str(perspective.id)==perspective_id:
            _load(perspective.journal,study,true);return

func _set_perspectives(selected_id:String)->void:
    perspective_picker.clear();active_perspective=selected_id
    if not peer.is_empty() and listening_perspective not in [selected_id,str(peer.perspective_id)]:listening_perspective=selected_id
    var selected_listener=listening_perspective if not peer.is_empty() else selected_id
    for perspective in active_case.get("perspectives",[]):
        perspective_picker.add_item(perspective.label)
        var i=perspective_picker.item_count-1
        perspective_picker.set_item_metadata(i,str(perspective.id))
        if str(perspective.id)==selected_listener:perspective_picker.select(i)
    perspective_picker.tooltip_text="Listening faction" if not peer.is_empty() else "Recorded faction / audience"
    perspective_picker.disabled=case_bundle.is_empty() or perspective_picker.item_count<2 or loader!=null or (installing and not preparing_loop)

func select_perspective(perspective_id:String)->void:
    if not peer.is_empty() and perspective_id in [active_perspective,str(peer.perspective_id)]:
        listening_perspective=perspective_id;_set_perspectives(active_perspective);_sync_audio();return
    if case_bundle.is_empty() or perspective_id==active_perspective or loader!=null:return
    var target=Recording.view_index(case_bundle,perspective_id)
    if not target.get("ok",false):status.text=target.get("error","Unknown recorded faction");return
    var anchor=Recording.navigation_anchor(index,world.timeline.display_ms,selected_row,retained_view_anchor)
    var at=Recording.anchor_time(target,anchor)
    anchor.mapped_time_ms=at;retained_view_anchor=anchor
    var resume=not world.timeline.paused
    pending_bundle=case_bundle;pending_perspective=perspective_id
    pending_selected_id=str(selected_row.get("source_row_id",selected_row.get("id","")))
    pending_index=target
    _discard_spare()
    _seek(at,resume,true)
    perspective_picker.disabled=true

func _select_row(row:Dictionary)->void:
    selected_row=row
    if inspector.visible:_show_inspector(row)

func _scrub(time_ms:float,finished:bool)->void:
    resume_when_tracks_ready=false
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
    loop_start=row.start_ms;loop_end=end;loop_enabled=true;loop_button.set_pressed_no_signal(true)
    _seek(loop_start,true)

static func _read_selection(directory:String,record:Dictionary,perspective_id:String,token:Dictionary,compare:bool=true)->Dictionary:
    if record.is_empty():
        var selected=Recording.read(directory,token)
        if selected.get("ok",false):_prepare_recording_sources(selected)
        return selected
    var bundle=Recording.read_case(record,token)
    if not bundle.get("ok",false):return bundle
    for source in bundle.views.values():
        if Recording.canceled(token):return {"ok":false,"canceled":true}
        _prepare_recording_sources(source)
    if perspective_id.is_empty():perspective_id=bundle.default_perspective_id
    if compare:bundle=Recording.compare_case(bundle,token)
    if not bundle.get("ok",false):return bundle
    for source in bundle.views.values():
        if not source.has("media_preload"):_prepare_recording_sources(source)
    var selected=Recording.view_index(bundle,perspective_id)
    return {"ok":true,"index":selected,"bundle":bundle,"perspective_id":perspective_id}

static func _prepare_recording_sources(source:Dictionary)->void:
    source.media_preload=RecordingMedia.plan(source)
    source.cache.merge(source.media_preload.source_files,false)

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

static func _restore_selection(source:Dictionary,bundle:Dictionary,selected_id:String,target:float,token:Dictionary)->Dictionary:
    var restored=Recording.restore(source,target,token)
    if restored==null:return {}
    var result={"primary":restored}
    if bundle.get("comparison",false):
        for id in bundle.views:
            if str(id)==selected_id:continue
            var other=Recording.restore(bundle.views[id],target,token)
            if other==null:return {}
            result.peer={"timeline":other,"index":bundle.views[id],"perspective_id":str(id)}
            break
    return result

func _discard_spare()->void:
    ReplayPanes.discard(spare_peer);spare_peer={}
    if spare_viewport!=null:spare_viewport.queue_free()
    spare_viewport=null;spare_world=null;spare_index={};frozen_spare_viewports=[]

func _discard_candidate()->void:
    ReplayPanes.discard(candidate_peer);candidate_peer={}
    if candidate_tracks!=null:candidate_tracks.queue_free();candidate_tracks=null
    candidate_preview_errors=[]
    frozen_candidate_viewports=[]
    if candidate_viewport!=null:candidate_viewport.queue_free()
    candidate_viewport=null;candidate_world=null;candidate_index={};installing=false;tracks.thumbnails.suspended=false

func _load(directory: String,study:Dictionary={},autoplay:bool=false) -> void:
    if directory.is_empty():return
    resume_when_tracks_ready=false
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
    world.timeline.paused=true;_cancel_pair_advance()
    if not peer.is_empty():peer.world.timeline.paused=true
    status.text="Indexing exact SDK recording… current preview retained."
    if loader==null:_start_load()

func _start_load()->void:
    loader_token=Recording.cancellation();loader=Thread.new()
    loader.start(_read_selection.bind(pending_directory,pending_case_request.get("case",{}),pending_case_request.get("perspective_id",""),loader_token,comparison_enabled))
    pending_directory="";pending_case_request={};perspective_picker.disabled=true

func _seek(time_ms: float, resume: bool=false, keep_view_anchor:bool=false) -> void:
    var source:Dictionary=pending_index if not pending_index.is_empty() else index
    if source.is_empty() or loader!=null:return
    _cancel_loop_preparation()
    resume_when_tracks_ready=false
    var target=clampf(time_ms,0,source.get("presentation_end_ms",source.duration_ms))
    if not tracks.drag_playhead and not is_equal_approx(target,scrub_target):scrub_target=-1.0
    if is_same(source,index) and not installing and seeker==null and requested_seek<0 and is_equal_approx(target,world.timeline.display_ms):
        scrub_target=-1.0
        var prepared:Dictionary=tracks.prepare_visible(true)
        resume_when_tracks_ready=resume and not prepared.settled
        world.timeline.paused=not resume or resume_when_tracks_ready
        return
    if not keep_view_anchor:retained_view_anchor={}
    world.timeline.paused=true;_cancel_pair_advance();Recording.cancel(seeker_token)
    seek_generation+=1;_discard_candidate()
    requested_seek=target
    preparation_measurement={"target_ms":target,"loop":false,"requested_usec":Time.get_ticks_usec()}
    resume_after_install=resume
    status.text="Preparing %.3f s… previous clock and scene retained."%(requested_seek/1000)

func _prepare_candidate(restored: Dictionary, source: Dictionary)->void:
    var started=Time.get_ticks_usec()
    preparation_measurement.restore_wait_ms=(started-int(preparation_measurement.get("requested_usec",started)))/1000.0
    candidate_index=source;_stage_tracks(source)
    var paired=restored.has("peer")
    candidate_budget=int(replay_budget_bytes/(2 if paired else 1))
    var spare={"viewport":spare_viewport,"world":spare_world,"index":spare_index,"frozen":frozen_spare_viewports} if spare_world!=null else {}
    spare_viewport=null;spare_world=null;spare_index={};frozen_spare_viewports=[]
    var shared=is_same(source,index) or (not case_bundle.is_empty() and is_same(pending_bundle,case_bundle))
    var prepared=ReplayPanes.prepare(self,restored.primary,source,world,spare,candidate_budget,paired,shared,not index.is_empty())
    candidate_world=prepared.world;candidate_viewport=prepared.viewport
    if not prepared.reused:_listener(candidate_world)
    preparation_measurement.reused_spare=prepared.reused
    if paired:
        var other:Dictionary=restored.peer
        var reference:Node3D=peer.world if not peer.is_empty() else world
        var peer_shared=not peer.is_empty() and is_same(peer.index,other.index)
        candidate_peer=ReplayPanes.prepare(self,other.timeline,other.index,reference,spare_peer,candidate_budget,true,peer_shared,not index.is_empty())
        spare_peer={};candidate_peer.perspective_id=other.perspective_id
        if not candidate_peer.reused:_listener(candidate_peer.world)
    else:ReplayPanes.discard(spare_peer);spare_peer={}
    installing=true;installation_generation=worker_generation
    preparation_measurement.create_ms=(Time.get_ticks_usec()-started)/1000.0
    preparation_measurement.created_usec=Time.get_ticks_usec()

func _publish_candidate()->void:
    _freeze_loop_candidate(false)
    preparation_measurement.publish_ms=(Time.get_ticks_usec()-int(preparation_measurement.get("requested_usec",Time.get_ticks_usec())))/1000.0
    transport_measurements.append(preparation_measurement.duplicate());preparation_measurement={}
    if transport_measurements.size()>32:transport_measurements.pop_front()
    var previous=viewport
    var previous_world=world
    var previous_peer=peer
    _cancel_pair_advance()
    var changed=not is_same(index,candidate_index)
    viewport=candidate_viewport;world=candidate_world
    peer=candidate_peer;candidate_peer={}
    if is_equal_approx(world.timeline.display_ms,scrub_target):scrub_target=-1.0
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    preparing_loop=false
    candidate_viewport=null;candidate_world=null;installing=false;tracks.thumbnails.suspended=false
    # A renderer's _exit_tree owns teardown. Reparenting its viewport would
    # trigger that teardown even if it reentered immediately, so only the
    # displayed texture changes; both viewport owners keep stable parents.
    previous.audio_listener_enable_3d=false;previous_world.component_renderer.audio.set_enabled(false)
    viewport.audio_listener_enable_3d=true
    if not previous_peer.is_empty():previous_peer.viewport.audio_listener_enable_3d=false;previous_peer.world.component_renderer.audio.set_enabled(false)
    peer_preview.visible=not peer.is_empty()
    peer_preview.texture=peer.viewport.get_texture() if not peer.is_empty() else null
    preview.texture=viewport.get_texture()
    if changed:previous.queue_free();ReplayPanes.discard(previous_peer);_discard_spare()
    else:
        _discard_spare()
        spare_viewport=previous;spare_world=previous_world;spare_index=index
        spare_peer=previous_peer
        if not spare_peer.is_empty():spare_peer.world.timeline.paused=true;ReplayPanes.freeze(spare_peer,true)
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
        previous_tracks.hide();timeline_split.move_child(tracks,0);tracks.show();previous_tracks.queue_free()
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
    if not peer.is_empty():peer.world.timeline.paused=world.timeline.paused
    if listening_perspective not in [active_perspective,str(peer.get("perspective_id",""))]:listening_perspective=active_perspective
    _sync_audio()
    world.media_warmup.budget_bytes=candidate_budget
    world.media_plan_key=[] # normal optional demand may resume after publication
    if inspector.visible:
        if inspector_mode=="log":inspector_text.text=JSON.stringify(world.timeline.event_log(),"  ")
        elif inspector_mode=="row":_refresh_row_inspector(selected_row)
    status.text="Ready · Q/E view · wheel zoom · middle-drag pan · Space play · G grid · Z walls" if candidate_preview_errors.is_empty() else "Source preview unavailable · Inspect for details"
    candidate_preview_errors=[]
    print("STUDIO_FRAME_READY: %.3f s, sequence %d, world %d"%[world.timeline.display_ms/1000,world.timeline.sequence,world.world_revision])

func _sync_candidate_view()->bool:
    var changed=false
    if not peer.is_empty() and not candidate_peer.is_empty() and is_same(peer.index,candidate_peer.index):
        if candidate_peer.world.presentation_mutes!=peer.world.presentation_mutes or candidate_peer.world.presentation_solo!=peer.world.presentation_solo:
            candidate_peer.world.presentation_mutes=peer.world.presentation_mutes.duplicate()
            candidate_peer.world.presentation_solo=peer.world.presentation_solo.duplicate();changed=true
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
    if not index.is_empty() and (not is_equal_approx(candidate_world.camera.size,candidate_zoom) or candidate_world.camera_focus!=world.camera_focus):
        candidate_world.camera.size=candidate_zoom;candidate_world.camera_focus=world.camera_focus;candidate_world.position_camera();changed=true
    return changed

func _sync_peer_view(other:Node3D,reference:Node3D)->bool:
    var changed=false
    var quarter=reference.requested_quarter if reference.rotation_pending() else reference.quarter
    var other_quarter=other.requested_quarter if other.rotation_pending() else other.quarter
    if quarter!=other_quarter:other.request_view(quarter);changed=true
    if other.wall_mode!=reference.wall_mode:other.wall_mode=reference.wall_mode;other.update_wall_visibility();changed=true
    if other.grid_visible!=reference.grid_visible:other.grid_visible=reference.grid_visible;changed=true
    if other.camera.size!=reference.camera.size or other.camera_focus!=reference.camera_focus:
        other.camera.size=reference.camera.size;other.camera_focus=reference.camera_focus;other.initial_focus=reference.initial_focus;other.position_camera();changed=true
    other.playback_speed=reference.playback_speed
    return changed

func _process(_delta: float) -> void:
    # A seek's required world sources outrank optional thumbnail work. Visible
    # thumbnail requests remain active, including the staged candidate's rows.
    var preparing_sources=installing and not preparation_measurement.has("ready_ms")
    tracks.thumbnails.prewarm_suspended=preparing_sources
    if candidate_tracks!=null:candidate_tracks.thumbnails.prewarm_suspended=preparing_sources
    if not peer.is_empty():
        ViewportLayout.resize(peer.viewport,peer.world.camera,peer_preview.size)
        _sync_peer_view(peer.world,world);_sync_listener(peer.world)
        peer.world.timeline.paused=world.timeline.paused
    if resume_when_tracks_ready and tracks.prepare_visible(true).settled:
        resume_when_tracks_ready=false;world.timeline.paused=false
    if preparing_loop and (not loop_enabled or world.timeline.paused or prepared_loop_range!=Vector2(loop_start,loop_end)):_cancel_loop_preparation()
    ViewportLayout.resize(viewport,world.camera,preview.size)
    _sync_listener(world)
    if loader!=null and not loader.is_alive():
        var result=loader.wait_to_finish();loader=null
        if not pending_directory.is_empty():_start_load()
        elif Recording.canceled(loader_token):_set_perspectives(active_perspective)
        elif result is Dictionary and result.get("ok",false):
            pending_index=result.get("index",result)
            pending_bundle=result.get("bundle",{});pending_perspective=result.get("perspective_id","")
            # Explicit Library navigation starts the selected study at its
            # beginning, even if another study uses this same recording.
            var keep_clock=not pending_autoplay and active_directory==pending_index.directory
            _seek(minf(world.timeline.display_ms,pending_index.get("presentation_end_ms",pending_index.duration_ms)) if keep_clock else 0,pending_autoplay)
            print("STUDIO_INDEX_READY: %d operations, %d rows, %.3fs, %.1fms compile"%[pending_index.operations,pending_index.rows.size(),pending_index.duration_ms/1000,pending_index.compile_ms])
        elif not (result is Dictionary and result.get("canceled",false)):
            scrub_target=-1.0
            pending_study_selection={}
            status.text="Recording rejected; previous preview kept: "+str(result.get("error","Invalid source") if result is Dictionary else "Authoring/recording compile failed")
            _set_perspectives(active_perspective)
    if seeker!=null and not seeker.is_alive():
        var restored=seeker.wait_to_finish();seeker=null
        if restored is Dictionary and not restored.is_empty() and worker_generation==seek_generation:_prepare_candidate(restored,pending_index if not pending_index.is_empty() else index)
    if seeker==null and requested_seek>=0 and loader==null:
        worker_generation=seek_generation;seeker_token=Recording.cancellation()
        var target=requested_seek;requested_seek=-1
        var source=pending_index if not pending_index.is_empty() else index
        var bundle=pending_bundle if not pending_bundle.is_empty() else case_bundle
        var perspective=pending_perspective if not pending_perspective.is_empty() else active_perspective
        seeker=Thread.new();seeker.start(_restore_selection.bind(source,bundle,perspective,target,seeker_token))
    if installing and installation_generation==seek_generation:
        var candidate_size=Vector2(maxf(1,(preview_row.size.x-3)/2),preview_row.size.y) if not candidate_peer.is_empty() else preview_row.size
        var size_changed=ViewportLayout.resize(candidate_viewport,candidate_world.camera,candidate_size)
        var view_changed=_sync_candidate_view() or size_changed
        _sync_listener(candidate_world)
        var peer_ready=true
        if not candidate_peer.is_empty():
            # The candidate pair uses the future split geometry before publication.
            ViewportLayout.resize(candidate_peer.viewport,candidate_peer.world.camera,candidate_size)
            var peer_changed=_sync_peer_view(candidate_peer.world,candidate_world)
            _sync_listener(candidate_peer.world)
            peer_ready=not peer_changed and not candidate_peer.world.rotation_pending() and candidate_peer.world.playback_prepared() and _recording_sources_ready(candidate_peer.world)
        var tracks_ready=true
        if candidate_tracks!=null:
            candidate_tracks.size=tracks.size
            candidate_tracks.quarter=candidate_world.quarter
            candidate_tracks.set_light_context({"light_strength":candidate_world.light_strength,"fire_light_flicker":candidate_world.fire_light_flicker},candidate_world.fixture_clips)
            var prepared:Dictionary=candidate_tracks.prepare_visible(true)
            candidate_tracks.thumbnails.seed_source_images(candidate_world.source_images)
            tracks_ready=prepared.pending==0
            if not candidate_peer.is_empty():candidate_tracks.thumbnails.seed_source_images(candidate_peer.world.source_images)
            candidate_preview_errors=prepared.errors
        else:
            # A same-recording seek can follow a filter/expand selection. Keep
            # its visible previews preparing too; scene readiness alone is not
            # sufficient to publish that selection.
            var prepared:Dictionary=tracks.prepare_visible(true)
            tracks.thumbnails.seed_source_images(candidate_world.source_images)
            tracks_ready=prepared.pending==0
            candidate_preview_errors=prepared.errors
        if view_changed:_freeze_loop_candidate(false)
        if not candidate_peer.is_empty() and (not candidate_peer.world.presentation_errors.is_empty() or not candidate_peer.world.media_issue.is_empty()):
            candidate_world.presentation_errors.append("Peer: "+str(candidate_peer.world.presentation_errors)+candidate_peer.world.media_issue)
        if not candidate_world.presentation_errors.is_empty() or not candidate_world.media_issue.is_empty():
            scrub_target=-1.0
            pending_study_selection={}
            status.text="Candidate rejected; previous preview retained: "+str(candidate_world.presentation_errors)+candidate_world.media_issue
            if preparing_loop:_cancel_loop_preparation();world.timeline.paused=true
            _discard_candidate();pending_index={};pending_bundle={};pending_perspective="";_set_perspectives(active_perspective)
        elif peer_ready and tracks_ready and not view_changed and not candidate_world.rotation_pending() and candidate_world.playback_prepared() and _recording_sources_ready(candidate_world):
            if not preparation_measurement.has("ready_ms"):preparation_measurement.ready_ms=(Time.get_ticks_usec()-int(preparation_measurement.get("created_usec",Time.get_ticks_usec())))/1000.0
            if not preparing_loop or world.timeline.display_ms>=loop_end:_publish_candidate()
            else:_freeze_loop_candidate(true)
    if not index.is_empty():
        if not world.timeline.paused and not installing:
            if loop_enabled and loop_end>loop_start and world.timeline.display_ms>=loop_end and not preparing_loop:
                _seek(loop_start,true)
            elif world.timeline.display_ms>=index.get("presentation_end_ms",index.duration_ms) and not world.timeline.busy() and (peer.is_empty() or not peer.world.timeline.busy()):
                world.timeline.paused=true
        tracks.set_light_context({"light_strength":world.light_strength,"fire_light_flicker":world.fire_light_flicker},world.fixture_clips)
        tracks.playhead_ms=scrub_target if scrub_target>=0 else world.timeline.display_ms;tracks.quarter=world.quarter;tracks.queue_redraw()
        clock_label.text="%.3f / %.3f s%s"%[world.timeline.display_ms/1000,index.get("presentation_end_ms",index.duration_ms)/1000," · event end" if world.timeline.display_ms>=index.duration_ms else ""]
    play_button.text="Play" if world.timeline.paused else "Pause"
    if not index.is_empty():
        world.playback_end_ms=minf(loop_end,index.presentation_end_ms) if loop_enabled and loop_end>loop_start else index.presentation_end_ms
        _prepare_loop()
    _advance_pair(_delta)
    markers.queue_redraw()
    if inspector.visible and inspector_mode=="log" and inspector_log_revision!=world.timeline.revision:
        inspector_log_revision=world.timeline.revision
        inspector_text.text=JSON.stringify(world.timeline.event_log(),"  ")
    if inspector.visible and inspector_mode=="row" and inspected_row.get("kind")=="light" and Time.get_ticks_usec()-inspector_update_usec>=200000:
        _refresh_light_inspector()
    if inspector.visible and inspector_mode=="row" and inspected_row.get("kind")=="audio" and Time.get_ticks_usec()-inspector_update_usec>=200000:_refresh_audio_inspector()
    if not world.presentation_errors.is_empty() and str(world.presentation_errors)!=last_status:
        last_status=str(world.presentation_errors);print("STUDIO_RENDER_ISSUES: "+last_status)

func _recording_sources_ready(owner:Node3D)->bool:
    # Prepare budget-selected assets from this recording once before showing
    # the case. Each seek still proves its own exact current-frame readiness.
    return Play.MediaWarmup.ready(owner.media_warmup,owner.media_warmup.preload_selected)

func _prepare_loop()->void:
    if not loop_enabled or loop_end<=loop_start or world.timeline.paused or preparing_loop:return
    if loader!=null or seeker!=null or installing or requested_seek>=0 or not pending_index.is_empty():return
    # Prepare the next exact authoritative prefix while this iteration plays.
    # The hidden candidate cannot publish state, audio or its image before Out.
    preparing_loop=true;prepared_loop_range=Vector2(loop_start,loop_end)
    preparation_measurement={"target_ms":loop_start,"loop":true,"requested_usec":Time.get_ticks_usec()}
    seeker_token=Recording.cancellation();worker_generation=seek_generation;resume_after_install=true
    seeker=Thread.new();seeker.start(_restore_selection.bind(index,case_bundle,active_perspective,loop_start,seeker_token))

func _cancel_loop_preparation()->void:
    if not preparing_loop:return
    preparing_loop=false;Recording.cancel(seeker_token);seek_generation+=1;_discard_candidate()

func _freeze_loop_candidate(freeze:bool)->void:
    if candidate_viewport==null:return
    ReplayPanes.freeze(candidate_peer,freeze)
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
    if resume_when_tracks_ready:
        resume_when_tracks_ready=false
        return
    if loader!=null or ((installing or seeker!=null) and not preparing_loop):return
    if world.timeline.paused and not index.is_empty() and world.timeline.display_ms>=index.get("presentation_end_ms",index.duration_ms):
        _seek(loop_start if loop_enabled else 0.0,true)
        return
    world.timeline.paused=not world.timeline.paused
    if world.timeline.paused:
        _cancel_loop_preparation();_cancel_pair_advance()
        if not peer.is_empty():peer.world.timeline.paused=true

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

static func provenance_lines(row:Dictionary)->Array[String]:
    var lines:Array[String]=[]
    if row.is_empty():return lines
    var event:Dictionary=row.get("event",{})
    var requirement:Dictionary=row.get("requirement",{})
    var data:Dictionary=row.get("track",row.get("component",{}))
    if not event.is_empty():
        lines.append("Origin: recorded server event; its visual choices and display timing are authored separately.")
    elif row.get("kind") in ["condition","condition_state"]:
        lines.append("Origin: recorded condition state/lifetime; its visible mechanisms are separate authored child tracks.")
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
    if row.has("owner"):
        lines.append("Recorded condition: "+str(row.owner.id)+(" (already active at initialization)" if row.owner.get("initial",false) else ""))
    if row.has("render_method"):
        var method:Dictionary=row.render_method
        lines.append("Rendering operation: "+str(method.get("label",method.get("node","")))+" on "+str(method.get("surface",""))+" · "+str(row.get("recipient_name",row.get("actor_name",""))))
        lines.append("Renderer: "+str(method.get("renderer","")))
        if method.has("shader"):lines.append("Shader: "+str(method.shader))
        if row.get("kind")=="light":
            lines.append("Source membership and property keys use actual displayed commits. Position follows compiled actor motion; flicker follows the prepared fixture source. No added fade.")
        elif row.get("kind")=="condition_restore":
            lines.append("Recorded removal restores the composed pose/material selected by the remaining state. This inspection track creates no additional effect.")
            lines.append("Before → after: "+JSON.stringify(row.get("transition",{})))
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
    else:inspector_text.text=inspector_row_text

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
