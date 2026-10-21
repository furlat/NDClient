extends RefCounted
## Display-only projection. Every clip/member is an unchanged indexed row.
const Tracks=preload("res://presentation/tracks.gd")

static func action_id(row:Dictionary,by_id:Dictionary)->String:
    var chain:Array=[]
    var id:String=row.id
    while by_id.has(id):
        var current:Dictionary=by_id[id]
        chain.append(current)
        id=current.parent
    # A real reaction is its own action even when caused by movement or a spell.
    for current in chain:
        var event:Dictionary=current.get("event",{})
        if str(event.get("behavior_id","")).begins_with("reaction."):return current.id
    for current in chain:
        var event:Dictionary=current.get("event",{})
        if event.get("kind")=="spell":
            if not event.has("cast_owner_event") or not event.has("sequence"):return current.id
            var owner="%s:%s"%[event.sequence,event.cast_owner_event]
            return owner if by_id.has(owner) else current.id
    # Opportunity attacks must not become another movement segment. Their real
    # attack event remains inspectable separately under the original hierarchy.
    for current in chain:
        if current.get("event",{}).get("kind")=="attack":return current.id
    for current in chain:
        if current.get("event",{}).get("kind")=="movement":return current.id
    for i in range(chain.size()-1,-1,-1):
        if chain[i].kind=="event":return chain[i].id
    return chain.back().id if not chain.is_empty() else row.id

static func lane_key(row:Dictionary)->Array:
    var component:Dictionary=row.get("component",{})
    if row.kind=="body":return ["body",row.track.actor_uuid,row.track.clip]
    if row.kind=="native_effect":return [row.kind,component.get("spell_id",""),component.get("source_id",""),component.get("native_clip",{}).get("id",""),component.get("native_cue",{}).get("role","effect"),row.get("source_perspective","")]
    if row.kind=="audio":return [row.kind,component.get("cue_id",row.label)]
    return [row.kind,row.get("source_perspective","")]

static func source_label(row:Dictionary)->String:
    var component:Dictionary=row.get("component",{})
    if not component.get("native_spell",false):return row.label
    var role:String=component.get("native_cue",{}).get("role",row.label)
    var label=str(component.get("spell_id","")).capitalize()+" · "+role.capitalize()
    var phase:String=str(component.get("native_clip",{}).get("id","")).get_file()
    if role=="attached" and not phase.is_empty() and phase!=role:label+=" · "+phase.capitalize()
    return label

static func project(source:Array,visible:Dictionary,by_id:Dictionary,preview_kinds:Array,collapsed:Dictionary)->Dictionary:
    var actions={};var order:Array=[];var owner_of={};var raw_to_display={};var owned={};var bodies={}
    for row in source:
        if row.kind=="body":
            var key=JSON.stringify([row.group_id,row.track.actor_uuid])
            if not bodies.has(key):bodies[key]=[]
            bodies[key].append(row)
        var owner=action_id(row,by_id);owner_of[row.id]=owner
        if not owned.has(owner):owned[owner]=[]
        owned[owner].append(row)
        if not visible.has(row.id):continue
        if row.kind in ["event","perspective"]:continue
        if row.kind in ["parts","part","condition","condition_exit","condition_state","temporary_hp_grant"] and row.get("status")!="missing":continue
        if not actions.has(owner):
            actions[owner]={"raw":[],"lanes":{},"missing":[],"other":[]}
            order.append(owner)
        actions[owner].raw.append(row)
    var roots:Array=[];var children={};var display={}
    for owner in order:
        # Expanded original ancestry owns its nested reactions while visible.
        # Do not also publish those same raw IDs as independent compact roots.
        var owner_ancestor:String=by_id.get(owner,{}).get("parent","")
        var covered=false
        while by_id.has(owner_ancestor):
            if not collapsed.get("display:details:"+owner_ancestor,true):covered=true;break
            owner_ancestor=by_id[owner_ancestor].parent
        if covered:continue
        var data:Dictionary=actions[owner]
        if by_id.get(owner,{}).get("kind","") not in ["event","condition","condition_exit","temporary_hp_grant"]:
            for row in data.raw:roots.append(row);display[row.id]=row;raw_to_display[row.id]=row.id
            continue
        var header:Dictionary=by_id.get(owner,data.raw[0]).duplicate()
        header.display_action=true;header.action_id=owner
        header.start_ms=data.raw[0].start_ms;header.end_ms=data.raw[0].end_ms
        var motion_lanes={};var audio:Array=[];var recipients={}
        for event_row in owned[owner]:
            if event_row.kind!="event":continue
            var target=event_row.event.get("target_uuid")
            if event_row.event.get("kind")=="spell" and target!=null:recipients[target]=true
        header.recipient_ids=recipients.keys()
        if recipients.size()>1:header.label+=" · %d recipients"%recipients.size()
        for row in data.raw:
            header.start_ms=minf(header.start_ms,row.start_ms);header.end_ms=maxf(header.end_ms,row.end_ms)
            if row.get("status")=="missing":data.missing.append(row);continue
            if row.kind=="audio":audio.append(row);continue
            if row.kind not in preview_kinds:data.other.append(row);continue
            _add_clip(data.lanes,row,owner)
            if row.kind=="body" and row.track.get("motion",false):motion_lanes[row.id]=JSON.stringify(lane_key(row))
        for row in audio:
            var component:Dictionary=row.component
            var body_id:String=component.get("body_track_id","")
            # Step ownership is semantic data; unrelated sound cues stay lanes.
            var event:Dictionary=by_id.get(row.parent,{}).get("event",{})
            if event.get("kind")=="step" and motion_lanes.has(body_id):
                data.lanes[motion_lanes[body_id]].cues.append(row)
            else:_add_clip(data.lanes,row,owner)
        roots.append(header);display[header.id]=header;children[owner]=[]
        for lane in data.lanes.values():
            var motion:bool=lane.clips[0].kind=="body" and lane.clips[0].track.get("motion",false)
            if motion:lane.windows=_motion_windows(lane,bodies)
            lane.clips.sort_custom(func(a,b):return a.start_ms<b.start_ms)
            var ends:Array=[];var bands={}
            lane.phase_strip=lane.clips.size()>1 and lane.clips[0].get("component",{}).get("native_spell",false)
            for clip in lane.clips:
                var band=0
                while not motion and not lane.phase_strip and band<ends.size() and ends[band]>clip.start_ms:band+=1
                if band==ends.size():ends.append(clip.end_ms)
                else:ends[band]=clip.end_ms
                bands[clip.id]=band;raw_to_display[clip.id]=lane.id
            lane.bands=bands;lane.band_count=maxi(1,ends.size())
            lane.label=source_label(lane.clips[0])+" · %d"%lane.clips.size()
            if lane.phase_strip:
                lane.label+=" deliveries" if lane.clips[0].component.native_cue.role in ["flight","impact"] else " clips"
                lane.phase_windows=_phase_windows(lane.clips)
                children[lane.id]=lane.clips
                for clip in lane.clips:
                    display[clip.id]=clip
                    if not collapsed.get(lane.id,true):raw_to_display[clip.id]=clip.id
            if lane.clips[0].kind=="body":lane.label=str(lane.clips[0].track.clip).to_snake_case().capitalize()+" · %d segments"%lane.clips.size()
            for cue in lane.cues:raw_to_display[cue.id]=lane.id
            # One source needs no synthetic wrapper or changed selection ID.
            if lane.clips.size()==1 and lane.cues.is_empty():
                var single:Dictionary=lane.clips[0]
                children[owner].append(single);display[single.id]=single;raw_to_display[single.id]=single.id
            else:children[owner].append(lane);display[lane.id]=lane
        for row in data.other:children[owner].append(row);display[row.id]=row;raw_to_display[row.id]=row.id
        if not data.missing.is_empty():
            var kinds={}
            for requirement in data.missing:kinds[requirement.label]=kinds.get(requirement.label,0)+1
            var descriptions:Array=[]
            for label in kinds:descriptions.append(str(label)+" ×"+str(kinds[label]))
            var missing={"id":"display:missing:"+owner,"parent":owner,"kind":"missing_group","action_id":owner,
                "label":"Missing work · %d kinds / %d records"%[kinds.size(),data.missing.size()],"summary":"; ".join(descriptions),"start_ms":header.start_ms,"end_ms":header.end_ms,
                "members":data.missing,"status":"missing"}
            children[owner].append(missing);children[missing.id]=data.missing;display[missing.id]=missing
            for row in data.missing:raw_to_display[row.id]=missing.id
        var detail={"id":"display:details:"+owner,"parent":owner,"kind":"action_details","action_id":owner,
            "label":"Details · original hierarchy","start_ms":header.start_ms,"end_ms":header.end_ms}
        children[owner].append(detail);display[detail.id]=detail
        children[detail.id]=[]
        if not collapsed.get(detail.id,true):
            children[owner]=[detail]
        if not collapsed.get(detail.id,true):
            var members={}
            for row in source:
                if row.id==owner:continue
                var belongs=owner_of[row.id]==owner
                var ancestor:String=row.parent
                while not belongs and by_id.has(ancestor):
                    belongs=ancestor==owner;ancestor=by_id[ancestor].parent
                if belongs:members[row.id]=row
            for row in members.values():
                raw_to_display[row.id]=row.id
                var parent:String=row.parent if members.has(row.parent) else detail.id
                if not children.has(parent):children[parent]=[]
                children[parent].append(row)
    return {"roots":roots,"children":children,"display":display,"raw_to_display":raw_to_display,"owner_of":owner_of}

static func _phase_windows(clips:Array)->Array:
    var boundaries:Array=[];var windows:Array=[]
    for clip in clips:
        for at in [clip.start_ms,clip.end_ms]:
            if at not in boundaries:boundaries.append(at)
    boundaries.sort()
    for i in range(1,boundaries.size()):
        var first:float=boundaries[i-1];var last:float=boundaries[i]
        var active:Array=clips.filter(func(clip):return clip.start_ms<last and clip.end_ms>first)
        if not active.is_empty():windows.append({"start_ms":first,"end_ms":last,"clips":active,"cell_width":74.0*active.size()})
    return windows

static func _motion_windows(lane:Dictionary,bodies:Dictionary)->Array:
    var groups={};var members={};var windows:Array=[]
    for row in lane.clips:
        members[row.id]=row
        var key=JSON.stringify([row.group_id,row.track.actor_uuid])
        if not groups.has(key):groups[key]={"start_ms":row.start_ms,"end_ms":row.end_ms}
        groups[key].start_ms=minf(groups[key].start_ms,row.start_ms)
        groups[key].end_ms=maxf(groups[key].end_ms,row.end_ms)
    for key in groups:
        var span:Dictionary=groups[key];var candidates:Array=bodies[key]
        var boundaries:Array=[span.start_ms,span.end_ms]
        for row in candidates:
            for at in [row.start_ms,row.end_ms]:
                if at>span.start_ms and at<span.end_ms and at not in boundaries:boundaries.append(at)
        boundaries.sort()
        var tracks:Array=candidates.map(func(row):return row.track)
        for i in range(1,boundaries.size()):
            var first:float=boundaries[i-1];var last:float=boundaries[i]
            var sampled=Tracks.samples(tracks,(first+last)*.5-candidates[0].group_start_ms)
            var id:String=sampled.get(candidates[0].track.actor_uuid,{}).get("trace_track_id","")
            if not members.has(id):continue
            if not windows.is_empty() and windows.back().row.id==id and windows.back().end_ms==first:windows.back().end_ms=last
            else:windows.append({"row":members[id],"start_ms":first,"end_ms":last})
    windows.sort_custom(func(a,b):return a.start_ms<b.start_ms)
    return windows

static func _add_clip(lanes:Dictionary,row:Dictionary,owner:String)->void:
    var key=JSON.stringify(lane_key(row))
    if not lanes.has(key):
        lanes[key]={"id":"display:lane:"+owner+":"+key,"parent":owner,"action_id":owner,"kind":"compact_lane",
            "label":row.label,"clips":[],"cues":[],"start_ms":row.start_ms,"end_ms":row.end_ms,"status":"available"}
    lanes[key].clips.append(row)
    lanes[key].start_ms=minf(lanes[key].start_ms,row.start_ms)
    lanes[key].end_ms=maxf(lanes[key].end_ms,row.end_ms)
