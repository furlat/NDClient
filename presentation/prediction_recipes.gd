extends RefCounted
# Explicit adapters from admitted choices/previews to authored visual prefixes.
# Adding an event family changes this adapter, not command reconciliation or clocks.
const Authoring = preload("res://presentation/authoring.gd")
const Tracks = preload("res://presentation/tracks.gd")
const Prediction = preload("res://presentation/prediction.gd")

static func prepare(state: Dictionary, action: Dictionary, selection: Dictionary, preview: Dictionary, cache: Dictionary) -> Dictionary:
    if not preview.get("can_confirm",false) or action.is_empty(): return {"reason":"no_admitted_preview"}
    if selection.get("action_index")!=action.get("discovery_index") or selection.get("target_indices",[]).size()!=1: return {"reason":"no_single_target_prefix"}
    var actor: Dictionary = state.actors.get(action.discovery_actor_uuid,{})
    if actor.is_empty() or actor.get("life_state")!="alive" or actor.get("last_visual_position")==null: return {"reason":"actor_not_present"}
    var target = {}
    for row in action.valid_targets:
        if row.index==selection.target_indices[0]: target=row; break
    if target.is_empty(): return {"reason":"target_not_admitted"}
    if action.behavior_id in ["action.move","action.jump"]:
        return _movement(state,actor,action,target,preview,cache)
    if action.get("performs_attack",false): return _attack(state,actor,action,target,cache)
    return {"reason":"no_authored_prediction_prefix"}

static func _movement(state: Dictionary, actor: Dictionary, action: Dictionary, target: Dictionary, preview: Dictionary, cache: Dictionary) -> Dictionary:
    if action.get("connector_traversal")!=null: return {"reason":"connector_prefix_not_authored"}
    var jumping = action.behavior_id=="action.jump"
    var route: Dictionary = preview.get("selected_route") if preview.get("selected_route")!=null else {}
    var path: Array = target.get("path",[]) if jumping else route.get("path",[])
    var exposures: Array = target.get("opportunity_attack_exposures",[]) if jumping else route.get("opportunity_attack_exposures",[])
    if path.size()<2 or path[0]!=actor.last_visual_position: return {"reason":"no_admitted_route"}
    for exposure in exposures:
        if exposure.from_position==path[0] and exposure.to_position==path[1]: return {"reason":"first_edge_reaction"}
    if not jumping and route.get("affordable_endpoint")==path[0]: return {"reason":"no_affordable_step"}
    var supports = []
    for position in [path[0],path[1]]:
        var key = "%s,%s" % [position[0],position[1]]
        if not state.tiles.has(key): return {"reason":"undisclosed_support"}
        supports.append(state.tiles[key].elevation_steps*5.0)
    var mode = "walking"
    for facet in action.variant_facets:
        if facet.key=="movement": mode=facet.value
    var description = {"from_position":path[0],"to_position":path[1],"from_elevation_feet":supports[0],"to_elevation_feet":supports[1],
        "trajectory":"direct_arc" if jumping else "path","movement_mode":mode,"connector_presentation_key":null}
    var body = Authoring.body("movement",actor,description,cache)
    if body.is_empty() or not body.actor.enabled: return {"reason":"body_disabled"}
    var clip = Authoring.clip(actor,body.actor.clip,cache)
    var track = Tracks.body(actor.uuid,Authoring.rig_id(actor,cache),body.actor.clip,clip,body.actor.playbackSpeed,10)
    if track.is_empty(): return {"reason":"missing_clip"}
    track.occurrence = "prediction"
    var motion = Authoring.load_data("catalog/movement_context.json",cache)
    var context = Tracks.jump_context(path,motion,"prediction") if jumping else {"occurrence":"prediction"}
    # Speed is a presentation estimate until StepFact supplies resolved speed.
    # A different authoritative program fails exact-prefix reconciliation.
    Tracks.movement(track,description,motion,body,clip,context,body.actor.playbackSpeed,1.0)
    return {"actor_tracks":[track],"limit_ms":minf(Prediction.MAX_PREFIX_MS,track.duration_ms*0.4)}

static func _attack(state: Dictionary, actor: Dictionary, action: Dictionary, target: Dictionary, cache: Dictionary) -> Dictionary:
    var recipe = Authoring.attack_prefix(action,actor,cache)
    if recipe.is_empty() or not recipe.actor.enabled: return {"reason":"no_common_attack_prefix"}
    var clip = Authoring.clip(actor,recipe.actor.clip,cache)
    var rate = recipe.actor.playbackSpeed*Authoring.playback_rate(actor,cache)
    var track = Tracks.body(actor.uuid,Authoring.rig_id(actor,cache),recipe.actor.clip,clip,rate,20)
    if track.is_empty(): return {"reason":"missing_clip"}
    var slot: Variant = action.get("weapon_slot")
    var set_name = "ranged" if slot in ["RANGED_MAIN","RANGED_OFF"] else "melee"
    if actor.visual_loadout.active_weapon_set!=set_name: return {"reason":"weapon_set_change"}
    var contact_ms = INF
    for anchor in recipe.anchors:
        if anchor.name in ["contact","release"]: contact_ms=minf(contact_ms,float(anchor.frame)/clip.fps/rate*1000.0)
    if not is_finite(contact_ms) or contact_ms<=0: return {"reason":"no_windup_anchor"}
    var origin: Array = actor.last_visual_position
    var tile: Dictionary = state.tiles.get("%s,%s" % [origin[0],origin[1]],{})
    if tile.is_empty(): return {"reason":"undisclosed_support"}
    var target_position: Variant = target.get("position")
    if target_position==null: target_position=state.actors.get(target.get("target_uuid"),{}).get("last_visual_position")
    if target_position==null: return {"reason":"undisclosed_target"}
    track.merge({"occurrence":"prediction","from_position":origin,"to_position":origin,"from_elevation_feet":tile.elevation_steps*5.0,
        "to_elevation_feet":tile.elevation_steps*5.0,"target_uuid":target.get("target_uuid"),"target_position":target_position,
        "hidden_slots":recipe.actor.get("hiddenSlots",[]),"visual_loadout":actor.visual_loadout.duplicate(true),"contact_ms":contact_ms},true)
    return {"actor_tracks":[track],"limit_ms":minf(Prediction.MAX_PREFIX_MS,contact_ms*0.5)}
