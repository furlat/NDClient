extends RefCounted
## Optional resource candidates from disclosed choices, selection and displayed records.
## No synthetic facts, outcome prediction, scene creation or texture decoding.
const Authoring = preload("res://presentation/authoring.gd")
const NativeSpells = preload("res://presentation/native_spell_authoring.gd")
const NativeActions = preload("res://presentation/native_action_authoring.gd")
const Effects = preload("res://presentation/effect_package.gd")
const Characters = preload("res://presentation/characters.gd")
const WorldRows = preload("res://presentation/world.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const EncounterMedia = preload("res://presentation/encounter_media.gd")
const NativeSupport = preload("res://presentation/native_scene_support.gd")
const Catalog = preload("res://source_catalog.gd")
const Choices = preload("res://sdk/choices.gd")

static func create() -> Dictionary:
    return {"task":-1,"pending":{},"result":{},"control":{},"cache":{},"key":[],
        "value":{},"revision":0,"closed":false,"jobs":0,"discarded":0,
        "object_rows":{},"object_contacts":{},"object_cells":{},"disclosed_objects":{},
        "owner_preview":{},"owner_result":{},"owner_rows":{},"owner_contacts":{},"owner_items":{},
        "actor_sources":{},"object_sources":{},"source_revision":0,"owner_source_revision":-1,
        "profile_active_job":{},"profile_last_job":{},"profile_last_discarded":{}}

static func _outfit(actor: Dictionary, state:Dictionary={}) -> Array:
    return [actor.get("creature_content_ref"),actor.get("appearance"),actor.get("visual_loadout"),actor.get("presentation_layers"),actor.get("life_state"),Characters.item_looks(actor,state)]

static func owners(data: Dictionary, state: Dictionary, preview: Dictionary) -> Dictionary:
    var rows: Dictionary=state.get("objects",{})
    var senses: Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    var contacts: Dictionary=senses.get("objects",{})
    var changed=not is_same(rows,data.object_rows) or not is_same(contacts,data.object_contacts)
    var items:Dictionary=state.get("items",{})
    if is_same(rows,data.owner_rows) and is_same(contacts,data.owner_contacts) and is_same(items,data.owner_items) and is_same(preview,data.owner_preview) and data.owner_source_revision==data.source_revision and not data.owner_result.is_empty():return data.owner_result
    if changed:
        data.object_rows=rows;data.object_contacts=contacts;data.object_cells={};data.disclosed_objects={}
        for id in rows:
            if not contacts.get(id,{}).get("visual",false):continue
            data.disclosed_objects[id]=rows[id]
            var cell=WorldRows.cell_key(rows[id].placement.position)
            if not data.object_cells.has(cell):data.object_cells[cell]=[]
            data.object_cells[cell].append(id)
    var recipients={}
    for field in ["affected_entity_uuids","effective_target_uuids"]:
        for id in preview.get(field,[]):recipients[id]=true
    var objects={}
    var positions: Array=Choices.preview_positions(preview,true)
    if not positions.is_empty() or not recipients.is_empty():
        for position in positions:
            for id in data.object_cells.get(WorldRows.cell_key(position),[]):objects[id]=true
        for id in recipients:
            if rows.has(id) and contacts.get(id,{}).get("visual",false):objects[id]=true
    var object_ids: Array=objects.keys();object_ids.sort()
    var recipient_ids: Array=recipients.keys();recipient_ids.sort()
    var banks={};var families={}
    for id in object_ids:
        var known: Dictionary=data.object_sources.get(id,{})
        if is_same(known.get("item"),rows[id].item):
            for bank in known.banks:banks[bank]=true
        else:banks["object:"+id]=true
    for id in recipient_ids:
        var actor: Dictionary=state.get("actors",{}).get(id,{})
        if actor.is_empty():continue
        var known: Dictionary=data.actor_sources.get(id,{})
        families["family:"+str(known.family) if known.get("signature")==_outfit(actor,state) else "actor:"+id]=true
    var object_resources: Array=banks.keys();object_resources.sort()
    var response_resources: Array=families.keys();response_resources.sort()
    data.owner_rows=rows;data.owner_contacts=contacts;data.owner_items=items
    data.owner_source_revision=data.source_revision
    data.owner_preview=preview;data.owner_result={"objects":object_ids,"recipients":recipient_ids,
        "object_resources":object_resources,"response_resources":response_resources,
        "exact":preview.get("area_preview")=="computed" or not preview.get("effective_target_uuids",[]).is_empty()}
    return data.owner_result

static func _cancelled(control: Dictionary) -> bool:
    control.mutex.lock()
    var value: bool = control.cancelled
    control.mutex.unlock()
    return value

static func cancel(data: Dictionary) -> void:
    if not data.profile_active_job.is_empty() and not data.profile_active_job.has("cancelled_usec"):
        data.profile_active_job.cancelled_usec=Time.get_ticks_usec()
    if not data.control.is_empty():
        data.control.mutex.lock(); data.control.cancelled=true; data.control.mutex.unlock()
    data.pending={}; data.key=[]
    if not data.value.is_empty(): data.value={}; data.revision+=1

static func request(data: Dictionary, key: Array, actor_uuid: String, behavior: String,
        state: Dictionary, budget_bytes: int, source_files: Dictionary = {}, preview: Dictionary = {}, eligible: Array = [], hints: Dictionary = {}, profile: String = "", behaviors: Array = [], record_profile:bool=false) -> void:
    if data.closed or key==data.key: return
    # A hover refinement replaces only unpublished work. Keep the accepted base
    # closure while the replacement metadata job prepares its exact candidates.
    if hints.is_empty():hints=owners(data,state,preview)
    var retained: Dictionary=data.value.duplicate()
    for field in ["paths","cpu_required","gpu_only","source_sizes"]:
        if retained.has(field):retained[field]=retained[field].duplicate()
    var shared_environment={}
    var shared_objects={}
    var shared_banks={}
    for bank in hints.object_resources:
        if retained.get("bank_paths",{}).has(bank):
            shared_banks[bank]=retained.bank_paths[bank]
            shared_environment.merge(retained.bank_paths[bank])
    for id in hints.objects:
        if retained.get("object_paths",{}).has(id):
            shared_objects[id]=retained.object_paths[id]
            shared_environment.merge(retained.object_paths[id])
    for path in retained.get("environment",{}):
        if shared_environment.has(path):continue
        retained.bytes-=int(retained.source_sizes.get(path,0))*(2 if retained.cpu_required.has(path) else 1)
        for field in ["paths","cpu_required","gpu_only","source_sizes"]:retained[field].erase(path)
    if not retained.is_empty():retained.environment=shared_environment;retained.object_paths=shared_objects;retained.bank_paths=shared_banks;retained.banks=shared_banks.keys()
    cancel(data)
    data.value=retained
    data.key=key.duplicate(true)
    if (behavior.is_empty() and behaviors.is_empty()) or budget_bytes<=0: return
    # Canonical after-values are immutable. Copy only membership indexes, as the
    # existing MediaWarmup snapshot does; no inventory or senses graph copying.
    var actors={}; var objects={}
    for id in state.get("actors",{}):
        var actor: Dictionary=state.actors[id]
        if WorldRows.visible_actor(actor,state): actors[id]=actor
    var senses: Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    var recipients: Array=hints.recipients
    for id in hints.objects:objects[id]=state.objects[id]
    data.pending={"key":data.key.duplicate(true),"actor_uuid":actor_uuid,"behavior":behavior,
        "state":{"actors":actors,"items":state.get("items",{}).duplicate(),"objects":objects,"tiles":{},"senses":senses},
        "budget_bytes":budget_bytes,"source_files":source_files.duplicate(),"recipients":recipients,"eligible":eligible.duplicate(),"exact_recipients":hints.exact,
        "disclosed_objects":data.disclosed_objects.duplicate(),"profile":profile,"behaviors":behaviors.duplicate(),
        "record_profile":record_profile,"requested_usec":Time.get_ticks_usec() if record_profile else 0}
    _start(data)

static func _start(data: Dictionary) -> void:
    if data.closed or data.task>=0 or data.pending.is_empty(): return
    var pending: Dictionary=data.pending
    data.pending={}; data.result={};data.control={"mutex":Mutex.new(),"cancelled":false}
    data.jobs+=1
    data.profile_active_job={}
    if pending.get("record_profile",false):
        data.profile_active_job={"job":data.jobs,"actor_uuid":pending.actor_uuid,"behavior":pending.behavior,
            "behavior_count":pending.behaviors.size(),"request_kind":"body_choices" if pending.behavior.is_empty() else "selected_action",
            "requested_usec":pending.requested_usec,"dispatched_usec":Time.get_ticks_usec(),"dispatched_frame":Engine.get_process_frames()}
    data.task=WorkerThreadPool.add_task(_work.bind(pending,data.result,data.control,data.cache),false,"Selected action media metadata")

static func poll(data: Dictionary) -> bool:
    var revision: int=data.revision
    if data.task>=0 and WorkerThreadPool.is_task_completed(data.task):
        WorkerThreadPool.wait_for_task_completion(data.task)
        var result: Dictionary=data.result
        var accepted:bool=result.get("complete",false) and result.key==data.key and not _cancelled(data.control)
        if not data.profile_active_job.is_empty():
            var completed:Dictionary=data.profile_active_job.duplicate()
            completed.merge(result.get("profile_job",{}));completed.polled_usec=Time.get_ticks_usec()
            completed.polled_frame=Engine.get_process_frames();completed.accepted=accepted
            completed.cancelled=_cancelled(data.control);completed.worker_complete=result.get("complete",false)
            data.profile_last_job=completed
            if not accepted:data.profile_last_discarded=completed
        if accepted:
            data.value=result.value;data.revision+=1
            data.actor_sources.merge(result.value.get("actor_sources",{}))
            data.object_sources.merge(result.value.get("object_sources",{}))
            data.source_revision+=1
        else: data.discarded+=1
        data.task=-1;data.result={};data.control={};data.profile_active_job={}
        _start(data)
    return data.revision!=revision

static func close(data: Dictionary) -> void:
    cancel(data);data.closed=true
    if data.task>=0: WorkerThreadPool.wait_for_task_completion(data.task)
    data.task=-1;data.result={};data.cache.clear();data.control={};data.profile_active_job={}
    data.object_rows={};data.object_contacts={};data.object_cells={};data.owner_preview={};data.owner_result={}
    data.owner_rows={};data.owner_contacts={};data.owner_items={}
    data.disclosed_objects={};data.actor_sources={};data.object_sources={}

static func _actor_paths(actor: Dictionary, clips: Array, result: Dictionary, cache: Dictionary, state:Dictionary={}) -> Dictionary:
    if clips.is_empty() or Characters.effect_owned(actor,cache): return {}
    var sources=Characters.sheet_paths(actor,clips,cache,Characters.item_looks(actor,state))
    if not sources.ok: result.errors.append(sources.error.message);return {}
    var paths: Dictionary=sources.value.duplicate()
    result.paths.merge(sources.value);result.cpu_required.merge(sources.cpu_required);result.gpu_only.merge(sources.gpu_only)
    result.normal_sets.merge(sources.get("normal_sets",{}))
    for path in sources.geometry_slots:
        var cpu: Dictionary=NativeSupport.cpu_required_paths(path,sources.geometry_slots[path],cache,true)
        for optical in NativeSupport.required_paths(path,sources.geometry_slots[path],cache).values():
            result.paths[optical]=true
            paths[optical]=true
            if cpu.has(optical):result.cpu_required[optical]=true
            elif not result.cpu_required.has(optical):result.gpu_only[optical]=true
    return paths

static func _responses(actor: Dictionary, result: Dictionary, cache: Dictionary, state:Dictionary={}) -> void:
    if actor.get("life_state")=="dead":return
    var rig: Dictionary=Authoring.rigs(cache).get(Characters.rig_id(actor,cache),{})
    var clips=[]
    for role in ["damage","death"]:
        var body: Dictionary=Authoring.body(role,actor,{},cache).get("actor",{})
        if body.get("enabled",true) and body.has("clip") and rig.get("clips",{}).has(body.clip):clips.append(body.clip)
    var paths: Dictionary=_actor_paths(actor,clips,result,cache,state)
    var key: Array=paths.keys();key.sort();key.make_read_only()
    if not cache.has("__selection_response_families"):cache.__selection_response_families={}
    if not cache.__selection_response_families.has(key):cache.__selection_response_families[key]=cache.__selection_response_families.size()
    result.actor_sources[actor.uuid]={"signature":_outfit(actor,state),"family":cache.__selection_response_families[key]}

static func _break_banks(row: Dictionary, cache: Dictionary) -> Array:
    # Enumerate actual registered alternatives, without choosing a destruction
    # outcome or altering the disclosed object. Some banks are state-specific.
    var index: Dictionary=Catalog.environment_index(cache)
    if row.kind=="wall":
        var walls: Dictionary=index.wall_destructions
        return [walls[row.material]] if walls.has(row.material) else []
    if row.kind not in ["prop","door","trap"]:return []
    var group: String={"prop":"props","door":"doors","trap":"traps"}[row.kind]
    var owner: Dictionary=index[group][row.asset]
    var banks={}
    for field in ["destructions","destructions_without_attachments"]:
        for state in owner.get(field,{}):
            if state==row.get("state","default") or (row.kind=="door" and state.begins_with(row.state+".")):
                banks[owner[field][state]]=true
    return banks.keys()

static func plan(request: Dictionary, cache: Dictionary, control: Dictionary, trace:Dictionary={}) -> Dictionary:
    var result={"paths":{},"cpu_required":{},"gpu_only":{},"environment":{},"source_sizes":{},"source_files":{},
        "errors":[],"skipped":0,"bytes":0,"actors":[],"banks":[],"object_paths":{},"bank_paths":{},"onset_paths":{},"native_selection":{},"native_action_clips":[],"native_action_conditions":[],"actor_sources":{},"object_sources":{},"normal_sets":{}}
    var state: Dictionary=request.state
    var caster: Dictionary=state.actors.get(request.actor_uuid,{})
    if caster.is_empty() or _cancelled(control):return result
    var phase_started:int=Time.get_ticks_usec() if not trace.is_empty() else 0
    var recipe: Dictionary=NativeSpells.recipe({"behavior_id":request.behavior},cache)
    if not trace.is_empty():
        trace.phases_ms.recipe=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    if _cancelled(control):return result
    if recipe.is_empty():
        # A choice names resources, not a received fact. Resolve its authored
        # body/native candidates without inventing occurrence inputs or outcomes.
        var clips={}
        var behaviors: Array=request.get("behaviors",[])
        if behaviors.is_empty():behaviors=[request.behavior]
        var native_clips:Dictionary={}
        var native_conditions:Dictionary={}
        var action_bindings:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache)
        for behavior in behaviors:
            if _cancelled(control):return result
            for clip in NativeSpells.effect_clips(NativeSpells.preparation_selection(str(behavior),cache)):
                native_clips[Effects.key(clip)]=clip
            for clip in NativeActions.effect_clips(behavior,cache):native_clips[Effects.key(clip)]=clip
            for id in action_bindings.get(behavior,{}).get("applies_conditions",[]):native_conditions[id]=true
            var body: Dictionary=Authoring.action({"kind":"action","behavior_id":behavior},cache,caster).get("actor",{})
            if body.get("enabled",true) and body.has("clip"):clips[body.clip]=true
            if behavior=="action.move" and not Characters.effect_owned(caster,cache):
                # Locomotion is authored through movement/rig contexts rather
                # than a body-action recipe. Reuse the encounter source owner's
                # finite closure before the first click, including connectors
                # and condition poses, without predicting any movement outcome.
                var index:Dictionary=Catalog.read_file("catalog-index.json",cache)
                var rig:Dictionary=Characters.rigs(cache)[Characters.rig_id(caster,cache)]
                for clip in EncounterMedia._priority_clips(caster,rig,index,cache):clips[clip]=true
                var pose:Dictionary=Authoring.ConditionPose.select(caster,Characters.rig_id(caster,cache),"move",cache)
                if not pose.is_empty():clips[pose.clip]=true
        result.native_action_clips=native_clips.values()
        result.native_action_conditions=native_conditions.keys()
        if not trace.is_empty():
            trace.phases_ms.action_descriptors=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
        if _cancelled(control):return result
        if not clips.is_empty():
            _actor_paths(caster,clips.keys(),result,cache,state)
            result.actors.append({"uuid":request.actor_uuid,"clips":clips.keys()})
            result.onset_paths=result.paths.duplicate()
        if not trace.is_empty():trace.phases_ms.body_paths=(Time.get_ticks_usec()-phase_started)/1000.0
        return _finish_plan(request,result,{},cache,control,trace)
    # Admit only the selected passive feedback operand. Its actual release
    # remains exclusively driven by a received authoritative damage fact.
    if recipe.get("damage")!=null and Catalog.residue_asset(cache).is_empty():
        result.errors.append("Cannot load selected asset metadata: particles.region.blood")
    result.native_selection=NativeSpells.preparation_selection(request.behavior,cache)
    var rigs: Dictionary=Authoring.rigs(cache)
    var actor_order: Array=[request.actor_uuid]
    actor_order.append_array(state.actors.keys().filter(func(id):return id!=request.actor_uuid))
    for id in actor_order:
        if _cancelled(control):return result
        var actor: Dictionary=state.actors[id]
        var rig: Dictionary=rigs.get(Characters.rig_id(actor,cache),{})
        if rig.is_empty():continue
        var clips={}
        var rest=Characters.rest_sample(actor,rig,cache)
        if rest.ok:clips[rest.value.clip]=true
        if id==request.actor_uuid:
            var cast: Dictionary=recipe.get("cast",{})
            if cast.get("enabled",true) and cast.has("actionClip"):clips[cast.actionClip]=true
            var recovery: Dictionary=cast.get("recovery",{})
            if recovery.get("enabled",false):clips[recovery.bodyClip]=true
            # Read raw layer metadata; Palette.prepare would decode a sheet.
            var layers: Array=cast.get("effects",[]).duplicate()
            for field in ["weaponGlow","aura"]:
                if cast.get(field)!=null:layers.append(cast[field])
            var casting: Dictionary=actor.duplicate()
            casting.presentation_layers=actor.get("presentation_layers",Characters.Appearance.actor_components(actor,cache).map(func(row):return row.layer)).duplicate()
            for layer in layers:
                if layer.get("enabled",true) and not layer.get("hidden",false):casting.presentation_layers.append(layer)
            if cast.has("actionClip"):_actor_paths(casting,[cast.actionClip],result,cache,state)
        var available: Array=clips.keys().filter(func(clip):return rig.clips.has(clip))
        _actor_paths(actor,available,result,cache,state)
        result.actors.append({"uuid":id,"clips":available})
    # These sources are needed for the opening cast and current occluders.
    # Response/death/destruction candidates below remain useful later work.
    result.onset_paths=result.paths.duplicate()
    for id in request.get("recipients",[]):
        if _cancelled(control):return result
        if recipe.get("damage")!=null and state.actors.has(id):_responses(state.actors[id],result,cache,state)
    var disclosed: Dictionary=state.duplicate()
    disclosed.objects=request.get("disclosed_objects",state.objects)
    var rows=WorldRows.rows(disclosed,cache)
    var bank_paths={}
    for row in rows.rows:
        if _cancelled(control):return result
        if recipe.get("damage")==null or row.get("destroyed",false):continue
        var selected_banks: Array=_break_banks(row,cache)
        result.object_sources[row.id]={"item":disclosed.objects[row.id].item,"banks":selected_banks}
        if not state.objects.has(row.id):continue
        var object_paths={}
        for bank_id in selected_banks:
            if bank_paths.has(bank_id):object_paths.merge(bank_paths[bank_id]);continue
            result.banks.append(bank_id)
            var paths={}
            var bank: Dictionary=Catalog.bank_data(bank_id,cache)
            for pose in bank.get("surface_frames_by_pose",{}):
                var frames: Array=bank.surface_frames_by_pose[pose]
                for index in frames.size():
                    if _cancelled(control):return result
                    var surface: Dictionary=frames[index].duplicate()
                    var region: Dictionary=bank.frames_by_pose[pose][index] if bank.has("frames_by_pose") else {"path":bank.path,"rect":[index*bank.cell[0],bank.rows.find(pose)*bank.cell[1],bank.cell[0],bank.cell[1]]}
                    if row.kind=="door" and bank.has("leaf_path"):
                        region={"path":bank.leaf_path,"rect":[index*bank.cell[0],bank.rows.find(pose)*bank.cell[1],bank.cell[0],bank.cell[1]]}
                    surface.merge({"path":region.path,"rect":region.rect,"native_size":bank.cell})
                    EnvironmentMedia.record_paths(Catalog.texture_layout(Catalog.receiving_normal(surface,cache),cache),paths,cache)
            bank_paths[bank_id]=paths;object_paths.merge(paths)
        result.environment.merge(object_paths);result.object_paths[row.id]=object_paths
    result.paths.merge(result.environment);result.cpu_required.merge(result.environment)
    for id in state.actors:
        if _cancelled(control):return result
        if recipe.get("damage")!=null and not request.get("exact_recipients",false) and id not in request.get("recipients",[]) and (request.get("eligible",[]).is_empty() or id in request.eligible):
            _responses(state.actors[id],result,cache,state)
    if not trace.is_empty():trace.phases_ms.spell_candidates=(Time.get_ticks_usec()-phase_started)/1000.0
    return _finish_plan(request,result,bank_paths,cache,control,trace)

static func _finish_plan(request: Dictionary, result: Dictionary, bank_paths: Dictionary, cache: Dictionary, control: Dictionary, trace:Dictionary={}) -> Dictionary:
    var phase_started:int=Time.get_ticks_usec() if not trace.is_empty() else 0
    for path in result.cpu_required:result.gpu_only.erase(path)
    var profile: String=request.get("profile","")
    result.normal_sets.make_read_only()
    result.paths=Characters.CharacterGeometry.for_profile(result.paths,result.normal_sets,profile,cache,"selection_paths")
    result.onset_paths=Characters.CharacterGeometry.for_profile(result.onset_paths,result.normal_sets,profile,cache,"selection_onset")
    result.cpu_required=Characters.CharacterGeometry.for_profile(result.cpu_required,result.normal_sets,profile,cache,"selection_cpu")
    result.gpu_only=Characters.CharacterGeometry.for_profile(result.gpu_only,result.normal_sets,profile,cache,"selection_gpu")
    if not trace.is_empty():
        trace.phases_ms.profile_paths=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
        trace.candidate_paths=result.paths.size();trace.candidate_onset_paths=result.onset_paths.size()
    var estimates=EncounterMedia.estimates(result.paths,result.cpu_required,result.gpu_only,cache)
    result.source_headers=cache.get("__encounter_headers",{}).duplicate()
    if not trace.is_empty():
        trace.phases_ms.headers=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var accepted={};var cpu={};var gpu={};var environment={}
    for path in result.paths:
        if _cancelled(control):return result
        var estimate: Dictionary=estimates[path]
        if not estimate.has("bytes") or result.bytes+int(estimate.bytes)>request.budget_bytes:
            result.skipped+=1;continue
        accepted[path]=Catalog.media_path(path);result.bytes+=int(estimate.bytes)
        result.source_sizes[path]=int(estimate.gpu_bytes)
        if result.cpu_required.has(path):cpu[path]=true
        if result.gpu_only.has(path):gpu[path]=true
        if result.environment.has(path):environment[path]=true
    result.paths=accepted;result.cpu_required=cpu;result.gpu_only=gpu;result.environment=environment
    var onset:Dictionary={}
    for path in result.onset_paths:
        if accepted.has(path):onset[path]=true
    result.onset_paths=onset
    for id in result.object_paths:
        var retained_paths={}
        for path in result.object_paths[id]:
            if accepted.has(path):retained_paths[path]=true
        result.object_paths[id]=retained_paths
    for bank in bank_paths:
        var retained_paths={}
        for path in bank_paths[bank]:
            if accepted.has(path):retained_paths[path]=true
        result.bank_paths[bank]=retained_paths
    if not trace.is_empty():
        trace.phases_ms.budget_paths=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    result.source_files=Catalog.source_snapshot(cache)
    if not trace.is_empty():trace.phases_ms.source_snapshot=(Time.get_ticks_usec()-phase_started)/1000.0
    return result

static func _work(request: Dictionary, result: Dictionary, control: Dictionary, cache: Dictionary) -> void:
    var started=Time.get_ticks_usec()
    var trace:Dictionary={"phases_ms":{},"worker_started_usec":started} if request.get("record_profile",false) else {}
    Catalog.adopt_snapshot(cache,request.source_files)
    if not trace.is_empty():trace.phases_ms.adopt_snapshot=(Time.get_ticks_usec()-started)/1000.0
    var value=plan(request,cache,control,trace)
    if not trace.is_empty():
        trace.worker_finished_usec=Time.get_ticks_usec();trace.worker_elapsed_ms=(trace.worker_finished_usec-started)/1000.0
        trace.accepted_paths=value.paths.size();trace.onset_paths=value.onset_paths.size()
        trace.source_headers=value.get("source_headers",{}).size();trace.source_files=value.get("source_files",{}).size()
        result.profile_job=trace
    if _cancelled(control):return
    result.key=request.key;result.value=value;result.elapsed_ms=(Time.get_ticks_usec()-started)/1000.0;result.complete=true
