extends SceneTree
const Preview=preload("res://presentation/native_effect_preview.gd")
var passed=0
var failures:Array=[]
var samples:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var owner=Node3D.new();root.add_child(owner)
    var camera_basis=Basis.looking_at(Vector3(-6,-sqrt(24.0),-6))
    for id in ["blood.hit_a1","blood.hit_a2"]:
        for fps in [30,60]:
            for rate in [1,2]:
                var preview=Preview.new();owner.add_child(preview)
                check(preview.configure(id,{},73).is_empty(),id+" native source constructs")
                var observed=0;var maximum_lag=0.0
                for frame in 12:
                    await process_frame
                    var age=float(frame+1)*rate/fps
                    var result=preview.sample(age,camera_basis,Vector3.ZERO,1.0,[],{"native_continuous":true,"native_frame_seconds":root.get_process_delta_time()})
                    check(result.error.is_empty(),id+" source accepts advancing age")
                    await RenderingServer.frame_post_draw
                    maximum_lag=maxf(maximum_lag,absf(preview.sampled_age-age))
                    check(is_equal_approx(preview.sampled_age,age),id+" native draw reaches requested age at %dfps %dx"%[fps,rate])
                    check(preview.surface.visible and preview.sample_ready,id+" advancing source publishes without repeated same-age request")
                    if frame==5:
                        var image=preview.views[0].viewport.get_texture().get_image()
                        for y in image.get_height():
                            for x in image.get_width():
                                if image.get_pixel(x,y).a>0.0:observed+=1
                check(observed>0,id+" advancing source produces actual native coverage")
                samples.append({"id":id,"fps":fps,"rate":rate,"max_source_age_error":maximum_lag,"native_covered_pixels":observed})
                preview.close();preview.free()
    owner.free()
    var report={"passed":passed,"failed":failures.size(),"failures":failures,"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Stationary native particle progress/coverage at supplied30/60Hz display age steps and actual native process delta; production lighting, moving-history parity and depth receiver are separate"}
    var file=FileAccess.open("res://generated/native_effect_particle_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print(JSON.stringify(report));quit(1 if failures.size() else 0)
