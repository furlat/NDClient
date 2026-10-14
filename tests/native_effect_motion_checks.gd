extends SceneTree
# Independent native playback is the oracle for the sampler's explicit-clock
# adapter. Both use the selected source, but the reference never calls sample.
const Preview=preload("res://presentation/native_effect_preview.gd")
const Sources=preload("res://presentation/native_effects.gd")
var passed=0
var failures:Array=[]
var samples:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);push_error(label)
func freeze(native:Dictionary)->void:
    for row in native.emitters:row.node.speed_scale=0.
func _initialize()->void:call_deferred("run")
func transform_at(age:float)->Transform3D:
    var t=clampf(age/.4,0.,1.)
    return Transform3D(Basis(Vector3.UP,.3*t),Vector3(2.4*t,.4*sin(t*PI),-.6*t))
func run()->void:
    var fps=60
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--fps="):fps=int(arg.trim_prefix("--fps="))
    var owner=Node3D.new();root.add_child(owner)
    var basis=Basis.looking_at(Vector3(-6,-sqrt(24.),-6))
    var history:Array=[]
    for tick in 25:history.append({"age_seconds":tick/60.,"transform":transform_at(tick/60.)})
    for rate in [1.,2.]:
        var actual=Preview.new();owner.add_child(actual)
        var reference=Preview.new();owner.add_child(reference)
        var control=Preview.new();owner.add_child(control)
        check(actual.configure("spell.magic_missile.travel",{},19).is_empty(),"Moving selected native source builds")
        check(reference.configure("spell.magic_missile.travel",{},19).is_empty(),"Independent native reference builds")
        check(control.configure("spell.magic_missile.travel",{},19).is_empty(),"Second independent original native control builds")
        var reference_variations=0;var adapter_variations=0
        var control_bounds_variations=0;var sampled_transforms:Array=[]
        var last_age=0.
        for frame in range(1,int(.4*fps/rate)+1):
            await process_frame
            var age=frame*rate/fps
            var current=transform_at(age)
            var result=actual.sample(age,basis,Vector3.ZERO,1.,history,{"native_continuous":true,"native_frame_seconds":1./fps,"native_transform":current})
            check(result.error.is_empty(),"Live native sample accepts exact current transform")
            for original in [reference,control]:
                var native=original.handle
                if frame==1:
                    for row in native.emitters:
                        row.node.restart(true)
                        row.node.emitting=row.initial
                native.root.transform=current
                var native_rate=(age-last_age)/(1./fps)
                for row in native.emitters:row.node.speed_scale=native_rate
                RenderingServer.frame_post_draw.connect(func():freeze(native),CONNECT_ONE_SHOT)
                # Both original controls use direct native playback, never sample().
                original._frame_history(history,basis)
                for i in original.views.size():
                    original.views[i].camera.transform=actual.views[i].camera.transform
                    original.views[i].viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
                    original.views[i].output.render_target_update_mode=SubViewport.UPDATE_ONCE
            await RenderingServer.frame_post_draw
            check(actual.surface.visible and is_equal_approx(actual.sampled_age,age),"Advancing native projectile is visible at requested display age")
            check(actual.handle.root.transform==current,"Moving source follows exact supplied local transform")
            for i in actual.handle.emitters.size():
                var emitter=actual.handle.emitters[i].node;var original=reference.handle.emitters[i].node
                check(emitter.global_transform.is_equal_approx(original.global_transform) and emitter.seed==original.seed and emitter.fixed_fps==original.fixed_fps,"Native source transform, seed and fixed cadence match original")
            var a=actual.viewport.get_texture().get_image();var b=reference.viewport.get_texture().get_image()
            var c=control.viewport.get_texture().get_image()
            adapter_variations+=int(a.get_data()!=b.get_data())
            reference_variations+=int(b.get_data()!=c.get_data())
            for i in reference.handle.emitters.size():
                control_bounds_variations+=int(reference.handle.emitters[i].node.capture_aabb()!=control.handle.emitters[i].node.capture_aabb())
            if frame==1 or frame==int(.4*fps/rate):
                DirAccess.make_dir_recursive_absolute("res://.captures/native-effects/motion")
                a.save_png("res://.captures/native-effects/motion/%d-%d-%d-actual.png"%[fps,rate,frame]);b.save_png("res://.captures/native-effects/motion/%d-%d-%d-reference.png"%[fps,rate,frame]);c.save_png("res://.captures/native-effects/motion/%d-%d-%d-control.png"%[fps,rate,frame])
            if frame==int(.4*fps/rate):
                var alpha=0
                for y in a.get_height():
                    for x in a.get_width():alpha+=int(a.get_pixel(x,y).a>0)
                check(alpha>0,"Actual moving projectile has native source coverage")
                samples.append({"fps":fps,"rate":rate,"age":age,"covered_pixels":alpha,"canvas":[a.get_width(),a.get_height()],"adapter_different_frames":adapter_variations,"original_control_different_frames":reference_variations,"original_control_different_bounds":control_bounds_variations})
            last_age=age
        # Fixed-seed native instances can still differ; retain the independent
        # control result rather than silently adopting pixel tolerance.
        check(adapter_variations==0 or reference_variations>0,"Any byte-parity limitation is also reproduced by two direct native controls")
        # A paused request consumes no additional native simulation work.
        var held=actual.sample(last_age,basis,Vector3.ZERO,1.,history,{"native_continuous":false,"native_frame_seconds":1./fps})
        check(held.source_ready,"Paused native sample is already prepared")
        var held_bytes=actual.viewport.get_texture().get_image().get_data()
        for tick in 3:
            await process_frame
            actual.sample(last_age,basis,Vector3.ZERO,1.,history,{"native_continuous":false,"native_frame_seconds":1./fps})
            await RenderingServer.frame_post_draw
        check(actual.viewport.get_texture().get_image().get_data()==held_bytes,"Paused source preserves native particle image without repeated emission")
        actual.close();reference.close();control.close();actual.free();reference.free();control.free()
    owner.free()
    var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":samples,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Moving original selected Magic Missile emitter transforms and native fixed_fps at real display cadence; independent native controls never call helper sample. Byte differences are reported separately; trajectory, native source configuration, visible advancing age and paused stability are asserted."}
    var file=FileAccess.open("res://generated/native_effect_motion_%d_checks.json"%fps,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print(JSON.stringify(report));quit(1 if failures.size() else 0)
