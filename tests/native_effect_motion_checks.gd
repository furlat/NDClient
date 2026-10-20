extends "res://tests/native_recorded_preparation_checks.gd"
## The retired native_effects Magic Missile record no longer plays in the
## client. Test the actual sealed recorded Magic Missile instead: production
## placement/sampling versus a raw recorded constructor following the SAME
## chronological path. Native GPUParticles fixed_fps/speed_scale assertions
## belonged to that removed implementation; recorded source time, exact path,
## native output parity and paused pixels are the current observable contract.
const SourceRecords=preload("res://presentation/native_effects.gd")
const CLIP_ID="spells/magic_missile/default/cast"

func transform_at(age:float)->Transform3D:
    var fraction:float=clampf(age/.4,0.0,1.0)
    return Transform3D(Basis(Vector3.UP,.3*fraction),Vector3(2.4*fraction,.4*sin(fraction*PI),-.6*fraction))

func moving_sample(handle:Dictionary,age:float,raw:bool)->void:
    var current:Transform3D=transform_at(age)
    if raw:
        handle.root.transform=current
        Baked.sample(handle,age)
    else:
        Effects.place(handle,current)
        Effects.sample(handle,age)
    # Both original occurrences must receive the same real path prefix. The
    # explicit matrix/clock checks below are independent expected operands;
    # exact framebuffer parity is against the independently built raw source.
    Baked.follow(handle,{"role":"flight","begin":0.0,"launch":0.0,"contact":.4,"end":handle.clip.seconds,
        "source_launch":0.0,"source_contact":.4},age,transform_at)
    handle.root.show()

func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    if not check(DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="forward_plus","Actual Forward+/Vulkan native renderer is required"):
        quit(2);return
    var fps:int=60
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--fps="):fps=int(argument.trim_prefix("--fps="))
    if not check(fps>0,"An actual positive display cadence is required"):finish_motion(fps,[]);return
    check(SourceRecords.source_record("spell.magic_missile.travel",{}).is_empty(),"The replaced Magic Missile record is not revived")
    var clip:Dictionary=Effects.clip(CLIP_ID)
    if not check(not clip.is_empty() and Effects.choice(clip).kind=="recorded","Current Magic Missile selects its actual recorded source"):
        finish_motion(fps,[]);return
    var cache:Dictionary={};var prepared:Dictionary={"ready":false,"errors":[]}
    var deadline:int=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        prepared=Effects.prepare([clip],cache,true)
        if prepared.ready or not prepared.errors.is_empty():break
        await frame()
    if not check(prepared.ready and prepared.errors.is_empty(),"Actual Magic Missile admits source textures and materials: "+str(prepared)):
        finish_motion(fps,[]);return
    var results:Array=[]
    for rate in [1.0,2.0]:
        var sides:Array=[view(),view()]
        var actual:Dictionary=Effects.make(sides[0].holder,clip,LAYER,0)
        if not check(actual.error.is_empty(),"Production original source constructs: "+actual.error):
            Effects.close(actual)
            for side in sides:side.viewport.free()
            continue
        # Background variant admission may change the available seed set
        # between passes. The oracle must use THIS occurrence's actual source,
        # rather than a previously selected bundle from the earlier pass.
        var bundle:Resource=actual.bundle
        check(clip.approaches.any(func(approach):return approach.kind=="recorded" and approach.path==bundle.resource_path),"Actual owner selects a supplied original recording variant")
        var source:Node3D=bundle.scene.instantiate()
        var original:Dictionary=source_state(bundle.scene,source)
        var reference:Dictionary=Baked.make(sides[1].holder,bundle,clip,LAYER)
        if not check(actual.error.is_empty() and reference.error.is_empty(),"Production and independent raw original source construct: "+str([actual.error,reference.error])):
            Effects.close(actual);Effects.close(reference)
            source.free()
            for side in sides:side.viewport.free()
            continue
        check(is_same(actual.bundle,bundle) and is_same(reference.bundle,bundle),"Both occurrences use the identical original recording/seed variant")
        check(actual.slot!=reference.slot and actual.root!=reference.root,"Raw and production clocks/nodes are private")
        var visible:int=0;var compared_frames:int=0;var last_age:float=0.0
        var frames:int=int(ceil(float(clip.seconds)*.9*fps/rate))
        for index in range(1,frames+1):
            last_age=minf(float(clip.seconds)*.9,float(index)*rate/fps)
            moving_sample(actual,last_age,false);moving_sample(reference,last_age,true)
            check(actual.root.transform==transform_at(last_age) and reference.root.transform==transform_at(last_age),"Current world transform is exact at "+str([fps,rate,index]))
            check(actual.age==last_age and reference.age==last_age,"Each source clock reaches the actual requested age")
            if actual.history!=null:
                var column:int=clampi(int(floor(last_age*Baked.PATH_RATE)),0,actual.history_image.get_width()-1)
                for row in 3:
                    var expected:Color=Color(actual.root.transform.basis.x[row],actual.root.transform.basis.y[row],actual.root.transform.basis.z[row],actual.root.transform.origin[row])
                    check(actual.history_image.get_pixel(column,row)==expected,"Current recorded path column equals the independently supplied affine transform")
            await frame();await frame()
            var compared:Dictionary=pixels(image(sides[1]),image(sides[0]))
            check(compared.different_pixels==0,"Actual moving source equals independent raw original RGBA at "+str([fps,rate,index]))
            visible=maxi(visible,compared.visible_pixels);compared_frames+=1
        check(visible>0,"Moving actual Magic Missile includes positive native source pixels at rate "+str(rate))
        var held:PackedByteArray=image(sides[0]).get_data()
        for tick in 3:
            moving_sample(actual,last_age,false)
            await frame()
        check(image(sides[0]).get_data()==held,"Paused source preserves exact native output without new source time")
        check(source_state(bundle.scene,source)==original,"Motion and private clocks leave the original source properties unchanged")
        var owners:Array=[weakref(actual.root),weakref(reference.root)]
        Effects.close(actual);Effects.close(reference)
        check(owners.all(func(value):return value.get_ref()==null),"Both independent native occurrence owners are released")
        results.append({"fps":fps,"rate":rate,"frames":compared_frames,"age":last_age,"covered_pixels":visible,"source_bundle":bundle.resource_path})
        source.free()
        for side in sides:side.viewport.free()
        await frame()
    finish_motion(fps,results)

func finish_motion(fps:int,results:Array)->void:
    var report:Dictionary={"checks":checks,"failed":failures.size(),"failures":failures,"cases":results,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Actual sealed recorded Magic Missile at requested display cadences/rates; exact root/path/source clock operands, independent raw-recorded same-prefix RGBA, positive native output, pause and source immutability. Retired GPUParticles speed_scale/fixed_fps implementation is not claimed."}
    FileAccess.open("res://generated/native_effect_motion_%d_checks.json"%fps,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
