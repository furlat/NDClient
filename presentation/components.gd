extends RefCounted
const Occurrences=preload("res://presentation/occurrences.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const ApplicationResults=preload("res://presentation/application_results.gd")
const NativeActions=preload("res://presentation/native_action_authoring.gd")
const ReactionInputs=preload("res://presentation/reaction_inputs.gd")
const NativeItems=preload("res://presentation/native_items.gd")
## Finite, passive presentation mechanisms shared by the compiler and renderer.
const Authoring=preload("res://presentation/authoring.gd")
const Palette=preload("res://presentation/palette.gd")
const AudioCues=preload("res://presentation/audio_cues.gd")
const Placement=preload("res://placement.gd")
const Characters=preload("res://presentation/characters.gd")
const Blood=preload("res://presentation/blood.gd")
const ImpactPlacement=preload("res://presentation/impact_placement.gd")

static func effect_seed(component:Dictionary)->int:
    var occurrence:String=component.get("source_event_uuid","")
    if occurrence.is_empty():
        occurrence=component.get("id","")
        var prefix=occurrence.get_slice(":",0)
        if prefix.is_valid_int() and occurrence.contains(":"):occurrence=occurrence.substr(prefix.length()+1)
    return absi(hash([occurrence,component.get("kind",""),component.get("source_id",""),component.get("source",""),
        component.get("attachment",""),component.get("actor_uuid",""),component.get("target_uuid",""),
        component.get("condition_uuid",""),component.get("layer",{}).get("id",""),component.get("application_index",0)]))

static func weapon_trail(recipe: Dictionary,fact: Dictionary,actor: Dictionary,cache: Dictionary) -> Dictionary:
    var trail: Dictionary=recipe.get("weaponTrail",{}) if recipe.get("weaponTrail")!=null else {}
    if trail.is_empty() or recipe.get("projectile")!=null or fact.get("attack_source_kind")!="equipped":return {}
    var outcome: String={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}.get(fact.get("attack_outcome"),"")
    if fact.behavior_id not in trail.get("behaviorIds",[]) and outcome not in trail.get("outcomes",[]):return {}
    var rig_id=Authoring.rig_id(actor,cache)
    var rig: Dictionary=Authoring.rigs(cache)[rig_id]
    var outfit=Characters._select_layers(actor,rig,actor.get("appearance",{}).get("presentation_kind")=="layered",cache)
    if not outfit.ok:return {}
    var slot="offhand" if fact.weapon_slot=="MELEE_OFF" else "weapon"
    for layer in outfit.value:
        if layer.slot!=slot:continue
        for pose in trail.poses:
            if pose.rigId==rig_id and pose.category==layer.category and pose.clip==recipe.actor.clip:
                return {"pose":pose,"palette":trail.palette,"impact_asset_id":trail.impactAssetId}
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

static func native_spell(group:Dictionary,node:Dictionary,recipe:Dictionary,selected:Dictionary,start:float,duration:float,points:Dictionary,cache:Dictionary,owner:Dictionary,fact:Dictionary,application_index:int=0,graph:Dictionary={})->void:
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
    for phase in NativeSpells.phases(selected,owner,start,duration,index,include_cast):
        if phase.native_cue.role=="impact" and fact.get("attack_outcome","") in ["Miss","Crit Miss"]:continue
        var parameters:Dictionary=common.duplicate()
        parameters.merge(phase,true)
        parameters.merge({"native_spell":true,"cast_recipe":cast,"native_cast_id":cast_id},true)
        var constructor:Dictionary=phase.native_cue.get("constructor_input",{})
        if not constructor.is_empty() and parameters.get("status")!="missing":
            var observed:Dictionary=ApplicationResults.project(node,constructor,graph.get("application_results",{}))
            if observed.ready:
                parameters.native_constructor_inputs=[{"component_path":constructor.component_path,"input_field":constructor.input_field,"values":observed.values}]
                parameters.native_constructor_evidence=observed.evidence
            else:
                parameters.status="missing";parameters.reason=observed.reason
                parameters.unbound_constructor_inputs=[constructor.input_field]
        add(group,node,"native_effect",phase.start_ms,phase.duration_ms,phase.source,parameters)

static func native_action(group:Dictionary,node:Dictionary,binding:Dictionary,recipe:Dictionary,track:Dictionary,markers:Dictionary,graph:Dictionary,cache:Dictionary,observations:Array=[])->void:
    for phase in NativeActions.phases(binding,node.fact,recipe,track,markers,cache):
        var descriptor:Dictionary=phase.native_cue.get("constructor_input",{})
        if descriptor.get("kind")=="reaction_observation":
            var projected:Dictionary=ReactionInputs.project(node,descriptor,graph)
            if not projected.applies:continue
            var actual:Dictionary=phase.duplicate()
            if projected.ready:
                actual.native_reaction_observation=projected.observation
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,
                    "input_field":descriptor.input_field,"values":projected.observation}]
                actual.native_constructor_evidence=projected.evidence
            _native_action_component(group,node,node,actual,ReactionInputs.inputs(projected),graph)
        elif descriptor.get("kind")=="observed_event":
            if Occurrences.application(node):continue
            for projected in ApplicationResults.observed(node,descriptor,graph):
                var actual:Dictionary=phase.duplicate()
                actual.start_ms=float(graph.starts[projected.node.id])+float(phase.start_ms)-float(markers["event.start"])
                actual.native_constructor_inputs=[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}]
                actual.native_constructor_evidence=projected.evidence
                _native_action_component(group,node,projected.node,actual,{"values":{"lease_input":{},"event_input":projected.event},"gaps":[],"evidence":projected.evidence},graph,projected.target_uuid)
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
    var selected:=NativeSpells.selection(fact.behavior_id,cache)
    if not selected.is_empty():
        var cast_id:String=owner.get("source_event_uuid",node.id)
        var include_cast=not group.components.any(func(row):return row.get("native_cast_id")==cast_id and row.get("native_cue",{}).get("role")=="cast")
        var index:int=application_index
        for phase in NativeSpells.phases(selected,owner,start,duration,index,include_cast):
            if phase.native_cue.role=="impact" and fact.get("attack_outcome","") in ["Miss","Crit Miss"]:continue
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
            var rate=.67/maxf(.001,contact_seconds)
            var slash=_source(group,track_node,"class.martial.slash",track.start_ms,
                {"actor_uuid":track.actor_uuid,"attachment":"ground","scale":track.presentation_actor.appearance.visual_scale,
                "weapon_pose":trail.pose,"weapon_contact_seconds":contact_seconds*track.source_end_seconds/(track.duration_ms/1000.0),"native_age_rate":rate,"palette":trail.palette,"source_track":track},cache)
            slash.duration_ms=.94/rate*1000.0
            if track_node.fact.attack_outcome in ["Hit","Crit"]:
                _source(group,track_node,"class.martial.impact",track.impact_ms,
                    {"actor_uuid":track.actor_uuid,"target_uuid":track.target_uuid,"attachment":"target_body","scale":track.presentation_actor.appearance.visual_scale,"palette":trail.palette},cache)
        if track.get("motion",false) and track_node.fact.kind=="step":
            _movement_audio(group,track_node,track,sounds,cache)
    var native_sources: Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    var action_bindings:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache)
    for node in lineage.events:
        if node.canceled or node.get("fact")==null: continue
        var fact: Dictionary=Occurrences.spell(node,graph) if node.fact.kind=="spell" else node.fact
        var start: float=graph.starts.get(node.id,0)
        var recipe: Dictionary=graph.recipes.get(node.id,{})
        var contact=start
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
        elif fact.kind=="spell":
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
            if recipe.get("actionFeedback")!=null:_feedback(group,node,recipe.actionFeedback,contact,fact.source_entity_uuid,"catalog/body_action_recipes.json:/"+str(fact.behavior_id)+"/actionFeedback",cache)
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
            var resolved_sources={}
            for media in recipe.get("media",[]):
                for source_id in native_sources:
                    if media.assetId not in native_sources[source_id].get("media_ids",[]) or resolved_sources.has(source_id): continue
                    resolved_sources[source_id]=true
                    var component=_source(group,node,source_id,start+media.get("startOffsetMs",0),
                        {"actor_uuid":fact.source_entity_uuid,"attachment":media.attachment,"scale":media.get("scale",1),"alpha":media.get("alpha",1)},cache)
                    component.duration_ms=media.get("durationMs",component.duration_ms)
                    component.loop=media.get("loop",false)
                    component.source_duration_ms=native_sources[source_id].duration*1000.0
                    component.fade_in_ms=media.get("fadeInMs",0);component.fade_out_ms=media.get("fadeOutMs",0)
                    component.fade_curve=media.get("fadeCurve","linear")
        elif fact.kind=="damage" and fact.get("stage")=="applied" and fact.get("applied_damage",0)>0:
            var context=Authoring.load_data("catalog/damage_context.json",cache)
            var parent: Dictionary=graph.nodes.get(node.get("parent_lineage"),{})
            var damage_recipe: Dictionary={}
            var spell_behavior:=""
            while not parent.is_empty():
                if spell_behavior.is_empty() and parent.get("fact")!=null and parent.fact.kind=="spell":spell_behavior=Occurrences.spell(parent,graph).get("behavior_id","")
                if graph.recipes.has(parent.id) and graph.recipes[parent.id].has("damage"):
                    damage_recipe=graph.recipes[parent.id].damage; break
                parent=graph.nodes.get(parent.get("parent_lineage"),{})
            var timing: Dictionary=graph.get("damage_timings",{}).get(node.id,{})
            var flash: Dictionary=damage_recipe.get("hitFlash",{})
            if flash.get("enabled",context.get("flashEnabled",false)):
                var colors: Array=flash.get("palette",{}).get("colors",[])
                if colors.is_empty():
                    var palette: Dictionary=context.palette.byDamageType.get(fact.get("damage_type"),context.palette.untyped)
                    colors=[palette.elementColors.secondary,palette.elementColors.primary,palette.elementColors.tertiary]
                var hit=add(group,node,"material_flash",timing.get("flash",start),flash.get("durationMs",context.get("flashDurationMs",150)),
                    "catalog/damage_context.json:/flashEnabled",{"actor_uuid":fact.target_entity_uuid,"material":flash,"colors":colors,"damage_type":fact.get("damage_type"),"attachment":"body"})
                var native_hit:=NativeSpells.hit(spell_behavior,cache)
                if not native_hit.is_empty():
                    hit.native_hit=native_hit
                    var envelope:Dictionary=Authoring.load_data("sandbox/feedback.json",cache).hit_flash
                    hit.duration_ms=envelope.durationMs
                    hit.material=flash.duplicate(true)
                    hit.material.merge(envelope,true)
            if context.get("numberEnabled",false):
                var palette: Dictionary=context.palette.byDamageType.get(fact.get("damage_type"),context.palette.untyped)
                add(group,node,"damage_number",timing.get("number",start),damage_recipe.get("floatingNumber",{}).get("durationMs",900),
                    "catalog/damage_context.json:/numberEnabled",{"actor_uuid":fact.target_entity_uuid,"amount":fact.applied_damage,"text":str(fact.applied_damage),"color":palette.impactColor,"style":Authoring.load_data("catalog/number_style.json",cache),"attachment":"head"})
            _bound_audio(group,node,sounds.damage_types,str(fact.get("damage_type")),{"damage.hp":timing.get("hp",start),"event.start":start},fact.target_entity_uuid,"damage_types",cache)
            var release: Dictionary=fact.get("body_release",{}) if fact.get("body_release")!=null else {}
            # Damage alone never authorizes blood or a receiving tile. Region
            # artwork uses the same server ellipse and allowed-cell list as the
            # persistent after-values; air-only releases retain native spray.
            if release.get("release_id")=="body.blood":
                var blood_start:float=graph.get("damage_timings",{}).get(node.id,{}).get("hp",start)
                if not release.get("regions",[]).is_empty() and release.get("pattern")!=null:
                    var blood_asset=Blood.asset(cache)
                    if blood_asset.is_empty():
                        return {"ok":false,"error":{"kind":"authoring","message":"Cannot load selected asset metadata: particles.region.blood","retryable":false}}
                    var revealed=Blood.reveals(group,node,graph.get("initial_tiles",{}),blood_previous)
                    var blood_contact:Dictionary=graph.impact_contacts.get(node.id,{})
                    var source_height:Variant=blood_contact.get("from_elevation_feet")
                    if source_height!=null:source_height=float(source_height)/5.0
                    else:
                        for region in release.regions:
                            for point in region.positions:
                                if Blood.key(point)==Blood.key(release.position):source_height=region.elevation_steps
                    add(group,node,"residue_deposit",blood_start,Blood.duration(release,blood_asset),
                        "authoring/environment/surfaces/residue.blood.tres::region_particles",
                        {"actor_uuid":fact.target_entity_uuid,"attachment":"ground","position":release.position,"asset_metadata":blood_asset,
                        "elevation_steps":source_height,"flight_enabled":source_height!=null,
                        "body_release":release.duplicate(true),"reveals":revealed,"residue_deposition":true,
                        "authority_source":"DamageResultFact.body_release.regions + WorldTileState.residues"})
                else:
                    var selection: Dictionary=Authoring.load_data("native_effects/responses.json",cache)
                    var source_id: String=selection.damage_types.get(str(release.get("primary_damage_type")),selection.default)
                    var actors: Dictionary=graph.actor_inputs.get(node.id,{})
                    var impact=ImpactPlacement.prepare(actors.get(fact.target_entity_uuid,{}),group.actor_tracks,blood_start,graph.impact_contacts.get(node.id,{}),cache)
                    var common={"actor_uuid":fact.target_entity_uuid,"source_actor_uuid":fact.get("source_entity_uuid"),"attachment":"impact","impact":impact,"scale":selection.scale,
                        "body_release":release.duplicate(true),"residue_deposition":false,
                        "direction_from":actors.get(fact.get("source_entity_uuid"),{}).get("last_visual_position"),"direction_to":actors.get(fact.target_entity_uuid,{}).get("last_visual_position")}
                    var spray=_source(group,node,source_id,blood_start,common,cache)
                    if impact.status=="missing":spray.status="missing";spray.reason=impact.reason
        elif fact.kind=="actor_change":
            if group.actor_tracks.any(func(track):return track.source_event_uuid==node.id and track.get("equipment_change",false)):
                _bound_audio(group,node,sounds.get("equipment",{}),"change",audio_markers,group.actor_tracks.filter(func(track):return track.source_event_uuid==node.id)[0].actor_uuid,"equipment",cache,audio_track)
            for cue in graph.condition_cues.get(node.id,[]):
                var condition:Dictionary=cue.condition
                var binding:Dictionary=sounds.get("conditions",{}).get(str(condition.behavior_id),{})
                _bound_audio(group,node,binding,cue.phase,audio_markers,cue.actor_uuid,"conditions/"+str(condition.behavior_id),cache,audio_track)
                var feedback:Dictionary=cue.recipe.get(cue.phase,{})
                if not feedback.get("feedbackEnabled",false):continue
                var style=Authoring.load_data("catalog/badge_style.json",cache)
                var prefix:String=feedback.get("feedbackPrefix","−" if cue.phase=="removal" else "+")
                var text:String=prefix+str(condition.get("name",cue.recipe.get("label",condition.behavior_id)))
                var pointer:String=str(condition.behavior_id)+"/"+cue.phase+"/feedbackEnabled"
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
            var row=_bound_audio(group,node,sounds.movement,marker.binding,{"body.source_frame":at},track.actor_uuid,"movement",cache,track)
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

static func _feedback(group: Dictionary,node: Dictionary,feedback: Dictionary,start: float,actor_id: String,source: String,cache: Dictionary) -> void:
    var style=Authoring.load_data("catalog/badge_style.json",cache)
    add(group,node,"feedback_text",start,feedback.get("durationMs",style.durationMs),source,
        {"actor_uuid":actor_id,"text":feedback.text,"color":feedback.color,"style":style,"attachment":"head"})
