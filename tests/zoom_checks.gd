extends SceneTree
## Current player input/support preparation boundary. No GPU frame, rendered
## image or backend destruction claim belongs to this headless test.
const Quarter=preload("res://presentation/quarter_view.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")

class HUD extends "res://play_hud.gd":
    func _ready()->void:
        super._ready()
        hide()
        set_process(false)
    func pointer_over_controls(_point:Vector2=Vector2.INF)->bool:return false

class Player extends "res://play.gd":
    var interactions:Array=[]
    func _ready()->void:
        set_process(false)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.size=12;add_child(camera);camera.current=true;position_camera()
        add_child(context_menu);context_menu.hide()
    func command_ready()->bool:return true
    func _choose_world_option(option:Dictionary)->void:interactions.append(option)

var world:Player
var checks:int=0
var failures:Array=[]
var results:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ZOOM_FAIL ",label)
func wheel(button:int)->void:
    var event=InputEventMouseButton.new();event.button_index=button
    event.position=Vector2(850,400);event.pressed=true
    root.push_input(event,true)
func alt(pressed:bool)->void:
    var event=InputEventKey.new();event.keycode=KEY_ALT;event.physical_keycode=KEY_ALT;event.pressed=pressed
    Input.parse_input_event(event);Input.flush_buffered_events()
func zoom(target:float,label:String)->void:
    var before:Dictionary=world.timeline.state.duplicate(true)
    var selection:Dictionary=world.target_selection.duplicate(true)
    var actor_action:Dictionary=world.selected_action.duplicate(true)
    var transform:Transform3D=world.camera.transform
    var started:int=Time.get_ticks_usec()
    var outwards:bool=world.camera.size<target
    var inputs:int=0
    while inputs<64 and ((outwards and world.camera.size<target) or (not outwards and world.camera.size>target)):
        wheel(MOUSE_BUTTON_WHEEL_DOWN if outwards else MOUSE_BUTTON_WHEEL_UP);inputs+=1
    var input_ms:float=(Time.get_ticks_usec()-started)/1000.0
    check(inputs<64,"Wheel input reaches the requested scale: "+label)
    check(input_ms<100.0,"Camera input remains below100ms: "+label)
    check(world.camera.transform==transform,"Zoom changes scale without moving or rotating the camera: "+label)
    # The real preparation implementation must finish through bounded slices,
    # even while a different camera scale is published in the player.
    var target_view=Quarter.new();world.add_child(target_view);target_view.configure(world,world.quarter)
    var turns:int=0
    while not target_view.is_prepared and turns<2048:
        target_view.step(2000);turns+=1
        if not target_view.is_prepared:await process_frame
    check(target_view.is_prepared and target_view.geometry.targets.size()==world.timeline.state.tiles.size(),"Every elevated support finishes after zoom: "+label)
    check(target_view.slice_max_ms<250.0,"No CPU view preparation slice exceeds250ms: "+label)
    check(world.timeline.state==before and world.target_selection==selection and world.selected_action==actor_action,
        "Zoom/preparation preserve native state and the exact selected action: "+label)
    results.append({"case":label,"zoom":world.camera.size,"input_ms":input_ms,"preparation_slice_max_ms":target_view.slice_max_ms,"slices":turns,"supports":target_view.geometry.targets.size()})
    target_view.free()
func run()->void:
    root.size=Vector2i(1280,800)
    world=Player.new();root.add_child(world)
    var hud=HUD.new();hud.world=world;world.hud=hud;world.add_child(hud)
    var tiles:Dictionary={};var positions:Array=[]
    for x in range(37):
        for y in range(34):
            var position:Array=[x,y];positions.append(position)
            tiles["%d,%d"%[x,y]]={"tile_uuid":"support:%d:%d"%[x,y],"position":position,"elevation_steps":(x%3)-1}
    var door:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gallery_door_states.json")).before
    var id:String=door.placement.object_uuid
    var row:Dictionary={"id":id,"kind":"door","position":door.placement.position,"base_height_steps":door.placement.base_height_steps}
    world.timeline.state={"tiles":tiles,"actors":{},"objects":{id:door},"senses":{"visible":Cells.mask(positions)}}
    world.world_generation=1;world.world_quarter=0
    world.placements=[row];world.scenery_visibility={id:true}
    var option:Dictionary={"subject_uuid":id,"behavior_id":"action.environment.directional_door.open","label":"Open"}
    var action:Dictionary={"behavior_id":option.behavior_id,"display_name":"Open","discovery_index":4,"target_type":"object","target_set":0,"can_afford":true,"interaction_affordance":{"surface":"world"}}
    world.available_actions={"entity_uuid":"controlled-actor","discovery_generation":0,"object_actions":[action],"subjects":[{"uuid":id,"kind":"object"}],"target_sets":[[{"kind":"subject","subject":0,"index":7}]],"world_interactions":[option]}
    world.selected_action=action;world.target_selection={"action_index":4,"target_indices":[7],"extra_target_positions":[],"prefer_safe":true}
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();world.add_child(node)
    var material=ShaderMaterial.new();material.shader=world.ENVIRONMENT_SHADER;node.material_override=material
    var entry:Dictionary={"node":node,"material":material,"placement":row,"role":"door"}
    SourceMaterial.set_parameter(entry,"highlighted",false);world.static_entries=[entry]
    await zoom(50,"cold-out");await zoom(12,"back-in");await zoom(50,"warm-out")
    world.camera_focus.y=-2;world.position_camera()
    await zoom(12,"underground-in");await zoom(50,"underground-out")
    for index in range(100):wheel(MOUSE_BUTTON_WHEEL_DOWN)
    check(world.camera.size==80.0,"Zoom out clamps to the current player maximum")
    for index in range(100):wheel(MOUSE_BUTTON_WHEEL_UP)
    check(world.camera.size==4.0,"Zoom in clamps to the current player minimum")
    alt(true);hud._refresh_hover_feedback()
    check(material.get_shader_parameter("highlighted")==true,"Alt still highlights the actual admitted interactable after zoom")
    alt(false);hud._refresh_hover_feedback()
    check(material.get_shader_parameter("highlighted")==false,"Alt release restores the original object material after zoom")
    world.selected_action={};world.target_selection={}
    world.activate_world_label(id)
    check(world.interactions==[option],"The current object interaction reaches its exact admitted option after zoom; no editor destruction is synthesized")
    var report={"checks":checks,"failures":failures,"results":results,"scope":"Headless current Play wheel input, bounded support preparation, underground focus, clamps, selection/state preservation, native Alt material uniforms and exact object-option dispatch. No GPU pixels/FPS/backend outcome claim."}
    FileAccess.open("res://generated/zoom_performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ZOOM_CHECKS ",JSON.stringify(report))
    world.queue_free();await process_frame;await process_frame
    quit(0 if failures.is_empty() else 1)
