extends SceneTree
## Real native donors -> compiled phase retirement. Hidden branches cannot add
## empty timeline seconds; visible smoke/trails must retain their actual decay.
## The donor is the VFX package clip's native approach (its live emitters).
const Effects=preload("res://presentation/effect_package.gd")
const Bounds=preload("res://presentation/native_source_bounds.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_RETAINED_TAIL_FAIL ",label)

func run()->void:
    var owner=Node3D.new();root.add_child(owner)
    var cache:Dictionary={}
    for id in ["fireball","ice_knife","produce_flame","ray_of_frost"]:
        var selected=Spells.selection("spell."+id,cache)
        var phases=Spells.phases(selected,{"start":0.0,"prepare":0.0},1000.0,500.0,0,true)
        for phase in phases:
            var cue:Dictionary=phase.native_cue
            if not cue.get("stop_emission_at_release",false) and not cue.get("stop_emission_at_contact",false):continue
            Effects.set_requested("native")
            var loading:Dictionary=Effects.prepare([phase.native_clip],cache)
            var deadline:int=Time.get_ticks_msec()+60000
            while not loading.ready and loading.errors.is_empty() and Time.get_ticks_msec()<deadline:
                await process_frame;loading=Effects.prepare([phase.native_clip],cache)
            var handle=Effects.make(owner,phase.native_clip.duplicate(false),1<<19)
            check(handle.error.is_empty() and handle.effect_kind=="native",id+": actual selected source constructs "+str(handle.error))
            if not handle.error.is_empty():Effects.close(handle);continue
            var donor:Dictionary=handle.inner
            var emitters=Bounds.emitters(donor)
            var bounds={"emitters":emitters}
            var cutoff:float=cue.contact if cue.get("stop_emission_at_contact",false) else cue.launch
            var tail=Spells.retained_particle_tail(bounds,cue,cutoff)
            check(phase.duration_ms/1000.0+0.00001>=cutoff+tail,id+": actual retained particles survive the compiled retirement")
            var stored=selected.source_bounds[cue.staged_clip]
            check(is_equal_approx(Spells.retained_particle_tail(stored,cue,cutoff),tail),id+": serialized source intake agrees with the actual donor")
            for emitter in emitters:
                if emitter.kind=="gpu_trail":
                    check(emitter.tail_seconds<emitter.lifetime,id+": native trail history count is not treated as seconds")
            if cue.role=="flight":
                var expected:float=3.0 if id=="ice_knife" else (.55 if phase.native_clip.id=="recovered/travelIce" else 1.0)
                check(is_equal_approx(tail,expected),id+": retained smoke/sparks determine the actual tail")
                var sped=cue.duplicate(true);sped.source_rate=8.0
                check(is_equal_approx(Spells.retained_particle_tail(bounds,sped,cutoff),tail),id+": post-contact source clock stays1x, independent of formation speed")
            if id=="fireball" and cue.role=="flight":
                check(phase.duration_ms<2000.0,"Fireball flight retires after its one-second retained source tail, not45seconds")
                var hidden=cue.duplicate(true);hidden.contact_hide=["effect/Donor"]
                check(is_zero_approx(Spells.retained_particle_tail(bounds,hidden,cutoff)),"Hiding the actual donor subtree removes all of its particle tail")
                hidden.contact_hide=["effect/Donor/GPUTrail"]
                check(is_equal_approx(Spells.retained_particle_tail(bounds,hidden,cutoff),tail),"A sibling path prefix is not treated as an ancestor")
                var sparks:GPUParticles3D=handle.root.get_node("effect/Donor/smallparticles_constant")
                sparks.lifetime=6.0
                check(is_equal_approx(Spells.retained_particle_tail({"emitters":Bounds.emitters(donor)},cue,cutoff),6.0),"A real six-second retained emitter remains six seconds; no blanket duration cap")
            evidence.append({"spell_id":id,"clip":phase.native_clip.id,"retained_tail":tail,"duration_ms":phase.duration_ms,"emitters":emitters})
            Effects.close(handle)
            await process_frame
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"sources":evidence}
    FileAccess.open("res://.runtime/native-spell-retained-tail-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_RETAINED_TAIL ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    owner.free();quit(0 if failures.is_empty() else 1)
