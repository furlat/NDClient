extends SceneTree
## Actual delivered body setter and current private renderer materials.
const Inputs=preload("res://presentation/native_inputs.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Body=preload("res://modular.gdshader")
const Construction=preload("res://presentation/actor_construction.gd")
class OwnerTimeline extends RefCounted:
    var condition_owners:Dictionary={}
class World extends Node3D:
    var timeline:RefCounted=OwnerTimeline.new()
    var visual_actors:Dictionary={}
    var rigs:Dictionary={"fixture":{"cell_width":128,"cell_height":128,"origin_y_from_ground":32,"facing_rows":{"SW":0},"clips":{"Idle":{"fps":1.0,"frames":1}},"body_anchor":Vector2(64,64),
        "pose_sockets":{"head":{"Idle":{"SW":[Vector2(64,16)]}},"hand":{"Idle":{"SW":[Vector2(72,64)]}}}}}
    var rig_config:Dictionary={"TILE_W":128,"FACING_CYCLE":["E","SE","S","SW","W","NW","N","NE"]}
    var playbacks:Dictionary={}
    var camera:Node3D
    var quarter:int=0
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
class Receiver extends RefCounted:
    var surface:Dictionary={}
    var calls:int=0
    var uploads:int=0
    func update(value:Dictionary)->void:
        calls+=1
        if value.get("gpu_geometry_key",[])!=surface.get("gpu_geometry_key",[]):uploads+=1
        surface=value
class SurfaceProvider extends RefCounted:
    var calls:int=0
    var origin:Vector3=Vector3.ZERO
    var selected:Array=[]
    var selected_region:Dictionary={}
    var prepared:Array=[]
    func sample(_world:Node,actor:String,slots:Array=[],region:Dictionary={})->Dictionary:
        calls+=1
        selected=[actor,slots];selected_region=region
        return {"actor":actor,"actor_uuid":actor,"entity_uuid":actor,"ready":true,"reason":"","points":[],"origin":origin,"gpu_geometry_key":["same-source-pose"]}
    func prepare(_world:Node,actors:Array,slots:Array,priority:bool)->void:prepared.append([actors,slots,priority])
    func clear()->void:pass
class EndpointProbe extends Node3D:
    var parameters:Dictionary={}
    var endpoints:Array=[]
    var admitted:Array=[]
    var cells_calls:int=0
    var accepts_cells:bool=true
    var delivery:Vector2=Vector2.ZERO
    func set_live_endpoints(value:Array)->void:endpoints=value
    func set_admitted_cells(value:Array)->bool:
        cells_calls+=1;admitted=value;return accepts_cells
    func set_delivery_timing(launch:float,travel:float)->void:delivery=Vector2(launch,travel)
class NullableCellProbe extends Node3D:
    var calls:int=0
    var last:Variant="not supplied"
    func set_admitted_cells(value:Variant)->void:calls+=1;last=value
class ProjectionProbe extends Node3D:
    var parameters:Dictionary={}
    var calls:int=0
    var packet:Dictionary={}
    func set_owner_projection(value:Dictionary)->void:calls+=1;packet=value
class HistoryProbe extends Node3D:
    var parameters:Dictionary={"actor_history":{"mirror":true,"specifications":[{"delay":0.0}]}}
    var packet:Dictionary={}
    var state:Dictionary={}
    var state_calls:int=0
    func set_actor_context(value:Dictionary)->bool:packet=value;return not value.is_empty()
    func set_history_state(value:Dictionary)->void:state_calls+=1;state=value
class SelectorProbe extends Node3D:
    var calls:int=0
    var value:Variant
    func set_selector(selected:Variant)->void:calls+=1;value=selected
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_INPUT_FAIL "+label)
func actor(world:World,id:String)->Dictionary:
    var node:MeshInstance3D=MeshInstance3D.new();node.mesh=QuadMesh.new();world.add_child(node)
    var material:ShaderMaterial=ShaderMaterial.new();material.shader=Body;node.material_override=material
    material.set_shader_parameter("frame_uv",Vector4(.25,0,.25,.125));material.set_shader_parameter("tint",Vector3(.6,.3,.2))
    var entry:Dictionary={"id":id+":body","node":node,"material":material,"role":"body","actor_layer":{"slot":"body","effect":{},"paths":{}},"source_binding_revision":1,"source_version":1}
    var row:Dictionary={"id":id,"rig":"fixture","position":[10,0] if id=="b" else [0,0],"base_height_steps":0,"scale":1.0,"facing":"SW"}
    var shape:Dictionary=Construction.layer_shape(world.rigs[row.rig],128.0/float(world.rig_config.TILE_W)*row.scale)
    node.mesh=Construction.QuadShapes.mesh(shape.mesh_size,shape.mesh_center)
    entry.pivot=shape.pivot;entry.scale=shape.scale;node.basis=world.camera.basis
    node.position=Inputs.Sockets.Placement.contact(row)
    world.visual_actors[id]={"valid":true,"row":row,"entries":[entry]}
    return entry
func run()->void:
    var world:World=World.new();root.add_child(world)
    world.camera=Node3D.new();world.add_child(world.camera)
    var a:Dictionary=actor(world,"a");var b:Dictionary=actor(world,"b")
    var bridge:RefCounted=Inputs.new()
    check(Inputs.recipient({"actor_uuid":"a","target_uuid":"b","native_cue":{"attachment":"recipient_ground"}})=="b","Explicit recipient does not select caster")
    check(Inputs.recipient({"actor_uuid":"a","target_uuid":"","ground_target":true,"native_cue":{}}).is_empty(),"An aimed ground position cannot borrow caster body geometry")
    check(Inputs.recipient({"actor_uuid":"a","target_uuid":null,"ground_target":true,"native_cue":{}}).is_empty(),"A native nullable target is absence, not a synthetic actor identifier")
    check(Inputs.recipient({"actor_uuid":"a","target_uuid":"b","native_cue":{"attachment":"caster_hand"}})=="a","Caster attachment names the actual caster")
    var phase:Script=load("res://assets/vfx/conditions/condition_stoneskin_persistent/application.gd")
    Effects._ensure_clock()
    var occurrence:Node3D=phase.make_component({"layer_mask":0});world.add_child(occurrence)
    var handle:Dictionary={"clip":Effects.clip("conditions/continuation/condition_stoneskin_persistent/application"),"occurrence":occurrence}
    var component:Dictionary={"actor_uuid":"a","target_uuid":"b","native_cue":{"attachment":"recipient_ground"},"lifecycle_phases":{},"condition":{"state":{}}}
    var points:Dictionary={"hand":Vector3.ZERO,"to":Vector3.ONE}
    var result:Dictionary=bridge.sync(world,handle,component,points)
    var selector:SelectorProbe=SelectorProbe.new()
    var selector_handle:Dictionary={"clip":{"inputs":["energy_type"],"input_setters":{"energy_type":"set_selector"}},"occurrence":selector}
    var selector_component:Dictionary={"native_cue":{},"condition":{"state":{"energy_type":null}}}
    var selected:Dictionary=bridge.sync(world,selector_handle,selector_component,points)
    check(selector.calls==0 and selected.unavailable.get("energy_type")=="provider_not_bound","Canonical null selector stays undisclosed instead of reaching a typed Factory setter")
    for value in [false,0,"Fire"]:
        selector_component.condition.state.energy_type=value
        selected=bridge.sync(world,selector_handle,selector_component,points)
        check(selected.unavailable.is_empty() and selector.value==value,"A disclosed selector retains its exact value, including false/zero: "+str(value))
    selector.free()
    check(result.unavailable.is_empty(),"Ordinary delivered body treatment needs no fabricated pose-capture provider")
    check(a.material.shader==Body and b.material.shader!=Body,"Factory binds only the real recipient's private material")
    check(b.material.get_shader_parameter("frame_uv")==Vector4(.25,0,.25,.125) and b.material.get_shader_parameter("tint")==Vector3(.6,.3,.2),"Binding retains actual frame and ordinary outfit tint")
    check(occurrence.body_treatment.materials==[b.material],"Body program references the actual current renderer material")
    var uploads:int=occurrence.body_treatment.uploads
    bridge.sync(world,handle,component,points);bridge.sync(world,handle,component,points)
    check(occurrence.body_treatment.uploads==uploads,"Unchanged layer identity performs no treatment rebinding")
    var second:Node3D=phase.make_component({"layer_mask":0});world.add_child(second)
    var other:Dictionary={"clip":handle.clip,"occurrence":second}
    bridge.sync(world,other,component,points)
    check(b.material.get_shader_parameter("factory_body_count")==2,"Independent owners compose on one recipient material")
    occurrence.free()
    check(b.material.shader!=Body and b.material.get_shader_parameter("factory_body_count")==1,"Removing one owner retains the other owner treatment")
    second.free()
    check(b.material.shader==Body and a.material.shader==Body,"Removing the final owner restores the original shader precisely")
    check(b.material.get_shader_parameter("frame_uv")==Vector4(.25,0,.25,.125),"Restoration preserves the currently bound source frame")
    var capture_phase:Script=load("res://assets/vfx/conditions/condition_petrified_body_persistent/application.gd")
    var capture:Node3D=capture_phase.make_component({"layer_mask":0});world.add_child(capture)
    var capture_handle:Dictionary={"clip":Effects.clip("conditions/continuation/condition_petrified_body_persistent/application"),"occurrence":capture}
    var missing:Dictionary=bridge.sync(world,capture_handle,component,points)
    check(missing.unavailable.get("pose_provider")=="condition_original_pose_not_observed" and b.material.shader==Body,"A logical pose capture remains unavailable instead of displaying the live pose as petrified capture")
    component.condition_uuid="stone-owner"
    world.timeline.condition_owners["stone-owner"]={"logical_pose":{"actor_uuid":"b","clip":"Attack1","frame":4,"source_seconds":.4,"world_facing":"NE"}}
    missing=bridge.sync(world,capture_handle,component,points)
    check(missing.unavailable.is_empty() and capture.body_treatment.logical_capture,"Actual original logical pose acquires before the first layer binding")
    check(b.material.shader!=Body and capture.body_treatment.materials==[b.material],"Petrification binds actual layers after capture admission without a lost first delivery")
    var pose_binding:RefCounted=capture_handle.pose_provider_binding
    capture.free()
    check(pose_binding.owners.is_empty() and b.material.shader==Body,"Closing captured source releases only its lease and restores actual current material")
    component.erase("condition_uuid")

    # Contract probes use disclosed values explicitly. These do not claim a
    # real server count transition; the native replay gate checks actual art.
    world.camera.free();world.camera=Camera3D.new();world.add_child(world.camera)
    for entry in [a,b]:entry.geometry_ground_pixels=23.0;entry.node.basis=world.camera.basis
    world.visual_actors.b.sampled_pose={"key":["Idle",2,"SW"]}
    var history_probe:HistoryProbe=HistoryProbe.new();world.add_child(history_probe)
    var history_handle:Dictionary={"clip":{"inputs":["actor_context","history_state"],"input_setters":{"actor_context":"set_actor_context","history_state":"set_history_state"}},"occurrence":history_probe,"root":history_probe}
    var history_component:Dictionary={"actor_uuid":"a","target_uuid":"b","native_cue":{},"condition":{"state":{"duplicate_count":3}}}
    var depth:GradientTexture2D=GradientTexture2D.new()
    var history_result:Dictionary=bridge.sync(world,history_handle,history_component,points,depth)
    check(history_result.unavailable.is_empty() and history_probe.packet.actor_uuid=="b","History context names only the displayed actual recipient")
    check(history_probe.packet.camera==world.camera and history_probe.packet.receiver_depth==depth and history_probe.packet.depth_encoding=="rgb24_reversed_z","History receives the real camera and GPU depth texture without readback")
    check(history_probe.packet.layers[0].node==b.node and history_probe.packet.layers[0].pivot==b.pivot and history_probe.packet.layers[0].ground_pixels==23.0,"History keeps actual layer nodes, pivot and authored ground height")
    var revision:Array=history_probe.packet.material_revision.duplicate(true)
    b.source_version+=1;bridge.sync(world,history_handle,history_component,points,depth)
    check(history_probe.packet.material_revision!=revision,"Changed source pixels invalidate the pose material capture even with the same source identity")
    for count in [3,2,1,0]:
        history_component.condition.state.duplicate_count=count
        bridge.sync(world,history_handle,history_component,points,depth)
        check(history_probe.state=={"duplicate_count":count},"History state preserves disclosed count "+str(count))
    var state_calls:int=history_probe.state_calls
    history_component.condition={"behavior_id":"condition.spell.blur","state":{"duplicate_count":null}}
    history_component.native_preparation_inputs={"history_state":{"duplicate_count":3}}
    history_result=bridge.sync(world,history_handle,history_component,points,depth)
    check(history_result.unavailable.get("history_state")=="duplicate_count_not_disclosed" and "history_state" not in history_result.supplied,"Blur's canonical null count remains unavailable instead of borrowing a future Mirror count")
    check(history_probe.state_calls==state_calls and history_probe.state=={"duplicate_count":0},"A canonical null never reaches the native integer consumer or overwrites the last actual count")
    history_component.erase("condition")
    for count in [2,0]:
        history_component.native_preparation_inputs={"history_state":{"duplicate_count":count}}
        history_result=bridge.sync(world,history_handle,history_component,points,depth)
        check(history_result.unavailable.is_empty() and history_probe.state.duplicate_count==count,"Future preparation preserves the exact disclosed count including zero: "+str(count))
    state_calls=history_probe.state_calls
    history_component.native_preparation_inputs={"history_state":{"duplicate_count":null}}
    history_result=bridge.sync(world,history_handle,history_component,points,depth)
    check(history_result.unavailable.get("history_state")=="duplicate_count_not_disclosed" and history_probe.state_calls==state_calls,"A null preparation count never forwards to the native setter")
    history_component.erase("native_preparation_inputs");history_component.condition={"state":{}}
    history_result=bridge.sync(world,history_handle,history_component,points,depth)
    check(history_result.unavailable.get("history_state")=="duplicate_count_not_disclosed","No default three copies when the server did not disclose a count")
    history_probe.parameters.actor_history.specifications=[{"delay":.08}]
    history_result=bridge.sync(world,history_handle,history_component,points,depth)
    check(history_result.unavailable.get("actor_context")=="authentic_actor_history_not_bound","Delayed histories cannot fabricate predecessors from the current pose")
    history_probe.parameters.actor_history.specifications=[{"delay":0.0}]
    Effects.hide(history_handle)
    check(history_probe.packet.is_empty() and not history_handle.actor_context_bound,"Hiding a retained occurrence invalidates its capture context")
    history_probe.free()

    # Actual legacy package adapter: targets is forwarded to a source's
    # set_live_endpoints. Finger of Death requires its target at index one.
    var legacy:Node3D=load("res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd").new()
    var source:Node3D=Node3D.new();var endpoint_probe:EndpointProbe=EndpointProbe.new();source.add_child(endpoint_probe);legacy.handle={"root":source}
    var legacy_handle:Dictionary={"clip":{"inputs":["targets"],"input_setters":{"targets":"set_targets"}},"occurrence":legacy,"root":world}
    var aimed:Dictionary={"actor_uuid":"a","target_uuid":"b","native_cue":{"attachment":"recipient_ground"}}
    var exact:Dictionary={"hand":Vector3(1,2,3),"to":Vector3(8,5,-4)}
    result=bridge.sync(world,legacy_handle,aimed,exact)
    check(endpoint_probe.endpoints.size()==2 and endpoint_probe.endpoints[0].point==exact.hand and endpoint_probe.endpoints[1].point==exact.to,"Actual legacy targets adapter receives source and recipient in its required order")
    check(result.unavailable.is_empty() and not endpoint_probe.endpoints[0].has("surface"),"An endpoint-only target needs no optical image scan or invented source surface")

    var prepared:Node3D=load("res://assets/vfx/conditions/runtime.gd").new();var receiving:Receiver=Receiver.new();prepared.receiving=receiving
    var optical:SurfaceProvider=SurfaceProvider.new();bridge.surfaces=optical
    var prepared_handle:Dictionary={"clip":{"inputs":["entity_geometry","targets","live_endpoints"],"input_setters":{"entity_geometry":"set_entity_geometry","targets":"set_targets","live_endpoints":"set_live_endpoints"}},"occurrence":prepared,"root":world}
    result=bridge.sync(world,prepared_handle,aimed,exact)
    check(result.unavailable.is_empty() and receiving.surface.actor=="b" and optical.calls==1,"Actual prepared adapter discovers the one exact recipient surface in the shared endpoint packet")
    var calls:int=receiving.calls;var geometry_uploads:int=receiving.uploads
    bridge.sync(world,prepared_handle,aimed,exact)
    check(receiving.calls==calls,"Unchanged optical geometry and endpoint aliases perform no setter/tree/material traversal")
    world.position+=Vector3(3,0,5);optical.origin+=Vector3(3,0,5)
    exact.hand+=Vector3(3,0,5);exact.to+=Vector3(3,0,5)
    bridge.sync(world,prepared_handle,aimed,exact)
    check(receiving.uploads==geometry_uploads,"Co-moving recipient and effect retain their local optical upload key")
    optical.origin+=Vector3.RIGHT
    bridge.sync(world,prepared_handle,aimed,exact)
    check(receiving.uploads==geometry_uploads+1,"A recipient moving relative to a fixed effect invalidates that receiver's optical key")
    var prior_key:Array=receiving.surface.gpu_geometry_key
    world.basis=Basis(Vector3.UP,.25)
    bridge.sync(world,prepared_handle,aimed,exact)
    check(receiving.surface.gpu_geometry_key!=prior_key,"Changed receiving rotation/scale cannot reuse world points in an old local basis")
    aimed.native_cue.entity_geometry={"actor":"caster","slots":["weapon"]}
    bridge.sync(world,prepared_handle,aimed,exact)
    check(optical.selected==["a",["weapon"]],"Actual authored actor and weapon-only slot operands reach the optical provider unchanged")
    var regional:Dictionary=aimed.duplicate(true)
    regional.native_cue.entity_geometry={"actor":"caster","slots":["body","head","helmet"],"region":{"socket":"head","radius_cells":.18}}
    world.visual_actors.a.row.scale=1.5
    for factor in [.5,2.0]:
        world.visual_actors.a.sampled_pose={"body_scale":{"factor":factor}}
        bridge.geometry_sample(world,regional,"entity_geometry")
        check(is_equal_approx(optical.selected_region.radius,.18*1.5*factor),"Head region follows source scale and actual published Reduce/Enlarge once: "+str(factor))
        check(optical.selected==["a",["body","head","helmet"]] and optical.selected_region.point==Inputs.Sockets.pose_point(world,world.visual_actors.a.row,"head").point,"Region admission uses the actual source actor head socket and body support, independently of cosmetic head membership")
    world.visual_actors.a.row.scale=1.0;world.visual_actors.a.erase("sampled_pose")
    aimed.native_cue.entity_geometry.actor="target2"
    result=bridge.sync(world,prepared_handle,aimed,exact)
    check(result.unavailable.get("entity_geometry")=="authored_actor_binding_not_bound:target2","An unbound second recipient cannot silently borrow the first recipient's body")

    world.transform=Transform3D.IDENTITY
    for socket in ["hand","cast_hand"]:
        var hand_component:Dictionary={"actor_uuid":"a","target_uuid":"b","from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,"cast_recipe":{"enabled":false},
            "native_cue":{"role":"attached","attachment":"caster_ground","live_endpoints":[{"actor":"caster","socket":socket}]}}
        var hand_points:Dictionary=Inputs.Sockets.endpoints(world,hand_component)
        check(hand_points.ready and hand_points.hand.y>hand_points.caster_ground.y,"Authored caster "+socket+" explicitly demands the real pose hand even for a ground-registered attached cue")
    var authored:Dictionary={"actor_uuid":"a","target_uuid":"b","native_clip":legacy_handle.clip,"native_cue":{"live_endpoints":[{"actor":"target","socket":"head","view_basis":true}]}}
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.is_empty() and endpoint_probe.endpoints.size()==1 and endpoint_probe.endpoints[0].actor_uuid=="b" and is_equal_approx(endpoint_probe.endpoints[0].point.x,10.0),"A one-row authored recipient head endpoint resolves the target's actual pose instead of caster/ground")
    check(endpoint_probe.endpoints[0].view_basis==world.camera.global_basis,"Authored view_basis carries the actual displayed camera basis")
    authored.native_cue.live_endpoints=[{"actor":"caster","socket":"cast_hand"},{"actor":"target","socket":"body_center","surface_slots":["body","chest"]},{"cue_point":"source"},{"actor":"target","socket":"ground"}]
    exact.from=Vector3(4,6,8)
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.is_empty() and endpoint_probe.endpoints.size()==4 and endpoint_probe.endpoints[0].point==exact.hand and endpoint_probe.endpoints[2].point==exact.from and endpoint_probe.endpoints[3].point==Vector3(10,0,0),"Authored four-row delivery preserves current hand, recipient, accepted source and ground roles/order")
    check(optical.selected==["b",["body","chest"]] and endpoint_probe.endpoints[1].surface.actor=="b","Endpoint surface_slots requests the exact actor and slots without a body-wide substitute")
    bridge.prepare(world,[authored],false)
    check(optical.prepared.back()==[["b"],["body","chest"],false],"Early endpoint surface preparation shares the exact slot request and optional priority")
    authored.native_cue.live_endpoints=[{"actor":"target2","socket":"ground"}]
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.get("targets")=="authored_actor_binding_not_bound:target2" and endpoint_probe.endpoints.is_empty(),"Missing second-role binding clears the previous packet and is not marked supplied")
    authored.native_actor_uuids={"target2":"a"}
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.is_empty() and endpoint_probe.endpoints[0].actor_uuid=="a","An explicit actual second-role UUID can bind without inventing an entity")
    authored.native_cue.live_endpoints=[{"point":[2,0,0]}]
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.get("targets")=="review_endpoint_position_not_bound","Literal Factory review coordinates cannot become gameplay endpoints")
    authored.native_cue.live_endpoints=[];authored.native_cue.review_trajectory={"points":[[1,0,0]]}
    result=bridge.sync(world,legacy_handle,authored,exact)
    check(result.unavailable.get("targets")=="review_trajectory_not_bound","A Factory review trajectory remains explicitly unavailable")

    var cell_probe:EndpointProbe=EndpointProbe.new()
    var cell_clip:Dictionary=Effects.clip("conditions/continuation/spatial_web_persistent/application").duplicate()
    cell_clip.inputs=["admitted_cells","delivery_timing"];cell_clip.input_setters={"admitted_cells":"set_admitted_cells","delivery_timing":"set_delivery_timing"}
    var cell_handle:Dictionary={"clip":cell_clip,"occurrence":cell_probe}
    var area:Dictionary={"native_cue":{"launch":.25,"contact":.75},"resolved_area_positions":[[2,3],[5,7]],"to_elevation_feet":10.0}
    result=bridge.sync(world,cell_handle,area,exact)
    check(cell_probe.admitted==[{"centre":Vector3(2,2*Inputs.Sockets.Placement.HEIGHT_UNIT,3),"half_size":Vector2(.5,.5)},{"centre":Vector3(5,2*Inputs.Sockets.Placement.HEIGHT_UNIT,7),"half_size":Vector2(.5,.5)}],"Spatial membership passes only actual disclosed cells and their elevation")
    check(cell_probe.delivery==Vector2(.25,.5),"Delivery timing uses the actual two-argument setter")
    bridge.sync(world,cell_handle,area,exact)
    check(cell_probe.cells_calls==1,"Unchanged footprint performs no cell conversion, setter or upload")
    area.resolved_area_positions=[];bridge.sync(world,cell_handle,area,exact)
    check(cell_probe.cells_calls==2 and cell_probe.admitted.is_empty(),"An empty authoritative footprint explicitly clears previous Factory membership")
    area.resolved_area_positions=[[1,2]];cell_probe.accepts_cells=false
    result=bridge.sync(world,cell_handle,area,exact)
    check(result.unavailable.get("admitted_cells")=="admitted_cells_not_accepted","A rejected actual cell setter cannot create a successful provider witness")
    area.resolved_area_positions=null
    result=bridge.sync(world,cell_handle,area,exact)
    check(cell_probe.admitted.is_empty() and result.unavailable.get("admitted_cells")=="admitted_cells_not_disclosed","A prepared mask clears prior membership when cells are unknown instead of reporting a supplied footprint")
    var native_cells:Node3D=load("res://assets/vfx/clips/8b40e88ffc9f324db4a86ee7/construct.gd").new()
    var cell_source:Node3D=Node3D.new();var nullable:NullableCellProbe=NullableCellProbe.new();cell_source.add_child(nullable)
    # The actual native inner method asserts a nonempty pair array. It is not
    # prepared/sampled here; the real adapter forwarding is the test boundary.
    var acid:Node3D=load("res://assets/vfx/sources/cfd9b5e2882e480dfcd1/acid_arrow.gd").new();cell_source.add_child(acid)
    native_cells.handle={"root":cell_source}
    var native_clip:Dictionary=Effects.clip("bg3-36/acid-arrow/impact").duplicate();native_clip.inputs=["admitted_cells"]
    var native_root:Node3D=Node3D.new();world.add_child(native_root);native_root.position=Vector3(2,1,3)
    var native_handle:Dictionary={"clip":native_clip,"occurrence":native_cells,"root":native_root}
    var native_area:Dictionary={"native_cue":{},"resolved_area_positions":null,"to_elevation_feet":10.0}
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.is_empty() and nullable.calls==0 and acid.admitted_cells.is_empty(),"Native null omits the inapplicable void setter instead of forwarding an invalid empty Array")
    native_area.resolved_area_positions=[[2,3],[5,7]]
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.is_empty() and nullable.calls==1 and nullable.last==[[0.0,0.0],[3.0,4.0]],"A native void-return setter accepts actual local cell pairs without a false rejection")
    check(acid.admitted_cells==nullable.last,"The actual delivered native adapter forwards pairs into its real source consumer")
    bridge.sync(world,native_handle,native_area,exact)
    check(nullable.calls==1,"An unchanged native footprint and root frame performs no new conversion or setter traversal")
    native_root.position+=Vector3.RIGHT;bridge.sync(world,native_handle,native_area,exact)
    check(nullable.calls==2 and nullable.last==[[-1.0,0.0],[2.0,4.0]],"A moved native root updates its local footprint exactly once")
    native_root.basis=Basis(Vector3.UP,PI/4)
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.get("admitted_cells")=="native_admitted_cells_frame_not_grid_aligned" and nullable.calls==2,"An oblique local frame is not silently treated as square grid cells")
    native_root.basis=Basis.IDENTITY.scaled(Vector3(2,1,2))
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.get("admitted_cells")=="native_admitted_cells_frame_not_grid_aligned" and nullable.calls==2,"A scaled native root cannot change authoritative cell size")
    native_root.basis=Basis(Vector3.UP,PI/2)
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.is_empty() and nullable.calls==3,"A unit quarter-turn remains an exact square-grid frame")
    native_area.resolved_area_positions=[]
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.get("admitted_cells")=="native_admitted_cells_empty" and nullable.calls==3,"An authoritative empty native footprint hides its owner without violating the source's nonempty setter")
    native_area.resolved_area_positions=null
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.is_empty() and nullable.calls==3,"Native null stays distinct from an authoritative empty footprint")
    native_area.spatial_owner=true
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.get("admitted_cells")=="admitted_cells_not_disclosed","An actual spatial owner cannot treat unknown membership as an optional non-area operand")
    native_area.spatial_owner=false;native_area.resolved_area_positions=[[9,12]]
    native_handle.clip.inputs=["admitted_cells","targets"]
    native_area.actor_uuid="a";native_area.target_uuid="b"
    native_area.native_cue.live_endpoints=[{"actor":"target","socket":"ground"}]
    native_root.transform=Transform3D(Basis(Vector3.UP,PI/4),Vector3(20,0,30))
    result=bridge.sync(world,native_handle,native_area,exact)
    check(result.unavailable.is_empty() and nullable.last==[[-1.0,12.0]],"Native world-aligned surface topology uses the first actual authored endpoint, not its differently transformed wrapper root")
    var generic:Node3D=load("res://presentation/native_constructed_occurrence.gd").new()
    var generic_source:Node3D=Node3D.new();var generic_cells:NullableCellProbe=NullableCellProbe.new();generic_source.add_child(generic_cells)
    generic.handle={"root":generic_source}
    var generic_clip:Dictionary=native_clip.duplicate();generic_clip.construction_inputs=[]
    var generic_handle={"clip":generic_clip,"occurrence":generic,"root":native_root}
    native_area.resolved_area_positions=[[9,12]]
    result=bridge.sync(world,generic_handle,native_area,exact)
    check(result.unavailable.is_empty() and generic_cells.calls==1 and generic_cells.last==[[-1.0,12.0]],"A publicly constructed occurrence forwards authoritative cells to its actual child source")
    bridge.sync(world,generic_handle,native_area,exact)
    check(generic_cells.calls==1,"Unchanged constructed cell membership is not forwarded again")
    var projection_probe:ProjectionProbe=ProjectionProbe.new()
    var projection_handle={"clip":{"inputs":["owner_projection"],"input_setters":{"owner_projection":"set_owner_projection"}},"occurrence":projection_probe}
    var projection_component={"actor_uuid":"a","native_cue":{},"native_inputs":{"owner_projection":{"actor_uuid":"a","owner_uuid":"actual"}}}
    bridge.sync(world,projection_handle,projection_component,exact);bridge.sync(world,projection_handle,projection_component,exact)
    check(projection_probe.calls==1,"An unchanged immutable event packet reaches a rebuilding source setter only once")
    projection_component.native_inputs={"owner_projection":{"actor_uuid":"a","owner_uuid":"next"}}
    bridge.sync(world,projection_handle,projection_component,exact)
    check(projection_probe.calls==2 and projection_probe.packet.owner_uuid=="next","A changed observed packet still updates the source")
    projection_component.native_inputs.owner_projection.owner_uuid="removed"
    bridge.sync(world,projection_handle,projection_component,exact)
    check(projection_probe.calls==3 and projection_probe.packet.owner_uuid=="removed","The setter witness owns its small snapshot, so an in-place packet update is not mistaken for the previous value")
    projection_component={"actor_uuid":"a","native_cue":{},"persistent_owner":true,"initial":false,"duration_ms":INF,
        "condition":{"condition_uuid":"held","behavior_id":"class_feature.barbarian.raging"}}
    result=bridge.sync(world,projection_handle,projection_component,exact)
    check(result.unavailable.is_empty() and projection_probe.packet.removed_seconds==-1.0 and projection_probe.packet.owner_uuid=="held","A held condition projects the actual owner with no invented removal")
    projection_component.duration_ms=5000.0;bridge.sync(world,projection_handle,projection_component,exact)
    check(projection_probe.packet.removed_seconds==5.0,"A real observed end updates the same source owner")
    projection_component.initial=true;result=bridge.sync(world,projection_handle,projection_component,exact)
    check(result.unavailable.get("owner_projection")=="condition_application_not_observed","A pre-existing owner never borrows a fabricated application history")
    projection_probe.free();generic.free();generic_source.free()
    legacy.free();source.free();prepared.free();cell_probe.free();native_cells.free();cell_source.free();native_root.free()
    bridge.clear();world.queue_free();await process_frame
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual Factory setters/private ownership/restoration; native output and first-use pipeline timing are separate GPU gates"}))
    quit(0 if failures.is_empty() else 1)
