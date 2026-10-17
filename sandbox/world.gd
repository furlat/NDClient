extends "res://play.gd"
## Presentation-only fixture using production actor, normal, light and sort paths.
## No Session, SDK messages, game rules, damage or server connection.
const NativeSpellPlayback=preload("res://presentation/native_spell_playback.gd")
const FactorySource = preload("res://sandbox/factory_source.gd")
const Choreography = preload("res://sandbox/choreography.gd")
const Feedback = preload("res://sandbox/actor_feedback.gd")
const EffectLayer = preload("res://sandbox/effect_layer.gd")
const NativeSupport = preload("res://presentation/native_scene_support.gd")
const SourceLights = preload("res://sandbox/source_lights.gd")
const SurfaceSockets = preload("res://sandbox/surface_sockets.gd")
const BodyMaterial = preload("res://sandbox/body_material.gd")
const Casting = preload("res://sandbox/casting.gd")
const BodySurface = preload("res://sandbox/body_surface.gd")
const BodySurfaces = preload("res://presentation/body_surfaces.gd")

@export var spells: Array[Resource] = []
@export_range(0.25, 2.0, 0.25) var rate := 1.0
@export var loop := true
@export var authored_sockets := true
@export var spell_hit_flash := true
@export_enum("Colour treatment","Full spell material") var hit_appearance:=1
@export var floor_size := Vector2i(21, 13)
var spell: Resource
var recipe: Dictionary = {}
var socket_recipe: Dictionary = {}
var handles: Dictionary = {}
var elapsed := 0.0
var duration := 0.0
var release := 0.0
var arrival := 0.0
var cast_duration := 0.0
var playing := true
var fixture_ready := false
var phase_mode := "Sequence"
var phase_label: Label
var progress: ProgressBar
var controls: Control
var loop_count := 0
var startup_ms := 0
var source_start := Vector3.ZERO
var source_end := Vector3.ZERO
var projectile_placement: Dictionary = {}
var size_control: SpinBox
var selected_spell := 0
var placement_snapshot: Array = []
var library: Dictionary = {}
var source_clips: Array = []
var spell_choices: OptionButton
var hit_flash_button: CheckButton
var hit_appearance_choice:OptionButton
var body_material=BodyMaterial.new()
var phase_choices: OptionButton
var cast_choices:OptionButton
var cast_variants:Array=[]
var pieces: VBoxContainer
var pieces_panel: PanelContainer
var source_overrides: Dictionary = {}
var active_clips: Dictionary = {}
var placement_mode := false
var preparation_begin := 0.0
var effect_layer: Dictionary = {}
var spell_colours := true
var staging: Dictionary = {}
var staging_spec: Dictionary = {}
var cue_plan: Dictionary = {"cues":[],"contacts":[],"end":0.0}
var feedback: Dictionary = {}
var flight_speed := 8.0
var flight_control: SpinBox
var split_targets := false
var actor_markers := {"caster":"Caster","target":"Target","target2":"Target2"}
var native_support=NativeSupport.new()
var socket_samples:Dictionary={}
var body_surface_bindings:Array=[]
var body_surface_actors:Dictionary={}

func _ready() -> void:
    var started = Time.get_ticks_msec()
    if "--visual-review" in OS.get_cmdline_user_args() or "--batch-check" in OS.get_cmdline_user_args() or "--feedback-check" in OS.get_cmdline_user_args() or "--ice-web-check" in OS.get_cmdline_user_args() or "--support-feedback-check" in OS.get_cmdline_user_args() or "--utility-feedback-check" in OS.get_cmdline_user_args() or "--casting-check" in OS.get_cmdline_user_args() or "--body-surface-check" in OS.get_cmdline_user_args():
        get_window().unfocusable=true
        get_window().position=Vector2i(-16000,-16000)
    if "--sandbox-check" in OS.get_cmdline_user_args() or "--projectile-check" in OS.get_cmdline_user_args() or "--sandbox-regression-check" in OS.get_cmdline_user_args() or "--choreography-check" in OS.get_cmdline_user_args() or "--scene-integration-check" in OS.get_cmdline_user_args() or "--particle-clock-check" in OS.get_cmdline_user_args():
        get_window().unfocusable=true
        get_window().position=Vector2i(-16000,-16000)
        set_process_unhandled_input(false)
    external_playback = true
    external_clock = true
    source_lighting=SourceLights.new()
    super._ready()
    DisplayServer.window_set_title("NDClient · Native spell sandbox · Offline")
    camera_focus = Vector3(0,0.5,0)
    camera.size = 7
    position_camera()
    wall_mode = "solid"
    _fixture()
    effect_layer=EffectLayer.make(self)
    native_support.attach(self,effect_layer.viewport,effect_layer.camera)
    EffectLayer.integrate(effect_layer,native_support)
    library = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    staging=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/staging.json"))
    spells.clear()
    # Resources retain editable placement/timing defaults; the resolved source
    # manifest retains original Factory components, variants and provenance.
    for specification in library.spells:
        spells.append(load("res://authoring/sandbox/"+specification.id+".tres"))
    _build_controls()
    if spells.is_empty():
        phase_label.text = "Assign a spell Resource in the scene Inspector."
        return
    select_spell(library.spells.find_custom(func(value):return value.id=="fire_bolt"))
    fixture_ready = presentation_errors.is_empty()
    if not fixture_ready: phase_label.text = "Cannot prepare sandbox: "+str(presentation_errors)
    startup_ms = Time.get_ticks_msec()-started
    print("SPELL_SANDBOX_READY ",JSON.stringify({"startup_ms":startup_ms,"textures":textures.size(),"errors":presentation_errors}))
    if "--feedback-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_feedback_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--support-feedback-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_support_feedback_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--utility-feedback-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_utility_feedback_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--casting-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_casting_native_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--body-surface-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_body_surface_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--ice-web-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_ice_web_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--batch-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_batch_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--visual-review" in OS.get_cmdline_user_args():
        var review=load("res://tools/capture_spell_review.gd").new()
        add_child(review);review.run.call_deferred(self)
    if "--scene-integration-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_scene_integration_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--particle-clock-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_particle_clock_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--choreography-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_choreography_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--sandbox-regression-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/sandbox_regression_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--projectile-check" in OS.get_cmdline_user_args():
        var check=load("res://tests/projectile_sandbox_checks.gd").new()
        add_child(check);check.run.call_deferred(self)
    if "--sandbox-check" in OS.get_cmdline_user_args():
        var check = load("res://tests/spell_sandbox_checks.gd").new()
        add_child(check)
        check.run.call_deferred(self)

func texture(path: String) -> Texture2D:
    # Small fixture startup/explicit reload only. The live host forbids disk I/O
    # here; this offline fixture prepares its finite demand before playing.
    if not textures.has(path):
        var source = Image.load_from_file(Catalog.media_path(path))
        if source==null:
            presentation_errors.append("Missing sandbox asset: "+path)
            return null
        source_images[path] = source
        textures[path] = ImageTexture.create_from_image(source)
    return textures[path]

func _actor(id: String, head: String, armor: String) -> Dictionary:
    return {"uuid":id,"creature_content_ref":null,"life_state":"alive","conditions":[],
        "last_visual_position":[0,0],"appearance":{"presentation_kind":"layered",
        "visual_scale":1.0,"visual_scale_x":1.0,"body_category":"NakedBody",
        "skin_tint":0xE6BB98,"head_category":head,"hair_tint":0x663322,"has_beard":false},
        "visual_loadout":{"active_weapon_set":"melee","layers":[{"slot":"Body",
        "item_uuid":id+"-outfit","visual_item_name":armor,"visual_variant_id":null,
        "equipped_visual_policy":"visible"}]}}

func _fixture() -> void:
    timeline.state = {"actors":{"caster":_actor("caster","Head10","Robes"),"target":_actor("target","Head1","Chain Mail"),"target2":_actor("target2","Head1","Chain Mail")},
        "tiles":{},"objects":{},"audience":{"controlled":["caster","target","target2"]},
        "senses":{"entities":{},"visible":[],"light_sources":{}}}
    # A local studio lamp: uses the existing optical-light receiver, not donor 3D lights.
    timeline.state.senses.light_sources["sandbox-lamp"] = {"anchor_entity_uuid":null,
        "anchor_item_uuid":null,"actor_anchored":false,"appearance":"torch","position":[0,-1],
        "base_height_steps":1,"very_bright_radius_feet":0,"bright_radius_feet":25,"dim_radius_feet":10}
    _place_actors()
    media_metadata_ready = true
    _sync_actors()
    for x in range(-floor_size.x/2, floor_size.x/2+1):
        for z in range(-floor_size.y/2, floor_size.y/2+1):
            var row = {"id":"floor-%d-%d"%[x,z],"kind":"terrain","material":"stone",
                "position":[x,z],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]}
            add_entry(row,"terrain",0,ENVIRONMENT_SHADER,1)
            var entry: Dictionary = entries.back()
            initialize_entry(entry)
            source_lighting.apply(entry.material)
            static_entries.append(entry)
    # Prepare the other three authored floor views once, before controls are live.
    for view in [1,2,3,0]:
        quarter = view
        position_camera()
        for entry in static_entries: initialize_entry(entry)
    source_lighting.sync(timeline.state)
    source_lighting.sample({})

func _place_actors() -> void:
    timeline.state.tiles.clear()
    for id in actor_markers:
        var marker: Node3D = get_node(actor_markers[id])
        var position = [marker.position.x,marker.position.z]
        timeline.state.actors[id].last_visual_position = position
        timeline.state.tiles["%d,%d"%position] = {"elevation_steps":marker.position.y/Placement.HEIGHT_UNIT}
    if not feedback.is_empty():
        feedback.track.from_position=timeline.state.actors.caster.last_visual_position
        feedback.track.target_position=timeline.state.actors.target.last_visual_position
        for action in feedback.get("actions",[]):
            action.track.from_position=timeline.state.actors[action.spec.actor].last_visual_position
            action.track.target_position=timeline.state.actors[action.spec.target].last_visual_position
    timeline.revision += 1
    placement_snapshot = _marker_positions()

func _marker_positions() -> Array:
    return [$Caster.position,$Target.position,$Target2.position,$Caster/Release.position,$Target/Impact.position,authored_sockets]

func select_spell(index: int,profile_id:String="") -> void:
    var retain_placement=not profile_id.is_empty() and index==selected_spell
    selected_spell = index
    spell_choices.select(index)
    spell = spells[index]
    if not profile_id.is_empty():spell.casting_profile=profile_id
    cast_choices.select(cast_variants.find_custom(func(profile):return profile.id==spell.casting_profile))
    size_control.set_value_no_signal(spell.effect_scale)
    staging_spec=library.spells[index].get("staging",staging.spells.get(spell.spell_id,{}))
    for id in actor_markers:
        var actor:Dictionary=timeline.state.actors[id]
        actor.visual_loadout.layers=actor.visual_loadout.layers.filter(func(layer):return layer.slot=="Body")
        for item in staging_spec.get("actor_items",{}).get(id,[]):
            actor.visual_loadout.layers.append({"slot":item.slot,"item_uuid":id+"-"+item.slot,"visual_item_name":item.visual_item_name,"visual_variant_id":null,"equipped_visual_policy":"visible"})
    var target_position:Array=staging_spec.get("target_position",[2,0,0])
    if not retain_placement:$Target.position=Vector3(target_position[0],target_position[1],target_position[2])
    _place_actors()
    if not retain_placement:flight_speed=float(staging_spec.get("flight_speed",staging.base_speed_tiles_per_second))
    flight_control.set_value_no_signal(flight_speed)
    var focus:Array=staging_spec.get("camera_focus",[0,.5,0])
    if not retain_placement:
        camera_focus=Vector3(focus[0],focus[1],focus[2])
        camera.size=float(staging_spec.get("camera_size",7.0))
    position_camera()
    recipe = JSON.parse_string(FileAccess.get_file_as_string(spell.choreography))
    recipe=Casting.apply(recipe,rigs["neuroclient.modular"],spell.casting_profile)
    socket_recipe=recipe.get("projectile",recipe.cast)
    source_clips = library.spells[index].clips
    EffectLayer.colours(effect_layer,library.spells[index].get("palette",{}),spell_colours)
    phase_mode = "Sequence"
    phase_choices.clear(); phase_choices.add_item("Sequence")
    for clip in source_clips: phase_choices.add_item(clip.label)
    phase_choices.select(0)
    var rig: Dictionary = rigs["neuroclient.modular"]
    var clip: Dictionary = rig.clips[recipe.cast.actionClip]
    cast_duration = float(clip.frames)/float(clip.fps)/float(recipe.cast.bodyPlaybackSpeed)
    release = spell.lead_in_seconds+float(recipe.cast.releaseFrame)/float(clip.fps)/float(recipe.cast.bodyPlaybackSpeed)
    preparation_begin = spell.lead_in_seconds+float(recipe.cast.get("prepareFrame",socket_recipe.get("prepare",{}).get("startFrame",0)))/float(clip.fps)/float(recipe.cast.bodyPlaybackSpeed)
    feedback=Feedback.prepare(self)
    displayed_components=Feedback.samples(self,spell.lead_in_seconds+.001)
    var body_clips:Array=["Idle",recipe.cast.actionClip,"TakeDamage"]
    for action in feedback.actions:
        body_clips.append(action.track.clip)
        displayed_components.append_array(Feedback.samples(self,action.track.start_ms/1000.0+.001))
    _sync_actors()
    # Prepare exact cast/effect/reaction demands once, not during playback.
    for visual in visual_actors.values():
        for entry in visual.entries:
            for action in body_clips:
                if not entry.actor_layer.paths.has(action):continue
                var path:String=entry.actor_layer.paths[action]
                texture(path)
                for companion in CharacterGeometry.paths(path,entry.actor_layer.slot,catalog_cache):texture(companion)
                native_support.prepare(path,entry.actor_layer.slot,self)
    for issue in native_support.issues:
        if issue not in presentation_errors:presentation_errors.append(issue)
    for layer in feedback.layers:
        var noise:String=resources.get(layer.get("palette",{}).get("noiseSheet"),"")
        if not noise.is_empty():texture(noise)
    for action in feedback.actions:
        for layer in action.layers:
            var noise:String=resources.get(layer.get("palette",{}).get("noiseSheet"),"")
            if not noise.is_empty():texture(noise)
    var flash_noise:String=resources.get(feedback.flash.get("palette",{}).get("noiseSheet"),"")
    if not flash_noise.is_empty():texture(flash_noise)
    media_initial_ready=true
    restart()

func restart() -> void:
    body_surface_bindings.clear()
    for handle in handles.values(): FactorySource.close(handle)
    handles.clear(); active_clips.clear()
    # Reset the displayed pose before resolving source surfaces for the next
    # cast. A recast during TakeDamage must not inherit that old contact pose.
    cue_plan={"cues":[],"contacts":[],"end":0.0}
    elapsed=0.0;socket_samples.clear()
    _sample_frame(0.0)
    _endpoints()
    var targets:Array=[]
    var endpoints:Dictionary={}
    for id in actor_markers:
        endpoints[id]={"id":id,"body":_target_point(id),"ground":get_node(actor_markers[id]).global_position}
    var recipients:Array=["caster"] if staging_spec.get("recipient","target")=="caster" else ["target","target2"]
    for id in recipients:
        var marker:Node3D=get_node(actor_markers[id])
        var body=source_end if id=="target" else _target_point(id)
        targets.append({"id":id,"body":body,"ground":marker.global_position})
    if phase_mode=="Sequence":
        cue_plan=Choreography.compile(staging_spec,source_clips,release,spell.lead_in_seconds,
            spell.lead_in_seconds+cast_duration,source_start,targets,flight_speed,split_targets,preparation_begin,endpoints)
        for cue in cue_plan.cues:active_clips[cue.id]=cue.clip
    else:
        cue_plan={"cues":[],"contacts":[],"end":0.0}
        for clip in source_clips:
            if clip.id==phase_mode:active_clips["isolated"]=clip
    for key in active_clips:
        var handle=FactorySource.make($Effects,active_clips[key])
        if not handle.error.is_empty(): presentation_errors.append(handle.error)
        handles[key]=handle
        handle.root.name=key.capitalize()
        for piece in handle.geometry:
            var override_key=spell.spell_id+"/"+active_clips[key].id+"/"+piece.path
            if source_overrides.has(override_key):
                piece.selected=source_overrides[override_key]
                piece.node.visible=piece.selected
                if piece.selected: piece.node.layers=EffectLayer.LAYER
    body_material.configure(self)
    hit_appearance_choice.set_item_disabled(1,body_material.material==null)
    if body_material.material==null and hit_appearance==1:
        hit_appearance=0;hit_appearance_choice.select(0)
    hit_appearance_choice.tooltip_text="Receiver body: colour treatment or native spell surface." if body_material.material!=null else body_material.definition.get("reason","No damaging body material for this spell.")
    # Source constructors expose complete AnimationPlayer durations. Extend
    # cast/impact tails to them instead of cutting to export capture windows.
    for cue in cue_plan.cues:
        var actual:float=0.0 if cue.get("duration_policy","")=="authored" else handles[cue.id].native_animation_end
        if cue.role=="cast":cue.end=maxf(cue.end,cue.begin+actual/float(cue.get("source_rate",1)))
        elif cue.role=="attached":cue.end=maxf(cue.end,cue.begin+actual/float(cue.get("source_rate",1)))
        elif cue.role in ["impact","area"]:cue.end=maxf(cue.end,cue.begin+actual)
        elif cue.role in ["flight","strike"]:cue.end=maxf(cue.end,cue.contact+actual-cue.source_contact)
        var longest_particle=0.0
        for emitter in handles[cue.id].emitters:
            if emitter.layers==0 or not emitter.visible:continue
            var tail:float=emitter.lifetime/maxf(.001,float(handles[cue.id].emitter_speeds[emitter.get_instance_id()]))
            if emitter.get_script()!=null and emitter.get_script().resource_path.ends_with("GPUTrail3D.gd"):tail=float(emitter.length_seconds)
            longest_particle=maxf(longest_particle,tail)
        if cue.role=="flight" and cue.get("stop_emission_at_contact",false):
            cue.end=maxf(cue.end,cue.contact+longest_particle)
        if cue.has("emission_seconds"):
            cue.emission_stop=cue.begin+float(cue.emission_seconds)
            cue.end=maxf(cue.end,cue.emission_stop+longest_particle)
        if cue.get("stop_emission_at_release",false):
            cue.emission_stop=cue.launch
            cue.end=maxf(cue.end,cue.launch+longest_particle/float(cue.get("source_rate",1.0)))
        cue_plan.end=maxf(cue_plan.end,cue.end)
    elapsed=0.0
    if not cue_plan.contacts.is_empty():arrival=cue_plan.contacts[0].time
    var reaction_tail=0.0 if recipe.get("damage")==null else 1.25
    for contact in cue_plan.contacts:cue_plan.end=maxf(cue_plan.end,contact.time+reaction_tail)
    for action in feedback.actions:
        cue_plan.end=maxf(cue_plan.end,(action.track.start_ms+action.track.duration_ms)/1000.0)
        if action.spec.has("reaction"):
            var reaction:Dictionary=rigs[action.track.rig].clips[action.spec.reaction]
            cue_plan.end=maxf(cue_plan.end,action.contact_ms/1000.0+float(reaction.frames)/float(reaction.fps))
    duration=cue_plan.end+spell.tail_seconds if phase_mode=="Sequence" else _isolated_seconds(active_clips.isolated)+spell.tail_seconds
    body_surface_bindings=BodySurface.prepare(self)
    playing=true
    _sample_frame(0.0)
    _show_pieces()

func reload_authoring() -> void:
    body_material.close()
    catalog_cache.erase("sandbox/feedback.json")
    staging=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/staging.json"))
    library=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    spells[selected_spell]=ResourceLoader.load("res://authoring/sandbox/"+spell.spell_id+".tres","",ResourceLoader.CACHE_MODE_REPLACE)
    select_spell(selected_spell)

func select_phase(index: int) -> void:
    phase_choices.select(index)
    phase_mode="Sequence" if index==0 else source_clips[index-1].id
    restart()

func _endpoints() -> void:
    source_start = $Caster/Release.global_position
    source_end = $Target/Impact.global_position
    if authored_sockets and visual_actors.has("caster"):
        var component = {"kind":"native_effect","recipe":socket_recipe,
            "actor_uuid":"caster","target_uuid":"target",
            "from_position":[$Caster.position.x,$Caster.position.z],"to_position":[$Target.position.x,$Target.position.z],
            "from_elevation_feet":$Caster.position.y/Placement.HEIGHT_UNIT*5.0,"to_elevation_feet":$Target.position.y/Placement.HEIGHT_UNIT*5.0}
        projectile_placement=component
        var row:Dictionary=visual_actors.caster.row.duplicate()
        var direction=Vector2(component.to_position[0]-component.from_position[0],component.to_position[1]-component.from_position[1])
        if not direction.is_zero_approx():row.facing=_facing(direction)
        var facing=ComponentRenderer._facing(self,row)
        var pixel:Variant=socket_recipe.get("sourceSockets",{}).get("release",{}).get(facing)
        if pixel!=null:
            source_start = _cast_socket_point("release", int(recipe.cast.releaseFrame), facing, pixel)
        source_end = _target_point("target")
    arrival=release+source_start.distance_to(source_end)/flight_speed

func _process(delta: float) -> void:
    if not fixture_ready: return
    if placement_snapshot!=_marker_positions():
        _place_actors()
        restart()
    if playing:
        elapsed = minf(elapsed+delta*rate,duration)
        if elapsed>=duration:
            if loop:
                loop_count += 1
                restart()
            else: playing = false
    _sample_frame(delta)
    var phase = "Idle"
    if phase_mode!="Sequence": phase = active_clips.get("isolated",{}).get("label",phase_mode)
    elif elapsed>=arrival: phase = "Active" if recipe.get("damage")==null else "Impact"
    elif elapsed>=release: phase = "Apply" if staging_spec.get("target_local",false) else "Travel"
    elif elapsed>=spell.lead_in_seconds: phase = "Cast"
    phase_label.text = "%s  ·  %.2f / %.2f s  ·  %d FPS"%[phase,elapsed,duration,Engine.get_frames_per_second()]
    progress.value = elapsed/maxf(duration,0.001)*100

func _sample_frame(delta: float) -> void:
    if recipe.is_empty(): return
    timeline.display_ms = elapsed*1000.0
    displayed_samples = {}
    var start: float = spell.lead_in_seconds if phase_mode=="Sequence" else 0.0
    if recipe.cast.get("enabled",true) and (phase_mode=="Sequence" or active_clips.get("isolated",{}).get("phase","")=="cast") and elapsed>=start and elapsed<start+cast_duration:
        displayed_samples.caster = {"clip":recipe.cast.actionClip,"source_seconds":(elapsed-start)*float(recipe.cast.bodyPlaybackSpeed),
            "occurrence":"sandbox-cast","from_position":timeline.state.actors.caster.last_visual_position,
            "target_position":timeline.state.actors.target.last_visual_position,"hidden_slots":["weapon","offhand"]}
    displayed_components=Feedback.samples(self,elapsed)
    body_material.decorate(self,displayed_components)
    Feedback.reactions(self,elapsed)
    Feedback.actions(self,elapsed)
    # Positions/heights are independent editable visual markers, not cell support.
    for id in actor_markers:
        var marker: Node3D = get_node(actor_markers[id])
        if not displayed_samples.has(id): displayed_samples[id] = {"clip":"Idle","source_seconds":elapsed,"occurrence":"sandbox-idle-"+id}
        displayed_samples[id].position = [marker.position.x,marker.position.z]
        displayed_samples[id].base_height_steps = marker.position.y/Placement.HEIGHT_UNIT
    timeline.retained_directions = {"caster":[timeline.state.actors.caster.last_visual_position,timeline.state.actors.target.last_visual_position],
        "target":[timeline.state.actors.target.last_visual_position,timeline.state.actors.caster.last_visual_position]}
    _sync_actors()
    _sample_actors()
    # Sprite sockets rotate with their authored view. Rebind the existing cues
    # without restarting their clocks or changing contact times.
    var contact_time=arrival
    _endpoints()
    arrival=contact_time
    for cue in cue_plan.cues:
        cue.from=_target_point(cue.from_actor) if cue.has("from_actor") else source_start
        cue.to=source_end if cue.target=="target" else _target_point(cue.target)
        cue.ground=get_node(actor_markers[cue.target]).global_position
        cue.caster_ground=$Caster.global_position
    _sample_effects(delta)
    var surfaces=BodySurface.samples(self,elapsed)
    displayed_components.append_array(surfaces)
    var current_surfaces:Dictionary={}
    for sample in surfaces:current_surfaces[sample.actor_uuid]=true
    for id in current_surfaces:
        var stack=BodySurfaces.compose(id,surfaces)
        current_surfaces[id]=stack
        for missing in stack.missing:
            var message="Body surface capacity exceeded: "+str(missing.id)
            if message not in presentation_errors:presentation_errors.append(message)
            for sample in surfaces:
                if sample.id==missing.id:sample.merge(missing,true)
    # Retired owners also need a reset when unchanged actor poses are cached.
    # Source materials have sampled this frame; no second actor-animation pass.
    var affected=body_surface_actors.duplicate()
    affected.merge(current_surfaces,true)
    for id in affected:
        if not visual_actors.has(id):continue
        for entry in visual_actors[id].entries:
            if entry.role=="shadow":continue
            BodySurfaces.bind(entry.material,current_surfaces.get(id,{}))
    body_surface_actors=current_surfaces
    var optical:Dictionary={}
    if spell_colours and staging_spec.has("light_color"):optical.color=Color(staging_spec.light_color)
    optical.energy_multiplier=float(staging_spec.get("decorative_light_multiplier",1.0))
    source_lighting.prepare_native_handles(handles,{})
    source_lighting.sample_handles(handles,0.0,optical)
    EffectLayer.sync(effect_layer,self)
    _sync_native_lighting()
    _sort_draws()
    native_support.prepare_membership(static_entries,visual_actors)
    native_support.sync(static_entries,visual_actors,camera)

func _sample_effects(delta:float)->void:
    if phase_mode!="Sequence":
        _sample_isolated_effects(delta)
        return
    for cue in cue_plan.cues:
        var handle:Dictionary=handles[cue.id]
        handle.root.visible=elapsed>=cue.begin and elapsed<cue.end
        if not handle.root.visible:continue
        var transform=Choreography.transform(cue,elapsed,_preparation_point(),spell.effect_scale/.18)
        handle.root.transform=transform
        FactorySource.view(handle,camera)
        var age=Choreography.source_time(cue,elapsed)
        FactorySource.sample(handle,age,delta,elapsed-cue.launch)
        # Scene-native core origin; emitter buildup and trail do not move the
        # world carrier. Source registration is explicit and camera independent.
        if cue.has("origin_path"):
            var anchor:Node3D=handle.root.get_node(cue.origin_path)
            handle.root.global_position+=transform.origin-anchor.global_position
        _sample_controls(handle,cue,elapsed)
        if cue.has("body_surface"):handle.root.hide()

func _sample_controls(handle:Dictionary,cue:Dictionary,time:float)->void:
    NativeSpellPlayback.controls(handle,cue,time)
    for piece in handle.geometry:
        var key=spell.spell_id+"/"+cue.clip.id+"/"+piece.path
        if source_overrides.has(key):piece.node.visible=source_overrides[key]

func _isolated_seconds(clip:Dictionary)->float:
    var placement:Dictionary=clip.get("placement",{})
    return float(placement.source_end)/float(placement.get("source_rate",1.0)) if placement.has("source_end") else float(clip.seconds)

func _sample_isolated_effects(delta: float) -> void:
    var forward = source_end-source_start
    var basis = Basis.looking_at(forward.normalized(),Vector3.FORWARD if absf(forward.normalized().dot(Vector3.UP))>0.99 else Vector3.UP) if forward.length_squared()>0.00001 else Basis.IDENTITY
    for key in handles:
        var clip: Dictionary=active_clips[key]
        var stage: String=clip.get("stage",clip.phase) if key=="isolated" else key
        if stage=="palm": stage="cast"
        if stage=="lifecycle": stage="impact"
        var begin: float={"cast":preparation_begin,"travel":release,"impact":arrival,"delivery":release}.get(stage,0.0) if phase_mode=="Sequence" else 0.0
        var length: float=_isolated_seconds(clip)
        var time_map:Array=socket_recipe.get(clip.get("time_map",""),{}).get("timeMap",[])
        if clip.get("start_at","")=="cast" and phase_mode=="Sequence":
            begin=spell.lead_in_seconds
            if not time_map.is_empty():length=float(time_map.back().elapsedMs)/1000.0
        var active=elapsed>=begin and elapsed<begin+length
        var handle: Dictionary=handles[key]
        handle.root.visible=active
        if not active: continue
        var age=elapsed-begin
        var origin=_preparation_point() if stage=="cast" else source_start
        if stage in ["travel","delivery"]: origin=source_start.lerp(source_end,clampf(age/maxf(arrival-release if phase_mode=="Sequence" else float(clip.get("travel_source_seconds",length)),.001),0,1))
        elif stage=="impact": origin=source_end
        var source_basis=basis*Basis(Vector3.UP,deg_to_rad(float(clip.get("source_yaw_degrees",0))))
        var scale=spell.effect_scale*float(clip.get("native_unit_scale",1.0))*float(spell.stage_scales.get(stage,1.0))
        var attached:Dictionary=clip.get("placement",{})
        var origin_path:String=attached.get("origin_path","")
        for choice in staging_spec.cues:
            if choice.clip!=clip.id:continue
            scale=float(choice.get("scale",.18))*spell.effect_scale/.18
            origin_path=choice.get("origin_path",origin_path)
            var angles:Array=choice.get("rotation_degrees",[0,0,0])
            source_basis=basis*Basis.from_euler(Vector3(angles[0],angles[1],angles[2])*PI/180.)
            if choice.role=="area":source_basis=Basis.IDENTITY;origin=$Target.global_position
            if choice.role=="strike":origin=source_end
            if choice.role=="spray":origin=source_start
            if choice.role=="attached":attached=choice
        handle.root.transform=Transform3D(source_basis.scaled(Vector3.ONE*scale),origin)
        if not attached.is_empty():
            var id:String=staging_spec.get("recipient","target")
            var pose=attached.duplicate(true)
            pose.merge({"role":"attached","from":source_start,"to":_target_point(id),
                "ground":get_node(actor_markers[id]).global_position,"caster_ground":$Caster.global_position},true)
            handle.root.transform=Choreography.transform(pose,elapsed,_preparation_point(),spell.effect_scale/.18)
        var source_age=age
        if not time_map.is_empty() and phase_mode=="Sequence":
            source_age=_source_time(time_map,age,float(socket_recipe[clip.time_map].fps))
        if stage=="cast": source_age=age/maxf(length,.001)*float(clip.seconds)
        if stage in ["travel","delivery"] and clip.has("travel_source_seconds") and phase_mode=="Sequence":
            var travel_time=maxf(arrival-release,.001)
            source_age=minf(age/travel_time,1.0)*float(clip.travel_source_seconds)+maxf(0.0,age-travel_time)
        FactorySource.view(handle,camera)
        FactorySource.sample(handle,source_age*float(attached.get("source_rate",1.0)),delta,age)
        # Every isolated phase uses the same named native core as Sequence.
        # Register after native sampling, which may move the source internally.
        if not origin_path.is_empty():
            var anchor:Node3D=handle.root.get_node(origin_path)
            handle.root.global_position-=anchor.global_position-handle.root.global_position
        if not attached.is_empty():
            var controls=attached.duplicate(true)
            controls.clip=clip;controls.begin=begin;controls.end=begin+length;controls.role="attached"
            if controls.has("emission_seconds"):controls.emission_stop=float(controls.emission_seconds)
            _sample_controls(handle,controls,elapsed)
            if controls.has("body_surface"):handle.root.hide()
        # Inspector toggles override authored visibility only when explicitly set.
        for piece in handle.geometry:
            var override_key=spell.spell_id+"/"+clip.id+"/"+piece.path
            if source_overrides.has(override_key): piece.node.visible=source_overrides[override_key]

func _source_time(points:Array,seconds:float,fps:float)->float:
    for i in range(1,points.size()):
        var a:Dictionary=points[i-1];var b:Dictionary=points[i]
        if seconds*1000.0<=float(b.elapsedMs):
            return lerpf(float(a.sourceFrame),float(b.sourceFrame),clampf((seconds*1000.0-float(a.elapsedMs))/maxf(.001,float(b.elapsedMs)-float(a.elapsedMs)),0,1))/fps
    return float(points.back().sourceFrame)/fps

func _preparation_point() -> Vector3:
    if not authored_sockets: return source_start
    var row:Dictionary=visual_actors.caster.row
    if playbacks.caster.clip!=recipe.cast.actionClip:return _pose_socket_point("caster","hand")
    var facing=ComponentRenderer._facing(self,row)
    var points:Array=socket_recipe.get("sourceSockets",{}).get("preparation",{}).get(facing,[])
    if points.is_empty(): return _pose_socket_point("caster","hand")
    var seconds:float=displayed_samples.caster.get("source_seconds",0.0)
    var frame=clampi(int(seconds*rigs[row.rig].clips[recipe.cast.actionClip].fps),0,points.size()-1)
    if points[frame]==null: return source_start
    return _cast_socket_point("preparation",frame,facing,points[frame])

func _cast_socket_point(key:String,frame:int,facing:String,pixel:Dictionary)->Vector3:
    var sockets:Dictionary=socket_recipe.get("sourceSockets",{})
    var sources:Array=sockets.get("sources",[])
    var points:Array=[pixel]
    if not sources.is_empty():
        points.clear()
        var rig:Dictionary=rigs[visual_actors.caster.row.rig]
        for name in sources:points.append(rig.pose_sockets[name][recipe.cast.actionClip][facing][frame])
    var result:=Vector3.ZERO
    for index in points.size():
        var point:Dictionary=points[index]
        var placement=projectile_placement.duplicate(false)
        placement.recipe=socket_recipe.duplicate(false)
        placement.recipe.sourceSockets={"release":{facing:point}}
        var painted=ComponentRenderer._projectile_point(self,placement,0.0)
        # Resolve each painted hand before averaging: the space between hands
        # can contain torso pixels or no painted surface at all.
        result+=_surface_point(key if sources.is_empty() else key+"/"+sources[index],
            "caster",recipe.cast.actionClip,frame,facing,Vector2(point.x,point.y),painted,["weapon","offhand"])
    result/=points.size()
    if not sources.is_empty():
        var forward:Vector3=($Target.position-$Caster.position)*Vector3(1,0,1)
        var unit:float=128.0/float(rig_config.TILE_W)*visual_actors.caster.row.scale/Placement.PIXELS_PER_UNIT
        result+=forward.normalized()*float(sockets.get("forwardPixels",0.0))*unit
        socket_samples[key]={"point":result,"sources":sources,"frame":frame,"facing":facing}
    return result

func _surface_point(key:String,id:String,clip:String,frame:int,facing:String,pixel:Vector2,painted:Vector3,hidden:Array=[])->Vector3:
    var result=SurfaceSockets.resolve(self,id,clip,frame,facing,pixel,painted,hidden)
    socket_samples[key]=result
    return result.point

func _target_point(id:String)->Vector3:
    return _pose_socket_point(id,"body_center")

func _pose_socket_point(id:String,socket:String)->Vector3:
    var row:Dictionary=visual_actors[id].row
    var painted=ComponentRenderer._socket(self,row,socket)
    if not authored_sockets:return painted
    var playback:Node=playbacks[id]
    var rig:Dictionary=rigs[row.rig]
    var clip:String=playback.clip
    var frame=mini(int(playback.sample_seconds*rig.clips[clip].fps),int(rig.clips[clip].frames)-1)
    var facing=ComponentRenderer._facing(self,row)
    var points:Array=rig.get("pose_sockets",{}).get(socket,{}).get(clip,{}).get(facing,[])
    var point:Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else rig.get("body_anchor") if socket=="body_center" else null
    if point==null:return painted
    return _surface_point(id+"-"+socket,id,clip,frame,facing,Vector2(point.x,point.y),painted)

func rotate_view(step: int) -> void:
    quarter = posmod(quarter+step,4)
    position_camera()
    for entry in static_entries: initialize_entry(entry)
    static_order_dirty = true
    world_generation += 1
    _sample_frame(0.0)

func place_marker(id: String, position: Vector3) -> void:
    get_node(id).position = position
    _place_actors()
    _sample_frame(0.0)
    restart()

func _input(_event: InputEvent) -> void:
    pass # The live player's input handlers are intentionally not active here.

func _unhandled_input(event: InputEvent) -> void:
    if not fixture_ready: return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_SPACE: playing = not playing
            KEY_R: restart()
            KEY_Q: rotate_view(-1)
            KEY_E: rotate_view(1)
            _: return
        get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            camera.size = clampf(camera.size*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),3,18)
        elif event.button_index==MOUSE_BUTTON_LEFT and placement_mode:
            var id="Caster" if event.shift_pressed else "Target"
            var height:float=get_node(id).position.y
            var hit = Plane(Vector3.UP,height).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
            if hit!=null: place_marker(id,Vector3(snappedf(hit.x,0.25),height,snappedf(hit.z,0.25)))

func _build_controls() -> void:
    var canvas = CanvasLayer.new()
    add_child(canvas)
    controls = VBoxContainer.new()
    controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    controls.offset_left = 18; controls.offset_top = 14; controls.offset_right = -18
    canvas.add_child(controls)
    var bar = HFlowContainer.new(); controls.add_child(bar)
    var title = Label.new(); title.text = "NATIVE SPELL LAB"; bar.add_child(title)
    var choices = OptionButton.new(); spell_choices=choices;bar.add_child(choices)
    for value in spells: choices.add_item(value.title)
    choices.item_selected.connect(select_spell)
    choices.select(3)
    phase_choices=OptionButton.new(); bar.add_child(phase_choices)
    phase_choices.item_selected.connect(select_phase)
    cast_choices=OptionButton.new();bar.add_child(cast_choices)
    cast_variants=Casting.variants()
    for profile in cast_variants:
        cast_choices.add_item("Cast: "+profile.label)
        cast_choices.set_item_disabled(cast_choices.item_count-1,profile.status!="available")
    cast_choices.tooltip_text="Casting pose with its own preparation, release frame and hand trajectory. Authored preserves the spell's original choice."
    cast_choices.item_selected.connect(func(index):select_spell(selected_spell,cast_variants[index].id))
    _button(bar,"Cast · R",restart)
    _button(bar,"Pause · Space",func(): playing=not playing)
    _button(bar,"Reload",reload_authoring)
    _button(bar,"↶ Q",func(): rotate_view(-1))
    _button(bar,"↷ E",func(): rotate_view(1))
    var repeat = CheckButton.new(); repeat.text="Loop"; repeat.button_pressed=loop; bar.add_child(repeat)
    repeat.toggled.connect(func(value):loop=value)
    _number(bar,"Playback",rate,0.25,2,0.25,func(value):rate=value)
    size_control = _number(bar,"Size",0.18,0.02,1,0.02,func(value):if spell!=null:spell.effect_scale=value;restart())
    var sockets = CheckButton.new(); sockets.text="Hand sockets"; sockets.button_pressed=authored_sockets; bar.add_child(sockets)
    sockets.toggled.connect(func(value):authored_sockets=value;restart())
    _button(bar,"Pieces",func():pieces_panel.visible=not pieces_panel.visible)
    pieces_panel=PanelContainer.new(); canvas.add_child(pieces_panel)
    pieces_panel.position=Vector2(18,130);pieces_panel.size=Vector2(420,420);pieces_panel.hide()
    var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(420,420);pieces_panel.add_child(scroll)
    pieces=VBoxContainer.new();scroll.add_child(pieces)
    var placement_bar=HFlowContainer.new();controls.add_child(placement_bar)
    var placement=CheckButton.new();placement.text="Place actors";placement_bar.add_child(placement)
    placement.toggled.connect(func(value):placement_mode=value)
    var colours=CheckButton.new();colours.text="Spell colours";colours.button_pressed=spell_colours;placement_bar.add_child(colours)
    colours.toggled.connect(func(value):spell_colours=value;EffectLayer.colours(effect_layer,library.spells[selected_spell].get("palette",{}),value);_sample_frame(0.0))
    hit_flash_button=CheckButton.new();hit_flash_button.text="Spell hit flash"
    hit_flash_button.button_pressed=spell_hit_flash
    hit_flash_button.tooltip_text="Apply the spell colour/material flash to the hit body. The TakeDamage animation and impact VFX remain active."
    placement_bar.add_child(hit_flash_button)
    hit_flash_button.toggled.connect(func(value):spell_hit_flash=value;_sample_frame(0.0))
    hit_appearance_choice=OptionButton.new()
    hit_appearance_choice.add_item("Colour treatment");hit_appearance_choice.add_item("Full spell material")
    hit_appearance_choice.selected=hit_appearance
    hit_appearance_choice.tooltip_text="Receiver body: existing colour treatment or the native spell material."
    placement_bar.add_child(hit_appearance_choice)
    hit_appearance_choice.item_selected.connect(func(index):hit_appearance=index;_sample_frame(0.0))
    flight_control=_number(placement_bar,"Flight · tiles/s",flight_speed,1,24,.5,func(value):flight_speed=value;restart())
    var targets=OptionButton.new();targets.add_item("Repeated target");targets.add_item("Split targets");placement_bar.add_child(targets)
    targets.item_selected.connect(func(index):split_targets=index==1;restart())
    var hint = Label.new(); hint.text="Wheel: zoom"; placement_bar.add_child(hint)
    phase_label = Label.new(); controls.add_child(phase_label)
    progress = ProgressBar.new(); progress.show_percentage=false; progress.custom_minimum_size.y=4; controls.add_child(progress)

func _button(parent: Control, text: String, action: Callable) -> void:
    var button = Button.new(); button.text=text; button.focus_mode=Control.FOCUS_NONE
    button.pressed.connect(action); parent.add_child(button)

func _number(parent: Control, text: String, value: float, low: float, high: float, step: float, changed: Callable) -> SpinBox:
    var group=HBoxContainer.new();parent.add_child(group)
    var label = Label.new(); label.text=text; group.add_child(label)
    var number = SpinBox.new(); number.min_value=low; number.max_value=high; number.step=step; number.value=value
    number.custom_minimum_size.x=88; number.value_changed.connect(changed); group.add_child(number)
    return number

func _show_pieces() -> void:
    for child in pieces.get_children(): child.queue_free()
    for key in handles:
        var heading=Label.new();heading.text=active_clips[key].label;pieces.add_child(heading)
        for piece in handles[key].geometry:
            var button=CheckButton.new();button.text=piece.path
            button.button_pressed=piece.selected
            button.tooltip_text="Native source node. Unchecked pieces include authored disabled alternatives."
            pieces.add_child(button)
            var override_key=spell.spell_id+"/"+active_clips[key].id+"/"+piece.path
            button.toggled.connect(func(value):
                source_overrides[override_key]=value;piece.node.visible=value
                if value:piece.node.layers=EffectLayer.LAYER)

func _exit_tree() -> void:
    body_material.close()
    EffectLayer.detach(effect_layer)
    native_support.close()
    for handle in handles.values(): FactorySource.close(handle)
    super._exit_tree()
