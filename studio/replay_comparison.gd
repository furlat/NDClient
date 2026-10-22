extends RefCounted
## Offline common clock. It joins recorded causes, never audience state or cursors.
const EPS=0.00001

static func _canonical(value:Variant)->Variant:
    if value is Array:return value.map(func(item):return _canonical(item))
    if not value is Dictionary:return value
    var result:Dictionary={};var keys:Array=value.keys();keys.sort()
    for key in keys:
        # These are seat-local references, not factual correspondence operands.
        if key in ["commit_occurrence","applied_source_event_cursor"]:continue
        result[key]=_canonical(value[key])
    return result

static func _fact_operands(fact:Dictionary)->Dictionary:
    if fact.kind!="actor_change":return fact
    var actors:Array=[]
    for actor in fact.actors:
        var rows:Array=[]
        for row in actor.rows:
            if row.field!="condition":rows.append(row);continue
            # The public owner UUID names the membership edge. A controlled
            # seat may additionally know duration/private owner state; matching
            # that edge does not disclose or merge those independent values.
            rows.append({"field":"condition","condition_uuid":row.condition_uuid,
                "member":null if row.get("member")==null else {"behavior_id":row.member.behavior_id}})
        actors.append({"actor_uuid":actor.actor_uuid,"rows":rows})
    return {"kind":"actor_change","actors":actors}

## Read once from original packets, before presentation projection. A candidate
## is evidence only when unique in each participating view; equal integers are
## never a cross-audience identity. Sensory rows describe a specific observer.
static func packet_causes(packet:Dictionary)->Dictionary:
    var result:Dictionary={}
    for group in packet.get("lineages",[]):
        for node in group.get("events",[]):
            var fact:Variant=node.get("fact")
            if fact==null or node.get("canceled",false) or fact.kind in ["sensory","audience"]:continue
            var application:Variant=null
            if node.get("resolution")!=null:application=group.get("resolutions",[])[int(node.resolution)].get("application_id")
            var execution:Variant=node.get("turn_execution_id")
            if execution==null and application==null:continue
            result[str(node.occurrence)]=JSON.stringify([execution,application,_canonical(_fact_operands(fact))])
    return result

static func correspondence(bundle:Dictionary)->void:
    var candidates:Dictionary={}
    for view in bundle.views:
        var index:Dictionary=bundle.views[view]
        index.correspondence={};index.group_correspondence={}
        for occurrence in index.get("correspondence_candidates",{}):
            var key:String=index.correspondence_candidates[occurrence]
            if not candidates.has(key):candidates[key]={}
            if not candidates[key].has(view):candidates[key][view]=[]
            candidates[key][view].append(str(occurrence))
    for key in candidates:
        var matches:Dictionary=candidates[key]
        if matches.size()<2 or matches.values().any(func(values):return values.size()!=1):continue
        for view in matches:bundle.views[view].correspondence[matches[view][0]]="shared:"+key
    # Packet cursors, command numbers, occurrences and lineages are all local
    # to a seat. Groups without a proven shared fact keep private boundaries.

static func event_key(index:Dictionary,view:String,occurrence:String)->String:
    return index.get("correspondence",{}).get(occurrence,"view:"+view+":event:"+occurrence)

static func group_key(index:Dictionary,view:String,group:String)->String:
    return index.get("group_correspondence",{}).get(group,"view:"+view+":group:"+group)

static func _node(graph:Dictionary,id:String)->String:
    if not graph.times.has(id):graph.times[id]=0.0
    return id

static func _edge(graph:Dictionary,from:String,to:String,delay:float)->void:
    _node(graph,from);_node(graph,to)
    graph.edges.append([from,to,delay])

static func _equal(graph:Dictionary,a:String,b:String,offset:float=0)->void:
    _edge(graph,a,b,offset);_edge(graph,b,a,-offset)

static func _root(parents:Array,n:int)->int:
    while parents[n]!=n:n=parents[n]
    return n

static func _union(parents:Array,a:int,b:int)->void:
    var x=_root(parents,a);var y=_root(parents,b)
    if x!=y:parents[maxi(x,y)]=mini(x,y)

static func _failure(message:String)->Dictionary:
    return {"ok":false,"error":"Replay comparison: "+message}

static func _track_keys(group:Dictionary,view:String)->Array:
    var counts={};var result:Array=[]
    for track in group.actor_tracks:
        var role="%s:%s:%s:%s:%s"%[track.source_event_uuid,track.actor_uuid,track.get("activity",""),track.priority,track.get("motion",false)]
        var count:int=counts.get(role,0);counts[role]=count+1
        # A shared fact may have different native clips/rates in each admitted
        # view. Share its event/commit anchors, not its body-start clock: the
        # shorter source can hold before playing at its original rate.
        result.append("body:"+view+":"+role+":"+str(count))
    return result

static func build(bundle:Dictionary)->Dictionary:
    if not bundle.get("ok",false) or bundle.get("views",{}).is_empty():return _failure("No independently admitted views")
    var entries:Array=[];var parents:Array=[];var identities={};var per_view={}
    for view in bundle.views:
        per_view[view]=[]
        var index:Dictionary=bundle.views[view]
        for i in index.groups.size():
            var item:Dictionary=index.groups[i];var n=entries.size()
            entries.append({"view":view,"index":i,"item":item});parents.append(n);per_view[view].append(n)
            var ids=[group_key(index,str(view),str(item.group.id))]
            for event in item.group.get("events",[]):
                ids.append(event_key(index,str(view),str(event.event_uuid)))
            for id in ids:
                if identities.has(id):_union(parents,n,identities[id])
                else:identities[id]=n
    var blocks={};var membership={}
    for n in entries.size():
        var key="block:"+str(_root(parents,n));membership[n]=key
        if not blocks.has(key):blocks[key]={"id":key,"members":{},"event_ids":{}}
        var entry:Dictionary=entries[n]
        if blocks[key].members.has(entry.view):return _failure("One shared causal block spans several groups in "+str(entry.view)+"; explicit subdivision is required")
        blocks[key].members[entry.view]=n
        for event in entry.item.group.get("events",[]):blocks[key].event_ids[event_key(bundle.views[entry.view],str(entry.view),str(event.event_uuid))]=true
    var graph={"times":{},"edges":[]};_node(graph,"origin")
    var descriptors={}
    for view in per_view:
        var previous="origin";var previous_local_end=0.0
        for n in per_view[view]:
            var entry:Dictionary=entries[n];var item:Dictionary=entry.item;var group:Dictionary=item.group
            var block:String=membership[n];var begin=block+":start";var end=block+":end"
            _edge(graph,previous,begin,maxf(0,item.start_ms-previous_local_end))
            _edge(graph,begin,end,group.duration_ms)
            previous=end;previous_local_end=item.start_ms+group.duration_ms
            var d={"block":block,"start":begin,"end":end,"events":{},"commits":[],"tracks":_track_keys(group,view)}
            var commits={}
            for commit in group.commits:
                if commit.has("event_uuid"):commits[commit.event_uuid]=commit
            for event in group.get("events",[]):
                var identity:String=event_key(bundle.views[view],str(view),str(event.event_uuid))
                var commit:String="commit:"+identity
                var start:String="start:"+identity if event.kind!="undisclosed" else commit
                var finish:String="end:"+identity if event.kind!="undisclosed" else commit
                d.events[event.event_uuid]={"start":start,"end":finish,"commit":commit,"event":event}
                _edge(graph,begin,start,event._start_ms)
                if event.kind!="undisclosed":_edge(graph,start,finish,event._end_ms-event._start_ms)
                _edge(graph,finish,end,0)
                if commits.has(event.event_uuid):
                    var at:float=commits[event.event_uuid].at_ms
                    if event.kind!="undisclosed":_edge(graph,start,commit,at-event._start_ms)
                    if event.kind!="undisclosed" and absf(at-event._start_ms)<EPS:_equal(graph,start,commit)
                    elif event.kind!="undisclosed" and absf(at-event._end_ms)<EPS:_equal(graph,finish,commit)
            for event in group.get("events",[]):
                if not d.events.has(event.get("parent_event")):continue
                var parent:Dictionary=d.events[event.parent_event];var child:Dictionary=d.events[event.event_uuid]
                if parent.event.kind!="undisclosed" and event.kind!="undisclosed":
                    _edge(graph,parent.start,child.start,event._start_ms-parent.event._start_ms)
                    if parent.event._end_ms+EPS>=event._end_ms:_edge(graph,child.end,parent.end,0)
            var prior=begin;var prior_at=0.0
            for i in group.commits.size():
                var commit:Dictionary=group.commits[i]
                var key:String="commit:"+event_key(bundle.views[view],str(view),str(commit.event_uuid)) if commit.has("event_uuid") else end
                _edge(graph,prior,key,maxf(0,commit.at_ms-prior_at));_edge(graph,key,end,0)
                d.commits.append(key);prior=key;prior_at=commit.at_ms
            for i in group.actor_tracks.size():
                var track:Dictionary=group.actor_tracks[i];var key:String=d.tracks[i]
                var event:Dictionary=d.events.get(track.source_event_uuid,{})
                if event.is_empty():return _failure("Body source event is absent: "+str(track.source_event_uuid))
                _edge(graph,event.start,key,track.start_ms-event.event._start_ms)
                _edge(graph,key,end,track.duration_ms)
                var at:float=commits[track.source_event_uuid].at_ms
                if at>=track.start_ms-EPS:
                    _edge(graph,key,event.commit,at-track.start_ms)
                    if at<=track.start_ms+track.duration_ms+EPS:_equal(graph,key,event.commit,at-track.start_ms)
            descriptors[n]=d
    # Difference constraints preserve each native interval and add holds only.
    # A positive cycle means the recorded views cannot satisfy these anchors.
    var changed=false
    for iteration in graph.times.size():
        changed=false
        for edge in graph.edges:
            var value:float=graph.times[edge[0]]+edge[2]
            if value>float(graph.times[edge[1]])+EPS:graph.times[edge[1]]=value;changed=true
        if not changed:break
    if changed:return _failure("Conflicting recorded causal/animation anchors; comparison was not stretched or reordered")
    var result={"ok":true,"views":{},"schedule":[],"blocks":[],"duration_ms":0.0,"presentation_end_ms":0.0,"mappings":{}}
    for key in blocks:
        var block:Dictionary=blocks[key]
        result.blocks.append({"id":key,"start_ms":graph.times[key+":start"],"end_ms":graph.times[key+":end"],"event_ids":block.event_ids.keys(),"views":block.members.keys()})
        result.duration_ms=maxf(result.duration_ms,graph.times[key+":end"])
    for view in per_view:
        var original:Dictionary=bundle.views[view]
        var projected={"groups":[],"operations":{},"cache":original.cache,"directory":original.directory}
        var mapping:Array=[]
        for n in per_view[view]:
            var item:Dictionary=entries[n].item;var d:Dictionary=descriptors[n]
            var transformed=_retime(item,d,graph.times)
            if not transformed.ok:return transformed
            var common:Dictionary=transformed.item
            projected.groups.append(common)
            if not projected.operations.has(common.group.operation_sequence):projected.operations[common.group.operation_sequence]=[]
            projected.operations[common.group.operation_sequence].append(common.group)
            mapping.append({"group_id":item.group.id,"original_start_ms":item.start_ms,"common_start_ms":common.start_ms,
                "original_duration_ms":item.group.duration_ms,"common_duration_ms":common.group.duration_ms,
                "events":transformed.mapping,"commits":[]})
            for i in common.group.commits.size():
                var commit:Dictionary=common.group.commits[i]
                var cut={"view":view,"group_index":projected.groups.size()-1,"group_id":common.group.id,"commit_prefix":i+1,
                    "event_uuid":commit.get("event_uuid",""),"source_index":commit.source_index,
                    "correspondence_key":event_key(original,str(view),str(commit.get("event_uuid",""))),
                    "local_ms":item.start_ms+item.group.commits[i].at_ms,"common_ms":common.start_ms+commit.at_ms}
                result.schedule.append(cut);mapping[-1].commits.append(cut)
        projected.duration_ms=result.duration_ms
        result.views[view]=projected;result.mappings[view]=mapping
    result.schedule.sort_custom(func(a,b):
        if absf(a.common_ms-b.common_ms)>EPS:return a.common_ms<b.common_ms
        if a.view!=b.view:return a.view<b.view
        if a.group_index!=b.group_index:return a.group_index<b.group_index
        return a.commit_prefix<b.commit_prefix)
    for i in result.schedule.size():result.schedule[i].ordinal=i
    return result

static func _retime(item:Dictionary,d:Dictionary,times:Dictionary)->Dictionary:
    var group:Dictionary=item.group.duplicate(true)
    var base:float=times[d.start];group.preview_start_ms=base;group.duration_ms=times[d.end]-base
    var event_shift={};var mapping={};var tracks={};var commits={}
    for event in group.get("events",[]):
        var entry:Dictionary=d.events[event.event_uuid]
        var old:float=event._start_ms;var start:float=times[entry.start]-base
        event_shift[event.event_uuid]=start-old
        mapping[event.event_uuid]={"original_start_ms":item.start_ms+old,"common_start_ms":base+start,
            "original_commit_ms":item.start_ms+event._commit_ms,"common_commit_ms":times[entry.commit]}
        event._start_ms=start;event._end_ms=times[entry.end]-base
        event._commit_ms=times[entry.commit]-base;event._group_duration_ms=group.duration_ms
        event._admit_ms+=event_shift[event.event_uuid]
        if event.has("damage_timing"):
            for field in ["start","hp","flash","number"]:event.damage_timing[field]+=event_shift[event.event_uuid]
    for i in group.commits.size():
        group.commits[i].at_ms=times[d.commits[i]]-base
        if group.commits[i].has("event_uuid"):commits[group.commits[i].event_uuid]=group.commits[i]
    for i in group.actor_tracks.size():
        var track:Dictionary=group.actor_tracks[i]
        var shift:float=times[d.tracks[i]]-base-track.start_ms
        for field in ["start_ms","contact_ms","impact_ms"]:
            if track.has(field):track[field]+=shift
        tracks[track.trace_track_id]={"track":track,"shift":shift}
    for component in group.get("components",[]):
        var shift:float=event_shift.get(component.source_event_uuid,0.0)
        # Audio can begin before its visual contact. Choose its semantic timing
        # owner using the contact, then translate the whole unchanged clip.
        var anchor:float=component.get("impact_at_ms",component.get("contact_ms",component.start_ms))
        var body_id:String=component.get("body_track_id","")
        var source_track:Dictionary=component.get("source_track",{})
        if body_id.is_empty() and source_track.get("source_event_uuid")==component.source_event_uuid:body_id=source_track.get("trace_track_id","")
        if tracks.has(body_id):shift=tracks[body_id].shift
        else:
            var old_event:Dictionary=d.events.get(component.source_event_uuid,{}).get("event",{})
            if not old_event.is_empty() and absf(anchor-old_event._commit_ms)<EPS:
                shift=commits[component.source_event_uuid].at_ms-anchor
            else:
                for old in item.group.actor_tracks:
                    if old.source_event_uuid==component.source_event_uuid and anchor>=old.start_ms-EPS and anchor<=old.start_ms+old.duration_ms+EPS:
                        shift=tracks[old.trace_track_id].shift;break
        component.start_ms+=shift
        if component.has("contact_ms"):component.contact_ms+=shift
        if component.has("impact_at_ms"):component.impact_at_ms+=shift
        if component.has("source_track"):
            var old_id:String=component.source_track.get("trace_track_id","")
            if tracks.has(old_id):component.source_track=tracks[old_id].track
    var component_lookup={}
    for component in group.get("components",[]):component_lookup[component.id]=component
    for event in group.get("events",[]):
        for requirement in event.components:
            var id:String=requirement.get("trace_track_id","")
            if tracks.has(id):
                requirement.start_ms=tracks[id].track.start_ms;requirement.end_ms=requirement.start_ms+tracks[id].track.duration_ms
            elif component_lookup.has(id):
                requirement.start_ms=component_lookup[id].start_ms;requirement.end_ms=requirement.start_ms+component_lookup[id].duration_ms
            else:
                for field in ["start_ms","end_ms"]:
                    if requirement.has(field):requirement[field]+=event_shift[event.event_uuid]
                if requirement.get("timing",{}).get("resolved",false):
                    requirement.timing.start_ms+=event_shift[event.event_uuid];requirement.timing.end_ms+=event_shift[event.event_uuid]
        event._admit_ms=minf(event._commit_ms,event._admit_ms)
    # Staged source admission follows the same witnesses as the compiler,
    # evaluated on the aligned clocks; no actor/tile facts are added.
    for actor in group.staged_actors:
        var at:float=group.duration_ms
        for commit in group.commits:
            if commit.delta.get("actors",{}).has(actor):at=minf(at,commit.at_ms)
        for track in group.actor_tracks:
            if track.actor_uuid==actor or track.get("target_uuid")==actor:at=minf(at,track.start_ms)
        group.staged_at_ms[actor]=at
    for key in group.staged_tiles:
        var at:float=group.duration_ms
        for commit in group.commits:
            if commit.delta.get("tiles",{}).has(key):at=minf(at,commit.at_ms)
        for actor in group.staged_actors:
            var point:Variant=group.staged_actors[actor].last_visual_position
            if point!=null and "%d,%d"%[point[0],point[1]]==key:at=minf(at,group.staged_at_ms[actor])
        for track in group.actor_tracks:
            for field in ["from_position","to_position","target_position"]:
                var point:Variant=track.get(field)
                if point!=null and "%d,%d"%[point[0],point[1]]==key:at=minf(at,track.start_ms)
        group.staged_tile_at_ms[key]=at
    return {"ok":true,"item":{"start_ms":base,"group":group},"mapping":mapping}
