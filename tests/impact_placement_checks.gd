extends SceneTree
# Recorded damage -> immutable effect anchor, checked against the native body
# sampler and the displayed direction history. No particle or pixel claim.
const Recording=preload("res://studio/recording.gd")
const Impact=preload("res://presentation/impact_placement.gd")
const Graphs=preload("res://animation/graphs.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var output="res://generated/impact_placement_checks.json"
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("IMPACT_FAIL ",label)
func direction_at(tracks:Array,at:float,previous:Dictionary)->Dictionary:
    var directions=previous.duplicate()
    var ordered=tracks.duplicate();ordered.sort_custom(func(a,b):return a.start_ms<b.start_ms)
    for track in ordered:
        if track.start_ms>at:continue
        var first:Variant=track.get("from_position")
        var last:Variant=track.get("target_position",track.get("to_position"))
        if first!=null and last!=null and first!=last:directions[track.actor_uuid]=[first,last]
    return directions
func facing_of(points:Array,config:Dictionary)->String:
    var d=Vector2(points[1][0]-points[0][0],points[1][1]-points[0][1])
    return config.FACING_CYCLE[posmod(roundi((atan2(d.y,d.x)+PI/4)/(TAU/8))+config.FACING_CYCLE.find("E"),8)]
func run()->void:
    var paths:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):paths.append(argument.trim_prefix("--recording="))
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    if paths.is_empty():push_error("Explicit --recording required");quit(2);return
    var parent=Node.new();root.add_child(parent)
    var impacts=0
    for path in paths:
        var index=Recording.read(path)
        check(index.get("ok",false),"Real recording admitted "+path)
        if not index.get("ok",false):continue
        var directions={}
        var config=Impact.Authoring.load_data("catalog/rig.json",index.cache)
        var hosts={}
        for item in index.groups:
            var group:Dictionary=item.group
            for component in group.get("components",[]):
                if component.get("attachment")!="impact":continue
                impacts+=1
                var held_component=component.duplicate(true)
                var timeline=Recording.restore(index,item.start_ms+component.start_ms)
                var resolved=timeline.component_samples(index.cache).filter(func(row):return row.id==component.id)
                check(resolved.size()==1,"Restore publishes the exact due impact "+component.id)
                if resolved.is_empty():continue
                var receipt:Dictionary=resolved[0].impact
                var actor:Dictionary=component.presentation_actor
                var label=path+":"+component.id
                check(receipt.status=="available",label+" real recorded impact resolves")
                if receipt.status!="available":continue
                var sampled=Impact.Tracks.samples(group.actor_tracks,component.start_ms).get(component.actor_uuid,{})
                var current=direction_at(group.actor_tracks,component.start_ms,directions)
                var facing=facing_of(current[component.actor_uuid],config) if current.has(component.actor_uuid) else "SW"
                var rig:Dictionary=Impact.Authoring.load_data("catalog/rigs.json",index.cache)[receipt.source_rig]
                var frame=-1
                if not sampled.is_empty():
                    if not hosts.has(receipt.source_rig):hosts[receipt.source_rig]=Graphs.build_character(parent,rig,true)
                    var result=Graphs.sample(hosts[receipt.source_rig],sampled.clip,sampled.source_seconds,component.id)
                    check(result.ok,label+" native body sampling succeeds")
                    frame=mini(int(hosts[receipt.source_rig].sample_seconds*rig.clips[sampled.clip].fps),int(rig.clips[sampled.clip].frames)-1)
                    check(receipt.source_clip==sampled.clip and receipt.source_frame==frame,label+" impact uses actual native sampled clip/frame")
                check(receipt.source_facing==facing,label+" impact uses retained displayed facing")
                var pixel:Variant=rig.body_anchor
                var bank:Array=rig.get("pose_sockets",{}).get("body_center",{}).get(receipt.source_clip,{}).get(facing,[])
                if not bank.is_empty():pixel=bank[mini(frame,bank.size()-1)]
                check(pixel!=null,label+" recorded pose has authored impact socket")
                if pixel==null:continue
                var point:Array=sampled.get("position",actor.last_visual_position)
                var elevation=float(sampled.get("base_height_steps",receipt.elevation_feet/5.0))
                var foot=Vector3(point[0],elevation*Impact.Placement.HEIGHT_UNIT,point[1])
                var lift=float(sampled.get("lift_pixels",0))*128.0/float(config.TILE_W)/64.0*Impact.Placement.HEIGHT_UNIT
                var offset:Vector3=receipt.world_anchor-foot-Vector3.UP*lift
                var unit=128.0/float(config.TILE_W)*actor.appearance.visual_scale/Impact.Placement.PIXELS_PER_UNIT
                check(absf(offset.dot(Impact.REFERENCE_BASIS.x)-(pixel.x-rig.cell_width*.5)*actor.appearance.visual_scale_x*unit)<.000001,label+" canonical-view horizontal socket registration")
                check(absf(offset.dot(Impact.REFERENCE_BASIS.y)-(rig.cell_height-rig.origin_y_from_ground-pixel.y)*unit)<.000001,label+" canonical-view vertical socket registration includes exact support/lift")
                check(absf(Vector2(offset.x,offset.z).dot(Vector2(Impact.REFERENCE_BASIS.z.x,Impact.REFERENCE_BASIS.z.z)))<.000001,label+" upright point has no invented ground-depth displacement")
                var immutable=receipt.duplicate(true)
                var changed=actor.duplicate(true);changed.last_visual_position=[99,98]
                Impact.prepare(changed,[],component.start_ms,{},index.cache)
                check(receipt==immutable,label+" later recipient position does not move retained impact")
                timeline.paused=false;timeline.advance(minf(70.0,component.duration_ms*.25))
                var later=timeline.component_samples(index.cache).filter(func(row):return row.id==component.id)
                check(later.size()==1 and later[0].impact==immutable,label+" forward display keeps one exact impact-time anchor")
                var seek_again=Recording.restore(index,item.start_ms+component.start_ms+minf(70.0,component.duration_ms*.25))
                var seek_samples=seek_again.component_samples(index.cache).filter(func(row):return row.id==component.id)
                check(seek_samples.size()==1 and seek_samples[0].impact==immutable,label+" direct seek restores receipt without prior sampled frames")
                var tail_at=item.start_ms+group.duration_ms+.001
                if tail_at<item.start_ms+component.start_ms+component.duration_ms:
                    var tail=Recording.restore(index,tail_at)
                    var tails=tail.component_samples(index.cache).filter(func(row):return row.id==component.id)
                    check(tails.size()==1 and tails[0].impact==immutable,label+" completed-group tail retains impact-time direction")
                timeline.advance(component.duration_ms+1)
                check(not timeline.component_samples(index.cache).any(func(row):return row.id==component.id),label+" finite impact expires rather than retaining a finished occurrence")
                check(component==held_component,label+" delayed receipt never mutates compiler source")
                if impacts==1:_typed_boundaries(actor,rig,hosts[receipt.source_rig],index.cache)
                evidence.append({"recording":path,"component":component.id,"event":component.source_event_uuid,"clip":receipt.source_clip,"frame":frame,"receipt_facing":receipt.source_facing,"displayed_facing":facing,"source_pixel":receipt.source_pixel,"position":receipt.position,"world_anchor":receipt.world_anchor})
            directions=direction_at(group.actor_tracks,INF,directions)
        for host in hosts.values():host.free()
    check(impacts>0,"Explicit real recordings contain impact components")
    parent.free()
    var report={"checks":checks,"failures":failures,"impacts":impacts,"evidence":evidence,"invocation":Array(OS.get_cmdline_user_args()),"scope":"Real recorded compiled impacts compared with native AnimationTree sampling, retained presentation direction and authored socket projection. No GPU/particle/framebuffer claim."}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("IMPACT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"impacts":impacts}));quit(0 if failures.is_empty() else 1)

func _typed_boundaries(actor:Dictionary,rig:Dictionary,host:Node,cache:Dictionary)->void:
    var clip:Dictionary=rig.clips.Run
    var period=float(clip.frames)/clip.fps
    var track=Impact.Tracks.body(actor.uuid,Impact.Authoring.rig_id(actor,cache),"Run",clip,1,10)
    track.merge({"duration_ms":1000.0,"source_start_seconds":2*period+.05,"source_end_seconds":2*period+.25,
        "from_position":[2,3],"to_position":[4,3],"from_elevation_feet":5.0,"to_elevation_feet":10.0,
        "trajectory":"direct_arc","arc_height_px":24.0,"motion_fraction_from":0.0,"motion_fraction_to":1.0},true)
    var held_actor=actor.duplicate(true);var held_track=track.duplicate(true)
    var source=Impact.prepare(actor,[track],500,{},cache)
    Graphs.sample(host,"Run",2*period+.15,"impact-loop-boundary")
    var frame=mini(int(host.sample_seconds*clip.fps),int(clip.frames)-1)
    check(source.source_frame==frame,"Accumulated looping body time matches native AnimationTree frame")
    check(source.position==[3.0,3.0] and source.elevation_feet==7.5 and is_equal_approx(source.lift_pixels,24.0),"Impact source keeps fractional support and actual airborne pose")
    check(actor==held_actor and track==held_track,"Impact preparation preserves caller actor and track")
    var isolated=cache.duplicate();isolated["catalog/rigs.json"]=cache["catalog/rigs.json"].duplicate(true)
    var selected:Dictionary=isolated["catalog/rigs.json"][source.source_rig]
    if not selected.pose_sockets.body_center.has("Run"):selected.pose_sockets.body_center.Run={}
    selected.pose_sockets.body_center.Run.erase("SW")
    var fallback=Impact.with_direction(source,[],isolated)
    check(fallback.status=="available" and fallback.source_pixel==rig.body_anchor,"Absent socket bank uses the rig's declared body anchor")
    var empty:Array=[];empty.resize(int(clip.frames));empty.fill(null)
    selected.pose_sockets.body_center.Run.SW=empty
    var missing=Impact.with_direction(source,[],isolated)
    check(missing.status=="missing" and missing.reason=="impact_body_socket_explicitly_absent","Explicit null socket remains a named unavailable attachment")
    check(source.status=="pending_direction" and not source.has("world_anchor"),"Resolving directions never mutates borrowed preparation receipt")
