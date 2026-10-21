extends SceneTree
# Real adopted sources. This headless fixture proves resource/clock ownership;
# it is deliberately not native particle pixels or game-world composition proof.
const Effects=preload("res://presentation/native_effects.gd")
const Preview=preload("res://presentation/native_effect_preview.gd")
const Package=preload("res://presentation/effect_package.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var passed=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);push_error(label)
func blade_reference(path:Array,t:float,fps:float,contact:float,scale_x:float)->Vector3:
    var frame=t*contact/.67*fps
    var first=clampi(floori(frame),0,path.size()-1);var last=mini(first+1,path.size()-1)
    var p=Vector2(path[first].x,path[first].y).lerp(Vector2(path[last].x,path[last].y),frame-floor(frame))
    var sx=(p.x-64.)*2.*scale_x;var sy=(87.-p.y)*2.
    return Vector3(sx/128.-sy/192.,sy/96.,-sx/128.-sy/192.)
func _initialize()->void:call_deferred("run")
func run()->void:
    var parent=Node3D.new();root.add_child(parent)
    var cache={}
    var record=Effects.source_record("class.action_surge",cache)
    var saved=record.duplicate(true)
    var first=Effects.make(parent,record)
    var second=Effects.make(parent,record)
    check(first.error.is_empty() and second.error.is_empty(),"Exact selected class sources construct")
    check(first.subject.kind=="burst" and first.subject.side_name=="all","Both exported partitions resolve to one complete native composition")
    check(first.subject.ribbons.size()==6 and first.subject.motes.size()==19,"Original six ribbons and nineteen motes survive intake")
    check(record.palette.colors==["#496c84","#92b9cb","#ddbc89"],"Selected Action Surge palette is preserved")
    Effects.sample(first,.25);Effects.sample(second,.5)
    var geometry=first.subject.ribbons[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var mote=first.subject.motes[0].position
    Effects.sample(first,.7);Effects.sample(first,.25)
    check(first.subject.ribbons[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==geometry and first.subject.motes[0].position==mote,"Absolute backward/forward source sampling restores complete geometry")
    check(second.subject.age==.5,"Sampling one occurrence leaves the other source clock unchanged")
    check(not is_same(first.subject.ribbons[0].material_override,second.subject.ribbons[0].material_override),"Two occurrences own independent mutable materials")
    first.subject.ribbons[0].material_override.set_shader_parameter("strength",.01)
    check(second.subject.ribbons[0].material_override.get_shader_parameter("strength")!=.01,"Occurrence material edits do not leak")
    check(record==saved,"Construction and samples preserve borrowed source metadata")
    var source_script:Script=load(record.script)
    check(source_script!=null,"Native code counterpart is installed, not an exported sprite substitute")
    var preview=Preview.new();parent.add_child(preview)
    check(preview.configure("class.action_surge",cache).is_empty(),"Shared native presenter builds source viewport/palette/output")
    var request=preview.sample(.25,Basis.IDENTITY,Vector3(3,2,4),.5)
    check(not request.ready and request.source_ready,"Thumbnail readiness waits for actual native draw")
    check(preview.texture()!=null and preview.surface.mesh.size==Vector2(384,384)/float(record.pixels_per_unit),"Source output preserves native cell registration")
    preview.close();preview.free()
    var weapon_source=Effects.source_record("class.martial.impact",cache)
    var source_colors=weapon_source.palette.colors.duplicate()
    var recipe_colors=[0x1155aa,0x33bb88,0xeeff66]
    var tinted=Preview.new();parent.add_child(tinted)
    check(tinted.configure("class.martial.impact",cache,0,recipe_colors).is_empty(),"Native weapon effect accepts its authored occurrence palette")
    for view in tinted.views:
        var material:ShaderMaterial=view.output.get_child(0).get_child(0).material
        check(material.get_shader_parameter("palette_low")==Color("#1155aa") and material.get_shader_parameter("palette_middle")==Color("#33bb88") and material.get_shader_parameter("palette_high")==Color("#eeff66"),"Both source partitions use the recipe colors in their actual palette pass")
    check(weapon_source.palette.colors==source_colors and recipe_colors==[0x1155aa,0x33bb88,0xeeff66],"Palette override preserves cached source and caller recipe")
    tinted.close();tinted.free()
    for id in ["blood.hit_a1","blood.hit_a2"]:
        var selected=Effects.source_record(id,cache)
        var immutable=selected.duplicate(true)
        var effect=Effects.make(parent,selected,17)
        check(effect.error.is_empty(),id+" complete selected scene constructs")
        check(effect.emitters.size()==selected.emitters.size(),id+" every authored emitter retained")
        check(effect.players.size()==1,id+" declared property animation retained")
        var stopped=true
        for row in effect.emitters:stopped=stopped and row.node.speed_scale==0.0 and row.node.use_fixed_seed
        check(stopped,id+" particles wait for explicit display-clock work")
        var original:PackedScene=load(selected.scene)
        var independent:Node=original.instantiate()
        var original_player:AnimationPlayer=independent.get_node("AnimationPlayer")
        check(original_player.autoplay=="Init",id+" cached original autoplay/material resources stay immutable")
        var animation:Animation=original_player.get_animation("Init")
        var enabled=true
        for track in animation.get_track_count():enabled=enabled and animation.track_is_enabled(track)
        check(enabled,id+" source animation tracks are not changed by instance sampling")
        var unready=Effects.sample(effect,1.0,[Transform3D.IDENTITY])
        check(not unready.ready and not unready.error.is_empty(),id+" rejects missing moving-emitter history instead of fabricating trail")
        check(selected==immutable,id+" source record stays unchanged")
        independent.free();Effects.release(effect)
    # Spell phases now use the closed Factory package, shared with normal
    # gameplay. The obsolete raw donor ids must not resurrect a second path.
    Package.set_requested("gpu")
    var journal:Dictionary=Fixtures.read("gallery")
    check(journal.ok,"Original Gallery exposes current Magic Missile phases")
    for phase in ["flight","impact"]:
        var clip:Dictionary={}
        for wrapped in journal.get("groups",[]):
            for component in wrapped.group.components:
                if component.get("spell_id")=="magic_missile" and component.get("native_cue",{}).get("role")==phase:
                    clip=Package.occurrence_clip(component);break
            if not clip.is_empty():break
        check(not clip.is_empty(),"Actual Magic Missile "+phase+" retains its selected complete package clip")
        if clip.is_empty():continue
        var immutable=var_to_bytes(clip)
        var deadline=Time.get_ticks_msec()+30000
        var preparation:Dictionary=Package.prepare([clip],cache)
        while not preparation.ready and preparation.errors.is_empty() and Time.get_ticks_msec()<deadline:
            await process_frame;preparation=Package.prepare([clip],cache)
        check(preparation.ready and preparation.errors.is_empty(),"Selected Factory phase prepares: "+phase)
        if not preparation.ready:
            var job:Dictionary=Package.Admission._material_job
            print("FACTORY_PREPARATION_WAIT ",JSON.stringify({"phase":phase,"kind":Package.choice(clip).kind,"result":preparation,
                "source":clip.get("id"),"loading":Package.Admission.loading_path,"settling":Package.Admission.settling,
                "material_job":not job.is_empty(),"material_task_done":WorkerThreadPool.is_task_completed(job.task) if not job.is_empty() else true,
                "material_worker_ms":job.get("elapsed_ms",0.0),"material_count":job.get("materials",[]).size(),
                "last_worker":Package.Admission.material_profile}))
            # A failed phase leaves its genuine admission pending; later native
            # constructors cannot qualify while that same owner is occupied.
            Package.set_requested("");parent.free()
            print(JSON.stringify({"checks":passed+failures.size(),"failures":failures}))
            quit(1);return
        var first_spell:Dictionary=Package.make(parent,clip,1,91)
        var second_spell:Dictionary=Package.make(parent,clip,1,92)
        check(first_spell.error.is_empty() and second_spell.error.is_empty(),"Selected Factory phase constructs: "+phase)
        if first_spell.error.is_empty() and second_spell.error.is_empty():
            check(first_spell.root!=second_spell.root and first_spell.get("occurrence",first_spell.root)!=second_spell.get("occurrence",second_spell.root),"Factory occurrences own separate scene and clock: "+phase)
            Package.sample(first_spell,.1);Package.sample(second_spell,.2)
            Package.sample(first_spell,.3);Package.sample(first_spell,.1)
            check(is_equal_approx(first_spell.age,.1) and is_equal_approx(second_spell.age,.2),"Absolute source sampling preserves the other occurrence clock: "+phase)
            check(var_to_bytes(clip)==immutable,"Factory construction/sampling preserves selected metadata: "+phase)
        Package.close(first_spell);Package.close(second_spell)
        check(Effects.source_record("spell.magic_missile."+("travel" if phase=="flight" else phase),cache).is_empty(),"No retired raw spell donor substitutes the Factory source")
    var impact=Effects.make(parent,Effects.source_record("class.martial.impact",cache))
    check(impact.error.is_empty() and impact.subject.kind=="impact" and impact.subject.shards.size()==18,"Martial impact keeps original plane and eighteen shards")
    Effects.sample(impact,.25)
    var impact_position=impact.subject.shards[4].position
    Effects.sample(impact,.5);Effects.sample(impact,.25)
    check(impact.subject.shards[4].position==impact_position,"Martial impact seeks original explicit-age shard motion")
    Effects.release(impact)
    var slash_record=Effects.source_record("class.martial.slash",cache)
    var slash=Effects.make(parent,slash_record)
    var raw_paths=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_effects/class_actions/StrikePaths.json")).paths
    var path:Array=[]
    for point in raw_paths[3]:path.append({"x":point[0],"y":point[1]})
    var retained_path=path.duplicate(true)
    check(slash.error.is_empty(),"Native martial slash constructs original source")
    for clip in [[12.,.67,1.],[24.,.41,1.25],[8.,.9,.8]]:
        var context={"weapon_path":path,"weapon_path_fps":clip[0],"weapon_contact_seconds":clip[1],"weapon_scale_x":clip[2]}
        var result=Effects.sample(slash,.42,[],context)
        check(result.ready and result.error.is_empty() and slash.subject.trail.visible,"Measured slash accepts real clip/contact timing")
        var expected:Array=[]
        var latest=.42;var old=latest-.20
        for j in range(24):
            for ij in [Vector2i(j,0),Vector2i(j,1),Vector2i(j+1,1),Vector2i(j,0),Vector2i(j+1,1),Vector2i(j+1,0)]:
                var u=float(ij.x)/24.;var t=lerpf(old,latest,u)
                var point=blade_reference(path,t,clip[0],clip[1],clip[2])
                var tangent=blade_reference(path,t+.008,clip[0],clip[1],clip[2])-blade_reference(path,t-.008,clip[0],clip[1],clip[2])
                expected.append(point+tangent.cross(Vector3.ONE).normalized()*(.03+.055*sin(u*PI))*(1. if ij.y else -1.))
        var vertices=slash.subject.trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        var error=0.
        for i in vertices.size():error=maxf(error,vertices[i].distance_to(expected[i]))
        check(vertices.size()==144 and error<.000002,"Native smear vertices match recovered measured-pose equations across clip rates")
    check(path==retained_path,"Native slash leaves authored caller path unchanged")
    var missing=path.duplicate(true);missing[4]=null
    Effects.sample(slash,.42,[],{"weapon_path":missing,"weapon_path_fps":12.,"weapon_contact_seconds":.67})
    check(not slash.subject.trail.visible,"A missing measured pose omits the complete smear instead of fabricating a point")
    Effects.sample(slash,.42,[],{"weapon_path":path,"weapon_path_fps":12.,"weapon_contact_seconds":.67})
    check(slash.subject.trail.visible,"Restoring a measured path at the same age restores its native smear")
    Effects.release(slash)
    # Ground blood is now the authoritative field, not an independently
    # animated decal inferred at every impact. Its before/landing/settled and
    # reverse ownership/pixels are qualified by blood_kernel_cache_checks and
    # blood_residue_checks using the real schema16 deposits.
    for id in ["blood.deposit_a1","blood.deposit_j1"]:
        var removed=Effects.source_record(id,cache)
        var before=parent.get_child_count()
        check(removed.is_empty(),id+" is absent from current typed authoring")
        check(not Effects.make(parent,removed).error.is_empty() and parent.get_child_count()==before,"Retired client-invented deposit cannot attach an occurrence")
    var invalid=Effects.source_record("blood.hit_a1",cache).duplicate(true)
    invalid.node_properties={"missing_source_node":{"visible":false}}
    var owned_before=parent.get_child_count()
    check(not Effects.make(parent,invalid).error.is_empty() and parent.get_child_count()==owned_before,"Rejected source binding leaves no attached occurrence owner")
    # Keep a real source material and Script, not a fake task/completion flag.
    var terminal_materials:Array[Material]=[first.subject.ribbons[0].material_override]
    Effects.release(first);Effects.release(second);parent.free()
    # Leave the actual constructor's mutation frame before final submission.
    # No further frame, admission poll or normal readiness publication follows.
    await process_frame
    var token:RefCounted=RefCounted.new()
    var token_weak:WeakRef=weakref(token)
    var terminal_cache:Dictionary={"unpolled_owner_witness":token}
    token=null
    var already_prepared:bool=Package.Admission.prepare_materials(source_script,terminal_materials,terminal_cache)
    var job:Dictionary=Package.Admission._material_job
    var submitted:bool=not already_prepared and not job.is_empty() and is_same(job.get("owner"),terminal_cache) and int(job.get("task",-1))>=0
    check(submitted,"Actual material program task is submitted for terminal root ownership")
    var terminal:Dictionary={"native_pid":OS.get_process_id(),"submitted":submitted,
        "task":int(job.get("task",-1)),"unpolled_before_quit":submitted,
        "worker_complete_before_quit":WorkerThreadPool.is_task_completed(job.task) if submitted else null}
    # The production callback was connected before its actual task submission.
    # Observe the real root exit after that callback; never emit it manually.
    root.tree_exiting.connect(func():
        check(Package.Admission._material_job.is_empty(),"Actual root exit detaches the unpolled material job")
        check(token_weak.get_ref()==null,"Actual root exit joins the task and releases its bound cache owner")
        terminal.root_exit_observed=true
        terminal.material_job_empty=Package.Admission._material_job.is_empty()
        terminal.bound_owner_released=token_weak.get_ref()==null
        var report={"passed":passed,"failed":failures.size(),"failures":failures,"terminal_material":terminal,
            "scope":"Headless real-source geometry/property sampling and immutable instance ownership; actual unpolled material task root-exit collection. GPU particle/composition/palette pixels and historical crash task identity not claimed"}
        var file=FileAccess.open("res://generated/native_effect_source_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
        print(JSON.stringify(report)),CONNECT_ONE_SHOT)
    # The actual task/global owner is now the sole owner of this witness.
    job={};terminal_cache={};terminal_materials=[]
    quit(1 if failures.size() else 0)
