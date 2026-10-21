extends RefCounted
## Reference schema-16 fold. Native occurrence order and after-values own state.
const Audience=preload("res://sdk/audience.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const World=preload("res://sdk/fold_world.gd")
const Bodies=preload("res://sdk/fold_bodies.gd")
const Transitions=preload("res://sdk/transitions.gd")
const STATE_PRESENTATION_KINDS=["temporary_hit_points","spatial","turn","sensory","item_charge","faction"]
static func success(value:Variant)->Dictionary:return Audience.success(value)
static func failure(message:String)->Dictionary:return Audience.failure(message)
static func content_key(descriptor:Dictionary)->String:
    var ref:Dictionary=descriptor.ref;return "%s:%s:%s@%d"%[ref.pack_id,ref.definition_kind,ref.content_id,ref.content_version]
static func resolution_key(reference:Dictionary)->String:
    return str(reference.lineage)+(","+str(reference.application_id) if reference.get("application_id")!=null else "")
static func empty_state(generation:String,observer:String,world:Dictionary={},audience:Variant=null)->Dictionary:
    return {"generation":generation,"observer_uuid":observer,"world":world,"tiles":{},"objects":{},"object_members":{},"connectors":{},"static":{"tiles":{},"tile_looks":{},"residues":{},"object_looks":{},"boundary_structures":{},"visual_loadouts":{}},"senses":null,"reducer_cursor":0,"spatial_commit_cursors":{},"actors":{},"items":{},"spatial_content":{},"current_actor_uuid":null,"round_number":0,"hud_snapshot":null,"audience":Audience.resolve(observer,audience).value,"content":[],"combat_log_appends":[],"entity_members":{},"object_contact_members":{},"effect_members":{},"light_sources":{},"remembered_effects":{}}
static func copy_target(target:Dictionary)->Dictionary:return target.duplicate(true)
static func _retained_target(target:Dictionary)->Dictionary:
    var result=target.duplicate()
    for field in ["tiles","objects","object_members","connectors","actors","items","spatial_content","spatial_commit_cursors","entity_members","object_contact_members","effect_members","light_sources","remembered_effects"]:result[field]=target[field].duplicate()
    result.static=target.static.duplicate()
    for field in target.static:result.static[field]=target.static[field].duplicate()
    return result
static func enter_body(target:Dictionary,record:Dictionary)->Dictionary:return Bodies.enter_body(target,record)
static func enter_item(target:Dictionary,record:Dictionary)->Dictionary:return Bodies.enter_item(target,record)
static func apply_actor_change_fact(target:Dictionary,fact:Dictionary,condition_rows:Array=[],item_rows:Array=[])->Dictionary:return Bodies.actor_change(target,fact,condition_rows,item_rows)
static func clear_unseen_positions(target:Dictionary)->void:Audience.clear_unseen_positions(target)
static func apply_world_update(target:Dictionary,update:Dictionary,disclosed:Dictionary={})->Dictionary:
    return World.fold(target,update,disclosed)
static func stage_actors(target:Dictionary,bodies:Array)->Dictionary:
    var result=_retained_target(target)
    for record in bodies:
        if not result.actors.has(record.actor_uuid):
            var entered=Bodies.enter_body(result,record)
            if not entered.ok:return entered
    return success(result)
static func observe_actors(target:Dictionary,bodies:Array)->Dictionary:
    var result=_retained_target(target)
    for record in bodies:
        var entered=Bodies.enter_body(result,record)
        if not entered.ok:return entered
    return success(result)
static func stage_lineage(target:Dictionary,lineage:Dictionary)->Dictionary:
    var staged=stage_actors(target,lineage.get("bodies",[]))
    if not staged.ok:return staged
    var result:Dictionary=staged.value
    for update in lineage.get("world_updates",[]):
        var status=World.static_rows(result,update)
        if not status.ok:return status
        var tiles=World.tile_columns(update.get("tile_columns"),result.static.tiles,result.static.tile_looks)
        if not tiles.ok:return tiles
        for key in tiles.value:
            if not result.tiles.has(key):result.tiles[key]=tiles.value[key]
        var rows=World.object_rows(update.get("objects"))
        if not rows.ok:return rows
        for row in rows.value:
            if row.placement!=null and not result.objects.has(row.item_uuid):
                var placed=World.placement(row.item_uuid,row.placement,result.static.tiles);var item=World.floor_item(result.static.object_looks[row.item_uuid],row.state,result.static.boundary_structures)
                if not placed.ok:return placed
                if not item.ok:return item
                result.objects[row.item_uuid]={"placement":placed.value,"item":item.value,"contained_items":null}
        for row in update.get("connectors",[]):
            if not result.connectors.has(row.connector_uuid):result.connectors[row.connector_uuid]=row
    return success(result)

static func _write_actor(target:Dictionary,identity:Variant,changed_actors:Dictionary={})->Variant:
    if not target.actors.has(identity):return null
    var actor:Dictionary=target.actors[identity].duplicate();target.actors[identity]=actor;changed_actors[identity]=true;return actor
static func apply_player_fact(target:Dictionary,fact:Dictionary,source_cursor:Variant=null,values:Dictionary={},condition_rows:Array=[],item_rows:Array=[],changed_actors:Dictionary={},changed_items:Dictionary={},sensory_cells:Dictionary={})->Dictionary:
    var identity:Variant;var actor:Variant
    match fact.kind:
        "sensory":
            if values.is_empty():return failure("A sensory fact requires its group's rows")
            return Audience.fold(target,fact,values,changed_actors,sensory_cells)
        "actor_change":return Bodies.actor_change(target,fact,condition_rows,item_rows,changed_actors,changed_items)
        "faction":
            actor=_write_actor(target,fact.entity_uuid,changed_actors)
            if actor!=null:actor.faction=fact.faction_after
        "spatial":
            identity=fact.get("entity_uuid");actor=_write_actor(target,identity,changed_actors)
            if fact.get("terminal_departure",false) and actor!=null:
                actor.present=false;actor.last_visual_position=null;actor.occupancy_layer=null
                if target.senses!=null:
                    target.senses=target.senses.duplicate();target.senses.entities=target.senses.entities.duplicate();target.senses.entities.erase(identity);target.entity_members.erase(identity)
                return success(target)
            if actor!=null and fact.change_type=="entity_entered":actor.spatial_disposition="present"
            if actor!=null and fact.get("occupancy_layer")!=null:actor.occupancy_layer=fact.occupancy_layer
            if identity in target.audience.controlled and fact.change_type=="entity_entered":
                if actor!=null:actor.last_visual_position=fact.position
                if target.senses!=null and identity==target.observer_uuid:target.senses=target.senses.duplicate();target.senses.position=fact.position
        "item_charge":
            identity=fact.source_entity_uuid;actor=_write_actor(target,identity,changed_actors)
            if actor==null:return failure("Missing actor: "+str(identity))
            if actor.controlled_items==null or not identity in target.audience.controlled:return failure("item charges require the controlled actor's inventory")
            if fact.item_destroyed:
                actor.controlled_items=Bodies.remove(actor.controlled_items,"",fact.item_uuid);actor.visual_loadout=actor.visual_loadout.duplicate();actor.visual_loadout.layers=Bodies.remove(actor.visual_loadout.layers,"item_uuid",fact.item_uuid)
            elif fact.item_uuid in actor.controlled_items:
                var item:Dictionary=target.items[fact.item_uuid].duplicate()
                if item.state==null:return failure("item charges require the controlled item's state")
                item.state=item.state.duplicate();item.state.charges=fact.charges_after;item.state.stack_count=fact.stack_count_after;target.items[fact.item_uuid]=item;changed_items[fact.item_uuid]=true
        "attack":
            actor=_write_actor(target,fact.source_entity_uuid,changed_actors)
            if actor!=null:
                # AttackFact.weapon_set is a Python property, not a wire field.
                # Match that reference property on the actual declared source.
                var stance:String="none" if fact.get("attack_source_kind","equipped")!="equipped" else "ranged" if fact.weapon_slot in ["RANGED_MAIN","RANGED_OFF"] else "melee"
                actor.visual_loadout=actor.visual_loadout.duplicate();actor.visual_loadout.active_weapon_set=stance
        "damage","heal":
            if fact.kind=="damage" and fact.stage!="applied":return success(target)
            if fact.kind=="heal" and fact.get("was_blocked",false):return success(target)
            if fact.get("resulting_normal_hp")==null or fact.get("resulting_temporary_hp")==null:return failure("applied damage/healing requires exact committed HP")
            actor=_write_actor(target,fact.target_entity_uuid,changed_actors)
            if actor==null:return failure("Missing actor: "+str(fact.target_entity_uuid))
            actor.normal_hp=fact.resulting_normal_hp;actor.temporary_hp=fact.resulting_temporary_hp
            if actor.temporary_hp<=0:actor.temporary_hp_grant=null
        "temporary_hit_points":
            actor=_write_actor(target,fact.entity_uuid,changed_actors)
            if actor==null:return failure("Missing actor: "+str(fact.entity_uuid))
            actor.temporary_hp=fact.resulting_temporary_hp;actor.temporary_hp_grant=fact.get("grant")
        "life":
            actor=_write_actor(target,fact.entity_uuid,changed_actors)
            if actor==null:return failure("Missing actor: "+str(fact.entity_uuid))
            actor.life_state=fact.new_state;actor.normal_hp=fact.normal_hit_points;actor.remains_disposition=fact.get("remains_disposition","intact")
        "turn":
            if fact.get("round_number")!=null:target.round_number=fact.round_number
            if fact.event_type in ["turn_start","turn_end","encounter_end"]:target.current_actor_uuid=fact.entity_uuid if fact.event_type=="turn_start" else null
    return success(target)
static func apply_committed_player_fact(target:Dictionary,fact:Dictionary,source_cursor:int,occurrences:Variant,values:Dictionary={},condition_rows:Array=[],item_rows:Array=[],changed_actors:Dictionary={},changed_items:Dictionary={},sensory_cells:Dictionary={})->Dictionary:
    if fact.kind=="spatial" and fact.get("entity_uuid")!=null and fact.change_type in ["entity_entered","entity_left"]:
        var committed:Variant=fact.get("commit_occurrence")
        if committed==null or not committed in occurrences:return failure("Spatial change at cursor %d lacks its recorded commit version"%source_cursor)
        if committed<int(target.spatial_commit_cursors.get(fact.entity_uuid,-1)) and int(target.spatial_commit_cursors.get(fact.entity_uuid,-1))<source_cursor:return success(target)
        target.spatial_commit_cursors[fact.entity_uuid]=committed
    return apply_player_fact(target,fact,source_cursor,values,condition_rows,item_rows,changed_actors,changed_items,sensory_cells)

static func node_lineages(nodes:Array,versions:Dictionary)->Array:
    var owners={}
    for i in range(versions.get("occurrences",[]).size()):owners[int(versions.occurrences[i])]=int(versions.lineages[i])
    var result:Array=[]
    for node in nodes:result.append(owners[int(node.occurrence)])
    return result
static func parent_lineages(nodes:Array,versions:Dictionary)->Dictionary:
    var owners=node_lineages(nodes,versions);var result={}
    for i in range(nodes.size()):
        for child in nodes[i].get("children_lineages",[]):
            if not result.has(int(child)):result[int(child)]=owners[i]
    for i in range(nodes.size()):
        if nodes[i].get("parent_lineage")!=null and not result.has(owners[i]):result[owners[i]]=int(nodes[i].parent_lineage)
    return result
static func check_spell_declarations(nodes:Array,versions:Dictionary,resolutions:Array)->Dictionary:
    var owners=node_lineages(nodes,versions);var declared={}
    for i in range(nodes.size()):
        var fact:Variant=nodes[i].get("fact")
        if fact!=null and fact.kind=="spell" and fact.get("source_entity_uuid")!=null:declared[owners[i]]=true
    for node in nodes:
        var fact:Variant=node.get("fact");var reference:Variant=node.get("resolution")
        if fact!=null and fact.kind=="spell" and fact.get("source_entity_uuid")==null and reference!=null and resolutions[reference].get("application_id")!=null and not declared.has(int(resolutions[reference].lineage)):return failure("A spell application's group carries its cast's declaration")
    return success(null)
static func reduce_nodes(target:Dictionary,nodes:Array,versions:Dictionary,bodies:Array,updates:Array,rows:Dictionary={})->Dictionary:
    return _reduce_nodes_owned(copy_target(target),nodes,versions,bodies,updates,rows)
static func _reduce_nodes_owned(result:Dictionary,nodes:Array,versions:Dictionary,bodies:Array,updates:Array,rows:Dictionary={},recorded:Variant=null,profile:Variant=null,resolutions:Array=[],sensory_cells:Dictionary={})->Dictionary:
    var composed=Audience.composed_values(rows)
    if not composed.ok:return composed
    var casts:Dictionary={}
    if recorded!=null:
        var owners:Array=node_lineages(nodes,versions)
        for i in range(nodes.size()):
            var declared:Variant=nodes[i].get("fact")
            if declared!=null and declared.kind=="spell" and declared.get("source_entity_uuid")!=null:casts[owners[i]]=declared.source_entity_uuid
    var order:Array=range(bodies.size());order.sort_custom(func(a,b):return a<b if bodies[a].occurrence==bodies[b].occurrence else bodies[a].occurrence<bodies[b].occurrence)
    var pending:Array=[]
    for index in order:pending.append(bodies[index])
    var next=0;var world_updates={}
    for update in updates:world_updates[int(update.occurrence)]=update
    for node in nodes:
        var admitted:Array=[];var item_rows:Array=[];var changed_items={};var changed_actors={}
        while next<pending.size() and pending[next].occurrence<=node.occurrence:
            var entered=Bodies.enter_body(result,pending[next],item_rows,changed_actors,changed_items)
            if not entered.ok:return entered
            if recorded!=null:admitted.append(pending[next])
            next+=1
        var started:int=Time.get_ticks_usec() if profile!=null else 0
        var inputs:Dictionary=Transitions.actor_inputs(result,node) if recorded!=null else {}
        if recorded!=null and node.get("resolution")!=null and not resolutions.is_empty():
            var source:Variant=casts.get(int(resolutions[node.resolution].lineage))
            if source!=null and result.actors.has(source):inputs[source]=result.actors[source]
        var item_inputs:Dictionary=Transitions.item_inputs(result,inputs) if recorded!=null else {}
        var update:Variant=world_updates.get(int(node.occurrence));var disclosed={}
        if update!=null:
            var folded=apply_world_update(result,update,disclosed)
            if not folded.ok:return folded
            if recorded!=null:recorded.world[int(node.occurrence)]=disclosed
        if profile!=null:_profile_elapsed(profile,"world",started)
        var condition_rows:Array=[];started=Time.get_ticks_usec() if profile!=null else 0
        if not node.get("canceled",false) and node.get("fact")!=null:
            var folded=apply_committed_player_fact(result,node.fact,int(node.occurrence),versions.get("occurrences",[]),composed.value,condition_rows,item_rows,changed_actors,changed_items,sensory_cells)
            if not folded.ok:return folded
        if profile!=null:_profile_elapsed(profile,"facts",started)
        if recorded!=null:
            recorded.events.append({"event_uuid":int(node.occurrence),"occurrence":int(node.occurrence),"source_index":int(node.occurrence),"actor_inputs":inputs,"item_inputs":item_inputs,"condition_rows":condition_rows,"item_rows":item_rows,"delta":Transitions.capture_delta(result,node,admitted,update,{},true,disclosed,changed_actors,changed_items)})
    while next<pending.size():
        var item_rows:Array=[]
        var entered=Bodies.enter_body(result,pending[next],item_rows)
        if not entered.ok:return entered
        if recorded!=null:
            recorded.trailing_item_rows.append_array(item_rows)
            recorded.trailing.set.static=result.static.duplicate()
            recorded.trailing.actors[pending[next].actor_uuid]=result.actors[pending[next].actor_uuid]
            for record in pending[next].get("items",[]):recorded.trailing.items[record.item_uuid]=result.items[record.item_uuid]
            for row in item_rows:recorded.trailing.items[row.item_uuid]=result.items[row.item_uuid]
        next+=1
    return success(result)

static func apply_hud(target:Dictionary,patch:Dictionary)->Dictionary:
    var prior:Variant=target.hud_snapshot;var sheets={}
    if prior!=null:
        for row in prior.sheets:sheets[row.actor_uuid]=row
    for row in patch.get("sheets",[]):
        var next:Dictionary=sheets.get(row.actor_uuid,{"actor_uuid":row.actor_uuid}).duplicate();next.merge(row.changes,true)
        var values={}
        for value in row.get("resource_values",[]):values[value.key]=value
        if not values.is_empty():
            if not next.has("resources"):return failure("Resource values require the sheet's resources")
            var resources:Array=[]
            for resource in next.resources:
                var replacement:Dictionary=resource
                if values.has(resource.key):replacement=resource.duplicate();replacement.current=values[resource.key].current;replacement.maximum=values[resource.key].maximum;values.erase(resource.key)
                resources.append(replacement)
            if not values.is_empty():return failure("Resource values name a row the sheet does not hold")
            next.resources=resources
        sheets[row.actor_uuid]=next
    var initiative:Variant=patch.get("initiative") if patch.get("initiative")!=null else (prior.initiative if prior!=null else null)
    if initiative==null:return failure("A first HUD requires its initiative")
    target.hud_snapshot={"initiative":initiative,"sheets":sheets.values()};return success(target)
static func displayed_initiative(target:Dictionary)->Array:
    if target.hud_snapshot==null:return []
    var result:Array=[]
    for identity in target.hud_snapshot.initiative:
        if identity in target.audience.controlled or (target.senses!=null and target.senses.entities.has(identity)):result.append(identity)
    return result
static func reduce_initialization(initialization:Dictionary,content_additions:Array=[])->Dictionary:
    var target=empty_state(initialization.generation,initialization.observer_uuid,initialization.world,initialization.get("audience"));var checked=check_spell_declarations(initialization.nodes,initialization.version_rows,initialization.get("resolutions",[]))
    if not checked.ok:return checked
    var folded=_reduce_nodes_owned(target,initialization.nodes,initialization.version_rows,initialization.get("bodies",[]),initialization.get("world_updates",[]),initialization.get("sensory_rows",{}),null,null,initialization.get("resolutions",[]))
    if not folded.ok:return folded
    target.reducer_cursor=initialization.end_cursor
    if initialization.get("hud")!=null:
        var status=apply_hud(target,initialization.hud)
        if not status.ok:return status
    target.content=content_additions.duplicate();target.content.sort_custom(func(a,b):return content_key(a)<content_key(b));return success(target)
static func reduce_lineage(target:Dictionary,lineage:Dictionary)->Dictionary:return _reduce_lineage_owned(copy_target(target),lineage)
static func _reduce_lineage_owned(target:Dictionary,lineage:Dictionary,recorded:Variant=null,profile:Variant=null,sensory_cells:Dictionary={})->Dictionary:
    if lineage.end_cursor<=target.reducer_cursor:return failure("player lineage precedes this reduction position")
    var folded=_reduce_nodes_owned(target,lineage.events,lineage.version_rows,lineage.get("bodies",[]),lineage.get("world_updates",[]),lineage.get("sensory_rows",{}),recorded,profile,lineage.get("resolutions",[]),sensory_cells)
    if not folded.ok:return folded
    target.reducer_cursor=lineage.end_cursor
    if recorded!=null:recorded.trailing.set.reducer_cursor=target.reducer_cursor
    return success(target)
static func reduce_operation(target:Dictionary,update:Dictionary)->Dictionary:return _reduce_operation(target,update,false)
static func _reduce_operation_recorded(target:Dictionary,update:Dictionary,profile:Variant=null)->Dictionary:return _reduce_operation(target,update,true,profile)
static func _reduce_operation_retained(target:Dictionary,update:Dictionary,record_events:bool=false,profile:Variant=null,sensory_context:Dictionary={})->Dictionary:return _reduce_operation(target,update,record_events,profile,true,sensory_context)
static func _reduce_operation(target:Dictionary,update:Dictionary,record_events:bool,profile:Variant=null,retained:bool=false,sensory_context:Dictionary={})->Dictionary:
    if update.generation!=target.generation or update.observer_uuid!=target.observer_uuid:return failure("An operation belongs to another observer or generation")
    var cells:Dictionary={}
    if retained and is_same(sensory_context.get("state"),target):cells=sensory_context.get("cells",{}).duplicate()
    var result=_retained_target(target) if retained else copy_target(target)
    var records:Variant={"lineages":[]} if record_events else null
    var content={}
    if not update.get("content_additions",[]).is_empty():
        for descriptor in result.content:content[content_key(descriptor)]=descriptor
        for descriptor in update.content_additions:
            var key=content_key(descriptor)
            if content.has(key) and content[key]!=descriptor:return failure("An admitted content identity changed its definition")
            content[key]=descriptor
        var keys=content.keys();keys.sort();result.content=[]
        for key in keys:result.content.append(content[key])
    for lineage in update.get("lineages",[]):
        if lineage.start_cursor!=result.reducer_cursor:return failure("Operation occurrence sequence has a gap")
        var checked=check_spell_declarations(lineage.events,lineage.version_rows,lineage.get("resolutions",[]))
        if not checked.ok:return checked
        var recorded:Variant={"lineage":int(lineage.lineage),"lineage_uuid":int(lineage.lineage),"start_cursor":lineage.start_cursor,"end_cursor":lineage.end_cursor,"events":[],"trailing":Transitions.empty_delta(),"trailing_item_rows":[],"world":{}} if record_events else null
        var folded=_reduce_lineage_owned(result,lineage,recorded,profile,cells)
        if not folded.ok:return folded
        if record_events:records.lineages.append(recorded)
    if update.get("hud")!=null:
        var applied=apply_hud(result,update.hud)
        if not applied.ok:return applied
    var first:int=result.combat_log_appends.size()
    for i in range(update.get("combat_log_appends",[]).size()):
        var row:Dictionary=update.combat_log_appends[i]
        if row.generation!=result.generation or row.observer_uuid!=result.observer_uuid or row.operation_end_cursor>result.reducer_cursor or row.encounter_log_index!=first+i:return failure("Standalone log append is out of order or belongs to another audience")
    if not update.get("combat_log_appends",[]).is_empty():result.combat_log_appends=result.combat_log_appends.duplicate();result.combat_log_appends.append_array(update.combat_log_appends)
    var accepted=success(result)
    if record_events:accepted.transitions=records
    if retained:accepted.sensory_context={"state":result,"senses":result.senses,"cells":cells}
    return accepted

static func state_before_event(before:Dictionary,lineage:Dictionary,event:Dictionary)->Dictionary:
    var owners=node_lineages([event],lineage.version_rows);var first:int=9223372036854775807
    for i in range(lineage.version_rows.occurrences.size()):
        if int(lineage.version_rows.lineages[i])==owners[0]:first=mini(first,int(lineage.version_rows.occurrences[i]))
    var part=lineage.duplicate();part.events=lineage.events.filter(func(row):return row.occurrence<first)
    if part.events.is_empty():return success(_retained_target(before))
    part.end_cursor=first;part.bodies=lineage.get("bodies",[]).filter(func(row):return row.occurrence<first);part.world_updates=lineage.get("world_updates",[]).filter(func(row):return row.occurrence<first)
    var result=_retained_target(before)
    for update in lineage.get("world_updates",[]):
        var status=World.static_rows(result,update)
        if not status.ok:return status
    return _reduce_lineage_owned(result,part)
static func lineage_branch(lineage:Dictionary,root:Dictionary)->Dictionary:
    var owners=node_lineages(lineage.events,lineage.version_rows);var parents=parent_lineages(lineage.events,lineage.version_rows);var children={};var intervals={}
    for i in range(lineage.events.size()):
        var identity=owners[i]
        if not children.has(identity):children[identity]=[]
        children[identity].append_array(lineage.events[i].get("children_lineages",[]))
    for i in range(lineage.version_rows.occurrences.size()):
        var identity=int(lineage.version_rows.lineages[i]);var occurrence=int(lineage.version_rows.occurrences[i]);var interval:Array=intervals.get(identity,[occurrence,occurrence]);intervals[identity]=[mini(interval[0],occurrence),maxi(interval[1],occurrence)]
    var root_owner=node_lineages([root],lineage.version_rows)[0];var bounds:Array=intervals[root_owner];var pending:Array=[root_owner];var selected={}
    for identity in owners:
        if not parents.has(identity) and bounds[0]<=intervals[identity][0] and intervals[identity][1]<=bounds[1]:pending.append(identity)
    while not pending.is_empty():
        var identity=int(pending.pop_back())
        if selected.has(identity):continue
        selected[identity]=true;pending.append_array(children.get(identity,[]))
    var result=lineage.duplicate();result.events=[];var occurrences:Array=[];var lineages:Array=[];var identities={}
    for i in range(lineage.events.size()):
        if selected.has(owners[i]):
            if lineage.events[i].occurrence==root.occurrence:result.root=result.events.size()
            result.events.append(lineage.events[i])
    for i in range(lineage.version_rows.occurrences.size()):
        if selected.has(int(lineage.version_rows.lineages[i])):
            var occurrence=int(lineage.version_rows.occurrences[i]);occurrences.append(occurrence);lineages.append(int(lineage.version_rows.lineages[i]));identities[occurrence]=true
    result.version_rows={"occurrences":occurrences,"lineages":lineages};result.start_cursor=occurrences[0];result.end_cursor=occurrences[-1]+1
    result.bodies=lineage.get("bodies",[]).filter(func(row):return identities.has(int(row.occurrence)));result.world_updates=lineage.get("world_updates",[]).filter(func(row):return identities.has(int(row.occurrence)));return success(result)
static func index_player_lineage(lineage:Dictionary)->Dictionary:
    var result={"by_lineage":{},"by_uuid":{},"source_order":{},"owned":{},"results":{},"damage_requests":{},"parents":parent_lineages(lineage.events,lineage.version_rows)};var owners=node_lineages(lineage.events,lineage.version_rows)
    for i in range(lineage.events.size()):
        var node:Dictionary=lineage.events[i];result.by_lineage[owners[i]]=node;result.by_uuid[int(node.occurrence)]=node;result.source_order[int(node.occurrence)]=int(node.occurrence)
        if node.get("resolution")!=null:
            var key=resolution_key(lineage.resolutions[node.resolution])
            if not result.owned.has(key):result.owned[key]=[]
            result.owned[key].append(node)
            var fact:Variant=node.get("fact")
            if not node.get("canceled",false) and fact!=null and (fact.kind=="object_damage" or (fact.kind=="damage" and fact.stage=="applied")):
                if not result.results.has(key):result.results[key]=[]
                result.results[key].append(node)
    for i in range(lineage.events.size()):
        var current:int=owners[i];var ancestors:Array=[]
        while not current in ancestors and result.by_lineage.has(current):
            ancestors.append(current);var fact:Variant=result.by_lineage[current].get("fact")
            if fact!=null and fact.kind=="damage" and fact.stage=="taken":
                for identity in ancestors:result.damage_requests[identity]=current
                break
            if not result.parents.has(current):break
            current=int(result.parents[current])
    return success(result)
static func _profile_elapsed(profile:Dictionary,phase:String,started:int)->void:profile[phase]=float(profile.get(phase,0.0))+(Time.get_ticks_usec()-started)/1000.0
