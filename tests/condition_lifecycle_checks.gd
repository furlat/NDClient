extends SceneTree
## Every condition lifecycle in the VFX package, through the client's own
## path (NativePersistent rows and owner_state, EffectPackage occurrences):
## construction (first and second), first sample and first draw; the sustain
## sampled directly at 0, its loop seam, an arbitrary age, 180 s and a reverse
## seek (never blank, no bright seam, no expiry trough); a simulation (not
## seekable) plays 12 s on in 60 Hz steps, then jumps to 180 s and is rebuilt
## for its reverse seek, as the renderer does; removal from several sustain
## ages (continuous with the sustain it leaves, ends empty). Drawing is
## coverage and difference only (alpha>0), not a look comparison.
## Run with Forward+/Vulkan.
##   --script res://tests/condition_lifecycle_checks.gd -- [--only=key,...] [--save=res://.captures/condition-lifecycles]
const Effects=preload("res://presentation/effect_package.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const FrameProfile=preload("res://frame_profile.gd")
const SIZE:=Vector2i(256,256)
const LAYER:=1<<1
## Sustain ages: start, an arbitrary age, three minutes, then back (reverse seek).
const AGES:=[0.0,7.3,180.0,1.0]
## Removal starts at these sustain ages.
const REMOVALS:=[0.5,7.3,180.0]
## A sustain frame may not lose more than this share of its early coverage.
const TROUGH:=0.25
## Mean absolute byte difference allowed across the seam (two frames 1/60 s apart).
const SEAM:=6.0
var checks:int=0
var failures:Array=[]
var view:Dictionary={}
var cache:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONDITION_LIFECYCLE_FAIL ",label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func _view()->Dictionary:
    var viewport:=SubViewport.new()
    viewport.size=SIZE;viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var camera:=Camera3D.new();camera.cull_mask=LAYER;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.0
    camera.near=0.05;camera.far=200.0
    var environment:=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR
    camera.environment=environment
    viewport.add_child(camera)
    var holder:=Node3D.new();viewport.add_child(holder)
    root.add_child(viewport)
    camera.look_at_from_position(Vector3(0,6,10),Vector3(0,0.6,0))
    return {"viewport":viewport,"camera":camera,"holder":holder}

func image()->Image:
    var result:Image=view.viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result

static func coverage(value:Image)->int:
    var data:PackedByteArray=value.get_data();var count:=0
    for at in range(3,data.size(),4):
        if data[at]>0:count+=1
    return count

static func difference(a:Image,b:Image)->float:
    var x:PackedByteArray=a.get_data();var y:PackedByteArray=b.get_data();var total:=0
    for at in x.size():total+=absi(x[at]-y[at])
    return float(total)/maxf(1.0,x.size())

## The row the client builds for an owner of this lifecycle: applied at 0,
## removed at `removed` (seconds; INF while it lasts).
func component(selection:Dictionary,removed:float)->Dictionary:
    var condition:Dictionary={"condition_uuid":"check","behavior_id":str(selection.condition.owner_ids[0]),"state":selection.condition.get("when",{})}
    var common:Dictionary={"id":"condition:check","kind":"condition","condition_uuid":"check","actor_uuid":"actor","condition":condition,
        "start_ms":0.0,"absolute_start_ms":0.0,"duration_ms":removed*1000.0,"age_ms":0.0,"removal_age_ms":null,"initial":false}
    var rows:Array=Persistent.lifecycle_samples(common,[selection],cache)
    return rows[0] if rows.size()==1 else {}

## Draws the occurrence at owner age `age` as the renderer does: owner_state
## through the clip's setter, sampled on the owner's age, placed at its
## registration (origin_path aliases from construction).
func draw(handle:Dictionary,row:Dictionary,age:float)->Dictionary:
    var state:Dictionary=Persistent.lifecycle_state(row,age)
    var placed:Transform3D=Playback.transform(row.native_cue.merged({"from":Vector3.ZERO,"to":Vector3(0,0.9,0),"ground":Vector3.ZERO},true),age,Vector3.ZERO,1.0)
    Effects.place(handle,placed)
    var started:int=Time.get_ticks_usec()
    Effects.set_input(handle,"owner_state",state)
    Effects.sample(handle,state.owner_age_seconds)
    var sample_us:int=Time.get_ticks_usec()-started
    if row.native_cue.has("origin_path"):
        var anchor:Node3D=Effects.node(handle,row.native_cue.origin_path)
        if anchor!=null:handle.root.global_position+=placed.origin-anchor.global_position
    await frame();await frame()
    return {"state":state,"image":image(),"sample_us":sample_us}

## Plays from owner age `from` to `to` in 60 Hz steps, each drawn.
func play(handle:Dictionary,row:Dictionary,from:float,to:float)->void:
    var age:float=from
    while age<to:
        var state:Dictionary=Persistent.lifecycle_state(row,age)
        Effects.set_input(handle,"owner_state",state);Effects.sample(handle,state.owner_age_seconds)
        await frame();age+=1.0/60.0

func build(row:Dictionary)->Dictionary:
    while not Effects.Admission.can_mutate():await frame()
    var started:int=Time.get_ticks_usec()
    var handle:Dictionary=Effects.make(view.holder,row.native_clip,LAYER)
    handle.construct_ms=(Time.get_ticks_usec()-started)/1000.0
    if handle.error.is_empty():
        handle.missing_paths=Effects.resolve_paths(handle,row.native_cue,"")
        handle.root.show()
    return handle

func lifecycle_checks(selection:Dictionary,save_dir:String)->Dictionary:
    var key:String=str(selection.key)
    var result:Dictionary={"key":key,"owner_ids":selection.condition.owner_ids}
    var row:Dictionary=component(selection,INF)
    check(not row.is_empty() and row.status=="available","Lifecycle row resolves its three package clips: "+key)
    if row.is_empty() or row.status!="available":return result
    var phases:Dictionary=row.lifecycle_phases
    result.clips=phases.keys().map(func(phase):return phases[phase].id)
    var chosen:Dictionary=Effects.choice(row.native_clip)
    result.kind=chosen.kind;result.seekable=bool(chosen.approaches[0].get("seekable",false)) if not chosen.approaches.is_empty() else false
    var started:int=Time.get_ticks_usec()
    var prepared:Dictionary=Effects.prepare([row.native_clip],cache)
    while not prepared.ready and prepared.errors.is_empty():
        await frame();prepared=Effects.prepare([row.native_clip],cache)
    result.prepare_ms=(Time.get_ticks_usec()-started)/1000.0
    check(prepared.ready,"Prepared %s: %s"%[key,str(prepared.errors)])
    if not prepared.ready:return result
    # First construction (cold) is the one the Studio/game warm-up pays at
    # load; the second is what an occurrence costs while playing.
    var first:Dictionary=await build(row)
    check(first.error.is_empty(),"Builds: %s %s"%[key,first.error])
    if not first.error.is_empty():return result
    result.construct_first_ms=first.construct_ms
    var compiles:Dictionary=FrameProfile.pipeline_compilations()
    var drawn:Dictionary=await draw(first,row,0.05)
    var after:Dictionary=FrameProfile.pipeline_compilations();var count:=0
    for field in after:count+=int(after[field])-int(compiles.get(field,0))
    result.first_draw_compiles=count;result.first_sample_us=drawn.sample_us
    check(first.missing_paths.is_empty(),"Registration node exists in %s: %s"%[key,str(first.missing_paths)])
    Effects.close(first);await frame()
    var handle:Dictionary=await build(row)
    result.construct_ms=handle.construct_ms
    compiles=FrameProfile.pipeline_compilations()
    var application:float=float(phases.application.seconds)
    var images:Array=[]
    # A simulation (particles, not seekable) plays on: the renderer draws it in
    # 60 Hz steps through the application, then at the owner's age.
    var stepped:bool=not result.seekable
    if stepped:await play(handle,row,0.0,application*0.5)
    drawn=await draw(handle,row,application*0.5)
    after=FrameProfile.pipeline_compilations();count=0
    for field in after:count+=int(after[field])-int(compiles.get(field,0))
    result.second_draw_compiles=count
    result.application_coverage=coverage(drawn.image)
    check(drawn.state.phase=="application" and result.application_coverage>0,"Application draws at half its length: "+key)
    images.append(drawn.image)
    # The sustain on the owner's age: 0.5 s and 1.0 s give the early reference.
    if stepped:await play(handle,row,application*0.5,application+0.5)
    var early:Array=[await draw(handle,row,application+0.5)]
    if stepped:await play(handle,row,application+0.5,application+1.0)
    early.append(await draw(handle,row,application+1.0))
    var reference:int=maxi(coverage(early[0].image),coverage(early[1].image))
    result.sustain_motion=difference(early[0].image,early[1].image)
    var sustain:Dictionary={}
    # The seam: the sustain's loop length, else the Factory's 2 s sustain clip.
    var seam:float=float(selection.condition.get("sustain",{}).get("loop_seconds",0.0)) if selection.condition.get("sustain",{}).get("loop_seconds")!=null else 0.0
    if seam<=0.0:seam=float(phases.sustain.seconds)
    # Seekable: drawn directly at each age, then back (reverse seek). A
    # simulation plays 12 s on (its trough shows there), then jumps to 180 s
    # as a late join does; its reverse seek is a fresh occurrence.
    var ages:Array=AGES if not stepped else [3.0,6.0,9.0,12.0,180.0]
    var played:float=application+1.0
    var before:Dictionary={};var later:Dictionary={}
    for age in ages:
        if stepped and age<=12.0:
            if played<application+seam-1.0/120.0 and age>=seam:
                await play(handle,row,played,application+seam-1.0/120.0);before=await draw(handle,row,application+seam-1.0/120.0)
                later=await draw(handle,row,application+seam+1.0/120.0);played=application+seam+1.0/120.0
            await play(handle,row,played,application+age);played=application+age
        drawn=await draw(handle,row,application+age)
        check(drawn.state.phase=="sustain","Sustain phase at owner age %.2f: %s"%[application+age,key])
        var covered:int=coverage(drawn.image)
        sustain[str(age)]=covered;images.append(drawn.image)
        check(covered>0,"Sustain is never blank (age %.1f s): %s"%[age,key])
        check(covered>=int(reference*TROUGH),"No expiry trough at sustain age %.1f s (%d of early %d): %s"%[age,covered,reference,key])
    result.sustain_coverage=sustain;result.sustain_reference=reference
    if not stepped:
        before=await draw(handle,row,application+seam-1.0/120.0)
        later=await draw(handle,row,application+seam+1.0/120.0)
    result.seam_difference=difference(before.image,later.image)
    check(result.seam_difference<=SEAM,"No bright or blank seam at %.2f s (difference %.2f): %s"%[seam,result.seam_difference,key])
    Effects.close(handle);await frame()
    if stepped:
        # Reverse seek: the renderer rebuilds a simulation, plays its
        # application and draws the owner's age.
        handle=await build(row)
        await play(handle,row,0.0,application)
        drawn=await draw(handle,row,application+1.0)
        result.reverse_coverage=coverage(drawn.image)
        check(result.reverse_coverage>0,"Reverse seek to sustain 1.0 s draws: "+key)
        Effects.close(handle);await frame()
    # Removal from several sustain ages, each on a fresh owner removed there.
    var removals:Dictionary={}
    for age in REMOVALS:
        var removed:float=application+age
        var closing:Dictionary=component(selection,removed)
        handle=await build(closing)
        if not result.seekable:await play(handle,closing,0.0,application)
        var held:Dictionary=await draw(handle,closing,removed-1.0/120.0)
        var opened:Dictionary=await draw(handle,closing,removed+1.0/120.0)
        var halfway:Dictionary=await draw(handle,closing,removed+float(phases.removal.seconds)*0.5)
        var ended:Dictionary=await draw(handle,closing,removed+float(phases.removal.seconds)-1.0/240.0)
        check(opened.state.phase=="removal" and is_equal_approx(float(opened.state.removal_started_at_owner_age_seconds),removed),"Removal starts at the owner's removal age %.1f s: %s"%[age,key])
        var jump:float=difference(held.image,opened.image)
        removals[str(age)]={"start_jump":jump,"start":coverage(opened.image),"halfway":coverage(halfway.image),"end":coverage(ended.image)}
        check(coverage(held.image)==0 or coverage(opened.image)>0,"Removal continues a drawn sustain at %.1f s: %s"%[age,key])
        check(jump<=SEAM,"Removal starts from the sustain it leaves at %.1f s (difference %.2f): %s"%[age,jump,key])
        check(coverage(ended.image)<=coverage(opened.image),"Removal fades out by its end from %.1f s: %s"%[age,key])
        if age==REMOVALS[0]:images.append(halfway.image)
        Effects.close(handle);await frame()
    result.removals=removals
    if not save_dir.is_empty():
        var sheet:=Image.create_empty(SIZE.x*images.size(),SIZE.y,false,Image.FORMAT_RGBA8)
        sheet.fill(Color(0.08,0.09,0.11,1))
        for at in images.size():sheet.blend_rect(images[at],Rect2i(Vector2i.ZERO,SIZE),Vector2i(at*SIZE.x,0))
        sheet.save_png(ProjectSettings.globalize_path(save_dir.path_join(key+".png")))
    print("CONDITION_LIFECYCLE ",JSON.stringify(result))
    return result

## Display selection: visibility (invisible actor, life state) and one
## overhead marker group at a time per actor, live markers first.
func selection_checks()->void:
    var owners:Dictionary={}
    for pair in [["a","condition.prone"],["b","condition.spell.command.grovel"],["c","condition.spell.shield"]]:
        owners[pair[0]]={"id":pair[0],"actor_uuid":"actor","condition":{"condition_uuid":pair[0],"behavior_id":pair[1],"state":{}},"start_ms":0.0,"end_ms":INF,"initial":false,"life_state":"alive"}
    var shown:Callable=func(at:float,changed:Dictionary)->Array:
        var copy:Dictionary=owners.duplicate(true);copy.merge(changed,true)
        return Conditions.samples(copy,at,cache).filter(func(row):return row.has("lifecycle_key")).map(func(row):return row.lifecycle_key)
    var first:Array=shown.call(100.0,{});var second:Array=shown.call(100.0+Persistent.MARKER_TURN_MS,{})
    check("condition_shield_retained_native" in first and "condition_shield_retained_native" in second,"A body lifecycle shows beside the marker")
    check(first.filter(func(key):return key in ["condition_prone_native","condition_commanded_native"]).size()==1 and second.filter(func(key):return key in ["condition_prone_native","condition_commanded_native"]).size()==1 and first!=second,"One overhead marker group at a time, in turn: "+str(first)+" "+str(second))
    check(first.has("condition_prone_native"),"The higher-priority marker group shows first (Prone 50 over Commanded 30)")
    var prepared:Array=Conditions.samples(owners.duplicate(true),100.0,cache,{},false).filter(func(row):return row.has("lifecycle_key"))
    check(prepared.size()==3,"Preparation holds every lifecycle, not only the displayed marker")
    var invisible:Dictionary={"d":{"id":"d","actor_uuid":"actor","condition":{"condition_uuid":"d","behavior_id":"condition.invisible","state":{}},"start_ms":0.0,"end_ms":INF,"initial":false,"life_state":"alive"}}
    check(shown.call(100.0,invisible).is_empty(),"Lifecycles hide with an invisible actor")
    var dead:Dictionary={}
    for id in owners:dead[id]=owners[id].merged({"life_state":"dead"},true)
    check(shown.call(100.0,dead)==["condition_shield_retained_native"],"A marker hides with a dead actor; the shield (no life states) stays")
    var removed:Dictionary={"a":owners.a.merged({"end_ms":50.0},true)}
    check(shown.call(100.0,removed).has("condition_commanded_native") and not shown.call(100.0,removed).has("condition_prone_native"),"A live marker shows before a removing one")
    var reduce:Dictionary={"e":{"id":"e","actor_uuid":"other","condition":{"condition_uuid":"e","behavior_id":"condition.spell.enlarge_reduce","state":{"size_change":"enlarge"}},"start_ms":0.0,"end_ms":INF,"initial":false,"life_state":"alive"}}
    check(Persistent.lifecycles(reduce.e.condition).is_empty() and not Persistent.lifecycles({"behavior_id":"condition.spell.enlarge_reduce","state":{"size_change":"reduce"}}).is_empty(),"A lifecycle's `when` matches the disclosed state (Reduce, not Enlarge)")

func run()->void:
    create_timer(3000).timeout.connect(func():printerr("Condition lifecycle checks deadline");quit(2))
    var arguments:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        var parts:PackedStringArray=argument.trim_prefix("--").split("=",true,1)
        arguments[parts[0]]=parts[1] if parts.size()>1 else "true"
    var only:Array=arguments.get("only","").split(",",false)
    var save_dir:String=arguments.get("save","")
    if not save_dir.is_empty():DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
    view=_view()
    selection_checks()
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX))
    var results:Array=[];var keys:Dictionary={}
    for selection in index.selections:
        if selection.get("condition",{}).is_empty():continue
        keys[selection.key]=true
        if not only.is_empty() and str(selection.key) not in only:continue
        check(selection.condition.get("schema")=="vfxfactory.condition_lifecycle.v1","Lifecycle schema: "+str(selection.key))
        for id in selection.condition.owner_ids:
            check(Effects.conditions(str(id)).has(selection),"Condition id resolves its lifecycle: "+str(id))
        results.append(await lifecycle_checks(selection,save_dir))
    check(only.is_empty()==(results.size()==keys.size()),"Every package condition lifecycle checked")
    var report:Dictionary={"checks":checks,"failures":failures,"lifecycles":results,
        "scope":"Package condition lifecycles through the client's rows, owner_state and occurrences in an isolated world: construction, first sample/draw, sustain at 0/seam/7.3/180 s and a reverse seek, removal from 0.5/7.3/180 s. Coverage and pixel difference only, not a look comparison."}
    FileAccess.open("res://.runtime/condition-lifecycle-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_LIFECYCLE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
