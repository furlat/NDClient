extends RefCounted
## The Factory's VFX package (agent_docs/VFX_PACKAGE_CONTRACT_2026-10-18.md):
## finished files under res://assets/vfx/, loaded as they are. index.json lists
## every clip with its approaches: `recorded` (particle states per source
## frame, played by baked_effect.gd with this client's shaders), `gpu` and
## `native` (a constructor script sampled live, timed by the package's shared
## occurrence clock). Staging names clips; this resolves the package clip,
## picks the approach that plays, loads and warms it ahead of use, and builds,
## places, samples and retires its occurrences. The renderer owns the clock.
const Baked=preload("res://presentation/baked_effect.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const Native=preload("res://presentation/native_effects.gd")
const SOURCE_TABLE:="res://assets/vfx/format/speed-completion-20261021-source-resources.json"
const INDEX:="res://assets/vfx/index.json"
## Conditions whose package lifecycle the client keeps from playing.
const LIFECYCLES:="condition_lifecycles.json"
const Metadata=preload("res://presentation/source_metadata.gd")
const AbilityDocuments=preload("res://presentation/ability_documents.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
## Played when a clip has it and no kind is requested: recorded, else gpu, else native.
const KINDS:=["recorded","gpu","native"]
const LABELS:={"recorded":"Recorded","gpu":"GPU","native":"Native"}
## `-- --effect-kind=recorded|gpu|native` (game and Studio) plays that kind
## wherever a clip has it; the Studio's Inspect menu changes it while running.
static var requested:String=_launch_kind()
## Bumped with `requested`; preparation and warm-up keys include the kind.
static var revision:int=0
static var _mutex:Mutex=Mutex.new()
static var _clips:Dictionary={}
static var _selections:Dictionary={}
static var _condition_selection_keys:Dictionary={}
static var _conditions:Dictionary={}
static var _client:Dictionary={}
static var _phases:Dictionary={}
static var _clock:Script
static var _immutable_preparation:String=""
static var _loaded:bool=false

static func _launch_kind()->String:
    for argument in OS.get_cmdline_user_args():
        if not argument.begins_with("--effect-kind="):continue
        var kind:String=argument.trim_prefix("--effect-kind=")
        if kind in KINDS:return kind
        push_warning("Unknown --effect-kind (recorded, gpu or native): "+kind)
    return ""

static func set_requested(kind:String)->void:
    if kind==requested:return
    requested=kind;revision+=1

## Reload: the next request reads the package index again.
static func invalidate()->void:
    _mutex.lock()
    _loaded=false;_clips={};_selections={};_condition_selection_keys={};_conditions={};_client={};_phases={};_immutable_preparation=""
    _mutex.unlock()

static func _load()->void:
    _mutex.lock()
    if not _loaded:
        _loaded=true
        var index:Variant=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
        if index is Dictionary:
            for clip in index.get("clips",[]):_clips[clip.clip_id]=clip
            for selection in index.get("selections",[]):
                _selections[str(selection.get("spell_id",selection.key))]=selection
                if selection.has("condition"):_condition_selection_keys[str(selection.key)]=selection
                for id in selection.get("condition",{}).get("owner_ids",[]):
                    if not _conditions.has(id):_conditions[id]=[]
                    _conditions[id].append(selection)
            # The client can keep a package lifecycle from playing (abilities source).
            var listed:Variant=AbilityDocuments.read(LIFECYCLES)
            for id in (listed.get("suppressed",[]) if listed is Dictionary else []):_conditions.erase(id)
            _clock=Metadata.read(index.get("runtime",{}).get("clock",""),ResourceLoader.CACHE_MODE_REUSE) as Script
            _immutable_preparation=str(index.get("runtime",{}).get("production_construction",{}).get("immutable_preparation",""))
        else:push_error("VFX package index cannot be read: "+INDEX)
    _mutex.unlock()

## Passive package metadata only; the Session preparer owns this first read
## before publishing initialization. Clock textures remain scene-thread work.
static func prepare_metadata()->void:
    _load()

## The shared occurrence clock's texture and global uniform exist before any
## package material compiles (its live materials read `vfx_package_clock`).
static func _ensure_clock()->void:
    _load()
    if _clock!=null:_clock.ensure_pool()

## The package clip staged as `staged_id` in `spell`'s cue with `role`: the
## same id; else the spell's selection clip renamed from it (`<id>/source-…`,
## one per source); else the selection's only cue in that role. {} when none.
static func resolve(staged_id:String,spell:String,role:String="")->Dictionary:
    _load()
    var id:String=staged_id
    if not _clips.has(id):
        var selection:Dictionary=_selections.get(spell,{})
        var renamed:Array=selection.get("clips",[]).filter(func(value):return str(value).begins_with(staged_id+"/"))
        var roles:Array=selection.get("staging",{}).get("cues",[]).filter(func(cue):return not role.is_empty() and cue.get("role")==role and _clips.has(str(cue.get("clip",""))))
        if renamed.size()==1:id=renamed[0]
        elif roles.size()==1:id=roles[0].clip
        else:return {}
    return clip(id)

## A typed standalone assignment is admitted only from the delivered public
## table. Reuse the existing phase/clip metadata caches without altering the
## indexed inventory or its condition selections.
static func for_cue(cue:Dictionary,spell:String="",role:String="")->Dictionary:
    var path:String=str(cue.get("source_phase",""))
    if path.is_empty():return resolve(str(cue.get("clip","")),spell,role)
    _load()
    var setters:Dictionary=cue.get("source_inputs",{})
    var identity:String="source_phase:"+path+"|"+JSON.stringify(setters)+"|"+str(cue.get("source_seekable",false))
    _mutex.lock()
    if _client.has(identity):
        var cached:Dictionary=_client[identity];_mutex.unlock();return cached
    var table:Variant=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_TABLE)) if FileAccess.file_exists(SOURCE_TABLE) else null
    var rows:Array=table.get("resources",[]) if table is Dictionary else []
    var matches:Array=rows.filter(func(row):return row.get("phase")==path)
    if matches.size()!=1 or setters.is_empty():_mutex.unlock();return {}
    if not _phases.has(path):_phases[path]=Metadata.read(path,ResourceLoader.CACHE_MODE_REUSE)
    var phase:Resource=_phases[path]
    if phase==null or str(phase.get("clip_id"))!=str(matches[0].clip_id):_mutex.unlock();return {}
    var options:Dictionary=phase.get("options")
    var value:Dictionary={"id":str(phase.clip_id),"spell":spell,"stage":str(phase.get("phase")),"seconds":float(phase.seconds),
        "loop":false,"inputs":setters.keys(),"input_setters":setters.duplicate(),"source_kind":"standalone_phase",
        "source_phase":path,"bounded_formation":bool(options.get("bounded_formation",false)),
        "content_hash":FileAccess.get_sha256(path),"approaches":[{"id":"standalone_phase","kind":"native",
            "path":"res://presentation/native_constructed_occurrence.gd","source_phase":path,"warm":[],
            "seekable":bool(cue.get("source_seekable",false)),"runtime_selection":"Explicit typed standalone source"}]}
    # A delivered public constructor may own admission before Source.make.
    # Keep its declared operand API with the exact mapped PhaseResource.
    if matches[0].has("constructor"):
        value.approaches[0].path=str(matches[0].constructor)
        value.approaches[0].construction_input_contract=matches[0].get("construction_input_contract",{})
        value.approaches[0].public_callbacks=matches[0].get("public_callbacks",{})
        value.approaches[0].forwarded_source_inputs=matches[0].get("forwarded_source_inputs",[])
    _client[identity]=value;_mutex.unlock();return value

## The package's condition lifecycles for a server condition id (selections
## with a `condition` block: application, sustain and removal clips, their
## registration and visibility), in package order; [] when it has none.
static func conditions(condition_id:String)->Array:
    _load()
    return _conditions.get(condition_id,[])

## Exact indexed selection reused by typed condition authoring. This does
## not add an owner alias to the sealed package or change default selections.
static func condition_selection(key:String)->Dictionary:
    _load()
    return _condition_selection_keys.get(key,{})

## The clip each package condition lifecycle constructs (its application:
## one occurrence plays all three phases).
static func lifecycle_clips()->Array:
    _load()
    var result:Array=[];var seen:Dictionary={}
    for selections in _conditions.values():
        for selection in selections:
            if seen.has(selection.key):continue
            seen[selection.key]=true
            var value:Dictionary=clip(str(selection.condition.phases.application))
            if not value.is_empty():result.append(value)
    return result

## The client's clip record for a package clip: its index fields and whether
## its formation is bounded (cue timing does not extend to its animation end).
static func clip(id:String)->Dictionary:
    _load()
    _mutex.lock()
    var result:Dictionary=_client.get(id,{})
    if not result.is_empty() or not _clips.has(id):
        _mutex.unlock();return result
    var entry:Dictionary=_clips[id]
    var bounded:bool=false
    for approach in entry.approaches:
        if approach.has("source_phase"):
            var path:String=approach.source_phase
            if not _phases.has(path):_phases[path]=Metadata.read(path,ResourceLoader.CACHE_MODE_REUSE)
            var phase:Resource=_phases[path]
            bounded=phase!=null and bool(phase.get("options").get("bounded_formation",false));break
    result={"id":id,"spell":entry.spell,"stage":entry.stage,"seconds":float(entry.seconds),"loop":entry.loop,"inputs":entry.inputs,
        "input_setters":entry.input_setters,"approaches":entry.approaches,"bounded_formation":bounded,"content_hash":entry.content_hash}
    _client[id]=result;_mutex.unlock()
    return result

## Optional approach_id is an exact source assignment, ahead of the global
## kind preference. Otherwise keep the original first live program in package
## order; recorded approaches retain their seed-ordered variant family.
static func choice(value:Dictionary)->Dictionary:
    var exact:String=str(value.get("approach_id",""))
    if not exact.is_empty():
        for approach in value.get("approaches",[]):
            if str(approach.id)==exact:return {"kind":approach.kind,"approaches":[approach],"reason":"explicit package approach "+exact}
        return {"kind":"","approaches":[],"reason":"the package has no approach "+exact+" for "+str(value.get("id",""))}
    var order:Array=KINDS.duplicate()
    if not requested.is_empty():order.erase(requested);order.push_front(requested)
    for kind in order:
        var found:Array=value.get("approaches",[]).filter(func(approach):return approach.kind==kind and not str(approach.get("runtime_selection","")).begins_with("Unselected alternative"))
        if found.is_empty():continue
        if kind=="recorded":found.sort_custom(func(a,b):return int(a.get("variant",0))<int(b.get("variant",0)))
        else:found=[found[0]]
        var reason:String="" if requested.is_empty() or kind==requested else "no "+LABELS[requested]+" approach in the package; "+LABELS[kind]+" plays"
        return {"kind":kind,"approaches":found,"reason":reason}
    return {"kind":"","approaches":[],"reason":"the package has no approach for "+str(value.get("id",""))}

## Neutral public templates can load their immutable art without an outcome,
## but construction/warm draws require that occurrence's actual operands.
static func requires_construction(value:Dictionary)->bool:
    return value.get("requires_constructor_input",false) or choice(value).approaches.any(func(approach):return approach.get("construction_required",false))

static func key(value:Dictionary)->String:
    var selected:Dictionary=choice(value)
    var sources:Array=selected.approaches.map(func(approach):return [str(approach.id),str(approach.path),str(approach.get("source_phase",""))])
    var identity:Array=[str(value.get("id","")),selected.kind,sources,str(value.get("opacity_uniform",""))]
    if not str(value.get("immutable_preparation","")).is_empty():identity.append(value.immutable_preparation)
    if value.get("preparation_inputs","construction")!="construction":identity.append(value.preparation_inputs)
    if not str(value.get("construction_argument","")).is_empty():identity.append(value.construction_argument)
    return JSON.stringify(identity)

static func occurrence_clip(component:Dictionary)->Dictionary:
    var result:Dictionary=component.native_clip.duplicate(false)
    var approach:String=str(component.get("native_cue",{}).get("approach",""))
    if not approach.is_empty():result.approach_id=approach
    var preparation:String=str(component.get("native_cue",{}).get("immutable_preparation",""))
    if not preparation.is_empty():result.immutable_preparation=preparation
    result.preparation_inputs=str(component.get("native_cue",{}).get("preparation_inputs","construction"))
    if component.has("native_constructor_inputs"):
        result.construction_inputs=component.native_constructor_inputs
        result.preparation_owner=component.id
    var argument:String=str(component.get("native_cue",{}).get("constructor_input",{}).get("argument",""))
    if not argument.is_empty():result.construction_argument=argument
    if component.get("native_cue",{}).get("sampling")=="absolute":result.absolute_sampling=true
    if component.get("native_cue",{}).has("opacity_uniform"):result.opacity_uniform=component.native_cue.opacity_uniform
    return result

## Files this clip's playing approach reads (Studio preview dependencies).
static func resource_paths(value:Dictionary)->Array:
    var result:Array=[]
    if "actor_context" in value.get("inputs",[]):
        result.append("res://assets/vfx/extensions/production-review-20261020/sources/6e2fd9339711629213f5/condition_actor_history.gd")
    if not str(value.get("immutable_preparation","")).is_empty():result.append(value.immutable_preparation)
    for approach in choice(value).approaches:
        result.append(approach.path)
        if approach.has("source_phase"):result.append(approach.source_phase)
    return result

## Loads (on workers, one file at a time) and warms what these clips play.
## A recording is one file whose textures are created one per frame; a live
## approach loads its constructor, phase and every file the phase names, and
## compiles its `warm` materials on a worker. Nothing is constructed here.
## A recording's `warm` list names live materials. Its actual scene/prototype
## programs use the same worker admission; native first-draw pipelines still
## belong to native_source_startup.gd and the actual drawing viewport.
static func prepare(clips:Array,cache:Dictionary,urgent:bool=true,interests:Array=[])->Dictionary:
    # Incremental consumers retain their full current request, including sibling
    # optional calls. Abandoned work drains before any later loading can enter.
    retain_source_preparation(cache,interests if not interests.is_empty() else clips)
    # No occurrence or package program is requested by an empty consumer set.
    if clips.is_empty():return {"ready":true,"pending":0,"errors":[]}
    # A retained source already owns admission. Let that exact owner finish
    # its current unit before a newly required sibling adds uncached paths.
    var continued:Dictionary=Admission.step_owned_source(cache,urgent)
    _ensure_clock()
    var pending:int=0;var errors:Array=[];var paths:Dictionary={};var live:Array=[]
    for value in clips:
        if requires_construction(value) or value.has("construction_inputs"):paths["res://presentation/native_constructed_occurrence.gd"]=true
        var chosen:Dictionary=choice(value)
        if chosen.kind.is_empty():errors.append(chosen.reason);continue
        if chosen.kind=="recorded":
            var bundle:Variant=Baked.ready_for(value,0,urgent)
            if bundle==null:pending+=1
            elif not bundle is Resource:errors.append("Recording cannot be loaded: "+str(value.id))
            elif not Admission.prepare_materials(bundle,Baked.material_programs(bundle),cache,urgent):pending+=1
            continue
        var approach:Dictionary=chosen.approaches[0]
        live.append(approach)
        for path in [approach.path,approach.source_phase]+approach.warm:paths[path]=true
        for path in resource_paths(value):paths[path]=true
        var preparation:String=str(value.get("immutable_preparation",_immutable_preparation))
        if not preparation.is_empty():paths[preparation]=true
        var phase:Resource=cache.get(approach.source_phase)
        if phase!=null:
            if not cache.has("effect_package_phase_paths"):cache.effect_package_phase_paths={}
            if not cache.effect_package_phase_paths.has(phase):
                var found:Dictionary={};_resource_values(phase.to_clip().get("components",[]),found)
                cache.effect_package_phase_paths[phase]=found.keys()
            for path in cache.effect_package_phase_paths[phase]:paths[path]=true
    if not live.is_empty():
        var loading:Dictionary=Admission.prepare(paths.keys(),cache,false,urgent)
        pending+=loading.pending;errors.append_array(loading.errors)
        if loading.pending==0 and loading.errors.is_empty():
            for approach in live:
                var materials:Array[Material]=[]
                for path in approach.warm:
                    if cache.get(path) is Material:materials.append(cache[path])
                if not Admission.prepare_materials(cache[approach.path],materials,cache,urgent):pending+=1
            var prepared:Dictionary=_prepare_immutable(clips,cache,urgent,bool(continued.get("stepped",false)))
            pending+=prepared.pending;errors.append_array(prepared.errors)
    if not clips.is_empty() and not Admission.can_mutate():pending+=1
    return {"ready":pending==0 and errors.is_empty(),"pending":pending,"errors":errors}

## Source-owned bounded resource discovery. This cache belongs to the existing
## preparation consumer; completed jobs retain resource paths, never facts or
## sampled prototypes. The Factory owns the shared immutable resource bank.
static func _prepare_immutable(clips:Array,cache:Dictionary,urgent:bool,stepped:bool=false)->Dictionary:
    if not cache.has("native_immutable_jobs"):cache.native_immutable_jobs={}
    var jobs:Dictionary=cache.native_immutable_jobs
    var pending:int=0;var errors:Array=[]
    for value in clips:
        var selected:Dictionary=choice(value)
        if selected.kind=="recorded" or selected.approaches.is_empty():continue
        # Neutral construction templates can prepare ordinary dependencies,
        # but must not discover or build a successful review occurrence.
        if requires_construction(value) and not value.has("construction_inputs"):continue
        var preparation_path:String=str(value.get("immutable_preparation",_immutable_preparation))
        if preparation_path.is_empty():continue
        var preparation:Script=cache[preparation_path]
        var identity:String=_preparation_identity(value,selected)
        if not jobs.has(identity):
            var phase:Resource=cache[selected.approaches[0].source_phase]
            var actual:Dictionary=Constructed.clip_with_inputs(phase,value.construction_inputs) if value.has("construction_inputs") and value.get("preparation_inputs","construction")=="construction" else phase.to_clip()
            jobs[identity]=preparation.begin(actual)
            jobs[identity].preparation_owner=str(value.get("preparation_owner",""))
        var job:Dictionary=jobs[identity]
        if not job.complete and job.error.is_empty() and not stepped:
            var progress:Dictionary=Admission.step_source(preparation,job,cache,urgent)
            stepped=bool(progress.get("stepped",false))
        if not job.error.is_empty():errors.append(job.error)
        elif not job.complete:pending+=1
    return {"pending":pending,"errors":errors}

static func _preparation_identity(value:Dictionary,selected:Dictionary)->String:
    return key(value)+"|"+str(selected.approaches[0].path)+"|"+str(value.get("preparation_owner","source"))

## Completed immutable discovery remains reusable. Only abandoned unfinished
## jobs are discarded locally; Admission retains an active job through drain.
static func retain_source_preparation(cache:Dictionary,clips:Array)->void:
    var jobs:Dictionary=cache.get("native_immutable_jobs",{})
    if jobs.is_empty():return
    var retained:Dictionary={}
    for value in clips:
        var selected:Dictionary=choice(value)
        if selected.kind=="recorded" or selected.approaches.is_empty():continue
        if requires_construction(value) and not value.has("construction_inputs"):continue
        if str(value.get("immutable_preparation",_immutable_preparation)).is_empty():continue
        retained[_preparation_identity(value,selected)]=true
    for identity in jobs.keys():
        if jobs[identity].complete or retained.has(identity):continue
        Admission.cancel_source(jobs[identity])
        jobs.erase(identity)

static func retain_preparation(cache:Dictionary,owners:Dictionary)->void:
    var jobs:Dictionary=cache.get("native_immutable_jobs",{})
    for id in jobs.keys():
        var owner:String=jobs[id].get("preparation_owner","")
        if not owner.is_empty() and not owners.has(owner):
            Admission.cancel_source(jobs[id])
            jobs.erase(id)

static func _resource_values(value:Variant,result:Dictionary)->void:
    if value is Dictionary:
        for item in value.values():_resource_values(item,result)
    elif value is Array:
        for item in value:_resource_values(item,result)
    elif value is String and value.begins_with("res://") and value.get_extension() in ["gd","tscn","tres","res","scn","gdshader"]:
        result[value]=true

## One occurrence of the playing approach under `parent`, hidden, at render
## layer `layer_mask`. Recorded variants are picked by `seed`. The handle's
## `root` holds the effect's nodes (staging paths resolve from it).
static func make(parent:Node3D,value:Dictionary,layer_mask:int,seed:int=0)->Dictionary:
    var started:int=Time.get_ticks_usec()
    var chosen:Dictionary=choice(value)
    var handle:Dictionary
    var needs_inputs:bool=value.get("requires_constructor_input",false) or chosen.approaches.any(func(approach):return approach.get("construction_required",false))
    if needs_inputs and not value.has("construction_inputs"):
        handle={"root":null,"error":"Native construction operands unavailable: "+str(value.get("id","")),"clip":value}
    elif chosen.kind=="recorded":
        var bundle:Variant=Baked.ready_for(value,seed)
        handle=Baked.make(parent,bundle,value,layer_mask) if bundle is Resource else {"root":null,"error":"Recording is not loaded: "+str(value.get("id","")),"clip":value}
    elif chosen.kind.is_empty():handle={"root":null,"error":chosen.reason,"clip":value}
    else:handle=_live(parent,value,chosen.approaches[0],layer_mask)
    handle.effect_kind=chosen.kind;handle.effect_reason=chosen.reason;handle.effect_revision=revision
    var actual:Dictionary=chosen.approaches[0] if not chosen.approaches.is_empty() else {}
    if chosen.kind=="recorded" and handle.get("bundle") is Resource:
        for approach in chosen.approaches:
            if str(approach.path)==str(handle.bundle.resource_path):actual=approach;break
    handle.effect_approach_id=str(actual.get("id",""));handle.effect_approach_path=str(actual.get("path",""))
    handle.effect_source_phase=str(actual.get("source_phase",""));handle.effect_key=key(value)
    if not handle.has("construction_phases"):handle.construction_phases={}
    handle.construction_phases.total=(Time.get_ticks_usec()-started)/1000.0
    return handle

static func _live(parent:Node3D,value:Dictionary,approach:Dictionary,layer_mask:int)->Dictionary:
    var handle={"root":null,"occurrence":null,"inner":{},"error":"","clip":value.duplicate(false),"layer_mask":layer_mask,"geometry":[],"emitters":[],
        "light_units":{},"opacity_bindings":[],"players":[],"seekable":bool(value.get("absolute_sampling",approach.get("seekable",false))),"initialized":false,"age":0.0,"construction_phases":{}}
    handle.forwarded_source_inputs=approach.get("forwarded_source_inputs",[]).duplicate()
    var phase_started:int=Time.get_ticks_usec()
    if not Admission.begin_mutation():
        handle.error="Live effect construction admission is pending";return handle
    handle.construction_phases.admission=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    var script:Script=ResourceLoader.load(approach.path)
    var constructed:Script
    var source_phase:Resource
    var contract:Variant=approach.get("construction_input_contract",{})
    # Delivered bound constructors accept actual phase/operand transport. New
    # tables retain the exact public contract as text rather than a map.
    var bound_constructor:bool=contract is String and not contract.is_empty()
    var direct_operands:bool=bound_constructor or contract is Dictionary and contract.has("operands")
    var bind_phase:bool=(value.has("construction_inputs") or value.get("source_kind")=="standalone_phase") and not direct_operands
    if bind_phase or bound_constructor:
        source_phase=ResourceLoader.load(approach.source_phase)
    if bind_phase:
        constructed=load("res://presentation/native_constructed_occurrence.gd")
    handle.construction_phases.script_load=(Time.get_ticks_usec()-phase_started)/1000.0
    if script==null or not script.has_method("make_component"):
        handle.error="Missing package constructor: "+str(approach.path);return handle
    phase_started=Time.get_ticks_usec()
    var occurrence:Node3D
    if direct_operands:
        var actual:Dictionary={"layer_mask":layer_mask,"operands":value.get("construction_inputs",[])}
        if bound_constructor:actual.phase=source_phase
        var argument:String=str(value.get("construction_argument",""))
        if not argument.is_empty():
            var operands:Array=value.get("construction_inputs",[])
            var fields:Array=source_phase.options.get("construction_operands",[]) if source_phase!=null else []
            if argument in ["layer_mask","phase","operands","clip"] or operands.size()!=1 \
                or operands[0].get("component_path")!=[argument] or operands[0].get("input_field","")!="" \
                or not operands[0].get("values") is Dictionary or fields.is_empty() \
                or operands[0].values.size()!=fields.size() or not fields.all(func(field):return operands[0].values.has(field)):
                handle.error="Native constructor argument operands unavailable: "+argument;return handle
            # The selected public constructor owns semantic value validation.
            # Copy only its admitted factual operand; shared phase data stays immutable.
            actual[argument]=operands[0].values.duplicate(true)
        occurrence=script.make_component(actual)
    elif bind_phase:
        occurrence=constructed.make_component({"layer_mask":layer_mask,"phase":source_phase,"operands":value.get("construction_inputs",[])})
    else:occurrence=script.make_component({"layer_mask":layer_mask})
    handle.construction_phases.make_component=(Time.get_ticks_usec()-phase_started)/1000.0
    handle.occurrence=occurrence
    if occurrence==null:
        handle.error="Native constructor has no admitted operands: "+str(value.get("id",""));return handle
    # The occurrence builds its source in _ready (some components create
    # layers there); its geometry starts on the caller's (hidden) layer.
    phase_started=Time.get_ticks_usec()
    if "actor_context" in value.get("inputs",[]):occurrence.hide()
    parent.add_child(occurrence)
    handle.construction_phases.ready=(Time.get_ticks_usec()-phase_started)/1000.0
    if not str(occurrence.construction_error).is_empty():
        handle.error=str(occurrence.construction_error);return handle
    phase_started=Time.get_ticks_usec()
    var inner:Dictionary=occurrence.handle
    handle.inner=inner;handle.root=occurrence if "actor_context" in value.get("inputs",[]) else inner.root
    for field in ["geometry","emitters","light_units","opacity_bindings","players"]:handle[field]=inner[field]
    handle.root.hide()
    if "actor_context" in value.get("inputs",[]):_watch_geometry(handle)
    # No live membership is invented: an input the game does not supply is
    # empty, never the Factory fixture's preview data.
    if "binding_owners" in value.get("inputs",[]):set_input(handle,"binding_owners",[])
    var uniform:String=value.get("opacity_uniform","")
    if not uniform.is_empty():
        for location in Baked.material_locations(handle.root):
            var material:Material=location.material
            if not material is ShaderMaterial or material.shader==null:continue
            if not material.shader.get_shader_uniform_list().any(func(entry):return entry.name==uniform):continue
            var current:Variant=material.get_shader_parameter(uniform)
            inner.opacity_bindings.append({"material":material,"uniform":uniform,"native":1.0 if current==null else float(current)})
        if inner.opacity_bindings.is_empty():handle.error="Missing opacity control: "+str(value.get("id",""))+" / "+uniform
    handle.construction_phases.adaptation=(Time.get_ticks_usec()-phase_started)/1000.0
    return handle

## The node paths a cue's staging names, by field.
static func _staged_paths(cue:Dictionary)->Dictionary:
    var result:Dictionary={}
    for field in ["contact_hide","release_hide","hide_nodes","show_nodes"]:
        if cue.has(field):result[field]=cue[field].map(func(path):return str(path))
    if cue.has("fade_bindings"):result.fade_bindings=cue.fade_bindings.map(func(binding):return str(binding.node))
    if cue.has("origin_path"):result.origin_path=[str(cue.origin_path)]
    return result

## Recorded-geometry sources explicitly verify that their original scene
## paths survive beneath their private wrappers. Only that supplied capability
## admits a deeper alias, and it still requires one unchanged full relative
## path and one actual target inside the occurrence.
static func _verified_wrapped_path(root:Node,path:String,canonical:String="")->Node:
    var paths:Array=[path]
    if not canonical.is_empty() and canonical!=path:paths.append(canonical)
    var relatives:Array[NodePath]=[]
    for actual in paths:
        var relative:NodePath=NodePath(actual)
        if relative.is_absolute() or relative.get_name_count()<2 or relative.get_subname_count()>0:return null
        for at in relative.get_name_count():
            if str(relative.get_name(at)) in [".",".."]:return null
        relatives.append(relative)
    var matches:Array=[]
    for wrapper in root.find_children("*","Node3D",true,false):
        if not wrapper.has_method("has_verified_stable_paths") or not wrapper.has_verified_stable_paths():continue
        var prefixes:Array=[wrapper];prefixes.append_array(wrapper.find_children("*","Node",true,false))
        for prefix in prefixes:
            for candidate_path in relatives:
                var target:Node=prefix.get_node_or_null(candidate_path)
                if target!=null and target not in matches:matches.append(target)
    return matches[0] if matches.size()==1 else null

## Staged node paths the built effect lacks. Where the package's own staging
## of this cue (same spell, clip and role) names that field's node under
## another path of this effect's tree, it is used (`handle.path_aliases`,
## read by Playback); what remains unresolved is returned and reported.
static func resolve_paths(handle:Dictionary,cue:Dictionary,spell:String)->Array:
    _load()
    var staged:Dictionary=_staged_paths(cue)
    var package:Dictionary={}
    for candidate in _selections.get(spell,{}).get("staging",{}).get("cues",[]):
        if str(candidate.get("clip",""))==str(handle.clip.get("id","")) and candidate.get("role")==cue.get("role"):package=_staged_paths(candidate);break
    var aliases:Dictionary={};var missing:Array=[]
    for field in staged:
        for at in staged[field].size():
            var path:String=staged[field][at]
            if handle.root.get_node_or_null(NodePath(path))!=null:continue
            var other:Array=package.get(field,[])
            # A condition registration names its node inside the component.
            var within:Array=handle.root.get_children().filter(func(child):return child.get_node_or_null(NodePath(path))!=null)
            if at<other.size() and handle.root.get_node_or_null(NodePath(str(other[at])))!=null:aliases[path]=str(other[at])
            elif within.size()==1:aliases[path]=str(within[0].name)+"/"+path
            elif within.is_empty():
                var wrapped:Node=_verified_wrapped_path(handle.root,path,str(other[at]) if at<other.size() else "")
                if wrapped!=null:aliases[path]=str(handle.root.get_path_to(wrapped))
                else:missing.append(path)
            else:missing.append(path)
    handle.path_aliases=aliases
    return missing

## A staged node of this occurrence (through its path aliases), or null.
static func node(handle:Dictionary,path:Variant)->Node:
    return handle.root.get_node_or_null(NodePath(str(handle.get("path_aliases",{}).get(str(path),path))))

## Places the occurrence: its declared `root_path` input when it has one.
static func place(handle:Dictionary,transform:Transform3D)->void:
    var occurrence:Node3D=handle.get("occurrence")
    if occurrence==null:handle.root.global_transform=transform;return
    handle.root.transform=Transform3D.IDENTITY
    if "root_path" in handle.clip.get("inputs",[]):occurrence.call(handle.clip.input_setters.root_path,transform)
    else:occurrence.global_transform=transform

## Source seconds -> the drawn state. A recording reads it directly; a live
## occurrence samples its source (the package's sampler steps its own
## particles by the time since its last sample).
static func sample(handle:Dictionary,seconds:float,refresh_geometry:bool=false)->void:
    if handle.get("baked",false):Baked.sample(handle,seconds);return
    # Existing authored dynamic geometry can change endpoints during a held
    # view/pose. Reuse the same equation-only path as constructed phases; the
    # ordinary occurrence still owns its clock, native players and GPU delta.
    if refresh_geometry:Constructed.refresh_held_source(handle.inner,seconds)
    handle.occurrence.sample(seconds)
    if handle.get("geometry_membership",{}).get("dirty",false):_refresh_geometry(handle)
    handle.age=seconds;handle.initialized=true

## Supplies a declared input through the clip's setter (no-op when the clip
## does not declare it).
static func set_input(handle:Dictionary,input:String,value:Variant,extra_arguments:Array=[])->void:
    if input not in handle.clip.get("inputs",[]) or not is_instance_valid(handle.get("occurrence")):return
    var method:String=handle.clip.input_setters[input]
    # Public aliases can bind more than forwarding does (notably targets).
    # Call the returned occurrence's declared method before its source seam.
    if handle.occurrence.has_method(method):
        if extra_arguments.is_empty():handle.occurrence.call(method,value)
        else:handle.occurrence.callv(method,[value]+extra_arguments)
    elif handle.clip.has("construction_inputs") or handle.clip.get("source_kind")=="standalone_phase" or method in handle.get("forwarded_source_inputs",[]):
        if extra_arguments.is_empty():handle.occurrence.forward(method,value)
        else:handle.occurrence.forward_arguments(method,[value]+extra_arguments)
    else:push_error("Declared native input has no public setter: "+method)

static func stop_emission(handle:Dictionary,source_seconds:float)->void:
    if handle.get("baked",false):Baked.stop_emission(handle,source_seconds)

static func close(handle:Dictionary)->void:
    if handle.has("geometry_membership"):
        var membership:Dictionary=handle.geometry_membership
        for pair in [[membership.tree.node_added,membership.added],[membership.tree.node_removed,membership.removed]]:
            if pair[0].is_connected(pair[1]):pair[0].disconnect(pair[1])
        membership.erase("added");membership.erase("removed")
    if handle.get("baked",false):Baked.release(handle)
    # Native.release keeps every material alive until the whole effect is
    # freed (destroying geometry can flush another pending instance update).
    var owner:Node=handle.get("occurrence") if is_instance_valid(handle.get("occurrence")) else handle.get("root")
    if is_instance_valid(owner):Native.release({"root":owner})
    handle.clear()

## Source-owned compositors add output quads after construction. Track tree
## membership changes; capture meshes in another World3D are never outputs.
static func _watch_geometry(handle:Dictionary)->void:
    var owner:WeakRef=weakref(handle.occurrence)
    var state:Dictionary={"dirty":true,"ids":{},"tree":handle.occurrence.get_tree()}
    state.added=func(node:Node):
        var occurrence:Node=owner.get_ref()
        if occurrence!=null and occurrence.is_ancestor_of(node):state.dirty=true
    state.removed=func(node:Node):
        if state.ids.has(node.get_instance_id()):state.dirty=true
    state.tree.node_added.connect(state.added)
    state.tree.node_removed.connect(state.removed)
    handle.geometry_membership=state

static func _refresh_geometry(handle:Dictionary)->void:
    var state:Dictionary=handle.geometry_membership
    state.dirty=false;state.ids.clear();handle.geometry.clear()
    var owner:Node3D=handle.occurrence
    var pending:Array=[owner]
    while not pending.is_empty():
        var node:Node=pending.pop_back()
        if node is Viewport:continue
        if node is GeometryInstance3D and node.get_world_3d()==owner.get_world_3d():
            var enabled:bool=node.layers!=0
            handle.geometry.append({"node":node,"layer_enabled":enabled})
            state.ids[node.get_instance_id()]=true
            node.layers=handle.layer_mask if enabled else 0
        pending.append_array(node.get_children())

## Also suspend source-owned capture viewports while a retained owner is idle.
static func hide(handle:Dictionary)->void:
    handle.root.hide()
    if "weapon_binding" in handle.get("clip",{}).get("inputs",[]):
        # The public invalid binding releases only this source's material
        # claims. Actor materials live outside the hidden occurrence subtree.
        set_input(handle,"weapon_binding",{})
        # A later identical valid packet must be delivered again on re-entry.
        handle.erase("weapon_input_key")
        handle.erase("weapon_hand_key")
    if handle.get("actor_context_bound",false):
        set_input(handle,"actor_context",{})
        handle.actor_context_bound=false

static func set_layer(handle:Dictionary,mask:int)->void:
    var previous:int=handle.layer_mask
    if previous==mask:return
    handle.layer_mask=mask
    if handle.get("inner",{}).has("layer_mask"):handle.inner.layer_mask=mask
    # Unpair before changing either side of a light/geometry mask. Godot
    # caches the light cull mask; changing it while paired can leave stale
    # geometry references which fail on a later seek or release.
    var light_visibility:Array=[]
    for entry in handle.light_units.values():
        light_visibility.append({"node":entry.node,"visible":entry.node.visible})
        entry.node.hide()
    for piece in handle.geometry:
        # Visibility can be keyed later by the source. An initially hidden
        # mesh still belongs to the source's render layer.
        var enabled:bool=piece.layer_enabled if previous==0 else piece.node.layers!=0
        piece.node.layers=mask if enabled else 0
    for entry in light_visibility:
        entry.node.light_cull_mask=mask;entry.node.layers=mask
        entry.node.visible=entry.visible

## Loads what hit_material reads: the clip's recording when it has one, else
## its playing live approach.
static func prepare_hits(clips:Array,cache:Dictionary,interests:Array=[],urgent:bool=true)->Dictionary:
    retain_source_preparation(cache,interests if not interests.is_empty() else clips)
    var live:Array=[];var pending:int=0
    for value in clips:
        var bundle:Variant=Baked.ready_for(value,0,true)
        if bundle==null:pending+=1
        elif not bundle is Resource:live.append(value)
    var result:Dictionary=prepare(live,cache,urgent,interests if not interests.is_empty() else clips) if not live.is_empty() else {"ready":true,"pending":0,"errors":[]}
    result.pending+=pending;result.ready=result.ready and pending==0
    return result

## The body material a spell hit borrows from this clip's effect: from its
## recorded scene when it has one (the source material and clock uniform as
## authored), else from a live construction. {} until the clip is prepared.
static func hit_material(parent:Node3D,value:Dictionary,node_path:String,surface:int)->Dictionary:
    var bundle:Variant=Baked.ready_for(value,0,true)
    var holder:Node
    var root:Node
    var handle:Dictionary={}
    if bundle is Resource:
        holder=bundle.scene.instantiate();root=holder
    else:
        handle=make(parent,value,0)
        if not handle.error.is_empty():
            var error:String=handle.error;close(handle);return {"error":error}
        root=handle.root
    var mesh:Node=root.get_node_or_null(node_path)
    var material:Material
    if mesh is MeshInstance3D and mesh.mesh!=null and surface>=0 and surface<mesh.mesh.get_surface_count():material=mesh.get_active_material(surface)
    if material!=null:material=material.duplicate(false)
    if holder!=null:holder.free()
    if not handle.is_empty():close(handle)
    return {"material":material} if material!=null else {"error":"Selected native hit material is unavailable"}
