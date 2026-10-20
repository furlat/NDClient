extends SceneTree
# Named native GUI boundary: physical opaque artwork + admitted compact choices.
# This is not a backend gameplay outcome or performance claim.
const SourceMaterial=preload("res://presentation/source_material.gd")
const Choices=preload("res://sdk/choices.gd")
class Peer extends RefCounted:
    var responses={}
    var status={"boundary":{"state_revision":"hover-ui","input_actor_uuid":"player"}}
    var next_id=0
    func request(_operation:String,_body:Dictionary={}) -> int: next_id+=1;return next_id
    func retire_record(_record:Dictionary) -> void: pass
    func close() -> void: pass
class HUD extends "res://play_hud.gd":
    func _ready() -> void:
        mouse_filter=Control.MOUSE_FILTER_IGNORE
        loot_panel.hud=self;history_panel.hud=self;settings_panel.hud=self
        for control in [actor_hud,top,notice,notice_row,copy_notice,loading,metrics,bar,history_button,grid_button,normals_button,loot_panel,history_panel,settings_panel,confirm_button,cancel_button,panel,panel_body,equipment,inventory_grid,inventory_summary,search,item_details,item_commands,popup,hover_info]:
            add_child(control);control.hide()
        set_process(false)
    func pointer_over_controls(_point:Vector2=Vector2.INF) -> bool: return false
class Player extends "res://play.gd":
    var clicks=[]
    func _ready() -> void:
        set_process(false)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10
        camera.position=Vector3(0,0,10);add_child(camera);camera.current=true
        add_child(context_menu);context_menu.hide()
    func command_ready() -> bool: return true
    func pick_cell(_point:Vector2) -> Dictionary: return {"position":[9,9]}
    func choose_target(position:Array,identity:String="",_scope:String="") -> bool:
        clicks.append({"position":position,"id":identity});return true
var checks=0
var failures=[]
var scene:Player
var hud:HUD
var viewport:SubViewport
func check(ok:bool,label:String) -> void:
    checks+=1
    if not ok: failures.append(label);printerr("HOVER_FEEDBACK_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func motion(point:Vector2) -> void:
    var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=Vector2(1,1)
    viewport.push_input(event,true)
func mouse_click(point:Vector2) -> void:
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
        viewport.push_input(event,true)
func alt(pressed:bool) -> void:
    var event=InputEventKey.new();event.keycode=KEY_ALT;event.physical_keycode=KEY_ALT;event.pressed=pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()
func refresh() -> void:
    scene.hover_due=0;scene._update_hover();hud._refresh_hover_feedback();hud._update_ground_preview()
func source(id:String,kind:String,x:float,texture:Texture2D) -> Dictionary:
    var shader=Shader.new()
    shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled;uniform sampler2D sheet:filter_nearest;uniform vec4 frame_uv;uniform bool highlighted=false;void fragment(){vec4 c=texture(sheet,UV);ALBEDO=highlighted?mix(c.rgb,vec3(.2,1.,.7),.55):c.rgb;ALPHA=c.a;}"
    var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("sheet",texture);material.set_shader_parameter("frame_uv",Vector4(0,0,1,1));material.set_shader_parameter("highlighted",false)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(1,1.5);node.position.x=x;node.material_override=material;scene.add_child(node)
    var row={"id":id,"kind":kind,"position":[int(x),0],"base_height_steps":0,"rig":"fixture"}
    var entry={"id":id,"node":node,"material":material,"placement":row,"role":"body","layer":1,"texture_path":"fixture","actor_layer":{"slot":"body","alpha":1.0},"record":{"path":"fixture","native_size":[16,24]},"cell":Vector2(16,24),"source_role":1}
    SourceMaterial.apply(entry,{"sheet":texture,"frame_uv":Vector4(0,0,1,1),"highlighted":false})
    return entry
func run() -> void:
    root.size=Vector2i(640,480)
    if "--background-check" in OS.get_cmdline_user_args():root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    viewport=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    scene=Player.new();scene.session=Peer.new();viewport.add_child(scene)
    hud=HUD.new();hud.world=scene;scene.hud=hud;scene.add_child(hud)
    var image=Image.create_empty(16,24,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT);image.fill_rect(Rect2i(3,3,10,18),Color(.6,.25,.15,1))
    var texture=ImageTexture.create_from_image(image);scene.source_images["fixture"]=image
    var actor=source("actor","actor",0,texture);var object=source("object","object",3,texture);var hidden=source("remembered","object",-3,texture)
    scene.rigs={"fixture":{"cell_width":16,"cell_height":24}}
    scene.visual_actors={"actor":{"row":actor.placement,"entries":[] if DisplayServer.get_name()=="headless" else [actor]}}
    scene.actor_rows=[actor.placement];scene.placements=[object.placement,hidden.placement]
    scene.actor_entries=[actor];scene.static_entries=[object,hidden];scene.draw_order=[actor,object,hidden]
    scene.scenery_visibility={"object":true}
    scene.timeline.state={"current_actor_uuid":"player","actors":{"actor":{"name":"Character"}},"objects":{"object":{"item":{"name":"Chest","item_id":"fixture"}},"remembered":{"item":{"name":"Remembered chest","item_id":"fixture"}}},"tiles":{"0,0":{"position":[0,0],"elevation_steps":0},"9,9":{"position":[9,9],"elevation_steps":0}}}
    var row={"discovery_index":0,"discovery_generation":"hover-ui","display_name":"Target","target_type":"multi_entity","target_set":0}
    var ground=row.duplicate();ground.target_type="position";ground.target_set=1
    scene.available_actions={"entity_uuid":"player","discovery_generation":"hover-ui","entity_actions":[row],"position_actions":[ground],"subjects":[{"uuid":"actor","kind":"creature"},{"uuid":"object","kind":"object"}],"positions":[[0,0],[3,0]],"target_sets":[[{"kind":"subject","subject":0,"position":0,"index":0},{"kind":"subject","subject":1,"position":1,"index":1}],[{"kind":"position","position":0,"index":0}]],"world_interactions":[{"subject_uuid":"object"},{"subject_uuid":"remembered"}]}
    scene.action_revision="hover-ui";scene.selected_action=row;scene.target_selection={"action_index":0,"target_indices":[],"extra_target_positions":[],"prefer_safe":true}
    await process_frame
    var point=scene.camera.unproject_position(actor.node.position)
    motion(point);refresh()
    check(scene.hover_hit.id=="actor" and hud._hover_target_subject()=="actor","Actual opaque body hover resolves its admitted subject")
    if DisplayServer.get_name()!="headless":check(hud.hover_outline.owners.has("actor"),"Hovered character uses separate assembled-alpha outline owner")
    check(scene.component_renderer.outlines.owners.is_empty(),"Hover does not replace native condition outlines")
    check(scene.ground_overlay.marks.is_empty(),"Entity-target click suppresses cursor cell")
    check(actor.material.get_shader_parameter("sheet")==texture and not actor.material.get_shader_parameter("highlighted"),"Actor source artwork and material colors stay intact")
    for repeat in range(2):
        mouse_click(point)
        check(hud.hover_outline.owners.is_empty() and scene.clicks.size()==repeat+1,"Actual target click clears temporary outline once")
        refresh();check(hud.hover_outline.owners.is_empty(),"Stationary pointer cannot immediately restore clicked outline")
        motion(point);refresh()
    motion(Vector2(20,220));refresh();check(hud.hover_outline.owners.is_empty(),"Mouse leaving character clears outline")
    scene.selected_action=ground;motion(point);refresh()
    check(scene.hover_hit.id=="actor" and hud._hover_target_subject().is_empty(),"Position spell stays ground-targeted over the same actual body")
    check(scene.ground_overlay.marks.has("0,0") and not scene.ground_overlay.marks.has("9,9") and hud.hover_outline.owners.is_empty(),"Ground-target click keeps the admitted cell over a body, not the floor ray below it")
    scene.selected_action=row
    var object_point=scene.camera.unproject_position(object.node.position)
    motion(object_point);refresh();check(object.material.get_shader_parameter("highlighted"),"Actual disclosed object hover highlights source")
    mouse_click(object_point);check(not object.material.get_shader_parameter("highlighted"),"Object click restores exact previous highlight parameter")
    motion(Vector2(20,220));refresh()
    alt(true);refresh()
    check(object.material.get_shader_parameter("highlighted"),"Actual Alt press highlights active disclosed object")
    check(not hidden.material.get_shader_parameter("highlighted"),"Alt cannot reveal remembered undisclosed object")
    alt(false);refresh()
    check(not object.material.get_shader_parameter("highlighted"),"Actual Alt release restores original object material")
    if DisplayServer.get_name()!="headless":
        scene.selected_action=row;motion(point);refresh()
        # The real HUD samples each frame, including after its private alpha
        # viewport has submitted. A process-frame wait alone is not that fence.
        var deadline:int=Time.get_ticks_msec()+2000
        while (not hud.hover_outline.owners.has("actor") or not hud.hover_outline.owners.actor.entry.node.visible) and Time.get_ticks_msec()<deadline:
            await process_frame;await RenderingServer.frame_post_draw;motion(point);refresh()
        scene._sort_draws();await RenderingServer.frame_post_draw
        check(hud.hover_outline.owners.has("actor") and hud.hover_outline.owners.actor.entry.node.visible,"Native assembled hover contour is drawn after real frame submission")
        var pixels=viewport.get_texture().get_image()
        var contour_pixels=0
        for y in range(204,276):
            for x in range(296,344):
                var colour=pixels.get_pixel(x,y)
                if colour.g>.25 and colour.g>colour.r*1.25:contour_pixels+=1
        check(contour_pixels>10,"Rendered character contour visibly changes real silhouette pixels")
        pixels.save_png("res://.runtime/ui/hover-feedback.png")
    var report={"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"Named native pointer/key GUI boundary; no backend outcomes or performance claim"}
    FileAccess.open("res://generated/hover_feedback_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("HOVER_FEEDBACK_CHECKS ",JSON.stringify(report))
    hud.clear_hover_feedback()
    viewport.queue_free()
    await process_frame;await process_frame
    quit(0 if failures.is_empty() else 1)
