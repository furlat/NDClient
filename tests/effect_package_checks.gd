extends SceneTree
## Inventory every selected spell cue/hit and every delivered approach.
## Time-only/root-path effects retain the isolated constructor, source-path,
## timed-sample and framebuffer oracle for every variant. An adaptive effect
## needs an actual disclosed owner/geometry/event, not the Factory review
## fixture: explicit missing construction operands must reject allocation;
## other adaptive output remains unqualified and listed per clip/approach.
## Real provider rendering gates supply that separate positive proof.
## Run with Forward+/Vulkan.
##   --script res://tests/effect_package_checks.gd -- [--spells=a,b] [--clips=id,...] [--save=res://.captures/effect-package]
const Effects=preload("res://presentation/effect_package.gd")
const Baked=preload("res://presentation/baked_effect.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const FrameProfile=preload("res://frame_profile.gd")
const SIZE:=Vector2i(256,256)
const LAYER:=1<<1
const TIMES:=[0.0,0.25,0.5,0.75]
# These two delivered programs explicitly contain only sample/pass. Their
# phases are inspection clocks for the renderer's real actor treatment. A
# blank interval is not a failed particle export or a rendered body witness.
# Exact sealed program identities keep an arbitrary blank source a failure.
const INSPECTION_PROGRAMS=["res://assets/vfx/sources/2fd2d9b87077a6008fc5/inspection_interval.gd",
    "res://assets/vfx/sources/3cb7f9045c39d6e78ccd/pose_probe_clock.gd"]
var checks:int=0
var failures:Array=[]
var report:Array=[]
var inventory:Array=[]
var authored_exclusions:Array=[]
var view:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("EFFECT_PACKAGE_FAIL ",label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func run()->void:
    create_timer(3000).timeout.connect(func():printerr("Effect package checks deadline");quit(2))
    var arguments:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        var parts:PackedStringArray=argument.trim_prefix("--").split("=",true,1)
        arguments[parts[0]]=parts[1] if parts.size()>1 else "true"
    var spells:Array=arguments.get("spells","").split(",",false)
    var ids:Array=arguments.get("clips","").split(",",false)
    var save_dir:String=arguments.get("save","")
    if not save_dir.is_empty():DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
    var cache:Dictionary={}
    var clips:Dictionary={}
    var index:Resource=Authoring.Sources.admission(cache).index
    check(index!=null,"Typed native spell index is admitted")
    if index==null:quit(1);return
    var selected_spells:Dictionary={}
    for behavior in index.spells:
        var selected:Dictionary=Authoring.selection(behavior,cache)
        if not spells.is_empty() and str(selected.id) not in spells:continue
        selected_spells[str(selected.id)]=true
        var cues:Array=selected.staging.cues
        for at in cues.size():
            var cue:Dictionary=cues[at]
            if at in selected.get("excluded_cue_indices",[]):
                authored_exclusions.append({"spell":selected.id,"cue_index":at,"clip":cue.clip,"role":cue.role,"source":selected.source+"/cues/"+str(at),"status":"authored_exclusion","draw_qualified":false})
                continue
            var clip:Dictionary=Effects.resolve(str(cue.clip),str(selected.id),str(cue.role))
            check(not clip.is_empty(),"Package clip for %s cue %d (%s)"%[selected.id,at,cue.clip])
            if clip.is_empty():continue
            if not clips.has(clip.id):clips[clip.id]={"clip":clip,"cues":[],"staged":{},"sources":[]}
            clips[clip.id].cues.append(cue);clips[clip.id].staged[str(cue.clip)]=str(selected.id)
            clips[clip.id].sources.append({"spell":selected.id,"cue_index":at,"role":cue.role,"source":selected.source+"/cues/"+str(at),"constructor_input":cue.get("constructor_input",{}),"unbound_constructor_inputs":cue.get("unbound_constructor_inputs",[])})
        var hit:Dictionary=Authoring.hit(behavior,cache)
        if hit.get("definition",{}).get("status")=="available":
            check(hit.has("clip"),"Spell hit clip resolves in the package: "+str(selected.id))
            if hit.has("clip"):
                if not clips.has(hit.clip.id):clips[hit.clip.id]={"clip":hit.clip,"cues":[],"staged":{},"sources":[]}
                clips[hit.clip.id].sources.append({"spell":selected.id,"role":"hit_material","source":hit.get("source",selected.source+"/hit")})
    for spell in spells:check(selected_spells.has(spell),"Requested spell exists in the selected typed inventory: "+spell)
    for id in ids:check(clips.has(id),"Requested clip exists in the selected typed inventory: "+id)
    check(not clips.is_empty(),"Selected typed inventory contains package clips")
    view=_view()
    for id in clips:
        if not ids.is_empty() and id not in ids:continue
        await clip_checks(clips[id],save_dir)
    Effects.set_requested("")
    var kinds:Dictionary={}
    for entry in report:
        var kind:String=entry.kind
        if not kinds.has(kind):kinds[kind]={"approaches":0,"built":0,"sampled":0,"drew":0,"construction_ms":[]}
        kinds[kind].approaches+=1
        if entry.contract=="context_free" and entry.error.is_empty():
            kinds[kind].built+=1;kinds[kind].construction_ms.append(entry.construction_ms)
        if entry.get("sampled",false):kinds[kind].sampled+=1
        if entry.get("drawn_max",0)>0:kinds[kind].drew+=1
    for kind in kinds:kinds[kind].construction_ms=FrameProfile.distribution(kinds[kind].construction_ms)
    var partition:Dictionary={"context_free":0,"constructor_required":0,"runtime_bound":0,"renderer_owned_interval":0}
    for entry in inventory:partition[entry.contract]+=1
    check(inventory.size()==report.size(),"Every enumerated approach variant has one explicit contract result")
    var expected:int=0
    for id in clips:
        if ids.is_empty() or id in ids:expected+=clips[id].clip.approaches.size()
    check(inventory.size()==expected,"The contract partition exhausts every selected package approach/variant")
    var adaptive:Array=report.filter(func(row):return row.contract!="context_free")
    var result={"checks":checks,"failures":failures,"spells":selected_spells.size(),"clips":clips.size(),"requested_clips":ids,"partition":partition,"kinds":kinds,"approaches":report,
        "authored_exclusions":authored_exclusions,"adaptive_output_qualified":adaptive.is_empty(),"adaptive_follow_up_required":adaptive.map(func(row):return {"clip":row.clip,"kind":row.kind,"approach_id":row.approach_id,"variant":row.variant,"constructor":row.get("constructor",""),"source_phase":row.get("source_phase",""),"inputs":row.inputs,"status":row.status,"sources":row.sources}),
        "scope":"Exhaustive selected typed spell cue/hit approach inventory. Context-free/root-path approaches retain constructor, staged paths, finite samples and isolated nonzero-alpha output assertions; that is pixel coverage, not a look comparison. Adaptive rows are not construction/sample/draw passes: explicit construction-required rows test allocation rejection only, and all actual adaptive outputs still require their real recording/provider gates. Authored exclusions are listed separately; this gate does not qualify all spells or providers."}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime"))
    FileAccess.open("res://.runtime/effect-package-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("EFFECT_PACKAGE_KINDS ",JSON.stringify(kinds))
    print("EFFECT_PACKAGE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)

func _view()->Dictionary:
    var viewport:=SubViewport.new()
    viewport.size=SIZE;viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var camera:=Camera3D.new();camera.cull_mask=LAYER;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9.0
    camera.near=0.05;camera.far=200.0
    var environment:=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR
    camera.environment=environment
    viewport.add_child(camera)
    var holder:=Node3D.new();viewport.add_child(holder)
    root.add_child(viewport)
    camera.look_at_from_position(Vector3(0,6,10),Vector3(0,0.5,0))
    return {"viewport":viewport,"camera":camera,"holder":holder}

## A flight across the view in source time (begin 0, launch at 20 %).
static func _flight(seconds:float)->Dictionary:
    return {"role":"flight","from":Vector3(-3,0.5,0),"to":Vector3(3,0.5,0),"bend":Vector2(0,1),"begin":0.0,"launch":0.2*seconds,"contact":seconds,
        "source_launch":0.2*seconds,"source_contact":seconds,"scale":1.0,"end":seconds}

func clip_checks(entry:Dictionary,save_dir:String)->void:
    var clip:Dictionary=entry.clip
    var rows:Array=[]
    for approach in clip.approaches:
        var kind:String=approach.kind
        var variant:int=int(approach.get("variant",0))
        var exact:Dictionary=clip.duplicate(false);exact.approach_id=str(approach.id)
        var selected_entry:Dictionary=entry.duplicate(false);selected_entry.clip=exact
        Effects.set_requested(kind)
        var chosen:Dictionary=Effects.choice(exact)
        check(chosen.kind==kind and chosen.approaches.size()==1 and chosen.approaches[0].id==approach.id,"The exact listed package approach is selected: "+clip.id+" "+str(approach.id))
        var contextual:Array=[]
        for input in clip.inputs:
            if input!="root_path" and input not in contextual:contextual.append(input)
        var construction:bool=Effects.requires_construction(exact) or entry.cues.any(func(cue):return not cue.get("constructor_input",{}).is_empty() or not cue.get("unbound_constructor_inputs",[]).is_empty())
        var contract:String="constructor_required" if construction else "runtime_bound" if not contextual.is_empty() else "renderer_owned_interval" if inspection_interval(exact) else "context_free"
        inventory.append({"clip":clip.id,"kind":kind,"approach_id":approach.id,"variant":variant,"contract":contract})
        if contract!="context_free":
            # Every approach remains an explicit unqualified inventory entry;
            # none borrows a default live constructor or a review fixture.
            var row:Dictionary={"clip":clip.id,"kind":kind,"approach_id":approach.id,"variant":variant,"contract":contract,"inputs":clip.inputs,"staged":entry.staged,"sources":entry.sources,
                "source_phase":approach.get("source_phase",""),"constructor":approach.path,"status":"requires_factual_provider","error":"","sampled":false,"draw_qualified":false}
            check(FileAccess.file_exists(approach.path) and (kind=="recorded" or FileAccess.file_exists(approach.source_phase)),"Adaptive program retains its delivered program/phase: "+clip.id+" "+str(approach.id))
            check(contextual.all(func(input):return not str(clip.input_setters.get(input,"")).is_empty()),"Adaptive input declarations retain their named public setters: "+clip.id)
            if construction:
                var raw:Dictionary=exact.duplicate(false);raw.requires_constructor_input=true
                var before:int=view.holder.get_child_count()
                var rejected:Dictionary=Effects.make(view.holder,raw,LAYER,variant)
                check(rejected.error=="Native construction operands unavailable: "+str(clip.id),"Missing actual construction operands reject explicitly: "+clip.id)
                check(rejected.root==null and rejected.get("occurrence")==null and view.holder.get_child_count()==before,"Rejected construction allocates no occurrence or draw: "+clip.id)
                row.status="missing_construction_rejected_output_unqualified";row.admission_error=rejected.error
            elif contract=="renderer_owned_interval":row.status="inspection_clock_only_actor_treatment_requires_separate_output_proof"
            report.append(row)
            print("EFFECT_PACKAGE_CONTEXT_REQUIRED ",JSON.stringify(row))
            continue
        var cache:Dictionary={}
        var deadline:int=Time.get_ticks_msec()+120000
        var started:int=Time.get_ticks_usec()
        var prepared:Dictionary=Effects.prepare([exact],cache)
        while not prepared.ready and prepared.errors.is_empty() and Time.get_ticks_msec()<deadline:
            await frame();prepared=Effects.prepare([exact],cache)
        var prepare_ms:float=(Time.get_ticks_usec()-started)/1000.0
        check(prepared.ready,"Prepared exact %s %s: %s"%[clip.id,approach.id,str(prepared.errors)])
        if not prepared.ready:
            report.append({"clip":clip.id,"kind":kind,"approach_id":approach.id,"variant":variant,"contract":"context_free","inputs":clip.inputs,"staged":entry.staged,"sources":entry.sources,
                "status":"preparation_failed","error":"Package preparation did not become ready: "+str(prepared),"sampled":false,"draw_qualified":false})
            continue
        var row:Dictionary=await approach_checks(selected_entry,kind,variant,prepare_ms)
        report.append(row);rows.append(row)
    if not save_dir.is_empty() and not rows.is_empty():
        var sheet:=Image.create_empty(SIZE.x*TIMES.size(),SIZE.y*rows.size(),false,Image.FORMAT_RGBA8)
        sheet.fill(Color(0.08,0.09,0.11,1))
        for r in rows.size():
            for c in rows[r].get("images",[]).size():
                var image:Image=rows[r].images[c]
                sheet.blend_rect(image,Rect2i(Vector2i.ZERO,SIZE),Vector2i(c*SIZE.x,r*SIZE.y))
        sheet.save_png(ProjectSettings.globalize_path(save_dir.path_join(str(clip.id).replace("/","__")+".png")))
    for row in rows:row.erase("images")

static func inspection_interval(clip:Dictionary)->bool:
    var selected:Dictionary=Effects.choice(clip)
    var approach:Dictionary={}
    if selected.kind=="recorded":
        # The original recorded family belongs to the original first live
        # source, not to any subsequently appended real-art alternative.
        for candidate in clip.approaches:
            if candidate.kind!="recorded":approach=candidate;break
    elif not selected.approaches.is_empty():approach=selected.approaches[0]
    if not approach.has("source_phase"):return false
    var phase:Resource=load(approach.source_phase)
    if phase==null or not phase.emitters.is_empty() or phase.components.is_empty():return false
    for part in phase.components:
        if part.constructor_script not in INSPECTION_PROGRAMS:return false
    return true

func approach_checks(entry:Dictionary,kind:String,variant:int,prepare_ms:float)->Dictionary:
    var clip:Dictionary=entry.clip
    var label:String="%s %s"%[clip.id,clip.approach_id]
    var compiles_before:Dictionary=FrameProfile.pipeline_compilations()
    var started:int=Time.get_ticks_usec()
    var built:Variant=Effects.make(view.holder,clip,LAYER,variant)
    var handle:Dictionary=built if built is Dictionary and built.has("error") else {"root":null,"error":"construction raised a script error","clip":clip}
    var construction_ms:float=(Time.get_ticks_usec()-started)/1000.0
    var row:Dictionary={"clip":clip.id,"kind":kind,"approach_id":clip.approach_id,"variant":variant,"contract":"context_free","inputs":clip.inputs,"status":"construction_failed","draw_qualified":false,"error":str(handle.get("error","")),"construction_ms":construction_ms,"prepare_ms":prepare_ms,
        "effect_kind":handle.get("effect_kind",""),"staged":entry.staged,"sources":entry.sources,"drawn":[],"sample_us":[],"images":[]}
    check(row.error.is_empty(),"Builds: "+label+" "+row.error)
    check(row.effect_kind==kind,"Plays the requested kind: "+label)
    var chosen:Dictionary=Effects.choice(clip).approaches[0]
    check(handle.effect_approach_id==chosen.id and handle.effect_approach_path==chosen.path and handle.effect_source_phase==str(chosen.get("source_phase","")),"Constructed occurrence uses the exact inventoried constructor/phase: "+label)
    check(handle.effect_key==Effects.key(clip),"Exact source preparation identity reaches the constructed occurrence: "+label)
    row.constructor=handle.effect_approach_path;row.source_phase=handle.effect_source_phase
    if not row.error.is_empty():
        if is_instance_valid(handle.get("occurrence")) or is_instance_valid(handle.get("root")):Effects.close(handle)
        return row
    for cue in entry.cues:
        var missing:Array=Effects.resolve_paths(handle,cue,str(entry.staged.get(str(cue.clip),"")))
        if not handle.path_aliases.is_empty():row.path_aliases=handle.path_aliases
        check(missing.is_empty(),"Staged node paths exist in %s: %s"%[label,str(missing)])
        if not missing.is_empty():row.missing_paths=missing
    var moving:bool="root_path" in clip.inputs
    var seconds:float=float(clip.seconds)
    var cue:Dictionary=_flight(seconds)
    handle.root.show()
    var played:float=0.0
    for fraction in TIMES:
        var time:float=fraction*seconds
        # A simulation (not seekable) plays up to the time at 60 Hz, as the
        # renderer's history warming does; other approaches jump directly.
        while not handle.get("seekable",false) and played+1.0/60.0<time:
            played+=1.0/60.0
            Effects.place(handle,Playback.transform(cue,played,cue.from,1.0) if moving else Transform3D.IDENTITY)
            Effects.sample(handle,played)
            await process_frame
        played=time
        Effects.place(handle,Playback.transform(cue,time,cue.from,1.0) if moving else Transform3D.IDENTITY)
        var sample_started:int=Time.get_ticks_usec()
        Effects.sample(handle,time)
        if handle.get("baked",false) and handle.bundle.moving:
            Baked.follow(handle,cue,time,func(at:float)->Transform3D:return Playback.transform(cue,at,cue.from,1.0))
        row.sample_us.append(Time.get_ticks_usec()-sample_started)
        await frame();await frame()
        var image:Image=view.viewport.get_texture().get_image()
        image.convert(Image.FORMAT_RGBA8)
        var drawn:int=0
        var data:PackedByteArray=image.get_data()
        for at in range(3,data.size(),4):
            if data[at]>0:drawn+=1
        row.drawn.append(drawn);row.images.append(image)
    row.sampled=true
    row.drawn_max=row.drawn.max()
    row.draw_qualified=row.drawn_max>0 and row.get("missing_paths",[]).is_empty()
    row.status="context_free_draw_passed" if row.draw_qualified else "context_free_draw_failed"
    row.compiles=0
    var compiles_after:Dictionary=FrameProfile.pipeline_compilations()
    for field in compiles_after:row.compiles+=int(compiles_after[field])-int(compiles_before.get(field,0))
    check(row.drawn_max>0,"Draws at 0/25/50/75 %%: %s %s"%[label,str(row.drawn)])
    print("EFFECT_PACKAGE_APPROACH ",JSON.stringify(row.duplicate().merged({"images":null},true)))
    Effects.close(handle)
    await frame()
    return row
