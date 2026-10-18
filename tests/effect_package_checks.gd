extends SceneTree
## Every clip the spells stage (and every spell hit's clip), through the
## client's package path: for each approach the clip has (each recorded
## variant, gpu, native) prepare it, build an occurrence, sample it at 0, 25,
## 50 and 75 % of its length and check that it builds, samples without error
## and draws. Moving clips fly a short path. Every node path the client's
## staging names must exist in every approach. Run with Forward+/Vulkan.
##   --script res://tests/effect_package_checks.gd -- [--spells=a,b] [--clips=id,...] [--save=res://.captures/effect-package]
const Effects=preload("res://presentation/effect_package.gd")
const Baked=preload("res://presentation/baked_effect.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const FrameProfile=preload("res://frame_profile.gd")
const SIZE:=Vector2i(256,256)
const LAYER:=1<<1
const TIMES:=[0.0,0.25,0.5,0.75]
var checks:int=0
var failures:Array=[]
var report:Array=[]
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
    for behavior in index.spells:
        var selected:Dictionary=Authoring.selection(behavior,cache)
        if not spells.is_empty() and str(selected.id) not in spells:continue
        var cues:Array=selected.staging.cues
        for at in cues.size():
            if at in selected.get("excluded_cue_indices",[]):continue
            var cue:Dictionary=cues[at]
            var clip:Dictionary=Effects.resolve(str(cue.clip),str(selected.id),str(cue.role))
            check(not clip.is_empty(),"Package clip for %s cue %d (%s)"%[selected.id,at,cue.clip])
            if clip.is_empty():continue
            if not clips.has(clip.id):clips[clip.id]={"clip":clip,"cues":[],"staged":{}}
            clips[clip.id].cues.append(cue);clips[clip.id].staged[str(cue.clip)]=str(selected.id)
        var hit:Dictionary=Authoring.hit(behavior,cache)
        if hit.get("definition",{}).get("status")=="available":
            check(hit.has("clip"),"Spell hit clip resolves in the package: "+str(selected.id))
            if hit.has("clip") and not clips.has(hit.clip.id):clips[hit.clip.id]={"clip":hit.clip,"cues":[],"staged":{}}
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
        if entry.error.is_empty():kinds[kind].built+=1;kinds[kind].construction_ms.append(entry.construction_ms)
        if entry.get("sampled",false):kinds[kind].sampled+=1
        if entry.get("drawn_max",0)>0:kinds[kind].drew+=1
    for kind in kinds:kinds[kind].construction_ms=FrameProfile.distribution(kinds[kind].construction_ms)
    var result={"checks":checks,"failures":failures,"clips":clips.size(),"kinds":kinds,"approaches":report,
        "scope":"Package clips staged by the client's 30 spells and spell hits; each approach prepared, built, sampled at 0/25/50/75 % and drawn in an isolated world. Drawing is coverage only (alpha>0), not a look comparison."}
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
    var kinds:Array=[]
    for approach in clip.approaches:
        if approach.kind not in kinds:kinds.append(approach.kind)
    var rows:Array=[]
    for kind in kinds:
        Effects.set_requested(kind)
        var cache:Dictionary={}
        var deadline:int=Time.get_ticks_msec()+120000
        var prepared:Dictionary=Effects.prepare([clip],cache)
        var started:int=Time.get_ticks_usec()
        while not prepared.ready and prepared.errors.is_empty() and Time.get_ticks_msec()<deadline:
            await frame();prepared=Effects.prepare([clip],cache)
        var count:int=clip.approaches.filter(func(approach):return approach.kind==kind).size()
        if kind=="recorded":
            while Time.get_ticks_msec()<deadline and not (Baked.request(clip) is Array and Baked.request(clip).size()==count):await frame()
        var prepare_ms:float=(Time.get_ticks_usec()-started)/1000.0
        check(prepared.ready,"Prepared %s %s: %s"%[clip.id,kind,str(prepared.errors)])
        if not prepared.ready:continue
        for variant in count:
            var row:Dictionary=await approach_checks(entry,kind,variant,prepare_ms)
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

func approach_checks(entry:Dictionary,kind:String,variant:int,prepare_ms:float)->Dictionary:
    var clip:Dictionary=entry.clip
    var label:String="%s %s%s"%[clip.id,kind,("-"+str(variant)) if kind=="recorded" else ""]
    var compiles_before:Dictionary=FrameProfile.pipeline_compilations()
    var started:int=Time.get_ticks_usec()
    var built:Variant=Effects.make(view.holder,clip,LAYER,variant)
    var handle:Dictionary=built if built is Dictionary and built.has("error") else {"root":null,"error":"construction raised a script error","clip":clip}
    var construction_ms:float=(Time.get_ticks_usec()-started)/1000.0
    var row:Dictionary={"clip":clip.id,"kind":kind,"variant":variant,"error":str(handle.get("error","")),"construction_ms":construction_ms,"prepare_ms":prepare_ms,
        "effect_kind":handle.get("effect_kind",""),"staged":entry.staged,"drawn":[],"sample_us":[],"images":[]}
    check(row.error.is_empty(),"Builds: "+label+" "+row.error)
    check(row.effect_kind==kind,"Plays the requested kind: "+label)
    if not row.error.is_empty():
        if is_instance_valid(handle.get("root")):Effects.close(handle)
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
    row.compiles=0
    var compiles_after:Dictionary=FrameProfile.pipeline_compilations()
    for field in compiles_after:row.compiles+=int(compiles_after[field])-int(compiles_before.get(field,0))
    check(row.drawn_max>0,"Draws at 0/25/50/75 %%: %s %s"%[label,str(row.drawn)])
    print("EFFECT_PACKAGE_APPROACH ",JSON.stringify(row.duplicate().merged({"images":null},true)))
    Effects.close(handle)
    await frame()
    return row
