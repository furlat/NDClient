extends RefCounted
## Inspection of the existing native optical sources. No illumination solver,
## hidden-owner inference, new light nodes or gameplay state changes.
const Lighting=preload("res://presentation/lighting_2d.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Settings=preload("res://presentation/render_settings.gd")
const Catalog=preload("res://source_catalog.gd")

static func configuration()->Dictionary:
    var settings=Settings.read()
    var native=Lighting.new()
    var profile=native.range_profile
    return {"light_strength":settings.light_strength,"fire_light_flicker":settings.fire_light_flicker,
        "normal_height_source_pixels":Lighting.NORMAL_HEIGHT_SOURCE_PIXELS,
        "carried_optical_lift_steps":Lighting.ExistingLighting.CARRIED_OPTICAL_LIFT_STEPS,
        "range_profile":{"source":profile.resource_path,"very_bright_edge":profile.very_bright_edge,"bright_edge":profile.bright_edge,"interpolation":"Gradient.GRADIENT_INTERPOLATE_CUBIC"} if profile!=null else {},
        "temporal_interpolation":"step","position_interpolation":"compiled_actor_motion"}

static func observe(history:Dictionary,state:Dictionary,at_ms:float,event_uuid:String,sequence:int,cache:Dictionary)->void:
    var resolved=Lighting.resolve(state)
    var senses:Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    var present={}
    for source in resolved.sources:
        var id:String=source.item_uuid
        present[id]=true
        # Keep only the optical fields consumed by the native light path. Tile
        # footprints remain authoritative reducer data, not duplicated per key.
        var observation:Dictionary=state.get("light_sources",{}).get(id,{})
        var observed={}
        for field in ["position","base_height_steps","very_bright_radius_feet","bright_radius_feet","dim_radius_feet","appearance","actor_anchored","anchor_entity_uuid","anchor_item_uuid"]:
            if observation.has(field):observed[field]=observation[field]
        var actor_name:String=state.actors.get(source.actor_uuid,{}).get("name","") if not source.actor_uuid.is_empty() else ""
        var anchor:String=source.get("anchor_item_uuid",id)
        var object:Dictionary=state.objects.get(anchor,{})
        var fixture=""
        if object.get("item",{}).get("is_lit")==true and senses.get("objects",{}).get(anchor,{}).get("visual",false):
            fixture=Catalog.environment_world(cache).get("props",{}).get(object.item.item_id,{}).get("lit_animation","")
        var pointer="PlayerState.light_sources/"+id
        var fields={}
        for field in ["position","base_height_steps","very_bright_radius_feet","bright_radius_feet","dim_radius_feet"]:fields[field]=pointer+"/"+field
        fields.enabled=pointer+" (source-set membership)"
        var value={"enabled":true,"source":source,"observed":observed,"actor_name":actor_name,"fixture_animation":fixture,"source_pointer":pointer,"source_fields":fields}
        if not history.has(id):history[id]={"id":id,"keys":[],"last":{},"source":pointer}
        var held:Dictionary=history[id]
        if held.last==value:continue
        held.last=value
        var key=value.duplicate();key.merge({"at_ms":at_ms,"source_event_uuid":event_uuid,"operation_sequence":sequence})
        held.keys.append(key)
    for id in history:
        var held:Dictionary=history[id]
        if present.has(id) or not held.last.get("enabled",false):continue
        held.last={"enabled":false}
        held.keys.append({"at_ms":at_ms,"enabled":false,"source_event_uuid":event_uuid,"operation_sequence":sequence,
            "source_pointer":"PlayerState.light_sources",
            "reason":"Emitter no longer in the disclosed native source set; this does not infer a private item switch."})

static func rows(history:Dictionary,index:Dictionary,motion:Dictionary)->Array:
    var output:Array=[]
    var events={}
    for row in index.rows:
        if row.kind=="event":events[row.event.event_uuid]=row.id
    var settings=configuration()
    var rig:Dictionary=Catalog.read_file("catalog/rig.json",index.cache)
    for held in history.values():
        var first:Dictionary=held.keys[0]
        var source:Dictionary=first.source
        var parent:String=events.get(first.source_event_uuid,"")
        var tracks:Array=[]
        var actors={}
        for key in held.keys:
            if key.enabled and not key.source.actor_uuid.is_empty():actors[key.source.actor_uuid]=true
        for actor_id in actors:tracks.append_array(motion.get(actor_id,[]))
        var fields:Dictionary=first.source_fields.duplicate()
        fields.energy="res://presentation/lighting.gd::OPTICAL_ENERGY × user://rendering_settings.cfg::rendering/light_strength"
        fields.color="res://authoring/environment/lighting/torch.tres::colour or Color.WHITE, selected by disclosed appearance"
        fields.normal_height="res://presentation/lighting_2d.gd::NORMAL_HEIGHT_SOURCE_PIXELS"
        fields.falloff="res://authoring/environment/lighting/lighting.tres::very_bright_edge/bright_edge"
        fields.position_sample="res://presentation/tracks.gd::samples → res://presentation/lighting.gd::sample"
        fields.fixture_height="res://presentation/sprite_sources.gd::_add_fixture_flame → res://play.gd::_sample_fixtures"
        output.append({"id":"light:"+held.id,"parent":parent,"kind":"light","label":"Torch light" if source.item_id in Lighting.TORCH_ITEM_IDS else "Optical light",
            "start_ms":first.at_ms,"end_ms":index.presentation_end_ms,"status":"available","source":held.source,"source_fields":fields,
            "optical_source_id":held.id,"actor_uuid":source.actor_uuid,"actor_name":first.actor_name,
            "anchor_item_uuid":source.get("anchor_item_uuid",source.item_uuid),"light_keys":held.keys,"motion_tracks":tracks,
            "light_settings":settings,"rig_tile_width":rig.TILE_W,"render_method":{"node":"PointLight2D","surface":"native receiving light atlas","renderer":"res://presentation/lighting_2d.gd::sync/sample/project"},
            "coverage":{"implementation":"implemented","source":"available","prepared":"not_examined","rendered":"not_witnessed"},
            "timing_source":"Actual ordered compiled state commits; no invented transition curve"})
    return output

static func sample(row:Dictionary,at_ms:float,settings_override:Dictionary={},fixture_curves:Dictionary={})->Dictionary:
    var key:Dictionary={}
    for point in row.light_keys:
        if point.at_ms>at_ms:break
        key=point
    if key.is_empty() or not key.enabled:return {"enabled":false,"energy":0.0,"at_ms":at_ms}
    var settings:Dictionary=row.light_settings.duplicate();settings.merge(settings_override,true)
    var source:Dictionary=key.source
    var actors={}
    if not source.actor_uuid.is_empty():
        var samples=Tracks.samples(row.motion_tracks.filter(func(track):return at_ms<track.group_end_ms),at_ms)
        var moving:Dictionary=samples.get(source.actor_uuid,{})
        if moving.has("position"):
            actors[source.actor_uuid]={"position":moving.position,"base_height_steps":moving.base_height_steps,
                "visual_height":float(moving.get("lift_pixels",0))*(128.0/float(row.rig_tile_width))/64.0}
    var energy={};var heights={};var height_ready=true
    var fixture:String=key.get("fixture_animation","")
    if not fixture.is_empty():
        var curve:Dictionary=fixture_curves.get(fixture,{})
        height_ready=not curve.is_empty()
        if height_ready:
            if settings.fire_light_flicker:
                var frame=fposmod(at_ms/1000.0*float(curve.authored.fps),float(curve.heights.size()))
                var current=floori(frame);var next=(current+1)%curve.heights.size();var blend=smoothstep(0.0,1.0,frame-current)
                heights[source.item_uuid]=lerpf(curve.heights[current],curve.heights[next],blend)
                energy[source.item_uuid]=lerpf(curve.energy[current],curve.energy[next],blend)
            else:heights[source.item_uuid]=curve.mean_height
    var resolver=Lighting.ExistingLighting.new()
    resolver.sources=[source];resolver.carried_optical_lift_steps=settings.carried_optical_lift_steps
    resolver.sample(actors,energy,heights)
    var sampled:Dictionary=resolver.sampled[source.item_uuid]
    var color:Color=Lighting.TORCH_COLOUR if source.item_id in Lighting.TORCH_ITEM_IDS else Color.WHITE
    return {"enabled":float(settings.light_strength)>0,"at_ms":at_ms,"source_key_ms":key.at_ms,
        "position":sampled.position if height_ready else null,"position_xy":Vector2(sampled.position.x,sampled.position.z),
        "height_status":"resolved" if height_ready else "fixture_media_not_prepared",
        "energy":sampled.energy*float(settings.light_strength) if height_ready or not settings.fire_light_flicker else null,
        "color":color,"very_bright_radius_feet":source.very_bright_radius_feet,"bright_radius_feet":source.bright_radius_feet,"dim_radius_feet":source.dim_radius_feet,
        "outer_radius_cells":source.outer,"bright_radius_cells":source.bright,"very_bright_radius_cells":source.very,
        "normal_height_source_pixels":settings.normal_height_source_pixels,"range_profile":settings.range_profile,
        "actor_uuid":source.actor_uuid,"actor_name":key.actor_name,"temporal_interpolation":"step","position_interpolation":"compiled_actor_motion"}
