extends SceneTree
## Exact physical source identity and default policy. Detached metadata controls
## use two real sealed inspection programs; they are not production assignments
## or rendered-art proof. Actual preparation and recorded seed resources remain
## the production APIs. Live constructor identity is asserted by the native
## package bench; native occurrence teardown is not a dummy-renderer contract.
const Effects=preload("res://presentation/effect_package.gd")
const Baked=preload("res://presentation/baked_effect.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("APPROACH_SELECTION_FAIL ",label)
func prepared(clip:Dictionary,cache:Dictionary)->Dictionary:
    var result:Dictionary={"ready":false,"errors":[]}
    var deadline:int=Time.get_ticks_msec()+30000
    while not result.ready and result.errors.is_empty() and Time.get_ticks_msec()<deadline:
        result=Effects.prepare([clip],cache)
        await process_frame
    return result
func run()->void:
    var original:Dictionary=Effects.clip("barkskin_native")
    var other:Dictionary=Effects.clip("high-level-22/flesh-to-stone/material-body-window")
    var original_bytes:PackedByteArray=var_to_bytes(original)
    var other_bytes:PackedByteArray=var_to_bytes(other)
    check(not original.is_empty() and not other.is_empty(),"Both source controls resolve actual sealed package programs")
    if original.is_empty() or other.is_empty():quit(1);return
    var primary:Dictionary=original.approaches.filter(func(value):return value.kind=="native")[0]
    var alternative:Dictionary=other.approaches.filter(func(value):return value.kind=="native")[0].duplicate(true)
    alternative.id="unit/unselected-alternative";alternative.variant=-100
    alternative.runtime_selection="Unselected alternative; retained exact default/recorded approaches and selections"
    var combined:Dictionary=original.duplicate(true);combined.approaches.append(alternative)
    Effects.set_requested("native")
    var default_key:String=Effects.key(original)
    var selected:Dictionary=Effects.choice(combined)
    check(selected.kind=="native" and selected.approaches==[primary],"Default live selection retains the original first program, without sorting appended alternatives")
    check(Effects.resource_paths(combined)==[primary.path,primary.source_phase],"Default dependency closure contains only its original constructor and phase")
    check(Effects.key(combined)==default_key,"Appending an unselected source does not invalidate the original warm identity")
    var exact:Dictionary=combined.duplicate(false);exact.approach_id=alternative.id
    Effects.set_requested("recorded")
    check(Effects.choice(exact).approaches==[alternative] and Effects.choice(exact).kind=="native","Exact source assignment takes precedence over the global kind")
    check(Effects.resource_paths(exact)==[alternative.path,alternative.source_phase],"Exact dependency closure names only its actual constructor and phase")
    check(Effects.key(exact)!=default_key,"Distinct physical approaches cannot borrow a preparation identity")
    var changed:Dictionary=exact.duplicate(true);changed.approaches[-1].source_phase=primary.source_phase
    check(Effects.key(changed)!=Effects.key(exact),"A phase replacement changes source readiness identity")
    changed=exact.duplicate(true);changed.approaches[-1].path=primary.path
    check(Effects.key(changed)!=Effects.key(exact),"A constructor replacement changes source readiness identity")
    changed=exact.duplicate(true);changed.opacity_uniform="unit-opacity"
    check(Effects.key(changed)!=Effects.key(exact),"Occurrence material adaptation retains its own preparation identity")
    var gpu:Dictionary=primary.duplicate(true);gpu.id="unit/original-gpu";gpu.kind="gpu"
    var gpu_only:Dictionary=original.duplicate(false);gpu_only.approaches=[gpu,alternative]
    Effects.set_requested("native")
    check(Effects.choice(gpu_only).approaches==[gpu] and Effects.choice(gpu_only).kind=="gpu","A Native preference cannot activate an explicitly unselected new alternative")
    Effects.set_requested("")
    check(Effects.choice(combined).kind=="recorded" and Effects.choice(combined).approaches.map(func(value):return int(value.variant))==[0,1,2],"The ordinary recorded seed family and its variant order are unchanged")
    var rejected:Dictionary=combined.duplicate(false);rejected.approach_id="unit/missing"
    check(Effects.choice(rejected).kind.is_empty() and Effects.choice(rejected).approaches.is_empty(),"An unknown exact assignment cannot fall back to another source")
    check(Effects.resource_paths(rejected).is_empty(),"An unavailable exact assignment has no substituted preparation dependencies")
    var holder:=Node3D.new();root.add_child(holder)
    var bad:Dictionary=Effects.make(holder,rejected,1)
    check(bad.root==null and not bad.error.is_empty() and holder.get_child_count()==0,"An unavailable assignment rejects allocation rather than drawing the default")
    var cache:Dictionary={}
    Effects.set_requested("native")
    var ready:Dictionary=await prepared(combined,cache)
    check(ready.ready,"The default source completes actual immutable preparation: "+str(ready))
    check(not cache.has(alternative.path) and not cache.has(alternative.source_phase),"Default preparation never loads or warms the appended alternative")
    var jobs_before:Array=cache.get("native_immutable_jobs",{}).keys()
    check(jobs_before.size()==1 and str(jobs_before[0]).begins_with(default_key),"The completed default readiness job belongs to the actual default approach")
    if ready.ready:check(cache[primary.source_phase].to_clip().id==original.id,"The prepared default phase retains its actual sealed program identity")
    await process_frame
    ready=await prepared(exact,cache)
    check(ready.ready,"The exact alternative completes its own immutable preparation: "+str(ready))
    var jobs_after:Array=cache.get("native_immutable_jobs",{}).keys()
    check(jobs_after.size()==2 and jobs_before.all(func(value):return value in jobs_after),"Preparing another exact source retains the original proof and creates a distinct readiness job")
    if ready.ready:check(cache[alternative.source_phase].to_clip().id==other.id,"The prepared alternative is its actual phase rather than another label for the default")
    var records:Array=original.approaches.filter(func(value):return value.kind=="recorded")
    records.sort_custom(func(a,b):return int(a.variant)<int(b.variant))
    var recorded:Dictionary=original.duplicate(false);recorded.approach_id=records[2].id
    check(Baked.recording_key(recorded)==Baked.recording_key(original),"An exact recorded selector shares the unchanged physical seed-family loader")
    changed=recorded.duplicate(true);changed.approaches.filter(func(value):return value.kind=="recorded")[0].path=records[1].path
    check(Baked.recording_key(changed)!=Baked.recording_key(original),"Replacing recording files changes the physical family cache identity")
    var first:Resource=load(records[0].path)
    check(Baked._selected_recordings(recorded,[first],false)==null,"An exact later variant waits instead of borrowing the first uploaded recording")
    check(Baked._selected_recordings(recorded,[first],true)==false,"A completed family without the selected variant fails explicitly")
    Effects.set_requested("native")
    ready=await prepared(recorded,{})
    check(ready.ready,"The exact recorded variant completes its actual file admission: "+str(ready))
    if ready.ready:
        var chosen:Resource=Baked.ready_for(recorded,47,true)
        check(chosen!=null and chosen.resource_path==records[2].path,"An arbitrary seed cannot substitute another physical recording for an exact selector")
        var handle:Dictionary=Effects.make(holder,recorded,1,47)
        check(handle.error.is_empty() and handle.effect_kind=="recorded","Exact recorded assignment overrides the global Native preference during construction")
        check(handle.get("bundle")==chosen and handle.effect_approach_id==records[2].id and handle.effect_approach_path==records[2].path,"The built occurrence retains the actual selected recording identity")
        if handle.error.is_empty():Effects.sample(handle,.25)
        Effects.close(handle)
        var family:Variant=Baked.request(original,true)
        check(family is Array and family.size()==3 and family.map(func(value):return value.resource_path)==records.map(func(value):return value.path),"The original completed default seed family remains intact and ordered")
        check(Baked.ready_for(original,2,true)==chosen,"Ordinary seed two still resolves its original recording")
    Effects.set_requested("")
    check(var_to_bytes(original)==original_bytes and var_to_bytes(other)==other_bytes,"Source selection and preparation never mutate the delivered clip metadata")
    holder.queue_free();await process_frame;await process_frame
    print("APPROACH_SELECTION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual sealed immutable preparation and exact recorded resources plus detached metadata selector controls. Live constructors and framebuffer output remain the native package bench; no rendered art or adaptive provider qualification."}))
    quit(0 if failures.is_empty() else 1)
