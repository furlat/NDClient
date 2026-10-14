extends Control
## Supplied server light observations, projected over the displayed Studio view.
## This diagnostic never computes light, darkvision, visibility or gameplay state.
const Placement=preload("res://placement.gd")
const NAMES=["Magical darkness","Darkness","Dim","Bright","Very bright"]
const COLOURS=[Color("b486ef"),Color("7297cf"),Color("53c9ba"),Color("f2bf5a"),Color("fff3aa")]
var host:Node
var level_source:Callable
var legend_label=""
var markers:Array=[]
var revision_key:Array=[]
var rebuilds=0
var ranges:Array=[]
var range_key:Array=[]

func _ready()->void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    # Play advances/samples at priority0; read its admitted displayed boundary.
    process_priority=20
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta:float)->void:
    if not is_visible_in_tree() or host==null or host.world==null:return
    var world:Node=host.world
    refresh(world.timeline.state,[world.get_instance_id(),world.timeline.initialization_revision,world.timeline.world_revision],world.camera,size)
    refresh_ranges(world.source_lighting.sources,world.source_lighting.sampled,world.camera,size)

func refresh(state:Dictionary,state_key:Array,camera:Camera3D,target_size:Vector2)->void:
    var key=state_key+[camera.get_instance_id(),camera.global_transform,camera.get_camera_projection(),target_size,level_source,legend_label]
    if key==revision_key:return
    revision_key=key;rebuilds+=1;markers.clear()
    queue_redraw()
    if not level_source.is_valid():return
    var source_size=Vector2(camera.get_viewport().get_visible_rect().size)
    if source_size.x<=0 or source_size.y<=0:return
    var screen_scale=target_size/source_size
    var screen_rect=Rect2(Vector2.ZERO,target_size)
    var senses:Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    for position in senses.get("visible",[]):
        var cell="%d,%d"%[position[0],position[1]]
        var tile:Dictionary=state.get("tiles",{}).get(cell,{})
        if tile.is_empty():continue
        var observed:Variant=level_source.call(tile,cell,state)
        if observed==null:continue
        var level=int(observed)
        if level<0 or level>=NAMES.size():continue
        var origin=Vector3(tile.position[0],float(tile.elevation_steps)*Placement.HEIGHT_UNIT,tile.position[1])
        if camera.is_position_behind(origin):continue
        var polygon=PackedVector2Array()
        for offset in [Vector3(-.5,0,-.5),Vector3(.5,0,-.5),Vector3(.5,0,.5),Vector3(-.5,0,.5)]:
            polygon.append(camera.unproject_position(origin+offset)*screen_scale)
        var bounds=Rect2(polygon[0],Vector2.ZERO)
        for point in polygon:bounds=bounds.expand(point)
        if not bounds.intersects(screen_rect):continue
        var spacing=maxi(1,ceili(24.0/maxf(1,minf(bounds.size.x,bounds.size.y))))
        markers.append({"tile_uuid":tile.tile_uuid,"position":tile.position,"elevation_steps":tile.elevation_steps,
            "level":level,"name":NAMES[level],"polygon":polygon,"center":camera.unproject_position(origin)*screen_scale,
            "label_visible":posmod(int(position[0]),spacing)==0 and posmod(int(position[1]),spacing)==0})
    queue_redraw()

func refresh_ranges(sources:Array,sampled:Dictionary,camera:Camera3D,target_size:Vector2)->void:
    var inputs=[]
    for source in sources:
        var point:Vector3=sampled.get(source.item_uuid,{}).get("position",source.position)
        # Horizontal ranges use the disclosed support band, not optical flame lift.
        point.y=float(sampled.get(source.item_uuid,{}).get("support_height_steps",source.base_height_steps))*Placement.HEIGHT_UNIT
        inputs.append([source.item_uuid,point,source.very,source.bright,source.outer])
    var key=[inputs,camera.global_transform,camera.get_camera_projection(),target_size]
    if key==range_key:return
    range_key=key;ranges.clear();queue_redraw()
    var screen_scale=target_size/Vector2(camera.get_viewport().get_visible_rect().size)
    for item in inputs:
        for tier in 3:
            var radius=float(item[tier+2])
            if radius<=0:continue
            var points=PackedVector2Array()
            for step in 65:
                var angle=float(step)/64.0*TAU
                points.append(camera.unproject_position(item[1]+Vector3(cos(angle),0,sin(angle))*radius)*screen_scale)
            ranges.append({"source_id":item[0],"origin":item[1],"radius_cells":radius,"tier":tier,"points":points})

func inspection()->Dictionary:
    return {"enabled":visible,"markers":markers.duplicate(true) if visible else [],"rebuilds":rebuilds,
        "source":legend_label,"ranges":ranges.duplicate(true) if visible else []}

func _draw()->void:
    var font=ThemeDB.fallback_font
    for marker in markers:
        var colour:Color=COLOURS[marker.level]
        var fill=colour;fill.a=.13
        draw_colored_polygon(marker.polygon,fill)
        var outline:PackedVector2Array=marker.polygon.duplicate();outline.append(outline[0])
        colour.a=.7;draw_polyline(outline,colour,1.0,true)
        if marker.label_visible:
            var text=str(marker.level)
            var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
            var at:Vector2=marker.center+Vector2(-width*.5,4)
            draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color("111820"))
            draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,COLOURS[marker.level])
    for ring in ranges:
        var colour:Color=COLOURS[4-ring.tier];colour.a=.65
        draw_polyline(ring.points,colour,1.5,true)
    var legend=legend_label+" · "
    for level in NAMES.size():legend+="%d %s%s"%[level,NAMES[level],"   " if level<4 else ""]
    var range_legend="Source ranges · very bright / bright / dim outer · unoccluded"
    var width=maxf(font.get_string_size(legend,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x,font.get_string_size(range_legend,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)
    draw_rect(Rect2(8,8,minf(width+16,size.x-16),44),Color(.04,.06,.09,.9))
    draw_string(font,Vector2(16,25),legend,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-32),12,Color("edf1f7"))
    draw_string(font,Vector2(16,42),range_legend,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-32),12,Color("c8d2df"))

