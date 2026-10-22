extends RefCounted
const Occurrences=preload("res://presentation/occurrences.gd")
const SpellDelivery=preload("res://presentation/spell_delivery.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const ApplicationResults=preload("res://presentation/application_results.gd")
const NativeActions=preload("res://presentation/native_action_authoring.gd")
const OperationResults=preload("res://presentation/operation_results.gd")
const ReactionInputs=preload("res://presentation/reaction_inputs.gd")
const CreationInputs=preload("res://presentation/creation_inputs.gd")
const ActorBirthInputs=preload("res://presentation/actor_birth_inputs.gd")
const PropagationInputs=preload("res://presentation/propagation_inputs.gd")
const NativeItems=preload("res://presentation/native_items.gd")
const NativePersistent=preload("res://presentation/native_persistent.gd")
## Finite, passive presentation mechanisms shared by the compiler and renderer.
const Authoring=preload("res://presentation/authoring.gd")
const Palette=preload("res://presentation/palette.gd")
const AudioCues=preload("res://presentation/audio_cues.gd")
const Placement=preload("res://placement.gd")
const Characters=preload("res://presentation/characters.gd")
const Blood=preload("res://presentation/blood.gd")
const ImpactPlacement=preload("res://presentation/impact_placement.gd")
const ConditionResponses=preload("res://presentation/condition_responses.gd")
const MovementMedia=preload("res://presentation/movement_media.gd")

static func effect_seed(component:Dictionary)->int:
    var occurrence:String=component.get("source_event_uuid","")
    if occurrence.is_empty():
        occurrence=component.get("id","")
        var prefix=occurrence.get_slice(":",0)
        if prefix.is_valid_int() and occurrence.contains(":"):occurrence=occurrence.substr(prefix.length()+1)
    return absi(hash([occurrence,component.get("kind",""),component.get("source_id",""),component.get("source",""),
        component.get("attachment",""),component.get("actor_uuid",""),component.get("target_uuid",""),
        component.get("condition_uuid",""),component.get("layer",{}).get("id",""),component.get("application_index",0)]))

## Existing environment resources own these programs; native facts supply
## identity, endpoints and admission. This is not another effect registry.
static func world_program(content_id:String,cache:Dictionary)->Dictionary:
    return Authoring.Catalog.environment_index(cache).get("spatial_media",{}).get(content_id,{})

static func world_activation_timing(fact:Dictionary,cache:Dictionary,support:Dictionary={})->Dictionary:
    var program:Dictionary=world_program(str(fact.get("mechanism_content_id","")),cache)
    var frames:Array=program.get("activation_frames",[])
    var fps:float=float(program.get("fps",0.0))
    if program.get("kind")!="sprite" or frames.is_empty() or fps<=0.0:return {}
    if str(program.get("default_orientation","")).is_empty() and (fact.get("direction")==null or fact.get("direction")==[0,0]):return {}
    var contact_index:int=frames.find(program.get("contact_frame",frames[0]))
    if contact_index<0:return {}
    var launch:float=float(contact_index)*1000.0/fps
    var travel:float=0.0
    var projectile:Dictionary=program.get("projectile",{})
    if not projectile.is_empty():
        if fact.get("origin_position")==null or fact.get("end_position")==null:return {}
        if not support.has("elevation_feet") or not support.has("end_elevation_feet"):return {}
        var speed:float=float(projectile.get("speed_tiles_per_second",0.0))
        if speed<=0.0:return {}
        var a:Array=fact.origin_position;var b:Array=fact.end_position
        travel=Vector3(b[0]-a[0],(float(support.end_elevation_feet)-float(support.elevation_feet))/5.0,b[1]-a[1]).length()*1000.0/speed
    return {"launch_delay_ms":launch,"projectile_ms":travel,"contact_ms":launch+travel,
        "duration_ms":maxf(float(frames.size())*1000.0/fps,launch+travel)}

static func world_activation(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    var fact:Dictionary=node.fact
    if node.get("phase")!="completion" or not fact.get("committed",false):return
    var program:Dictionary=world_program(str(fact.get("mechanism_content_id","")),cache)
    if program.get("kind")!="sprite" or program.get("activation_frames",[]).is_empty():return
    var support:Dictionary=graph.get("world_inputs",{}).get(str(node.id),{})
    var timing:Dictionary=world_activation_timing(fact,cache,support)
    var parameters:Dictionary={"actor_uuid":null,"target_uuid":fact.get("target_entity_uuid"),
        "mechanism_uuid":fact.get("mechanism_uuid"),"content_id":str(fact.mechanism_content_id),
        "origin_position":fact.get("origin_position"),"direction":fact.get("direction"),
        "end_position":fact.get("end_position"),"affected_positions":fact.get("affected_positions",[]),
        "elevation_feet":support.get("elevation_feet"),"source_cut":support.get("source_index"),
        "end_elevation_feet":support.get("end_elevation_feet"),
        "affected_elevations_feet":support.get("affected_elevations_feet",{}),
        "missing_support_positions":support.get("missing_support_positions",[]),
        "launch_delay_ms":timing.get("launch_delay_ms",0.0),"projectile_ms":timing.get("projectile_ms",0.0)}
    var missing_origin:bool=not support.has("elevation_feet") or fact.get("origin_position")==null
    var missing_cells:bool=support.get("affected_elevations_feet",{}).is_empty()
    var missing_endpoint:bool=not program.get("projectile",{}).is_empty() and not support.has("end_elevation_feet")
    if timing.is_empty() or missing_endpoint or (missing_origin if program.get("requires_object_anchor",true) else missing_cells):
        parameters.status="missing";parameters.reason="actual_mechanism_origin_or_source_timing_not_bound"
    add(group,node,"world_activation",float(graph.starts.get(node.id,0.0)),
        float(timing.get("duration_ms",0.0)),str(program.get("source","authoring/environment/surfaces/"+str(fact.mechanism_content_id)+".tres::world_media")),parameters)

static func world_portal_program(node:Dictionary,graph:Dictionary,cache:Dictionary)->Dictionary:
    var content_id:String=str(node.fact.get("portal_content_id","")) if node.fact.get("portal_content_id")!=null else ""
    if content_id.is_empty():content_id=str(graph.get("portal_inputs",{}).get(str(node.id),{}).get("content_id",""))
    var program:Dictionary=world_program(content_id,cache)
    return program.merged({"content_id":content_id}) if program.get("kind")=="portal" else {}

static func world_portal_timing(node:Dictionary,graph:Dictionary,cache:Dictionary)->Dictionary:
    var program:Dictionary=world_portal_program(node,graph,cache)
    if program.is_empty():return {}
    var before:Dictionary=graph.get("portal_inputs",{}).get(str(node.id),{})
    var entry:float=0.0
    if node.fact.get("start_position")!=null and before.has("elevation_feet"):
        entry=float(program.get("fall_delay_ms",0.0))+float(program.get("fall_ms",0.0))+float(program.get("transit_ms",0.0))
    var exit:Dictionary=program.get("roles",{}).get("exit",{})
    var close:float=float(exit.get("closing_frames",0.0))*1000.0/maxf(1.0,float(exit.get("fps",1.0)))
    return {"entry_ms":entry,"exit_ms":float(program.get("emerge_ms",0.0))+float(program.get("exit_hold_ms",0.0))+close}

static func world_portal_exit(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    var fact:Dictionary=node.fact
    if node.phase!="completion" or not fact.get("committed",false) or fact.get("end_position")==null:return
    var program:Dictionary=world_portal_program(node,graph,cache)
    var timing:Dictionary=world_portal_timing(node,graph,cache)
    var cut:Dictionary=graph.get("portal_inputs",{}).get(str(node.id),{})
    if program.is_empty() or timing.is_empty() or not cut.has("end_elevation_feet"):return
    add(group,node,"world_activation",float(graph.get("committed_at",{}).get(str(node.id),graph.times.get(node.id,graph.starts.get(node.id,0.0)))),float(timing.exit_ms),
        str(program.get("source","authoring/environment/surfaces/"+str(program.content_id)+".tres::world_media")),
        {"role":"portal_exit","actor_uuid":null,"target_uuid":fact.target_entity_uuid,
            "mechanism_uuid":fact.get("portal_uuid"),"content_id":program.content_id,
            "origin_position":fact.end_position,"direction":[0,0],"end_position":fact.end_position,"affected_positions":[fact.end_position],
            "elevation_feet":cut.end_elevation_feet,"source_cut":cut.source_index})

static func weapon_trail(recipe: Dictionary,fact: Dictionary,actor: Dictionary,cache: Dictionary) -> Dictionary:
    var trail: Dictionary=recipe.get("weaponTrail",{}) if recipe.get("weaponTrail")!=null else {}
    if trail.is_empty() or recipe.get("projectile")!=null or fact.get("attack_source_kind")!="equipped":return {}
    if str(trail.get("source_id","")).is_empty() or float(trail.get("contact_seconds",0.0))<=0.0 \
        or float(trail.get("end_seconds",0.0))<float(trail.contact_seconds):return {}
    var outcome: String={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}.get(fact.get("attack_outcome"),"")
    if fact.behavior_id not in trail.get("behaviorIds",[]) and outcome not in trail.get("outcomes",[]):return {}
    var rig_id=Authoring.rig_id(actor,cache)
    var rig: Dictionary=Authoring.rigs(cache)[rig_id]
    var outfit=Characters._select_layers(actor,rig,actor.get("appearance",{}).get("presentation_kind")=="layered",cache)
    if not outfit.ok:return {}
    var slot="offhand" if fact.weapon_slot=="MELEE_OFF" else "weapon"
    for layer in outfit.value:
        if layer.slot!=slot:continue
        var key:String=rig_id+"/"+str(layer.category)+"/"+str(recipe.actor.clip)
        var document:String=trail.get("poseDocuments",{}).get(key,"")
        if not document.is_empty():
            return {"pose":Authoring.load_data(document,cache),"palette":trail.palette,
                "source_id":str(trail.source_id),"impact_source_id":str(trail.get("impact_source_id","")),
                "contact_seconds":float(trail.contact_seconds),"end_seconds":float(trail.end_seconds),
                "source":str(trail.get("source",""))}
    return {}

static func attack_colors(fact: Dictionary,cache: Dictionary) -> Dictionary:
    var palettes: Dictionary=Authoring.load_data("catalog/damage_context.json",cache).palette
    var selected: String=""
    for type in fact.get("damage_types",[]):
        if selected.is_empty():selected=type
        if type not in ["Bludgeoning","Piercing","Slashing"]:selected=type;break
    return palettes.byDamageType.get(selected,palettes.untyped).elementColors

static func attack_layers(recipe: Dictionary,fact: Dictionary,actor: Dictionary,cache: Dictionary) -> Array:
    var outcome="onCrit" if fact.attack_outcome=="Crit" else ("onHit" if fact.attack_outcome=="Hit" else "onMiss")
    var selected: Dictionary=recipe.get("attackVfx",{}).get(outcome,{})
    var rig: Dictionary=Authoring.rigs(cache).get(Authoring.rig_id(actor,cache),{})
    var colors=attack_colors(fact,cache)
    var result: Array=[]
    var tokens={"white":0xffffff,"$element":colors.primary,"$element.primary":colors.primary,"$element.secondary":colors.secondary,"$element.tertiary":colors.tertiary}
    for slot in selected:
        var layer: Dictionary=selected[slot]
        if not layer.category in rig.get("slot_categories",{}).get(slot,[]):continue
        if not rig.get("clips",{}).get(recipe.actor.clip,{}).get("sheets",{}).has(layer.category):continue
        var tint: int=int(tokens.get(layer.tint,0xffffff)) if layer.tint is String else int(layer.tint)
        var palette=[colors.tertiary,tint,colors.secondary] if layer.tint is String and layer.tint.begins_with("$element") else [tint]
        result.append(Palette.prepare({"id":"attack."+slot,"slot":slot,"enabled":true,"hidden":false,"category":layer.category,"palette":{"colors":palette}},rig,recipe.actor.clip,cache))
    return result

static func bolt(group: Dictionary,node: Dictionary,recipe: Dictionary,start: float,track: Dictionary,target: Dictionary,cache: Dictionary) -> float:
    var a: Array=track.from_position;var b: Array=track.target_position
    var config=Authoring.load_data("catalog/rig.json",cache)
    var rig: Dictionary=Authoring.rigs(cache)[track.rig]
    var appearance: Dictionary=track.presentation_actor.appearance
    var direction=Vector2(b[0]-a[0],b[1]-a[1])
    var cycle: Array=config.FACING_CYCLE
    var facing: String=cycle[posmod(roundi((atan2(direction.y,direction.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]
    var socket: Variant=recipe.get("sourceSocketsByRig",{}).get(track.rig,{}).get("release",{}).get(facing)
    var offset=Vector2(recipe.originX,recipe.originY)*appearance.visual_scale
    if socket!=null:offset=Vector2((socket.x-rig.cell_width*.5)*appearance.visual_scale_x,socket.y-rig.cell_height+rig.origin_y_from_ground)*appearance.visual_scale
    var source=Placement.project(Vector2(a[0],a[1]),0,0)*config.TILE_W/128.0+offset
    var destination=Placement.project(Vector2(b[0],b[1]),0,0)*config.TILE_W/128.0
    destination.y+=float(recipe.targetY)*target.get("appearance",{}).get("visual_scale",0)
    var forward=(destination-source).normalized()
    source+=forward*recipe.get("sourceForwardPx",0);destination-=forward*recipe.get("targetForwardPx",0)
    var height=(track.get("target_elevation_feet",0)-track.get("from_elevation_feet",0))/5.0*64.0*config.TILE_W/128.0
    var distance=Vector2(source.distance_to(destination),height).length()
    var duration=maxf(recipe.minimumTravelDurationMs,distance*1000.0/recipe.speedPxPerSecond) if distance>=1 else 0.0
    var endpoint: Variant=node.fact.get("projectile_deflection_position")
    if endpoint!=null:
        var route=Vector2(b[0]-a[0],b[1]-a[1]);var along=Vector2(endpoint[0]-a[0],endpoint[1]-a[1])
        duration*=clampf(along.dot(route)/maxf(.001,route.length_squared()),0,1);b=endpoint
    if duration<=0:return 0.0
    add(group,node,"geometry_projectile",start,duration,"catalog/attack_recipes.json:/"+str(node.fact.behavior_id)+"/projectile",
        {"actor_uuid":track.actor_uuid,"target_uuid":node.fact.target_entity_uuid,"attachment":"projectile","recipe":recipe,
        "from_position":a,"to_position":b,"from_elevation_feet":track.get("from_elevation_feet",0),"to_elevation_feet":track.get("target_elevation_feet",0),
        "style":Authoring.load_data("catalog/bolt_style.json",cache),"colors":attack_colors(node.fact,cache),"source_track":track})
    return duration

static func cast_layers(cast: Dictionary, actor: Dictionary, cache: Dictionary) -> Array:
    var layers: Array=[]
    for field in ["weaponGlow","aura"]:
        var layer: Dictionary=cast.get(field,{}) if cast.get(field)!=null else {}
        if layer.get("enabled",false) and not layer.get("hidden",false): layers.append(layer)
    for layer in cast.get("effects",[]):
        if layer.get("enabled",true) and not layer.get("hidden",false): layers.append(layer)
    var rig: Dictionary=Authoring.rigs(cache).get(Authoring.rig_id(actor,cache),{})
    if rig.is_empty(): return []
    return layers.map(func(layer): return Palette.prepare(layer,rig,cast.actionClip,cache))

static func add(group: Dictionary, node: Dictionary, kind: String, start: float, duration: float, source: String, parameters: Dictionary) -> Dictionary:
    var row={"id":"%s:%s:%s:%d" % [group.operation_sequence,node.id,kind,group.components.size()],
        "kind":kind,"source_event_uuid":node.id,"source_lineage":node.lineage_id,
        "parent_id":"%s:%s" % [group.operation_sequence,node.id],"start_ms":start,"duration_ms":duration,
        "source":source,"status":"available","sample_hz":60.0}
    row.merge(parameters,true); group.components.append(row)
    return row

static func _source(group: Dictionary, node: Dictionary, source_id: String, start: float, parameters: Dictionary, cache: Dictionary) -> Dictionary:
    var sources: Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    var record: Dictionary=sources.get(source_id,{})
    parameters=parameters.duplicate()
    parameters.source_id=source_id
    parameters.sample_hz=record.get("sample_hz",60)
    parameters.status="available" if not record.is_empty() else "missing"
    parameters.reason="" if not record.is_empty() else "native_source_not_imported"
    return add(group,node,"native_effect",start,record.get("duration",0)*1000,"native_effects/index.json:/sources/"+source_id,parameters)

static func native_spell(group:Dictionary,node:Dictionary,recipe:Dictionary,selected:Dictionary,start:float,duration:float,points:Dictionary,cache:Dictionary,owner:Dictionary,fact:Dictionary,application_index:int=0,graph:Dictionary={},release:Dictionary={})->void:
    var cast:Dictionary=recipe.get("cast",{})
    var placement:Dictionary=recipe.get("projectile",{}).duplicate() if recipe.get("projectile")!=null else {}
    for key in ["sourceSockets","sourceSocketsByRig"]:
        if cast.has(key):placement[key]=cast[key]
    var common={"actor_uuid":fact.source_entity_uuid,"target_uuid":fact.get("target_entity_uuid"),
        "attachment":"projectile","recipe":placement,"scale":placement.get("scale",1.0)}
    common.merge(points,true)
    if Occurrences.application(node):
        common.application_id=node.resolution_record.application_id;common.cast_lineage=str(node.resolution_record.lineage);common.application_index=application_index
    var cast_id:String=owner.get("source_event_uuid",node.id)
    var include_cast=not group.components.any(func(row):return row.get("native_cast_id")==cast_id and row.get("native_cue",{}).get("role")=="cast")
    var index:int=application_index
    var propagation:Dictionary=PropagationInputs.descriptor(selected)
    var linked:Dictionary=PropagationInputs.project(node,propagation,graph) if not propagation.is_empty() else {}
    var delivery:Dictionary=selected
    if linked.get("ready",false) and not linked.primary:
        delivery=selected.duplicate();delivery.staging=selected.staging.duplicate()
        delivery.staging.cues=selected.staging.cues.map(func(original):
            var cue:Dictionary=original.duplicate(true)
            if cue.get("constructor_input",{}).get("kind")=="propagation_links":
                cue.charge_seconds=0.0;cue.source_socket=str(propagation.secondary_source_socket)
                cue.live_endpoints[0].socket=cue.source_socket
            return cue)
    for phase in NativeSpells.phases(delivery,owner,start,duration,index,include_cast):
        if not NativeSpells.miss_impact_authored(selected,fact) and phase.native_cue.role=="impact" and fact.get("attack_outcome","") in ["Miss","Crit Miss"]:continue
        var parameters:Dictionary=common.duplicate()
        parameters.merge(phase,true)
        parameters.merge({"native_spell":true,"cast_recipe":cast,"native_cast_id":cast_id},true)
        var constructor:Dictionary=phase.native_cue.get("constructor_input",{})
        var result_descriptor:Dictionary=phase.native_cue.get("observed_result",{})
        if not result_descriptor.is_empty() and parameters.get("status")!="missing":
            for observed_result in ApplicationResults.geometry_results(node,result_descriptor,graph):
                var actual:Dictionary=parameters.duplicate()
                # The selected source consumes only the actual receiver. Its
                # original caster remains factual evidence, never a required
                # optical source when this result has no delivery component.
                actual.actor_uuid=observed_result.target_uuid;actual.target_uuid=observed_result.target_uuid
                actual.from_position=observed_result.position;actual.to_position=observed_result.position
                actual.from_elevation_feet=observed_result.elevation_feet;actual.to_elevation_feet=observed_result.elevation_feet
                actual.cast_recipe={"enabled":false};actual.ground_target=false
                actual.native_result_evidence=observed_result.evidence
                if not graph.has("observed_spell_phases"):graph.observed_spell_phases=[]
                graph.observed_spell_phases.append({"node":observed_result.node,"parameters":actual,
                    "offset_ms":0.0,"at_commit":true})
            continue
        var destination:Dictionary=phase.native_cue.get("observed_destination",{})
        if not destination.is_empty() and parameters.get("status")!="missing":
            var observed:Array=[]
            if destination.get("kind")=="actor_birth":observed=ActorBirthInputs.observed(node,destination,graph,group.commits)
            elif destination.get("kind")=="spatial_creation":observed=CreationInputs.spatial_destinations(node,destination,graph,group.commits)
            if observed.size()!=1:
                parameters.status="missing"
                parameters.reason="native_observed_destination_not_disclosed" if observed.is_empty() else "native_observed_destination_ambiguous"
                add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)
            else:
                var admitted:Dictionary=observed[0]
                var actual:Dictionary=parameters.duplicate()
                actual.target_uuid=admitted.target_uuid;actual.to_position=admitted.position
                actual.to_elevation_feet=admitted.elevation_feet;actual.ground_target=true
                actual.native_destination=admitted.evidence.merged({"kind":str(destination.kind)})
                actual.native_cue=parameters.native_cue.duplicate(false)
                actual.native_cue.launch=float(actual.native_cue.source_launch_local)
                actual.native_cue.contact=float(actual.native_cue.source_contact_local)
                if not graph.has("observed_spell_phases"):graph.observed_spell_phases=[]
                graph.observed_spell_phases.append({"node":admitted.node,"parameters":actual,"offset_ms":0.0,"at_commit":true})
            continue
        if constructor.get("kind")=="payload_release":
            if not release.get("applies",false):continue
            if release.get("ready",false):
                parameters.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":"","values":release.values}]
                parameters.native_constructor_evidence=release.evidence
                parameters.native_accepted_release=release.release
            else:
                parameters.status="missing";parameters.reason=release.reason
                parameters.unbound_constructor_inputs=["accepted_release"]
            add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)
            continue
        if constructor.get("kind")=="actor_birth" and parameters.get("status")!="missing":
            var births:Array=ActorBirthInputs.observed(node,constructor,graph,group.commits)
            if births.is_empty():
                parameters.status="missing";parameters.reason="native_actor_birth_not_disclosed"
                add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)
            for birth in births:
                var actual:Dictionary=parameters.duplicate()
                actual.target_uuid=birth.target_uuid;actual.to_position=birth.position
                actual.to_elevation_feet=birth.elevation_feet;actual.ground_target=false
                actual.native_actor_birth=birth.binding
                actual.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":"","values":birth.values}]
                actual.native_constructor_evidence=birth.evidence
                if not graph.has("observed_spell_phases"):graph.observed_spell_phases=[]
                graph.observed_spell_phases.append({"node":birth.node,"parameters":actual,"offset_ms":0.0,"at_commit":true})
            continue
        if constructor.get("kind")=="observed_event" and parameters.get("status")!="missing":
            var observations:Array=ApplicationResults.observed(node,constructor,graph)
            if observations.is_empty() and constructor.outcome=="cast" and constructor.get("projection")!="immediate_blast":
                parameters.status="missing";parameters.reason="native_observed_event_recipient_not_disclosed"
                add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)
            for observation in observations:
                var actual:Dictionary=parameters.duplicate()
                actual.target_uuid=observation.target_uuid
                actual.to_position=graph.positions.get(observation.target_uuid)
                actual.to_elevation_feet=graph.contacts.get(observation.target_uuid,{}).get("from_elevation_feet",0)
                var receiver:Dictionary=graph.get("result_contacts",{}).get(str(observation.node.id),{})
                if receiver.get("target_uuid")==observation.target_uuid:
                    actual.to_position=receiver.position;actual.to_elevation_feet=float(receiver.elevation_steps)*5.0
                if observation.has("origin_position"):
                    actual.from_position=observation.origin_position;actual.to_position=observation.origin_position
                    if observation.has("origin_elevation_feet"):
                        actual.from_elevation_feet=observation.origin_elevation_feet;actual.to_elevation_feet=observation.origin_elevation_feet
                actual.ground_target=false
                actual.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":"","values":observation.values}]
                actual.native_constructor_evidence=observation.evidence
                actual.native_inputs=observation.inputs
                if observation.has("input_values"):actual.native_input_values=observation.input_values
                if observation.has("endpoint_bindings"):
                    actual.native_cue=actual.native_cue.duplicate(true)
                    actual.native_actor_uuids={}
                    for endpoint in observation.endpoint_bindings:
                        actual.native_actor_uuids[endpoint.actor]=endpoint.actor_uuid
                        actual.native_cue.live_endpoints.append({"actor":endpoint.actor,"socket":endpoint.socket})
                for field in ["native_quarry","creation_binding"]:
                    if observation.has(field):actual[field]=observation[field]
                if constructor.outcome=="cast":
                    add(group,observation.node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,actual)
                else:
                    # Scheduling this cast has not visited its descendants yet.
                    # Retain the delivery operands now; emit the result only in
                    # the existing post-schedule component pass, at its own clock.
                    if not graph.has("observed_spell_phases"):graph.observed_spell_phases=[]
                    graph.observed_spell_phases.append({"node":observation.node,"parameters":actual,
                        "offset_ms":float(phase.start_ms)-float(graph.starts[node.id]),
                        "at_commit":constructor.get("projection") in ["breath_grant","quarry_application","condition_outcome","owner_activity"]})
            continue
        if not constructor.is_empty() and parameters.get("status")!="missing":
            var observed:Dictionary={}
            if constructor.get("kind")=="area_links":observed=PropagationInputs.area_project(node,constructor)
            elif constructor.get("kind")=="propagation_links":observed=linked
            elif constructor.get("kind")=="spell_strike":observed=ApplicationResults.spell_strike(node,constructor,graph)
            elif constructor.get("kind")=="condition_application":observed=ApplicationResults.condition_application(node,constructor,graph)
            else:observed=ApplicationResults.project(node,constructor,graph.get("application_results",{}))
            if observed.ready:
                parameters.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":constructor.input_field,"values":observed.values}]
                parameters.native_constructor_evidence=observed.evidence
                if constructor.get("kind")=="condition_application":
                    parameters.condition={"condition_uuid":observed.condition.condition_uuid,"state":observed.condition.state}
                    parameters.condition_uuid=observed.condition.condition_uuid
                    parameters.native_condition_application=observed.evidence
                if observed.has("inputs"):parameters.native_inputs=observed.inputs
                if constructor.get("kind")=="propagation_links":
                    parameters.native_propagation=observed.link
                    parameters.native_rule_caster_uuid=fact.source_entity_uuid
                    parameters.actor_uuid=str(observed.link.source.uuid)
                    if not observed.primary:parameters.cast_recipe={"enabled":false}
                    parameters.native_cue=parameters.native_cue.duplicate()
                    parameters.native_cue.source_contact=float(constructor.source_launch)+duration/1000.0
            else:
                parameters.status="missing";parameters.reason=observed.reason
                parameters.unbound_constructor_inputs=[constructor.input_field]
        add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)

static func native_action(group:Dictionary,node:Dictionary,binding:Dictionary,recipe:Dictionary,track:Dictionary,markers:Dictionary,graph:Dictionary,cache:Dictionary,observations:Array=[])->void:
    var fact:Dictionary=Occurrences.spell(node,graph) if node.fact.kind=="spell" else node.fact
    for phase in NativeActions.phases(binding,fact,recipe,track,markers,cache):
        if phase.native_cue.get("scope")=="cast" and Occurrences.application(node):continue
        var descriptor:Dictionary=phase.native_cue.get("constructor_input",{})
        if descriptor.get("kind")=="reaction_observation":
            var projected:Dictionary=ReactionInputs.project(node,descriptor,graph)
            if not projected.applies:continue
            var actual:Dictionary=phase.duplicate()
            if projected.ready:
                actual.native_reaction_observation=projected.observation
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,
                    "input_field":descriptor.input_field,"values":{} if not phase.native_cue.get("incoming_track",{}).is_empty() else projected.observation}]
                if projected.has("presentation"):actual.native_counterspell=projected.presentation
                actual.native_constructor_evidence=projected.evidence
            _native_action_component(group,node,node,actual,ReactionInputs.inputs(projected),graph)
        elif descriptor.get("kind")=="creation_admission":
            for projected in CreationInputs.observed(node,descriptor,graph,observations,group.commits):
                var actual:Dictionary=phase.duplicate()
                actual.start_ms=float(graph.starts[projected.node.id])+float(phase.start_ms)-float(markers["event.start"])
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
                actual.native_creation=projected.location
                _native_action_component(group,node,projected.node,actual,{"values":{"lease_input":{},"event_input":projected.event},
                    "gaps":[],"evidence":projected.evidence},graph,projected.target_uuid)
        elif descriptor.get("kind") in ["observed_operation","item_consumption"]:
            var projected:Dictionary=OperationResults.item_consumption(node,graph) if descriptor.kind=="item_consumption" else OperationResults.project(node,descriptor,graph)
            var actual:Dictionary=phase.duplicate()
            if projected.ready:
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
            _native_action_component(group,node,node,actual,{"values":projected.get("inputs",{}),
                "gaps":[] if projected.ready else [projected.reason],"evidence":projected.get("evidence",{})},graph)
        elif descriptor.get("kind")=="area_links":
            if Occurrences.application(node):continue
            var projected:Dictionary=PropagationInputs.area_project(node,descriptor)
            var contact:Dictionary=graph.get("area_contacts",{}).get(str(node.id),{})
            if contact.is_empty():projected={"ready":false,"reason":"electric_area_support_not_disclosed"}
            var actual:Dictionary=phase.duplicate()
            var points:Dictionary={}
            if projected.ready:
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
                actual.area_geometry=fact.area_geometry;actual.resolved_area_positions=fact.resolved_area_positions;actual.ground_target=true
                points={"to_position":contact.position,"to_elevation_feet":float(contact.elevation_steps)*5.0}
            _native_action_component(group,node,node,actual,{"values":projected.get("inputs",{}),
                "gaps":[] if projected.ready else [projected.reason],"evidence":projected.get("evidence",{})},graph,"",points)
        elif descriptor.get("kind")=="spell_strike":
            var projected:Dictionary=ApplicationResults.spell_strike(node,descriptor,graph)
            var actual:Dictionary=phase.duplicate()
            if projected.ready:
                actual.start_ms=float(graph.starts[projected.node.id])+float(phase.start_ms)-float(markers["event.start"])
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
            _native_action_component(group,node,projected.get("node",node),actual,{"values":projected.get("inputs",{}),
                "gaps":[] if projected.ready else [projected.reason],"evidence":projected.get("evidence",{})},graph)
        elif descriptor.get("kind")=="observed_event":
            if Occurrences.application(node):continue
            for projected in ApplicationResults.observed(node,descriptor,graph):
                var actual:Dictionary=phase.duplicate()
                actual.start_ms=float(graph.starts[projected.node.id])+float(phase.start_ms)-float(markers["event.start"])
                for publication in projected.get("publication_occurrences",[]):
                    for commit in group.commits:
                        if str(commit.get("event_uuid",""))==str(publication):actual.start_ms=maxf(actual.start_ms,float(commit.at_ms))
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
                for field in ["native_quarry","creation_binding"]:
                    if projected.has(field):actual[field]=projected[field]
                if projected.has("condition"):
                    actual.condition=projected.condition;actual.condition_uuid=str(projected.condition.condition_uuid)
                if projected.has("weapon_result_item_uuid"):actual.weapon_result_item_uuid=projected.weapon_result_item_uuid
                var points:Dictionary={}
                if projected.has("origin_position"):
                    points={"from_position":projected.origin_position,"to_position":projected.get("destination_position",projected.origin_position),
                        "from_elevation_feet":projected.get("origin_elevation_feet",0.0),"to_elevation_feet":projected.get("destination_elevation_feet",projected.get("origin_elevation_feet",0.0))}
                _native_action_component(group,node,projected.node,actual,{"values":projected.inputs,"gaps":[],"evidence":projected.evidence},graph,projected.target_uuid,points)
        else:
            _native_action_component(group,node,node,phase,NativeActions.inputs(node,binding,phase,graph,observations),graph)

static func _native_action_component(group:Dictionary,owner:Dictionary,event:Dictionary,phase:Dictionary,observed:Dictionary,graph:Dictionary,recipient_uuid:String="",points:Dictionary={})->Dictionary:
    var fact:Dictionary=owner.fact
    var source:String=str(fact.get("source_entity_uuid",""))
    var target:String=recipient_uuid if not recipient_uuid.is_empty() else str(fact.get("target_entity_uuid","")) if fact.get("target_entity_uuid")!=null else ""
    var from:Variant=points.get("from_position",graph.positions.get(source))
    var to:Variant=points.get("to_position",graph.positions.get(target))
    var parameters:Dictionary=phase.duplicate()
    parameters.native_inputs=observed.values
    parameters.native_input_gaps=observed.gaps
    parameters.native_input_evidence=observed.evidence
    if not observed.gaps.is_empty() and parameters.get("status")!="missing":
        parameters.status="missing";parameters.reason=observed.gaps[0]
    var recipient:bool=str(phase.native_cue.get("attachment","")).begins_with("recipient")
    var target_endpoint:bool=phase.native_cue.get("live_endpoints",[]).any(func(endpoint):return endpoint.get("actor")=="target")
    var self_owned:bool=not recipient and not target_endpoint and to==null
    parameters.merge({"native_spell":true,"actor_uuid":source,"target_uuid":target,
        "from_position":from,"to_position":from if self_owned else to,
        "from_elevation_feet":points.get("from_elevation_feet",graph.contacts.get(source,{}).get("from_elevation_feet",0)),
        "to_elevation_feet":points.get("to_elevation_feet",graph.contacts.get(source if self_owned else target,{}).get("from_elevation_feet",0)),
        "recipe":{},"cast_recipe":{"enabled":false}},true)
    if self_owned:parameters.target_uuid=source
    if from==null or ((recipient or target_endpoint) and to==null):
        parameters.status="missing";parameters.reason="native_action_position_unavailable"
    return add(group,event,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)

static func _attack_impact_actor(node:Dictionary,graph:Dictionary,at_ms:float)->Dictionary:
    # Native completion is post-order: a killing hit can retire its contact
    # before the AttackFact arrives. Use its latest disclosed recipient cut
    # at contact, excluding later cuts, nested attacks and unrelated events.
    var pending:Array=[node]
    var selected:Dictionary={}
    var occurrence:int=-1
    while not pending.is_empty():
        var current:Dictionary=pending.pop_back()
        if current!=node and current.get("fact")!=null and current.fact.kind=="attack":continue
        if current.get("canceled",false):continue
        var actor:Dictionary=graph.actor_inputs.get(current.id,{}).get(node.fact.target_entity_uuid,{})
        if actor.get("last_visual_position")!=null and float(graph.times.get(current.id,INF))<=at_ms and int(current.id)>occurrence:
            occurrence=int(current.id);selected={"actor":actor,"occurrence":current.id}
        for child in current.get("children_lineages",[]):
            if graph.nodes.has(child):pending.append(graph.nodes[child])
    return selected

static func projectile(group: Dictionary,node: Dictionary,recipe: Dictionary,start: float,duration: float,source: Array,target: Array,contacts: Dictionary,cache: Dictionary,owner:Dictionary={},fact:Dictionary={},application_index:int=0) -> void:
    var common={"actor_uuid":fact.source_entity_uuid,"target_uuid":fact.target_entity_uuid,
        "from_position":source,"to_position":target,"from_elevation_feet":contacts.get(fact.source_entity_uuid,{}).get("from_elevation_feet",0),
        "to_elevation_feet":contacts.get(fact.target_entity_uuid,{}).get("from_elevation_feet",0),
        "attachment":"projectile","recipe":recipe.projectile,"scale":recipe.projectile.scale}
    if Occurrences.application(node):
        common.application_id=node.resolution_record.application_id;common.cast_lineage=str(node.resolution_record.lineage);common.application_index=application_index
    var selected:=NativeSpells.selection_for(fact,cache)
    if not selected.is_empty():
        var cast_id:String=owner.get("source_event_uuid",node.id)
        var include_cast=not group.components.any(func(row):return row.get("native_cast_id")==cast_id and row.get("native_cue",{}).get("role")=="cast")
        var index:int=application_index
        for phase in NativeSpells.phases(selected,owner,start,duration,index,include_cast):
            if not NativeSpells.miss_impact_authored(selected,fact) and phase.native_cue.role=="impact" and fact.get("attack_outcome","") in ["Miss","Crit Miss"]:continue
            var parameters:Dictionary=common.duplicate()
            parameters.merge(phase,true)
            parameters.merge({"native_spell":true,"cast_recipe":recipe.cast,"native_cast_id":cast_id},true)
            add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)
        return
    var row=_source(group,node,native_phase(recipe.projectile,"travel",cache),start,common,cache)
    row.duration_ms=duration
    var impact=common.duplicate(); impact.attachment="target_body"
    _source(group,node,native_phase(recipe.projectile,"impact",cache),start+duration,impact,cache)

static func native_phase(projectile_recipe: Dictionary, phase: String, cache: Dictionary) -> String:
    var asset: String=projectile_recipe.get(phase,{}).get("assetId",projectile_recipe.get("sprite",{}).get("assetId",""))
    for id in Authoring.load_data("native_effects/index.json",cache).sources:
        var record: Dictionary=Authoring.load_data("native_effects/index.json",cache).sources[id]
        if record.get("phase")==phase and asset in record.get("media_ids",[]): return id
    return "unassigned:"+asset+":"+phase

static func _native_interceptions(group:Dictionary,lineage:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    for node in lineage.events:
        var fact:Variant=node.get("fact")
        if fact==null or fact.get("intercepted_by_condition_uuid")==null:continue
        var id:String=fact.intercepted_by_condition_uuid
        var parent:Dictionary=graph.nodes.get(node.get("parent_lineage"),{})
        if parent.get("fact")!=null and parent.fact.get("intercepted_by_condition_uuid")==id:continue
        var condition:Dictionary={}
        for actor in graph.actor_inputs.get(node.id,{}).values():
            for candidate in actor.get("conditions",[]):
                if candidate.condition_uuid==id:condition=candidate;break
        if condition.is_empty():
            for cues in graph.condition_cues.values():
                for cue in cues:
                    if cue.condition.condition_uuid==id:condition=cue.condition;break
        var selected=NativeSpells.condition(str(condition.get("behavior_id","")),cache)
        if selected.is_empty():continue
        var target:String=fact.target_entity_uuid
        var position:Variant=graph.positions.get(target)
        if position==null:continue
        var at:float=graph.starts.get(node.id,0.0)
        # The interception lands when the attack does: a projectile's arrival,
        # not the bow release (melee impact equals its contact).
        for track in group.actor_tracks:
            if track.source_event_uuid==node.id:at=track.get("impact_ms",track.get("contact_ms",at))
        for phase in NativeSpells.contact_phases(selected):
            var parameters=phase.duplicate()
            parameters.merge({"native_spell":true,"intercepted_by_condition_uuid":id,"actor_uuid":target,"target_uuid":target,
                "from_position":position,"to_position":position,"from_elevation_feet":graph.contacts.get(target,{}).get("from_elevation_feet",0),
                "to_elevation_feet":graph.contacts.get(target,{}).get("from_elevation_feet",0),"recipe":{},"cast_recipe":{"enabled":false},
                "start_ms":at+phase.start_ms},true)
            add(group,node,"native_effect",parameters.start_ms,phase.duration_ms,phase.source,parameters)

static func compile(group: Dictionary,lineage: Dictionary,graph: Dictionary,cache: Dictionary) -> Dictionary:
    for node in lineage.events:
        for phase in ActorBirthInputs.terminal_phases(node,graph,cache):
            add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,phase)
    for observed in graph.get("observed_spell_phases",[]):
        var parameters:Dictionary=observed.parameters
        parameters.start_ms=float(graph.starts[observed.node.id])+observed.offset_ms
        if observed.get("at_commit",false):
            for commit in group.commits:
                if str(commit.get("event_uuid",""))==str(observed.node.id):parameters.start_ms=float(commit.at_ms);break
        if parameters.has("native_destination"):
            parameters.native_destination=parameters.native_destination.merged({"publication_ms":parameters.start_ms})
        add(group,observed.node,"native_effect",parameters.start_ms,parameters.duration_ms,parameters.source,parameters)
    _native_interceptions(group,lineage,graph,cache)
    var sounds: Dictionary=Authoring.load_data("audio/bindings.json",cache)
    var nodes: Dictionary={}
    var blood_previous:Dictionary={}
    for node in lineage.events: nodes[node.id]=node
    for track in group.actor_tracks:
        for layer in track.get("effect_layers",[]):
            var source:String=track.get("cast_source","")
            if source.is_empty():source="catalog/attack_recipes.json:/"+str(nodes[track.source_event_uuid].fact.behavior_id)+"/attackVfx/"+layer.slot
            add(group,nodes[track.source_event_uuid],"sprite_layer",track.start_ms,track.duration_ms,
                source,
                {"actor_uuid":track.actor_uuid,"body_track_id":track.trace_track_id,"layer":layer,"clip":track.clip,"rig":track.rig,"source_track":track,"sample_hz":Authoring.clip(track.presentation_actor,track.clip,cache).fps})
        var track_node: Dictionary=nodes[track.source_event_uuid]
        if track.has("weapon_trail"):
            var trail: Dictionary=track.weapon_trail
            var contact_seconds=(track.contact_ms-track.start_ms)/1000.0
            var rate:float=float(trail.contact_seconds)/maxf(.001,contact_seconds)
            var slash=_source(group,track_node,str(trail.source_id),track.start_ms,
                {"actor_uuid":track.actor_uuid,"attachment":"ground","scale":track.presentation_actor.appearance.visual_scale,
                "weapon_pose":trail.pose,"weapon_contact_seconds":contact_seconds*track.source_end_seconds/(track.duration_ms/1000.0),"native_age_rate":rate,"palette":trail.palette,"source_track":track,"assignment_source":str(trail.source)+"::trail_source",
                "timing_source":str(trail.source)+"::trail_contact_seconds"},cache)
            slash.duration_ms=float(trail.end_seconds)/rate*1000.0
            if track_node.fact.attack_outcome in ["Hit","Crit"] and not str(trail.impact_source_id).is_empty():
                _source(group,track_node,str(trail.impact_source_id),track.impact_ms,
                    {"actor_uuid":track.actor_uuid,"target_uuid":track.target_uuid,"attachment":"target_body","scale":track.presentation_actor.appearance.visual_scale,"palette":trail.palette,
                    "assignment_source":str(trail.source)+"::trail_impact_source"},cache)
        if track.get("motion",false) and track_node.fact.kind=="step" and not track_node.get("canceled",false) and track_node.fact.get("committed",false):
            for phase in MovementMedia.phases(track,group.actor_tracks,graph.actor_inputs.get(track_node.id,{}).get(track.actor_uuid,{}),cache):
                add(group,track_node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,phase)
        if track.get("motion",false) and not track.get("spatial_only",false) and track_node.fact.kind=="step":
            _movement_audio(group,track_node,track,sounds,cache)
    var fact_media_owners:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("observed_fact_owners",{})
    var action_bindings:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache)
    for node in lineage.events:
        if node.canceled:continue
        _passive_results(group,node,graph,action_bindings)
        if node.get("fact")==null:continue
        _condition_responses(group,node,graph,cache)
        if fact_media_owners.has(str(node.fact.kind)):_fact_media(group,node,graph,cache)
        var fact: Dictionary=Occurrences.spell(node,graph) if node.fact.kind=="spell" else node.fact
        var start: float=graph.starts.get(node.id,0)
        var recipe: Dictionary=graph.recipes.get(node.id,{})
        var contact=start
        if fact.kind=="attack" and not recipe.get("sourceTiming",{}).is_empty():
            contact=float(graph.get("committed_at",{}).get(node.id,start))
        var release_time=start
        var body_end=start
        var audio_track:Dictionary={}
        var audio_markers={"event.start":start}
        for track in group.actor_tracks:
            if track.source_event_uuid==node.id:
                release_time=track.get("contact_ms",start)
                contact=track.get("impact_ms",release_time)
                body_end=track.start_ms+track.duration_ms
                audio_track=track
                audio_markers["body.end"]=body_end
                if track.has("contact_ms"):audio_markers["body.contact"]=track.contact_ms
                if track.has("commit_ms"):audio_markers["body.commit"]=track.commit_ms
                if track.has("impact_ms"):audio_markers["body.impact"]=track.impact_ms
                elif track.has("contact_ms"):audio_markers["body.impact"]=track.contact_ms
                break
        if action_bindings.has(fact.get("behavior_id","")) and action_bindings[fact.behavior_id].has("effect_cues"):
            native_action(group,node,action_bindings[fact.behavior_id],recipe,audio_track,audio_markers,graph,cache,lineage.events)
        if fact.kind=="attack":
            _movement_reaction_feedback(group,node,graph,cache)
            var attributed:Dictionary=_weapon_result_binding(node,graph,cache,action_bindings)
            if not attributed.is_empty():native_action(group,node,attributed,recipe,audio_track,audio_markers,graph,cache,lineage.events)
            var impact_binding:Dictionary=NativeItems.impact_binding(fact,cache)
            if not impact_binding.is_empty():
                var packet={"operation_sequence":group.operation_sequence,"occurrence":str(node.id),"lineage":str(node.lineage_id),
                    "source_item_uuid":fact.source_item_uuid,"source_item_id":fact.source_item_id,"weapon_slot":fact.weapon_slot,
                    "source_entity_uuid":fact.source_entity_uuid,"target_entity_uuid":fact.target_entity_uuid,"attack_outcome":fact.attack_outcome}
                var cut:Dictionary=_attack_impact_actor(node,graph,contact)
                var receipt:Dictionary=ImpactPlacement.prepare(cut.get("actor",{}),group.actor_tracks,contact,graph.contacts.get(fact.target_entity_uuid,{}),cache)
                receipt.source_occurrence=cut.get("occurrence","")
                var source_actor:Dictionary=graph.actor_inputs.get(node.id,{}).get(fact.source_entity_uuid,{})
                var points={"from_position":audio_track.get("from_position",source_actor.get("last_visual_position")),
                    "from_elevation_feet":audio_track.get("from_elevation_feet",0),
                    "to_position":receipt.get("position"),"to_elevation_feet":receipt.get("elevation_feet",0)}
                for phase in NativeActions.phases(impact_binding,fact,recipe,audio_track,audio_markers,cache):
                    phase.start_ms+=float(phase.native_cue.get("delay_seconds",0.0))*1000.0
                    var observed={"values":{"weapon_impact":packet},"gaps":[],"evidence":packet}
                    var impact:Dictionary=_native_action_component(group,node,node,phase,observed,graph,"",points)
                    impact.weapon_impact=packet;impact.native_weapon_impact=true
                    impact.impact_actor_uuid=fact.target_entity_uuid;impact.impact_at_ms=contact
                    impact.impact=receipt
                    if impact.impact.status=="missing":impact.status="missing";impact.reason=impact.impact.reason
                    if fact.get("target_kind","creature")!="creature":
                        impact.status="missing";impact.reason="weapon_impact_object_contact_not_bound"
            var outcome: String={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}.get(fact.attack_outcome,"")
            var feedback: Variant=recipe.get("attackFeedback",{}).get(outcome) if recipe.get("attackFeedback")!=null else null
            if feedback!=null:_feedback(group,node,feedback,contact,fact.target_entity_uuid,"catalog/attack_recipes.json:/"+str(fact.behavior_id)+"/attackFeedback/"+outcome,cache)
            if sounds.weapons.has(str(fact.get("source_item_id",""))):
                _bound_audio(group,node,sounds.weapons,str(fact.source_item_id),audio_markers,fact.source_entity_uuid,"weapons",cache,audio_track)
            else:
                _bound_audio(group,node,sounds.get("attack_sources",{}),str(fact.attack_source_kind),audio_markers,fact.source_entity_uuid,"attack_sources",cache,audio_track)
        elif fact.kind=="mechanism_activation":
            world_activation(group,node,graph,cache)
        elif fact.kind=="portal_transfer":
            world_portal_exit(group,node,graph,cache)
        elif fact.kind=="spell":
            var caster:Dictionary=graph.get("casts",{}).get(SpellDelivery.cast_key(node,graph),{})
            if caster.get("source_event_uuid",node.id)==node.id:
                _bound_audio(group,node,sounds.get("spells",{}),fact.behavior_id,audio_markers,fact.source_entity_uuid,"spells",cache,audio_track)
        elif fact.kind=="equipment":
            _bound_audio(group,node,sounds.get("equipment",{}),"change",audio_markers,fact.source_entity_uuid,"equipment",cache,audio_track)
        elif fact.kind=="heal" and fact.get("actual_healing",0)>0:
            var context=Authoring.load_data("catalog/healing_context.json",cache)
            if context.get("feedbackEnabled",false):_feedback(group,node,{"text":str(fact.actual_healing)+" "+context.feedbackLabel,"color":context.feedbackColor,"durationMs":context.feedbackDurationMs},start,fact.target_entity_uuid,"catalog/healing_context.json",cache)
        elif fact.kind=="life":
            var context=Authoring.load_data("catalog/life_state_context.json",cache)
            var feedback: Dictionary=context.get("revived" if fact.new_state=="alive" else fact.new_state,{})
            if feedback.get("enabled",false):_feedback(group,node,feedback,start,fact.entity_uuid,"catalog/life_state_context.json:/"+fact.new_state,cache)
            if fact.new_state in ["dying","dead"] and fact.get("previous_state")=="alive":
                _bound_audio(group,node,sounds.life,"fall",audio_markers,fact.entity_uuid,"life",cache,audio_track)
            elif fact.new_state=="alive" and fact.get("previous_state") in ["dying","stable"]:
                _bound_audio(group,node,sounds.life,"rise",audio_markers,fact.entity_uuid,"life",cache,audio_track)
        elif fact.kind=="death_save":
            var key="criticalSuccess" if fact.natural_roll==20 else ("criticalFailure" if fact.natural_roll==1 else ("success" if fact.succeeded else "failure"))
            var feedback: Dictionary=Authoring.load_data("catalog/death_save_context.json",cache).get(key,{})
            if feedback.get("enabled",false):_feedback(group,node,feedback,start,fact.entity_uuid,"catalog/death_save_context.json:/"+key,cache)
        elif fact.kind=="object_damage" and fact.applied_damage>0 and fact.resulting_hp>0:
            var object: Dictionary=graph.object_inputs.get(node.id,{})
            var binding: Dictionary=sounds.objects.get(object.get("item",{}).get("item_id"),{})
            if binding.has("impact"):
                _bound_audio(group,node,binding,"impact",audio_markers,"","objects/"+object.item.item_id,cache)
                group.components.back().attachment="ground"
                group.components.back().position=object.placement.position
                group.components.back().elevation_feet=object.placement.base_height_steps*5.0
        elif fact.kind=="object_destroyed":
            var binding: Dictionary=sounds.objects.get(fact.item_id,{})
            if binding.has("destroyed"):
                _bound_audio(group,node,binding,"destroyed",audio_markers,"","objects/"+fact.item_id,cache)
                group.components.back().position=fact.placement.position
                group.components.back().elevation_feet=fact.placement.base_height_steps*5.0
        if fact.kind in ["action","shove"]:
            var feedback:Dictionary=Authoring.action_feedback(recipe,fact)
            if not feedback.is_empty() and (not str(feedback.field).begins_with("reactionFeedback/") or node.get("phase")=="completion"):
                var feedback_at:float=maxf(contact,float(graph.times.get(node.id,contact))) if str(feedback.field).begins_with("reactionFeedback/") else contact
                _feedback(group,node,feedback.value,feedback_at,fact.source_entity_uuid,Authoring.recipe_source(recipe,feedback.field,cache),cache)
            if not recipe.get("effectAudioCue","").is_empty():
                _audio(group,node,recipe.effectAudioCue,contact,fact.source_entity_uuid,cache)
                group.components.back().assignment_source=Authoring.recipe_source(recipe,"effectAudioCue",cache)
                for anchor_index in recipe.get("anchors",[]).size():
                    if recipe.anchors[anchor_index].name=="effect":
                        group.components.back().timing_source=Authoring.recipe_source(recipe,"anchors/"+str(anchor_index)+"/frame",cache)
                        break
                group.components.back().timing_selector="recipe.effect_anchor"
                if not audio_track.is_empty():
                    group.components.back().body_track_id=audio_track.trace_track_id
                    group.components.back().source_track=audio_track
            if recipe.get("effectAudioCue","").is_empty():
                _bound_audio(group,node,sounds.actions,fact.behavior_id,audio_markers,fact.source_entity_uuid,"actions",cache,audio_track)
            _action_media(group,node,recipe,str(fact.source_entity_uuid),start,graph,cache)
        elif fact.kind=="damage" and fact.get("stage")=="applied" and fact.get("applied_damage",0)>0:
            _condition_contact(group,node,graph,cache)
            var timing:Dictionary=graph.get("damage_timings",{}).get(node.id,{})
            _damage_feedback(group,node,graph,start,cache)
            _bound_audio(group,node,sounds.damage_types,str(fact.get("damage_type")),{"damage.hp":timing.get("hp",start),"event.start":start},fact.target_entity_uuid,"damage_types",cache)
            var release: Dictionary=fact.get("body_release",{}) if fact.get("body_release")!=null else {}
            # Damage alone never authorizes blood or a receiving tile. Region
            # artwork uses the same server ellipse and allowed-cell list as the
            # persistent after-values; air-only releases retain native spray.
            var release_binding:Dictionary=Blood.binding(release,cache)
            if not release_binding.is_empty():
                var residue_id:String=release_binding.residue_id
                var blood_start:float=graph.get("damage_timings",{}).get(node.id,{}).get("hp",start)
                if not release.get("regions",[]).is_empty() and release.get("pattern")!=null:
                    var blood_asset=Blood.asset(cache,residue_id)
                    if blood_asset.is_empty():
                        return {"ok":false,"error":{"kind":"authoring","message":"Cannot load selected asset metadata: "+str(release_binding.asset_id),"retryable":false}}
                    var revealed=Blood.reveals(group,node,graph.get("initial_tiles",{}),blood_previous,residue_id)
                    var blood_contact:Dictionary=graph.impact_contacts.get(node.id,{})
                    var source_height:Variant=blood_contact.get("from_elevation_feet")
                    if source_height!=null:source_height=float(source_height)/5.0
                    else:
                        for region in release.regions:
                            for point in region.positions:
                                if Blood.key(point)==Blood.key(release.position):source_height=region.elevation_steps
                    add(group,node,"residue_deposit",blood_start,Blood.duration(release,blood_asset),
                        release_binding.source,
                        {"residue_id":residue_id,"actor_uuid":fact.target_entity_uuid,"attachment":"ground","position":release.position,"asset_metadata":blood_asset,
                        "elevation_steps":source_height,"flight_enabled":source_height!=null,
                        "body_release":release.duplicate(true),"reveals":revealed,"residue_deposition":true,
                        "authority_source":"DamageResultFact.body_release.regions + WorldTileState.residues"})
                elif not str(release_binding.get("air_source_catalog","")).is_empty():
                    var selection: Dictionary=Authoring.load_data(release_binding.air_source_catalog,cache)
                    var source_id: String=selection.damage_types.get(str(release.get("primary_damage_type")),selection.default)
                    var actors: Dictionary=graph.actor_inputs.get(node.id,{})
                    var impact=ImpactPlacement.prepare(actors.get(fact.target_entity_uuid,{}),group.actor_tracks,blood_start,graph.impact_contacts.get(node.id,{}),cache)
                    var common={"actor_uuid":fact.target_entity_uuid,"source_actor_uuid":fact.get("source_entity_uuid"),"attachment":"impact","impact":impact,"scale":selection.scale,
                        "body_release":release.duplicate(true),"residue_deposition":false,
                        "direction_from":actors.get(fact.get("source_entity_uuid"),{}).get("last_visual_position"),"direction_to":actors.get(fact.target_entity_uuid,{}).get("last_visual_position")}
                    var spray=_source(group,node,source_id,blood_start,common,cache)
                    if impact.status=="missing":spray.status="missing";spray.reason=impact.reason
                else:
                    add(group,node,"residue_deposit",blood_start,0.,release_binding.source,
                        {"actor_uuid":fact.target_entity_uuid,"residue_id":residue_id,"body_release":release.duplicate(true),
                        "asset_metadata":{},"reveals":[],"status":"missing","reason":"actual_receiving_regions_not_disclosed",
                        "authority_source":"DamageResultFact.body_release.regions"})
        elif fact.kind=="actor_change":
            if group.actor_tracks.any(func(track):return track.source_event_uuid==node.id and track.get("equipment_change",false)):
                _bound_audio(group,node,sounds.get("equipment",{}),"change",audio_markers,group.actor_tracks.filter(func(track):return track.source_event_uuid==node.id)[0].actor_uuid,"equipment",cache,audio_track)
            for cue in graph.condition_cues.get(node.id,[]):
                var condition:Dictionary=cue.condition
                var binding:Dictionary=sounds.get("conditions",{}).get(Authoring.Catalog.condition_key(condition),{})
                _bound_audio(group,node,binding,cue.phase,audio_markers,cue.actor_uuid,"conditions/"+Authoring.Catalog.condition_key(condition),cache,audio_track)
                var feedback:Dictionary=cue.recipe.get(cue.phase,{})
                if not feedback.get("feedbackEnabled",false):continue
                var style=Authoring.load_data("catalog/badge_style.json",cache)
                var prefix:String=feedback.get("feedbackPrefix","−" if cue.phase=="removal" else "+")
                var text:String=prefix+str(condition.get("name",cue.recipe.get("label",condition.behavior_id)))
                var pointer:String=Authoring.Catalog.condition_key(condition)+"/"+cue.phase+"/feedbackEnabled"
                _feedback(group,node,{"text":text,"color":feedback.feedbackColor,"durationMs":feedback.get("feedbackDurationMs",style.durationMs)},start,cue.actor_uuid,Authoring.Catalog.source_pointer("catalog/condition_recipes.json",pointer,cache),cache)
    var projectiles={}
    for component in group.components:
        var actor: Dictionary=graph.actor_inputs.get(component.source_event_uuid,{}).get(component.get("actor_uuid"),{})
        component.presentation_actor={}
        for field in ["uuid","creature_content_ref","appearance","visual_loadout","last_visual_position","life_state","present","spatial_disposition","remains_disposition"]:
            if actor.has(field):component.presentation_actor[field]=actor[field]
        if not component.has("source_track"):
            for track in group.actor_tracks:
                if track.actor_uuid==component.get("actor_uuid") and track.start_ms<=component.start_ms and (track.start_ms+track.duration_ms>component.start_ms or track.get("holding_pose",false)):
                    if not component.has("source_track") or component.source_track.priority<=track.priority:component.source_track=track
        if component.get("attachment")=="projectile" and component.has("application_id") and (not component.get("native_spell",false) or component.native_cue.role=="flight"):
            var key=str(component.cast_lineage)+":"+str(component.target_uuid)
            if not projectiles.has(key):projectiles[key]=[]
            projectiles[key].append(component)
    for family in projectiles.values():
        family.sort_custom(func(a,b):return a.application_index<b.application_index)
        for i in family.size():family[i].same_target_index=i;family[i].same_target_count=family.size()
    return {"ok":true}


## Source uses retain their own authored socket/window. Only a registered
## two-half capture can collapse its matching rear/front aliases; unrelated
## uses and the two actual Font hands retain independent draw identities.
static func _action_media(group:Dictionary,node:Dictionary,recipe:Dictionary,actor:String,start:float,graph:Dictionary,cache:Dictionary,witness:Dictionary={})->void:
    var sources:Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    var legacy_seen:Dictionary={};var captures:Dictionary={}
    for index in recipe.get("media",[]).size():
        var media:Dictionary=recipe.media[index]
        if media.get("requiredSaveSuccess",false) and witness.get("succeeded")!=true:continue
        var condition_evidence:Dictionary={}
        if not str(media.get("requireAppliedConditionId","")).is_empty():
            var applied:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):return row.kind=="condition_application" \
                and row.target_uuid==actor and row.condition.get("behavior_id")==media.requireAppliedConditionId \
                and ApplicationResults._cast_owns_result(node,row.node,graph))
            if applied.size()!=1:continue
            condition_evidence={"condition_uuid":applied[0].condition.condition_uuid,"application_occurrence":str(applied[0].node.id)}
        var explicit:String=str(media.get("source_id",""))
        var candidates:Array=[explicit] if not explicit.is_empty() else sources.keys().filter(func(id):return media.get("assetId") in sources[id].get("media_ids",[]))
        for source_id in candidates:
            var record:Dictionary=sources.get(source_id,{})
            if not explicit.is_empty() and node.get("phase")!="completion":continue
            if explicit.is_empty():
                if legacy_seen.has(source_id):continue
                legacy_seen[source_id]=true
            var socket:String=str(media.get("poseSocket",""))
            var paired:bool=not explicit.is_empty() and media.get("id")==media.get("assetId") and ["back","front"].all(func(half):return half in record.get("capture_halves",[]))
            var capture:Array=[source_id,socket,media.get("attachment",""),media.get("startOffsetMs",0.0),media.get("durationMs",record.get("duration",0.0)*1000.0),
                media.get("alpha",1.0),media.get("scale",1.0),media.get("loop",false),media.get("fadeInMs",0.0),media.get("fadeOutMs",0.0),media.get("fadeCurve","linear"),media.get("timeMap",[]),condition_evidence]
            if paired and captures.has(capture):continue
            if paired:captures[capture]=true
            var component:Dictionary=_source(group,node,str(source_id),start+float(media.get("startOffsetMs",0.0)),
                {"actor_uuid":actor,"attachment":socket if not socket.is_empty() else media.get("attachment","ground"),
                "scale":media.get("scale",1.0),"alpha":media.get("alpha",1.0)},cache)
            component.duration_ms=float(media.get("durationMs",component.duration_ms));component.loop=media.get("loop",false)
            component.source_duration_ms=float(record.get("duration",0.0))*1000.0
            component.fade_in_ms=float(media.get("fadeInMs",0.0));component.fade_out_ms=float(media.get("fadeOutMs",0.0))
            component.fade_curve=media.get("fadeCurve","linear")
            component.authored_use_id=str(media.get("id",index))
            if not explicit.is_empty():
                component.assignment_source=Authoring.recipe_source(recipe,"media/"+str(index),cache)
                component.source=component.assignment_source
            if not socket.is_empty():component.requires_pose_socket=true
            if not condition_evidence.is_empty():component.observed_condition=condition_evidence
            if not witness.is_empty():component.observed_fact=witness.duplicate(true)
            var time_map:Array=media.get("timeMap",[])
            if time_map.size()==2:
                var hz:float=float(record.sample_hz)
                component.source_time_window={"begin_seconds":float(time_map[0].sourceFrame)/hz,
                    "end_seconds":float(time_map[1].sourceFrame)/hz,"duration_ms":float(time_map[1].elapsedMs)}

## The derived owner index names authored resources only. Actual public fact
## kind/stage/witness/recipient values own finite admission and its one clock.
static func _fact_media(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    if node.get("phase")!="completion":return
    var fact:Dictionary=node.fact
    var metadata:Dictionary=Authoring.load_data("native_effects/index.json",cache)
    var recipes:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache)
    for owner in metadata.get("observed_fact_owners",{}).get(str(fact.kind),[]):
        var recipe:Dictionary=recipes.get(owner,{})
        var selector:Dictionary=recipe.get("observedFact",{})
        if selector.has("stage") and fact.get("stage")!=selector.stage:continue
        var witness:Variant=fact.get(str(selector.get("witness","")))
        if witness==null or not selector.get("when",{}).keys().all(func(key):return witness.get(key)==selector.when[key]):continue
        var actor:Variant=fact.get(str(selector.get("actor_field","")))
        if actor==null:continue
        var selected:Dictionary=recipe.duplicate(false)
        selected._legacy_source="catalog/body_action_recipes.json:/"+str(owner)
        var evidence:Dictionary={"authored_owner":owner,"event_uuid":str(node.id),"lineage_uuid":str(node.lineage_id),
            "kind":fact.kind,"witness_field":selector.witness,"witness":witness.duplicate(true),"actor_uuid":str(actor),
            "selector_source":Authoring.recipe_source(selected,"observedFact",cache),"succeeded":witness.get("succeeded")}
        _action_media(group,node,selected,str(actor),float(graph.get("committed_at",{}).get(str(node.id),graph.times.get(node.id,graph.starts.get(node.id,0.0)))),graph,cache,evidence)

## Actual native response facts select one exact immutable condition member.
## These finite sources share ordinary phase, geometry and teardown handling.
static func _condition_responses(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    if node.get("fact")==null or node.fact.get("kind") not in ["damage","heal","temporary_hit_points","actor_change"]:return
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    var actors:Dictionary=graph.actor_inputs.get(node.id,{})
    var seen:Dictionary={}
    var membership_counts:Dictionary={}
    for actor in actors.values():
        for member in actor.get("conditions",[]):
            var key:String=str(member.get("condition_uuid",""))
            membership_counts[key]=int(membership_counts.get(key,0))+1
    for actor in actors.values():
        for member in actor.get("conditions",[]):
            if int(membership_counts.get(str(member.get("condition_uuid","")),0))!=1:continue
            var recipe:Dictionary=recipes.get(str(member.get("behavior_id","")),{})
            for cue in recipe.get("nativeResponses",[]):
                var projected:Dictionary=ConditionResponses.project(node,actor,member,cue.get("condition_response",{}),graph)
                if projected.is_empty():continue
                var identity:Array=[str(member.condition_uuid),int(cue.source_index)]
                if seen.has(identity):continue
                seen[identity]=true
                _condition_response(group,node,projected,cue,graph,str(member.condition_uuid),str(member.behavior_id),cache)
    var spatial:Dictionary=graph.get("spatial_contact_inputs",{}).get(str(node.id),{})
    if spatial.is_empty():return
    var behavior:String=str(spatial.effect.get("content_ref",{}).get("content_id",""))
    for cue in recipes.get(behavior,{}).get("nativeResponses",[]):
        var projected:Dictionary=ConditionResponses.project_spatial(node,spatial,cue.get("condition_response",{}),graph)
        if projected.is_empty():continue
        _condition_response(group,node,projected,cue,graph,str(spatial.identity),behavior,cache)

## One finite source compiler for either actual owner kind. The source UUID
## remains separate from the result occurrence and the receiving actor.
static func _condition_response(group:Dictionary,node:Dictionary,projected:Dictionary,cue:Dictionary,graph:Dictionary,identity:String,behavior:String,cache:Dictionary)->void:
    var receiving:Dictionary=graph.condition_response_inputs.get(node.id,{}).get(projected.actor,{})
    if receiving.is_empty():return
    var at:float=float(graph.times.get(node.id,graph.starts.get(node.id,0.0)))
    for commit in group.commits:
        if str(commit.get("event_uuid",""))==str(node.id):at=float(commit.at_ms);break
    var source:String=str(cue.get("source","catalog/condition_recipes.json:/"+behavior+"/nativeResponses/"+str(cue.source_index)))
    var selected:Dictionary={"id":behavior,"source":source,"staging":{"decorative_light_multiplier":float(cue.get("light_multiplier",1.0))},"source_bounds":{},"palette":{}}
    var phase:Dictionary=NativeSpells._phase(selected,cue,{"prepare":at},at,0.0,0)
    phase.source=source;phase.source_id=behavior+".response."+str(cue.source_index)
    phase.erase("spell_id")
    phase.merge({"native_spell":true,"cast_recipe":{"enabled":false},"actor_uuid":projected.actor,"target_uuid":projected.actor,
        "condition_response":projected.evidence,
        "from_position":receiving.position,"to_position":receiving.position,
        "from_elevation_feet":float(receiving.elevation_steps)*5.0,"to_elevation_feet":float(receiving.elevation_steps)*5.0,
        "ground_target":false,"native_constructor_evidence":projected.evidence},true)
    if projected.evidence.get("owner_kind")=="spatial_effect":phase.spatial_effect_uuid=identity
    else:phase.condition_uuid=identity
    if projected.has("native_inputs"):
        phase.native_inputs=projected.native_inputs.duplicate(true)
        if phase.native_inputs.has("weapon_impact"):phase.native_inputs.weapon_impact.operation_sequence=group.operation_sequence
    if projected.has("event_state"):
        phase.native_event_state=projected.event_state
        phase.native_event_binding=projected.event_binding
    if projected.has("attack"):
        var actor:Dictionary=graph.actor_inputs.get(node.id,{}).get(str(projected.recipient),{})
        var receipt:Dictionary=ImpactPlacement.prepare(actor,group.actor_tracks,at,graph.contacts.get(projected.recipient,{}),cache)
        var source_support:Dictionary=graph.condition_response_inputs.get(node.id,{}).get(projected.owner,{})
        if source_support.is_empty():return
        phase.from_position=source_support.position;phase.from_elevation_feet=float(source_support.elevation_steps)*5.0
        phase.impact=receipt;phase.native_weapon_impact=true
        phase.impact_actor_uuid=projected.recipient;phase.impact_at_ms=at
        if receipt.status=="missing":phase.status="missing";phase.reason=receipt.reason
    var constructor:Dictionary=cue.get("constructor_input",{})
    if not constructor.is_empty():
        var observed:Dictionary=ConditionResponses.source_result(node,identity,behavior,projected,constructor)
        if observed.is_empty():return
        phase.native_inputs=observed.inputs
        phase.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":str(constructor.get("input_field","")),"values":observed.values}]
        phase.native_constructor_evidence=observed.evidence
    add(group,node,"native_effect",phase.start_ms,phase.duration_ms,source,phase)

static func _condition_contact(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    var fact:Dictionary=node.fact
    if fact.get("source_condition_uuid")==null:return
    # Retaliation belongs to the actual condition holder, which can differ
    # from the damaged recipient and the damage's attributed original caster.
    var members:Array=[]
    var holders:Array=[]
    var member_cut:Dictionary=node
    while not member_cut.is_empty():
        for actor in graph.actor_inputs.get(member_cut.id,{}).values():
            for member in actor.get("conditions",[]):
                if member.get("condition_uuid")!=fact.source_condition_uuid:continue
                members.append(member);holders.append(str(actor.uuid))
        if not members.is_empty():break
        # A lethal tick can retire its member before the applied DamageFact.
        # Its exact native ancestor retains the actual pre-emission membership;
        # never search another operation or unrelated actor/condition by name.
        var parent:Variant=member_cut.get("parent_lineage")
        member_cut={} if parent==null else graph.nodes.get(str(parent),{})
    var spatial:Dictionary=graph.get("spatial_contact_inputs",{}).get(str(node.id),{})
    if members.size()+int(not spatial.is_empty())!=1:return
    var selected:Dictionary=NativePersistent.spatial_selection(spatial.effect,cache) if not spatial.is_empty() \
        else NativeSpells.condition(str(members[0].behavior_id),cache)
    if selected.is_empty():return
    for cue in selected.get("staging",{}).get("cues",[]):
        var descriptor:Dictionary=cue.get("constructor_input",{})
        var projected:Dictionary={}
        if not spatial.is_empty():
            if descriptor.get("projection")!="spatial_contact":continue
            projected=ApplicationResults.spatial_contact(node,str(spatial.identity),spatial.effect,descriptor,graph)
        else:
            if descriptor.get("projection")!="condition_contact":continue
            projected=ApplicationResults.condition_contact(node,members[0],descriptor,graph)
        if projected.is_empty():continue
        if not spatial.is_empty():
            projected.evidence.spatial_origin_cut=spatial.get("origin_cut","")
            if spatial.has("removal_occurrence"):projected.evidence.spatial_removal_occurrence=spatial.removal_occurrence
        if spatial.is_empty():
            projected.evidence.condition_holder_uuid=holders[0]
            projected.evidence.membership_cut_occurrence=str(member_cut.id)
        var at:float=float(graph.starts.get(node.id,0.0))
        var phase:Dictionary=NativeSpells._phase(selected,cue,{"prepare":at},at,0.0,0)
        # These finite contacts are optically recipient-owned. The constructor
        # retains the original caster; an undisclosed caster position is never
        # required to place a packet that consumes only the recipient surface.
        var position:Variant=graph.positions.get(fact.target_entity_uuid)
        if position==null:continue
        var elevation:float=float(graph.contacts.get(fact.target_entity_uuid,{}).get("from_elevation_feet",0.0))
        phase.merge({"native_spell":true,"cast_recipe":{"enabled":false},"actor_uuid":str(fact.target_entity_uuid),"target_uuid":str(fact.target_entity_uuid),
            "from_position":position,"to_position":position,"from_elevation_feet":elevation,"to_elevation_feet":elevation,
            "ground_target":false,"native_inputs":projected.inputs,
            "native_constructor_inputs":[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}],
            "native_constructor_evidence":projected.evidence},true)
        add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,phase)

static func _movement_audio(group:Dictionary,node:Dictionary,track:Dictionary,sounds:Dictionary,cache:Dictionary)->void:
    if node.fact.get("movement_mode")!="walking" and not (node.fact.get("movement_mode")==null and track.trajectory=="connector_transfer"):return
    var document:String=sounds.movement_contacts
    var contacts:Dictionary=Authoring.load_data(document,cache).rigs.get(track.rig,{}).get(track.clip,{}).get(track.trajectory,{})
    var source=document+":/rigs/"+track.rig+"/"+track.clip+"/"+track.trajectory
    if contacts.get("markers",[]).is_empty():
        var key="path" if track.trajectory=="path" else "landing"
        var row=_audio(group,node,sounds.movement[key].cue,track.start_ms,track.actor_uuid,cache)
        row.status="missing";row.reason="source_contact_markers_not_authored";row.duration_ms=0.0
        row.start_ms=track.start_ms;row.contact_ms=track.start_ms
        row.assignment_source="audio/bindings.json:/movement/"+key;row.timing_source=source
        row.body_track_id=track.trace_track_id;row.source_track=track
        return
    var clip=Authoring.clip(track.presentation_actor,track.clip,cache)
    for marker in contacts.markers:
        var invalid=AudioCues.contact_marker_error(marker,clip,track.get("loop",false))
        if not sounds.movement.has(marker.get("binding","")) or sounds.movement.get(marker.get("binding",""),{}).get("timing")!="body.source_frame":invalid="contact_binding_not_authored"
        if not invalid.is_empty():
            var gap=_audio(group,node,sounds.movement.get(marker.get("binding",""),{}).get("cue",""),track.start_ms,track.actor_uuid,cache)
            gap.status="missing";gap.reason=invalid;gap.duration_ms=0.0;gap.start_ms=track.start_ms;gap.contact_ms=track.start_ms
            gap.assignment_source="audio/bindings.json:/movement/"+str(marker.get("binding",""));gap.timing_selector="body.source_frame"
            gap.timing_source=source+"/markers/"+str(contacts.markers.find(marker));gap.body_track_id=track.trace_track_id;gap.source_track=track
            continue
        var times=AudioCues.source_frame_times(track,float(marker.frame),float(clip.fps),int(clip.frames),marker.direction)
        for at in times:
            var endpoint_error:String=AudioCues.motion_endpoint_error(marker,track,float(at))
            var row=_bound_audio(group,node,sounds.movement,marker.binding,{"body.source_frame":at},track.actor_uuid,"movement",cache,track)
            if not endpoint_error.is_empty():
                row.status="missing";row.reason=endpoint_error;row.duration_ms=0.0
            if marker.has("motion_endpoint"):row.motion_endpoint=marker.motion_endpoint
            row.timing_source=source+"/markers/"+str(contacts.markers.find(marker))
            row.source_frame=marker.frame;row.source_frame_boundary=marker.get("boundary","frame_start")
            row.contact_id=marker.id;row.contact_direction=marker.direction;row.contact_review=contacts.get("review_status","unreviewed")

static func _bound_audio(group:Dictionary,node:Dictionary,bindings:Dictionary,key:String,markers:Dictionary,actor_id:String,section:String,cache:Dictionary,track:Dictionary={})->Dictionary:
    if not bindings.has(key):return {}
    var binding:Dictionary=bindings[key]
    var available=markers.has(binding.timing)
    var row=_audio(group,node,binding.cue,float(markers.get(binding.timing,markers.get("event.start",0.0))),actor_id,cache,
        {"assignment_enabled":binding.get("enabled",true),"assignment_reason":binding.get("reason","audio_assignment_disabled")})
    row.assignment_source="audio/bindings.json:/"+section+"/"+key
    row.timing_source=row.assignment_source+"/timing";row.timing_selector=binding.timing
    row.timing_review=binding.get("review_status","unreviewed")
    if not track.is_empty():row.body_track_id=track.trace_track_id;row.source_track=track
    if binding.get("enabled",true) and not available:row.status="missing";row.reason="authored_audio_timing_unavailable";row.duration_ms=0.0
    return row

static func _audio(group:Dictionary,node:Dictionary,cue:String,start:float,actor_id:String,cache:Dictionary,assignment:Dictionary={})->Dictionary:
    var parameters={"actor_uuid":actor_id,"parent_id":str(group.operation_sequence)+":"+node.id,"source_event_uuid":node.id,"source_lineage":node.lineage_id}
    parameters.merge(assignment,true)
    var row=AudioCues.resolve(cue,str(group.operation_sequence)+":"+node.id,group.components.size(),start,-1,
        parameters,cache)
    group.components.append(row)
    return row


## Parent recipe options decorate this exact positive applied result. Source
## identity follows the actual ancestor chain, never a name/cursor heuristic.
static func _damage_feedback(group:Dictionary,node:Dictionary,graph:Dictionary,start:float,cache:Dictionary)->void:
    var fact:Dictionary=node.fact
    var context:Dictionary=Authoring.load_data("catalog/damage_context.json",cache)
    var parent:Dictionary=graph.nodes.get(node.get("parent_lineage"),{})
    var damage_recipe:Dictionary={};var owner_recipe:Dictionary={};var owner_occurrence:String=""
    var spell_behavior:String=""
    while not parent.is_empty():
        if spell_behavior.is_empty() and parent.get("fact")!=null and parent.fact.kind=="spell":spell_behavior=Occurrences.spell(parent,graph).get("behavior_id","")
        if graph.recipes.has(parent.id) and graph.recipes[parent.id].get("damage") is Dictionary:
            owner_recipe=graph.recipes[parent.id];damage_recipe=owner_recipe.damage;owner_occurrence=str(parent.id);break
        parent=graph.nodes.get(parent.get("parent_lineage"),{})
    var timing:Dictionary=graph.get("damage_timings",{}).get(node.id,{})
    var flash:Dictionary=damage_recipe.get("hitFlash",{})
    if flash.get("enabled",context.get("flashEnabled",false)):
        var colors:Array=flash.get("palette",{}).get("colors",[])
        if colors.is_empty():
            if flash.has("color"):colors=[flash.color]
            else:
                var palette:Dictionary=context.palette.byDamageType.get(fact.get("damage_type"),context.palette.untyped)
                colors=[palette.elementColors.secondary,palette.elementColors.primary,palette.elementColors.tertiary]
        var source:String=Authoring.recipe_source(owner_recipe,"damage/hitFlash",cache) if damage_recipe.has("hitFlash") else "catalog/damage_context.json:/flashEnabled"
        var hit:Dictionary=add(group,node,"material_flash",timing.get("flash",start),flash.get("durationMs",context.get("flashDurationMs",150)),source,
            {"actor_uuid":fact.target_entity_uuid,"material":flash,"colors":colors,"damage_type":fact.get("damage_type"),"attachment":"body",
            "feedback_policy":flash.duplicate(true),"feedback_policy_sources":_feedback_sources(owner_recipe,"hitFlash",flash,cache),"feedback_source_occurrence":owner_occurrence})
        var native_hit:Dictionary=NativeSpells.hit(spell_behavior,cache)
        if not native_hit.is_empty():
            hit.native_hit=native_hit
            var envelope:Dictionary=Authoring.load_data("sandbox/feedback.json",cache).hit_flash
            hit.duration_ms=envelope.durationMs
            hit.material=flash.duplicate(true)
            hit.material.merge(envelope,true)
    var number:Dictionary=damage_recipe.get("floatingNumber",{})
    if number.get("enabled",context.get("numberEnabled",false)):
        var palette:Dictionary=context.palette.byDamageType.get(fact.get("damage_type"),context.palette.untyped)
        var label:String=str(number.get("label",""))
        var source:String=Authoring.recipe_source(owner_recipe,"damage/floatingNumber",cache) if damage_recipe.has("floatingNumber") else "catalog/damage_context.json:/numberEnabled"
        add(group,node,"damage_number",timing.get("number",start),number.get("durationMs",context.get("numberDurationMs",900)),source,
            {"actor_uuid":fact.target_entity_uuid,"amount":fact.applied_damage,"label":label,
            "text":str(fact.applied_damage)+(" "+label if not label.is_empty() else ""),
            "color":number.get("color",palette.impactColor),"style":Authoring.load_data("catalog/number_style.json",cache),"attachment":"head",
            "feedback_policy":number.duplicate(true),"feedback_policy_sources":_feedback_sources(owner_recipe,"floatingNumber",number,cache),"feedback_source_occurrence":owner_occurrence})

static func _feedback_sources(recipe:Dictionary,name:String,policy:Dictionary,cache:Dictionary)->Dictionary:
    var sources:Dictionary={}
    for field in policy:
        var source:String=Authoring.recipe_source(recipe,"damage/"+name+"/"+str(field),cache)
        if not source.is_empty():sources[field]=source
    return sources

static func _movement_reaction_feedback(group:Dictionary,node:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    if not Occurrences.pre_motion_attack(node,graph):return
    var context:Dictionary=Authoring.load_data("catalog/movement_reaction_context.json",cache)
    if not context.get("feedbackEnabled",false):return
    var source:String=str(context.get("_resource_source",""))
    source=source+"::texts/reaction" if not source.is_empty() else "catalog/movement_reaction_context.json:/feedbackEnabled"
    _feedback(group,node,{"enabled":true,"text":context.label,"color":context.feedbackColor},
        float(graph.starts[str(node.id)]),str(node.fact.source_entity_uuid),source,cache)

static func _feedback(group: Dictionary,node: Dictionary,feedback: Dictionary,start: float,actor_id: String,source: String,cache: Dictionary) -> void:
    if not feedback.get("enabled",true):return
    var style=Authoring.load_data("catalog/badge_style.json",cache)
    add(group,node,"feedback_text",start,feedback.get("durationMs",style.durationMs),source,
        {"actor_uuid":actor_id,"text":feedback.text,"color":feedback.color,"style":style,"attachment":"head"})

## The actual effective-handler attribution selects a finite authored passive.
## It never manufactures an action or activates from a healing/damage amount.
static func _passive_results(group:Dictionary,trigger:Dictionary,graph:Dictionary,bindings:Dictionary)->void:
    for attribution in trigger.get("content_attributions",[]):
        var behavior:String=str(attribution.get("behavior_id",""))
        var binding:Dictionary=bindings.get(behavior,{})
        if binding.get("effect_cues",[]).is_empty():continue
        var results:Array=ReactionInputs.emitted_results(trigger,attribution,graph)
        var source:String=str(attribution.get("source_entity_uuid",""))
        for cue in binding.effect_cues:
            var descriptor:Dictionary=cue.get("constructor_input",{})
            if descriptor.get("projection")!="effective_handler" or descriptor.get("required_effective_handler")!=behavior:continue
            for result in results:
                var fact:Dictionary=result.fact
                var kind:String=str(descriptor.outcome)
                if fact.kind!=kind or fact.get("source_entity_uuid")!=source or fact.get("target_entity_uuid")==null:continue
                var target:String=str(fact.target_entity_uuid)
                if descriptor.get("self_only",false) and target!=source:continue
                var event:Dictionary={"uuid":str(result.id),"source_entity_uuid":source,"target_entity_uuid":target,
                    "canceled":false,"effect_admitted":true}
                if kind=="heal":
                    if fact.actual_healing<=0 or fact.was_blocked:continue
                    event.merge({"actual_healing":fact.actual_healing,"blocked":false})
                elif kind=="damage":
                    if fact.get("stage")!="applied" or fact.applied_damage<=0 \
                            or descriptor.get("damage_type")!=fact.damage_type:continue
                    event.merge({"actual_damage":fact.applied_damage,"damage_component_uuid":str(result.id)})
                else:continue
                var roles:Dictionary={"caster":source,"target":target}
                var values:Dictionary={"source_entity_uuid":source,"recipient_entity_uuid":target,
                    "owner_uuid":str(trigger.id),"event_uuid":str(result.id),"actor_roles":roles,
                    "geometry_actor":roles[descriptor.geometry_actor],"lease":{},"event":{},"plan_only":false,
                    "native_behavior_id":behavior}
                var at:float=float(graph.starts.get(result.id,0.0))
                var selected:Dictionary={"id":str(cue.get("selection",behavior)),"source":str(binding.source),
                    "source_bounds":{},"palette":{},"staging":{"decorative_light_multiplier":float(cue.get("light_multiplier",0.0))}}
                var phase:Dictionary=NativeSpells._phase(selected,cue,{"prepare":at},at,0.0,0)
                phase.source=str(binding.source)+"/"+str(cue.source_index)
                phase.source_id=behavior+".native."+str(cue.role)
                phase.erase("spell_id")
                phase.merge({"native_spell":true,"actor_uuid":source,"target_uuid":target,
                    "from_position":graph.actor_inputs.get(result.id,{}).get(source,{}).get("last_visual_position",graph.positions.get(source)),
                    "to_position":graph.actor_inputs.get(result.id,{}).get(target,{}).get("last_visual_position",graph.positions.get(target)),
                    "from_elevation_feet":graph.contacts.get(source,{}).get("from_elevation_feet",0.0),
                    "to_elevation_feet":graph.contacts.get(target,{}).get("from_elevation_feet",0.0),
                    "recipe":{},"cast_recipe":{"enabled":false},"native_inputs":{"lease_input":{},"event_input":event},
                    "native_constructor_inputs":[{"component_path":descriptor.component_path,"input_field":"","values":values}],
                    "native_constructor_evidence":{"attribution":attribution,"trigger_terminal_occurrence":str(trigger.id),
                        "result_occurrence":str(result.id),"result_lineage":str(result.lineage_id),"outcome":kind}},true)
                add(group,result,"native_effect",phase.start_ms,phase.duration_ms,phase.source,phase)

## Actual disclosed component sources opt into authored finite weapon cues.
## Neither weapon kind nor aggregate damage type selects a smite/rider.
static func _weapon_result_binding(node:Dictionary,graph:Dictionary,cache:Dictionary,actions:Dictionary)->Dictionary:
    var fact:Dictionary=node.fact
    if fact.get("attack_source_kind")!="equipped" or fact.get("attack_outcome") not in ["Hit","Crit"]:return {}
    var sources:Array=[]
    for row in graph.get("observed_results",{}).get(str(node.id),[]):
        if row.kind!="damage":continue
        for part in row.node.fact.get("components",[]):
            if part.get("source_id")!=null and part.source_id not in sources:sources.append(part.source_id)
    if sources.is_empty():return {}
    var owners:Array=[]
    var authored:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("weapon_result_owners",{})
    for source in sources:
        for owner in authored.get(source,[]):
            if owner not in owners:owners.append(owner)
    var cues:Array=[]
    for owner in owners:
        var choices:Array=actions.get(owner.id,{}).get("effect_cues",[]) if owner.kind=="action" \
            else NativeSpells.selection(str(owner.id),cache).get("staging",{}).get("cues",[])
        for cue in choices:
            var descriptor:Dictionary=cue.get("constructor_input",{})
            if descriptor.get("projection")!="weapon_component" or not descriptor.get("damage_source_ids",[]).any(func(id):return id in sources):continue
            cues.append(cue)
    return {} if cues.is_empty() else {"effect_cues":cues,"source":"authoring/abilities/spells::actual_weapon_components"}
