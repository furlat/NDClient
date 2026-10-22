extends RefCounted
## A detached effect owns its admitted impact point, never the actor's later pose.
## The body socket is presentation authoring. Optical normal/depth packets are
## receiving fields, not physical surfaces or a substitute for the grid order.
const Authoring=preload("res://presentation/authoring.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Placement=preload("res://placement.gd")
const Graphs=preload("res://animation/graphs.gd")
const REFERENCE_BASIS=Basis(Vector3(.7071067811865475,0,-.7071067811865475),Vector3(-.3535533905932738,.8660254037844386,-.3535533905932738),Vector3(.6123724356957945,.5,.6123724356957945))

static func prepare(actor: Dictionary,tracks: Array,at_ms: float,contact: Dictionary,cache: Dictionary) -> Dictionary:
    if actor.is_empty() or actor.get("last_visual_position")==null:return {"status":"missing","reason":"impact_recipient_not_disclosed"}
    var rig_id=Authoring.rig_id(actor,cache)
    var rig: Dictionary=Authoring.rigs(cache).get(rig_id,{})
    if rig.is_empty() or rig.get("body_anchor")==null:return {"status":"missing","reason":"impact_body_anchor_not_authored"}
    var sample: Dictionary=Tracks.samples(tracks,at_ms).get(actor.uuid,{})
    var position: Array=sample.get("position",actor.last_visual_position)
    var height=float(sample.get("base_height_steps",contact.get("from_elevation_feet",0)/5.0))
    var clip: String=sample.get("clip","")
    var frame=-1
    if not clip.is_empty():
        var seconds:float=sample.source_seconds
        if Graphs.character_loops(rig,clip):seconds=fposmod(seconds,float(rig.clips[clip].frames)/rig.clips[clip].fps)
        frame=clampi(int(seconds*rig.clips[clip].fps),0,int(rig.clips[clip].frames)-1)
    var receipt:Dictionary={"status":"pending_direction","position":position.duplicate(),"elevation_feet":height*5.0,
        "lift_pixels":sample.get("lift_pixels",0.0),"visual_scale":actor.appearance.visual_scale,
        "visual_scale_x":actor.appearance.visual_scale_x,"source_clip":clip,"source_frame":frame,"source_rig":rig_id}
    if rig.get("source_scale",1.0)!=1.0:receipt.source_registration=rig
    return receipt

static func with_direction(receipt: Dictionary,points: Array,cache: Dictionary) -> Dictionary:
    if receipt.status=="missing":return receipt
    var result=receipt.duplicate()
    var rig:Dictionary=receipt.source_registration if receipt.has("source_registration") else Authoring.rigs(cache)[receipt.source_rig]
    var config=Authoring.load_data("catalog/rig.json",cache)
    var facing="SW"
    if points.size()==2:
        var direction=Vector2(points[1][0]-points[0][0],points[1][1]-points[0][1])
        if not direction.is_zero_approx():
            var cycle:Array=config.FACING_CYCLE
            facing=cycle[posmod(roundi((atan2(direction.y,direction.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]
    result.source_facing=facing
    var pixel:Variant=rig.body_anchor
    var sockets:Array=rig.get("pose_sockets",{}).get("body_center",{}).get(receipt.source_clip,{}).get(facing,[])
    if not sockets.is_empty():pixel=sockets[mini(receipt.source_frame,sockets.size()-1)]
    if pixel==null:
        result.status="missing";result.reason="impact_body_socket_explicitly_absent";return result
    var unit=128.0/float(config.TILE_W)*receipt.visual_scale/Placement.PIXELS_PER_UNIT
    if rig.get("source_scale",1.0)!=1.0:unit*=float(rig.source_scale)
    var offset=Vector2((pixel.x-rig.cell_width*.5)*receipt.visual_scale_x,rig.cell_height-rig.origin_y_from_ground-pixel.y)*unit
    var foot=Vector3(receipt.position[0],receipt.elevation_feet/5.0*Placement.HEIGHT_UNIT,receipt.position[1])
    # Fix registration to the canonical view, then solve the upright attachment
    # plane: right·dP=offset.x and up·dP=offset.y with no ground-depth offset.
    # The resulting world point is reprojected, never rebuilt on camera rotation.
    var anchor=foot+REFERENCE_BASIS.x*offset.x+Vector3.UP*offset.y/REFERENCE_BASIS.y.y
    anchor.y+=receipt.lift_pixels*128.0/float(config.TILE_W)/64.0*Placement.HEIGHT_UNIT
    result.merge({"status":"available","world_anchor":anchor,"source_pixel":pixel,
        "registration":"authored_body_socket_on_upright_presentation_plane"},true)
    return result
