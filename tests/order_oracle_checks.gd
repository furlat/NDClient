extends SceneTree
## Engine-key painter oracle on real recordings (Studio cases and the Gallery
## journal) in all four quarters. Godot draws transparent instances sorted by
## material render priority, then by depth = near_plane.distance_to(origin) -
## sorting_offset, evaluated in float32 (render_forward_clustered.cpp,
## _fill_render_list; every participant sets sorting_use_aabb_center=false).
## Along the grid painter's key+id order (grid_order.gd, recomputed here from
## each participant's current placement) every drawn participant must reach the
## engine strictly in that order: (priority, -depth) strictly increases.
## Two offset sets are evaluated on the same frame: the offsets Play actually
## wrote, and the previous ordering path rebuilt here independently (statics and
## ground UI densely ranked, visible moving draws inserted with fractional
## ranks). Play's merged picking order must equal the key+id order too.
## A synthetic Play section adds exact actor/static key ties, statics between
## one actor's layers, many draws in one gap, continuous walks with lift and
## hidden ground stains whose keys differ only in number type.
## Usage: -- [--cases=all|none|a,b] [--gallery=<journal>|none] [--play-frames=N] [--explain]
const Studio=preload("res://studio/studio.gd")
const Order=preload("res://grid_order.gd")
const Placement=preload("res://placement.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const GALLERY:="res://tests/fixtures/schema16/scenarios/gallery/amber"
const CASES:=["dash","stairs","jump","oa-jump-late-lethal","window","window-break",
    "melee","magic-missile","hide-light","prone","ranged","move","invisibility","oa-walk"]
class Probe extends "res://play.gd":
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false)
        add_child(context_menu)
        camera = Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=6.0
        add_child(camera); camera.current=true
    func _process(_delta: float) -> void: pass
var checks:=0
var failures:Array=[]
var configurations:Array=[]
var coverage:Dictionary={}
var scratch:=PackedFloat32Array([0.0])
var studio

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:
        if failures.size()<200:failures.append(label)
        print("ORDER_ORACLE_FAIL ",label)
func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

func f32(value:float)->float:
    scratch[0]=value;return scratch[0]
func dot32(a:Vector3,b:Vector3)->float:
    return f32(f32(f32(a.x*b.x)+f32(a.y*b.y))+f32(a.z*b.z))
func before(a:Dictionary,b:Dictionary)->bool:
    return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id

func drawn(entry:Dictionary)->bool:
    var node=entry.get("node")
    if node==null or not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree():return false
    if node is MultiMeshInstance3D:return node.multimesh!=null and node.multimesh.visible_instance_count!=0 and node.multimesh.instance_count>0
    return true
func priority(entry:Dictionary)->int:
    var node=entry.node
    var material=node.material_override if node is GeometryInstance3D else null
    return material.render_priority if material!=null else 0
func overlay_entries(world:Node)->Array:
    var overlay=world.ground_overlay
    var result:Array=overlay.cells.values()+overlay.routes.values()+overlay.mark_batches.values()
    if not overlay.batch.is_empty():result.append(overlay.batch)
    return result

# Previous ordering path (play.gd before L3): visible statics merged with the
# ground UI take dense ranks; visible moving draws take ins-1+(j+1)/(m+1).
func reference_ranks(world:Node,keyed:Dictionary)->Dictionary:
    var fixed:Array=[]
    for entry in world.static_entries:
        if entry.node.visible:fixed.append(keyed[entry.node.get_instance_id()])
    var overlay=world.ground_overlay
    for entry in overlay.cells.values()+overlay.routes.values()+overlay.mark_batches.values()+([overlay.batch] if not overlay.batch.is_empty() and overlay.batch.node.visible else []):
        fixed.append(keyed[entry.node.get_instance_id()])
    fixed.sort_custom(before)
    var moving:Array=[]
    for entry in world.actor_entries:
        if entry.node.visible:moving.append(keyed[entry.node.get_instance_id()])
    moving.sort_custom(before)
    var ranks:Dictionary={}
    for i in fixed.size():ranks[fixed[i].entry.node.get_instance_id()]=float(i)
    var insertions:PackedInt32Array=[]
    for item in moving:
        var low:=0;var high:=fixed.size()
        while low<high:
            var middle:=(low+high)/2
            if before(fixed[middle],item):low=middle+1
            else:high=middle
        insertions.append(low)
    var first:=0;var widest:=0
    while first<moving.size():
        var stop:=first+1
        while stop<moving.size() and insertions[stop]==insertions[first]:stop+=1
        widest=maxi(widest,stop-first)
        for i in range(first,stop):ranks[moving[i].entry.node.get_instance_id()]=float(insertions[first]-1)+float(i-first+1)/float(stop-first+1)
        first=stop
    ranks[-1]=widest
    return ranks

func evaluate(world:Node,label:String,extra:Dictionary={},informational:bool=false)->Dictionary:
    var camera:Camera3D=world.camera
    var view:Transform3D=camera.get_camera_transform()
    var normal:Vector3=-view.basis.z
    var plane_d:float=f32(dot32(normal,view.origin)+f32(camera.near))
    var forward:Vector3=-camera.global_basis.z
    var participants:Array=[];var keyed:Dictionary={}
    var seen:Dictionary={}
    for entry in world.static_entries+overlay_entries(world)+world.actor_entries:
        var node=entry.get("node")
        if node==null or not is_instance_valid(node) or seen.has(node.get_instance_id()):continue
        seen[node.get_instance_id()]=true
        var item:={"entry":entry,"key":Order.key(entry.placement,entry.role,entry.layer,world.quarter,world.ground_is_background)}
        keyed[node.get_instance_id()]=item
        if drawn(entry):participants.append(item)
    participants.sort_custom(before)
    # The comparator has no order for two different keys that are numerically
    # equal (int and float slots: Array == is type-strict, Order.less is not).
    # Count such neighbours; the key+id order is only defined without them.
    for i in range(1,participants.size()):
        var a:Dictionary=participants[i-1];var b:Dictionary=participants[i]
        if not before(a,b) and not before(b,a) and (a.key!=b.key or a.entry.id==b.entry.id):
            _count("undefined_key_ties")
            if int(coverage.get("undefined_key_ties",0))<=8:print("ORDER_ORACLE_UNDEFINED_TIE ",label," ",a.entry.id," ",b.entry.id," ",a.key," ",b.key)
    var reference:Dictionary=reference_ranks(world,keyed)
    var actual_ok:=true;var reference_ok:=true;var first_failure:=""
    var min_actual:=INF;var min_reference:=INF;var max_offset:=0.0;var min_step:=INF
    var previous_actual:=[];var previous_reference:=[];var previous_rank:=NAN
    var priorities:Dictionary={}
    for item in participants:
        var entry:Dictionary=item.entry
        var node:GeometryInstance3D=entry.node
        var origin:Vector3=node.global_position
        var distance:float=f32(dot32(normal,origin)-plane_d)
        var offset:float=node.sorting_offset
        max_offset=maxf(max_offset,absf(offset))
        var level:int=priority(entry)
        priorities[level]=true
        var depth:float=f32(distance-offset)
        var reference_offset:float=f32(float(reference.get(node.get_instance_id(),NAN))*8.0+forward.dot(origin))
        var reference_depth:float=f32(distance-reference_offset)
        if not previous_actual.is_empty():
            if level==previous_actual[0]:
                min_actual=minf(min_actual,previous_actual[1]-depth)
                if not previous_actual[1]>depth:
                    if actual_ok and OS.get_cmdline_user_args().has("--explain"):
                        var gap_index:int=entry.get("order_gap",-1)
                        if world.get("order_gaps")!=null and gap_index>=0 and world.order_gaps[gap_index]!=null:
                            for member in world.order_gaps[gap_index]:print("ORDER_ORACLE_GAP ",member.id," ",var_to_str(member.order_key)," rank=",member.get("draw_rank")," visible=",member.node.visible," kind=",member.placement.get("kind"))
                        for value in [previous_actual[4],entry]:print("ORDER_ORACLE_EXPLAIN ",label," ",value.id," stored=",value.get("order_key")," gap_key=",value.get("order_gap_key")," stamp=",value.get("order_stamp")," keyed=",value.get("order_keyed")," row=",value.placement," node=",value.node.global_position," offset=",value.node.sorting_offset," rank=",value.get("draw_rank"))
                    if actual_ok:first_failure="%s (%s, rank %s, gap %s) before %s (%s, rank %s, gap %s): depth %.6f then %.6f"%[previous_actual[2],str(previous_actual[3]),str(previous_actual[4].get("draw_rank")),str(previous_actual[4].get("order_gap")),
                        entry.id,str(item.key),str(entry.get("draw_rank")),str(entry.get("order_gap")),previous_actual[1],depth]
                    actual_ok=false
            elif level<previous_actual[0]:actual_ok=false;first_failure="priority decreases at "+entry.id
            if level==previous_reference[0]:
                min_reference=minf(min_reference,previous_reference[1]-reference_depth)
                if not previous_reference[1]>reference_depth:reference_ok=false
            elif level<previous_reference[0]:reference_ok=false
        var rank:float=float(entry.get("draw_rank",NAN))
        if not is_nan(previous_rank) and not is_nan(rank):min_step=minf(min_step,(rank-previous_rank)*8.0)
        previous_rank=rank
        previous_actual=[level,depth,entry.id,item.key,entry];previous_reference=[level,reference_depth]
    var merged:Array=world.draw_order.filter(func(entry):return drawn(entry)).map(func(entry):return entry.id)
    var merged_ok:bool=merged==participants.map(func(item):return item.entry.id)
    if informational:
        # As rendered in real time: producers may still move or publish a draw
        # after the frame's order pass. Counted here; the caller then repeats
        # the order pass on this same state and requires exactness.
        if not actual_ok:
            _count("as_rendered_misorders")
            if int(coverage.as_rendered_misorders)<=12:print("ORDER_ORACLE_AS_RENDERED ",label," ",first_failure)
    else:
        check(actual_ok,label+": written offsets reach the engine in key+id order"+("" if actual_ok else " — "+first_failure))
        check(merged_ok,label+": merged picking order equals key+id order")
    check(reference_ok,label+": previous ordering path reaches the engine in key+id order")
    check(max_offset<=1048576.0,label+": |sorting_offset| <= 2^20")
    var summary:={"label":label,"quarter":world.quarter,"display_ms":world.timeline.display_ms if world.get("timeline")!=null else 0.0,"drawn":participants.size(),
        "statics":world.static_entries.size(),"moving":world.actor_entries.size(),"overlay":overlay_entries(world).size(),
        "actual_ok":actual_ok,"reference_ok":reference_ok,"min_depth_gap":min_actual,"min_reference_gap":min_reference,
        "max_abs_offset":max_offset,"min_rank_step":min_step,"widest_reference_gap":reference.get(-1,0),"priorities":priorities.keys()}
    summary.merge(extra)
    _cover(world,participants)
    configurations.append(summary)
    return summary

func _count(name:String,amount:int=1)->void:
    coverage[name]=int(coverage.get(name,0))+amount
func _cover(world:Node,participants:Array)->void:
    _count("configurations")
    for item in participants:
        var entry:Dictionary=item.entry;var row:Dictionary=entry.placement
        _count("drawn")
        if row.get("kind")=="door":_count("door_pass_"+str(entry.get("source_role","?")))
        if row.has("sort_position"):_count("sort_position")
        if entry.layer==100 and row.has("lit_animation"):_count("flame")
        if entry.get("ground_overlay",false):_count("overlay_route" if str(entry.id).begins_with("ground-route") else "overlay_other")
        if entry.get("generated_shadow",false):_count("generated_shadow")
        if row.get("kind")=="effect":_count("blood_stain")
        if entry.role=="native_effect":_count("blood_droplet_half")
        if float(row.get("base_height_steps",0))<0:_count("negative_elevation")
        if row.get("kind")=="actor" and entry.has("actor_layer"):
            var position:Array=row.position
            if float(position[0])!=floorf(float(position[0])) or float(position[1])!=floorf(float(position[1])):_count("mid_move_layer")
            if float(row.base_height_steps)!=floorf(float(row.base_height_steps)):_count("fractional_height_layer")
            if float(row.get("visual_height",0.0))!=0.0:_count("lift_layer")
    for entry in world.static_entries:
        if entry.has("wall_source") and not entry.node.visible:_count("hidden_wall_member")
    for sample in world.timeline.actor_samples().values() if world.get("timeline")!=null else []:
        if float(sample.get("passage_weight",0.0))>0.0:_count("passage_actor")

func settled()->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending()
func settle()->bool:
    var deadline:=Time.get_ticks_msec()+120000
    while not settled() and Time.get_ticks_msec()<deadline:await process_frame
    for i in 3:await process_frame
    return settled()

func instants()->Array:
    var times:Array=[0.0]
    var moves:=0;var blood:=0;var lifts:=0
    for row in studio.index.rows:
        var track:Dictionary=row.get("track",{})
        if row.kind=="body" and track.has("from_position") and track.has("to_position") and track.from_position!=track.to_position and moves<3:
            times.append(row.start_ms+(row.end_ms-row.start_ms)*0.37);moves+=1
        elif row.kind=="body" and str(track.get("clip","")).to_lower().contains("jump") and lifts<1:
            times.append(row.start_ms+(row.end_ms-row.start_ms)*0.5);lifts+=1
        elif row.kind=="native_effect" and str(row.get("component",{}).get("source_id","")).begins_with("blood") and blood<1:
            times.append(row.start_ms+200.0);blood+=1
    times.append(maxf(0.0,studio.index.duration_ms-50.0))
    return times

func journal(directory:String,play_frames:int)->void:
    studio._load(directory)
    if not await settle():
        check(false,directory+" loads: "+studio.status.text);return
    var name:String=directory.trim_suffix("/journal").get_base_dir().get_file() if not directory.contains("player-runs") else "gallery"
    for at in instants():
        studio._seek(at)
        if not await settle():
            # A Studio seek that never settles (dying-seed3-v3 and dying-seed5
            # end instants, on the previous code too) gives no order evidence.
            _count("unsettled_seeks");print("ORDER_ORACLE_UNSETTLED %s %.0f ms "%[name,at],studio.status.text);continue
        for turn in 4:
            if turn>0:
                studio.world.request_view(studio.world.quarter+1)
                if not await settle():check(false,"%s rotates at %.0f ms"%[name,at]);break
            evaluate(studio.world,"%s %.0fms q%d"%[name,at,studio.world.quarter])
    # Real-time playback: every displayed frame, including fractional moves.
    studio._seek(0.0)
    if not await settle():return
    studio.loop_enabled=false;studio._play_study()
    var failed:=failures.size()
    for i in play_frames:
        await process_frame
        if studio.world.world_revision>=0:
            var label:="%s play frame %d q%d"%[name,i,studio.world.quarter]
            evaluate(studio.world,label+" as rendered",{"playing":true,"as_rendered":true},true)
            studio.world._sort_draws()
            evaluate(studio.world,label,{"playing":true})
        if studio.world.timeline.paused and studio.world.timeline.display_ms>0:break
    studio.world.timeline.paused=true
    check(failures.size()==failed,name+" real-time frames keep exact engine order")

func overlay_routes()->void:
    # Ground UI with marks and a route under the real Gallery world.
    var world=studio.world
    var tiles:Dictionary=world.timeline.presentation_state().tiles
    var keys:Array=tiles.keys();keys.sort()
    if keys.size()<6:return
    var actor:Dictionary=world.actor_rows[0] if not world.actor_rows.is_empty() else {}
    var start:Array=[roundi(actor.position[0]),roundi(actor.position[1])] if not actor.is_empty() else tiles[keys[0]].position
    var route:Array=[start]
    for step in 6:
        var last:Array=route.back();var next:=[last[0]+(1 if step%2==0 else 0),last[1]+(0 if step%2==0 else 1)]
        if tiles.has("%d,%d"%next):route.append(next)
    var marks:={}
    for point in route:marks["%d,%d"%point]={"colour":Color(.8,.4,.8,.8),"width":2.0,"fill_colour":Color(.8,.4,.8,.2)}
    world.grid_visible=true
    world.ground_overlay.set_preview(marks,route,Color(.8,.4,.8))
    for turn in 4:
        if turn>0:
            world.request_view(world.quarter+1)
            if not await settle():break
        for i in 2:await process_frame
        evaluate(world,"gallery route q%d"%world.quarter,{"route_points":route.size()})
    world.ground_overlay.set_preview({})
    for i in 2:await process_frame
    # A map with negative supports keys every floor by its cell instead of the
    # background band; the same world keyed that way exercises that order.
    world.ground_is_background=false;world.static_order_dirty=true;world.draw_order_dirty=true
    for turn in 4:
        if turn>0:
            world.request_view(world.quarter+1)
            if not await settle():break
        world.ground_is_background=false;world.static_order_dirty=true;world.draw_order_dirty=true
        for i in 2:await process_frame
        evaluate(world,"gallery background off q%d"%world.quarter,{"background":false})
    world.ground_is_background=true;world.static_order_dirty=true;world.draw_order_dirty=true
    for i in 2:await process_frame

func synthetic()->void:
    var scene:=Probe.new();root.add_child(scene)
    scene.timeline.state={"actors":{}}
    scene.wall_mode="solid";scene.ground_is_background=false
    var make=func(id:String,kind:String,role:String,layer:int,position:Array,height:float)->Dictionary:
        var node:=MeshInstance3D.new();node.mesh=QuadMesh.new();node.sorting_use_aabb_center=false;scene.add_child(node)
        var row:={"id":id,"kind":kind,"position":position,"base_height_steps":height,"layer":0,"boundaries":[]}
        node.position=Placement.contact(row)
        return {"id":id,"placement":row,"node":node,"material":null,"role":role,"layer":layer}
    for quarter in 4:
        scene.quarter=quarter;scene.camera.transform=Placement.camera_transform(Vector3.ZERO,quarter)
        var statics:Array=[];var actors:Array=[]
        # Exact ties: a static with the actor's whole key (same row values,
        # role and layer) and statics whose layer falls between actor layers.
        var actor_row:={"id":"hero","kind":"actor","position":[0.25,0.0],"base_height_steps":0.0,"layer":0,"boundaries":[]}
        for layer in [0,3,7]:
            var value:Dictionary=make.call("hero:%d:body"%layer,"actor","body",layer,[0.25,0.0],0)
            value.placement=actor_row;actors.append(value)
        var shadow:Dictionary=make.call("hero:shadow","actor","shadow",-1,[0.25,0.0],0);shadow.placement=actor_row;actors.append(shadow)
        for tie in [["hero:3:a",3],["hero:3:c",3],["prop-between",5]]:statics.append(make.call(tie[0],"resource","body",tie[1],[0.25,0.0],0))
        for x in range(-3,4):
            # Negative-elevation supports: a pit the actor walks down into.
            for z in range(-2,3):statics.append(make.call("floor:%d,%d"%[x,z],"terrain","terrain",2,[x,z],-1.0 if posmod(x+z,3)==0 else 0.0))
            statics.append(make.call("wall:%d"%x,"wall","body",2,[x,1],0))
        # Many moving draws in one gap: droplet-like participants of one cell.
        for i in 40:actors.append(make.call("crowd:%02d"%i,"effect","native_effect",i,[2,-1],0))
        scene.static_entries=statics;scene.actor_entries=actors
        scene.static_order_dirty=true;scene.draw_order_dirty=true
        scene._sort_draws()
        evaluate(scene,"synthetic ties q%d"%quarter)
        for step in 90:
            var x:=-2.0+step/30.0
            actor_row.position=[x,0.1*sin(step*.2)];actor_row.base_height_steps=0.5*sin(step*.05)
            for value in actors.slice(0,4):value.node.position=Placement.contact(actor_row)+Vector3(0,0.4*absf(sin(step*.3)) if value.role!="shadow" else 0.0,0)
            actors[1].node.visible=step%7!=0
            scene._sort_draws()
            evaluate(scene,"synthetic walk q%d step %d"%[quarter,step])
        for value in statics+actors:value.node.free()
        scene.static_entries=[];scene.actor_entries=[];scene.static_order_dirty=true;scene.draw_order_dirty=true
    # Ground stains of equal keys on the background band, as blood residue
    # leaves them: hidden ones still carry a float height (0.0), shown ones an
    # int (0). Numerically equal keys of different types have no order in the
    # comparator, so hidden draws must not take part in ranking. Shown later,
    # they get the int height and rank by ID.
    scene.ground_is_background=true
    for quarter in 4:
        scene.quarter=quarter;scene.camera.transform=Placement.camera_transform(Vector3.ZERO,quarter)
        var statics:Array=[];var stains:Array=[]
        for x in range(-3,4):
            for z in range(-3,4):statics.append(make.call("floor:%d,%d"%[x,z],"terrain","terrain",2,[x,z],0))
        # Listed in falling ID order with a hidden float stain between shown
        # ones: neighbours compare equal, the shown pair does not.
        for k in range(3,-4,-1):
            var stain:Dictionary=make.call("stain:%d"%(k+3),"effect","covering",1,[k,-k],0)
            stain.placement.layer=1
            if posmod(k,2)==1:stain.placement.base_height_steps=0.0;stain.node.visible=false
            else:stain.placement.base_height_steps=0
            stains.append(stain)
        scene.static_entries=statics;scene.actor_entries=stains
        scene.static_order_dirty=true;scene.draw_order_dirty=true
        scene._sort_draws()
        evaluate(scene,"synthetic stains q%d"%quarter)
        for stain in stains:
            if not stain.node.visible:stain.placement.base_height_steps=0;stain.node.visible=true
        scene._sort_draws()
        evaluate(scene,"synthetic stains shown q%d"%quarter)
        for value in statics+stains:value.node.free()
        scene.static_entries=[];scene.actor_entries=[];scene.static_order_dirty=true;scene.draw_order_dirty=true
    scene.queue_free();await process_frame

func run()->void:
    root.size=Vector2i(1280,720)
    var selected:String=argument("--cases","default")
    var names:Array=CASES
    if selected=="all":
        names=[]
        for name in Fixtures.catalog():
            if not Fixtures.journal(name).is_empty():names.append(name)
    elif selected=="none":names=[]
    elif selected!="default":names=selected.split(",")
    var play_frames:=int(argument("--play-frames","600"))
    await synthetic()
    studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await settle()
    var gallery:=argument("--gallery",GALLERY)
    if gallery!="none":
        await journal(gallery,play_frames)
        await overlay_routes()
    for name in names:await journal(Fixtures.journal(name),play_frames)
    var worst:={"min_depth_gap":INF,"min_reference_gap":INF,"max_abs_offset":0.0,"min_rank_step":INF,"widest_reference_gap":0}
    for value in configurations:
        if value.get("as_rendered",false):continue
        for key in ["min_depth_gap","min_reference_gap","min_rank_step"]:worst[key]=minf(worst[key],value[key])
        worst.max_abs_offset=maxf(worst.max_abs_offset,value.max_abs_offset)
        worst.widest_reference_gap=maxi(worst.widest_reference_gap,value.widest_reference_gap)
    var report:={"checks":checks,"failures":failures,"configurations":configurations.size(),"journals":names.size()+(1 if gallery!="none" else 0),"coverage":coverage,"worst":worst,
        "scope":"Float32 engine sort key (priority, near-plane distance - sorting_offset) along the grid key+id order for every drawn static, ground UI and moving participant; written offsets and the previous ordering path; four quarters; real-time frames; synthetic exact ties, statics between actor layers, a pit and 40 draws in one gap"}
    FileAccess.open("res://generated/order_oracle_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"report":report,"configurations":configurations},"  "))
    print("ORDER_ORACLE ",JSON.stringify(report))
    studio.queue_free();await process_frame
    quit(0 if failures.is_empty() else 1)
