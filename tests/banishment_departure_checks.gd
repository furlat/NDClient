extends SceneTree
## Genuine original logical/optical operands. No compositor-output qualification.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Catalog=preload("res://source_catalog.gd")
const Characters=preload("res://presentation/characters.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Placement=preload("res://placement.gd")
const ROOT="res://tests/fixtures/schema16/banishment-departure"
const PATH="res://authoring/abilities/conditions/condition.spell.banishment.tres"
const ID="condition.spell.banishment"
const OWNER="ecf7b3e2-db29-4bd1-a409-db454c273679"
const ACTOR="624b4c84-d297-4a3e-9b17-f267b7c4ce81"
class CaptureProbe extends RefCounted:
    var history:Dictionary={}
    var ages:Array=[]
    func sample(seconds:float)->void:
        ages.append(seconds);history.recipient=[seconds]
    func capture_status()->Dictionary:
        return {"error":"","captures":[{"ready":not ages.is_empty(),"requested_identity":"original","drawn_identity":"original"}]}
class HistoryProbe extends Node3D:
    var parameters:Dictionary={"actor_history":{"capture_departure":true,"mirror":false}}
    var context:Dictionary={}
    var history_calls:int=0
    var actor_history:RefCounted=CaptureProbe.new()
    func set_actor_context(value:Dictionary)->bool:context=value;return true
    func set_history_state(_value:Dictionary)->void:history_calls+=1
class World extends Node3D:
    var catalog_cache:Dictionary={}
    var timeline:RefCounted
    var visual_actors:Dictionary={}
    var playbacks:Dictionary={}
    var rigs:Dictionary={}
    var rig_config:Dictionary={}
    var resources:Dictionary={}
    var textures:Dictionary={}
    var source_depth:bool=true
    var source_normals:bool=true
    var character_light_profile:String="original"
    var quarter:int=0
    var camera:Camera3D
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BANISHMENT_DEPARTURE_FAIL ",label)
func cache_for(entry:Resource)->Dictionary:
    var built:Dictionary=Build.documents({"conditions":{ID:entry}},{"conditions":{ID:PATH}})
    var cache:Dictionary={};var recipes:Dictionary=Catalog.read_file("catalog/condition_recipes.json",cache).duplicate()
    recipes.merge(built.docs["catalog/condition_recipes.json"],true);cache["catalog/condition_recipes.json"]=recipes
    return cache
func run()->void:
    Effects._ensure_clock()
    var entry:Resource=load(PATH);var cache:Dictionary=cache_for(entry)
    check(entry.capture_departure and entry.status=="partial","Typed departure intent remains separate from final visual acceptance")
    check(cache["catalog/condition_recipes.json"][ID].persistent.actorHistory.captureDeparture,"Typed intent round-trips into the one existing recipe path")
    var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX));var clips:Dictionary={}
    for clip in package.clips:clips[clip.clip_id]=clip
    var report:Dictionary={"errors":[],"warnings":[]}
    Build._check_departure_definitions({ID:entry},clips,report)
    check(report.errors.is_empty(),"Offline source proof selects only actual non-Mirror departure constructors: "+str(report.errors))
    check(not Inputs.departure_history({"baked":true,"clip":{}}),"Recorded handles without a live occurrence have no departure constructor")
    for seat in ["amber","blue"]:await inspect_seat(seat,cache)
    print("BANISHMENT_DEPARTURE ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both unchanged original admissions, independent original pre-cut operands, faction-specific null/retained position, async private source realization, explicit non-Mirror count N/A, camera re-realization and teardown. Native pixels and live performance are qualified separately by the shared compositor gate."}))
    quit(0 if failures.is_empty() else 1)
func inspect_seat(seat:String,cache:Dictionary)->void:
    var index:Dictionary=Recording.read(ROOT.path_join(seat),{},{},cache)
    check(index.ok,seat+" original complete journal opens: "+str(index.get("error","")))
    if not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==OWNER)
    check(spans.size()==1,seat+" one actual original condition UUID lifetime")
    if spans.size()!=1:return
    var span:Dictionary=spans[0]
    var before:RefCounted=Recording.restore(index,float(span.start_ms)-.001)
    var admitted:RefCounted=Recording.restore(index,float(span.start_ms)+.001)
    check(not before.condition_owners.has(OWNER),seat+" no future owner/capture before actual admission")
    var owner:Dictionary=admitted.condition_owners.get(OWNER,{})
    check(owner.has("logical_pose") and owner.logical_pose.has("departure"),seat+" actual pre-cut admission captures the original departure")
    if not owner.has("logical_pose") or not owner.logical_pose.has("departure"):return
    var capture:Dictionary=owner.logical_pose
    check(capture.actor_uuid==ACTOR and capture.condition_uuid==OWNER and capture.is_read_only() and capture.departure.is_read_only(),seat+" immutable capture retains actual actor/condition identities")
    var expected:Dictionary=original_actor(seat,7)
    check(capture.departure.actor.appearance==expected.appearance and capture.departure.actor.visual_loadout==expected.visual_loadout,seat+" pre-cut appearance/loadout equal the independently frozen SDK fold")
    check(capture.departure.row.position==[4,7] and capture.departure.actor.spatial_disposition=="present",seat+" original pre-departure support is retained before absence")
    var canonical:Dictionary=admitted.state.actors[ACTOR]
    check(canonical.spatial_disposition=="absent" and canonical.last_visual_position==(null if seat=="amber" else [4,7]),seat+" actual faction-specific null/retained position remains canonical")
    check(not admitted.actor_samples().get(ACTOR,{}).get("captured",false),seat+" departure capture never freezes or publishes an absent body")
    var planned:Dictionary=before._world_candidate(before.replay_plan(float(span.start_ms)+.001))
    check(not before.condition_owners.has(OWNER) and planned.state.actors[ACTOR].spatial_disposition=="absent",seat+" future world preparation keeps departure/canonical absence unpublished")
    var held:RefCounted=Recording.restore(index,lerpf(float(span.start_ms),float(span.end_ms),.75))
    check(held.condition_owners[OWNER].logical_pose==capture,seat+" late seek reconstructs the same original admission rather than later actor state")
    var restored:RefCounted=Recording.restore(index,float(span.end_ms)+.001)
    check(restored.state.actors[ACTOR].spatial_disposition=="present" and restored.state.actors[ACTOR].last_visual_position==[4,7],seat+" genuine concentration removal restores the actual body")
    check(restored.state.actors[ACTOR].visual_loadout==expected.visual_loadout,seat+" return preserves original public equipment")
    var native:Array=Conditions.native_samples(held.condition_owners,held.display_ms,index.cache).filter(func(component):return component.get("condition_uuid")==OWNER and "actor_context" in component.get("native_clip",{}).get("inputs",[]))
    check(native.size()==1,seat+" one actual UUID lifecycle receives departure operands")
    if native.size()!=1:return
    var component:Dictionary=native[0]
    check(component.logical_pose==capture and component.condition.state.duplicate_count==null,seat+" actual capture reaches the existing lifecycle while null count stays null")
    material_and_motion_controls(before,capture,component,index.cache,seat)
    var world:=World.new();world.timeline=held;world.catalog_cache=index.cache.duplicate();world.rigs=Characters.rigs(world.catalog_cache)
    var catalog:Dictionary=Catalog.read_file("catalog-index.json",world.catalog_cache)
    world.rig_config=Catalog.read_file(catalog.rig,world.catalog_cache);world.resources=Catalog.read_file(catalog.resources,world.catalog_cache)
    world.camera=Camera3D.new();world.add_child(world.camera);root.add_child(world)
    var source:=HistoryProbe.new();world.add_child(source)
    var handle:Dictionary={"occurrence":source,"clip":component.native_clip,"root":source}
    var bridge:RefCounted=Inputs.new();var start:int=Time.get_ticks_msec();var ready:Dictionary={}
    while Time.get_ticks_msec()-start<10000:
        ready=bridge.prepare_departure(world,handle,component)
        for path in handle.get("departure_paths",{}):
            if world.textures.has(path):continue
            var image:=Image.new();var decoded:Error=image.load(Catalog.media_path(path))
            check(decoded==OK,seat+" actual admitted departure image decodes: "+path)
            if decoded==OK:world.textures[path]=ImageTexture.create_from_image(image)
        if ready.ready or not ready.pending:break
        await process_frame
    check(ready.get("ready",false),seat+" existing metadata/private-actor workers finish: "+str(ready))
    if ready.get("ready",false):
        check(world.visual_actors.is_empty(),seat+" private capture enters no displayed actor registry")
        check(handle.departure_entries.all(func(layer):return layer.node.layers==0 and not layer.node.is_visible_in_tree()),seat+" capture-only private layers never draw directly")
        var snapshot:PackedByteArray=var_to_bytes(held.state)
        var receiver:=ImageTexture.create_from_image(Image.create_empty(2,2,false,Image.FORMAT_RGBA8))
        var previous_revision:Variant=null;var previous_logical:Variant=null;var nodes:Array=handle.departure_entries.map(func(layer):return weakref(layer.node))
        for quarter in range(4):
            world.quarter=quarter;world.camera.transform=Placement.camera_transform(Vector3.ZERO,quarter)
            var points:Dictionary=Inputs.Sockets.endpoints(world,component)
            check(points.ready and points.ground==Placement.contact(capture.departure.row),seat+" actual original ground registers absent target in view "+str(quarter))
            var bound:Dictionary=bridge.sync(world,handle,component,points,receiver)
            check(bound.unavailable.is_empty() and "actor_context" in bound.supplied,seat+" original layer packet reaches the actual public setter seam in view "+str(quarter))
            check(bound.not_applicable.get("history_state")=="non_mirror_departure_does_not_consume_duplicate_count" and source.history_calls==0,seat+" non-Mirror source count is explicitly N/A, never fabricated")
            check(source.actor_history.ages.size()==quarter+1 and source.actor_history.ages.all(func(age):return age==0.0),seat+" each new optical view seeds only the genuine original admission age, never the occurrence clock")
            var packet:Dictionary=source.context
            check(packet.layers.is_empty() and packet.departure_layers.size()==handle.departure_entries.size(),seat+" departure packet contains private original layers instead of current body proxies")
            check(packet.departure_origin==Placement.contact(capture.departure.row),seat+" departure origin does not change with camera")
            if previous_logical!=null:check(packet.departure_revision==previous_logical and packet.departure_capture_revision!=previous_revision,seat+" only optical capture revision changes across views")
            previous_logical=packet.departure_revision;previous_revision=packet.departure_capture_revision
            for layer in handle.departure_entries:
                check(layer.material.get_shader_parameter("sheet")==world.textures[layer.prepared_source_binding.path],seat+" capture borrows the exact admitted original source texture")
                check(layer.material.get_shader_parameter("tint")==Construction.Modular.rgb(layer.actor_layer.tint),seat+" actual pre-cut outfit tint reaches the private material")
                var expected_transform:Transform3D=original_transform(world.camera.basis,capture.departure.row,world.rigs[capture.rig],capture.departure.motion,layer.role,capture.clip,world.rig_config.FACING_CYCLE[posmod(world.rig_config.FACING_CYCLE.find(capture.world_facing)+quarter*2,8)],capture.frame,world.rig_config.TILE_W,capture.departure.material.body_scale.factor)
                check(layer.node.global_transform==expected_transform,seat+" private transform equals the independent pre-extraction displayed-body equations")
        check(var_to_bytes(held.state)==snapshot,seat+" preparation/recapture leaves absent canonical state byte-for-byte unchanged")
        var missing:Dictionary=component.duplicate();missing.erase("logical_pose")
        check(Inputs.Sockets.endpoints(world,missing).reason=="condition_original_departure_not_observed",seat+" missing original capture cannot borrow a retained/current actor position")
        Inputs.release_departure(handle)
        check(nodes.all(func(node):return node.get_ref()==null) and not handle.has("departure_entries"),seat+" existing occurrence teardown frees all private capture nodes/operands")
        # A pending worker belongs to the same close path; no unowned future result.
        bridge.prepare_departure(world,handle,component);Inputs.release_departure(handle)
        check(not handle.has("departure_task") and not handle.has("departure_output"),seat+" closing during preparation joins only this owner's task and clears its future packet")
    source.free();bridge.clear();world.free()
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+" all original indexed packets and captures stay immutable")
    evidence.append({"seat":seat,"start_ms":span.start_ms,"end_ms":span.end_ms,"capture":capture,"canonical_position":canonical.last_visual_position})
func material_and_motion_controls(before:RefCounted,capture:Dictionary,component:Dictionary,cache:Dictionary,seat:String)->void:
    # Explicit pure admission controls use genuine actor/member operands; they
    # are not additional claimed server events or supported interruption cases.
    var condition:Dictionary=component.condition
    var row:Dictionary={"actor_uuid":ACTOR,"before":null,"after":condition,"row":{"field":"condition","condition_uuid":OWNER}}
    var flash:Dictionary={"id":"unit/material","kind":"material_flash","actor_uuid":ACTOR,"start_ms":0.0,"duration_ms":1000.0,
        "colors":[0x336699],"material":{},"source_event_uuid":"unit-only"}
    var commit:Dictionary={"condition_rows":[row],"at_ms":250.0}
    var group:Dictionary={"actor_tracks":[],"components":[]}
    var retained:Array=[{"component":flash,"group_start_ms":0.0}]
    var original:PackedByteArray=var_to_bytes(before.state)
    var captured:Dictionary=Timeline.pose_admissions(commit,before.state,before.condition_owners,group,0.0,{},cache,retained)[OWNER]
    check(captured.departure.material.flash.id==flash.id and captured.departure.material.flash.age_ms==250.0,seat+" pure boundary retains finite treatment from an earlier group's actual clock")
    var packet:Dictionary=captured.departure.material.flash
    check(is_equal_approx(float(Conditions.parameters(captured.departure.material,{},{}).flash_strength),.75) and packet.colors==flash.colors,seat+" exact prior treatment envelope/colour survives logical capture")
    flash.native_hit={"clip":{"id":"unit-only"}}
    captured=Timeline.pose_admissions(commit,before.state,before.condition_owners,group,0.0,{},cache,retained)[OWNER]
    check(captured.departure.get("reason","").is_empty() \
        and captured.departure.material.flash.native_hit==flash.native_hit \
        and not captured.departure.material.flash.has("native_surface"),seat+" logical native-hit capture retains its immutable source dependency without borrowing a framebuffer")
    check(var_to_bytes(before.state)==original,seat+" pure material capture controls never alter canonical actor data")
    var unseen:Dictionary=before.state.duplicate(false);unseen.senses=unseen.senses.duplicate(false)
    unseen.senses.entities=unseen.senses.entities.duplicate(false)
    unseen.senses.entities[ACTOR]=unseen.senses.entities.get(ACTOR,{}).duplicate(false);unseen.senses.entities[ACTOR].visual=false
    unseen.audience=unseen.audience.duplicate(false);unseen.audience.controlled=unseen.audience.controlled.filter(func(id):return id!=ACTOR)
    var hidden:Dictionary=Timeline.pose_admissions(commit,unseen,before.condition_owners,group,0.0,{},cache)
    check(not hidden.has(OWNER),seat+" a remembered unseen living actor supplies no original departure or stale-position echo")
    unseen.audience.controlled=unseen.audience.controlled.duplicate();unseen.audience.controlled.append(ACTOR)
    var controlled:Dictionary=Timeline.pose_admissions(commit,unseen,before.condition_owners,group,0.0,{},cache)
    check(controlled.has(OWNER) and controlled[OWNER].has("departure"),seat+" the existing controlled-actor disclosure policy remains a valid original capture")
    var rig:Dictionary=Characters.rigs(cache)[capture.rig]
    var config:Dictionary=Catalog.read_file(Catalog.read_file("catalog-index.json",cache).rig,cache)
    var moved:Dictionary=capture.departure.row.duplicate();moved.scale_x=-1.0;moved.scale=1.25;moved.position=[3.5,6.25];moved.base_height_steps=2.0
    var motion:Dictionary={"lift_pixels":11.0,"passage_weight":.5,
        "passage":{"passageScale":[.8,.65],"passageSocket":"hand","passageBodyHeightPx":34.0}}
    for quarter in range(4):
        var basis:Basis=Placement.camera_transform(Vector3.ZERO,quarter).basis
        var facing:String=config.FACING_CYCLE[posmod(config.FACING_CYCLE.find(capture.world_facing)+quarter*2,8)]
        for scale in [.5,1.0,2.0]:
            for role in ["body","shadow"]:
                check(Construction.layer_transform(basis,moved,rig,motion,role,capture.clip,facing,int(capture.frame),config.TILE_W,scale)==original_transform(basis,moved,rig,motion,role,capture.clip,facing,int(capture.frame),config.TILE_W,scale),seat+" pure old displayed transform is exact across passage/lift/flip/body-scale/view controls")
func original_actor(seat:String,end:int)->Dictionary:
    var journal:RefCounted=Journal.new();var directory:String=ROOT.path_join(seat)
    check(journal.open(directory,true,false).ok,seat+" independent original prefix opens")
    for sequence in range(end+1):
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" independent original packet decodes "+str(sequence))
        if not decoded.ok:return {}
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" independent original prefix folds "+str(sequence))
        if not folded.ok:return {}
    return journal.state.actors[ACTOR]
func original_transform(camera_basis:Basis,row:Dictionary,rig:Dictionary,sample:Dictionary,role:String,clip_name:String,facing:String,frame:int,tile_width:float,body_scale:float)->Transform3D:
    # Frozen old Play equations are an independent extraction oracle, not runtime.
    var basis:Basis=camera_basis.scaled_local(Vector3(row.get("scale_x",1.0),1,1))
    var position:Vector3=Placement.contact(row)
    if sample.has("passage") and role!="shadow":
        var weight:float=sample.passage_weight;var passage:Dictionary=sample.passage
        var sx=lerpf(1,passage.passageScale[0],weight);var sy=lerpf(1,passage.passageScale[1],weight)
        basis=camera_basis.scaled_local(Vector3(row.get("scale_x",1.0)*sx,sy,1))
        var points:Array=rig.get("pose_sockets",{}).get(passage.passageSocket,{}).get(clip_name,{}).get(facing,[])
        var socket:Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else null
        var unit=128.0/float(tile_width)*row.scale/Placement.PIXELS_PER_UNIT
        position+=camera_basis.y*float(passage.passageBodyHeightPx)*(1-sy)*unit
        if socket!=null:
            position+=camera_basis.x*(rig.cell_width*.5-socket.x)*row.get("scale_x",1.0)*sx*weight*unit
            position-=camera_basis.y*(rig.cell_height-rig.origin_y_from_ground-passage.passageBodyHeightPx-socket.y)*sy*weight*unit
    if body_scale!=1.0:
        basis=basis.scaled_local(Vector3.ONE*body_scale)
        position=Placement.contact(row)+(position-Placement.contact(row))*body_scale
    if role!="shadow":position.y+=float(sample.get("lift_pixels",0))*(128.0/tile_width)/64.0*Placement.HEIGHT_UNIT
    return Transform3D(basis,position)
