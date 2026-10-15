extends SceneTree
const Source=preload('res://sandbox/factory_source.gd')
const Layer=preload('res://sandbox/effect_layer.gd')
var failures:Array=[]
var rows:Array=[]
func _initialize():
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    run.call_deferred()
func frame():
    await process_frame
    await RenderingServer.frame_post_draw
func run():
    DirAccess.make_dir_recursive_absolute('res://.captures/sandbox-scale')
    var library=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/sandbox/projectiles.json'))
    var clip:Dictionary
    for spell in library.spells:
        if spell.id=='chill_touch':clip=spell.clips[0]
    var views:Array=[]
    for scale in [1.0,.0251415744]:
        var view=SubViewport.new();view.size=Vector2i(384,384);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var camera=Camera3D.new();view.add_child(camera);camera.cull_mask=Layer.LAYER
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=112.5*scale;camera.position=Vector3(12,9.797958971,12)*scale;camera.near=.001;camera.far=1000;camera.look_at(Vector3.ZERO)
        var parent=Node3D.new();view.add_child(parent)
        var handle=Source.make(parent,clip.duplicate(true));handle.root.scale=Vector3.ONE*scale;handle.root.rotation.y=deg_to_rad(-45.);handle.root.show()
        views.append({'view':view,'handle':handle})
    var age=0.0
    for until in [1.4,1.64,1.7,2.3]:
        while age<float(until):
            age+=1./60.
            for v in views:Source.sample(v.handle,age,1./60.)
            await frame()
        # Isolate the spectral mesh before the contact flash. Whole-effect
        # pixel counts alone allowed the broken imported hand to pass.
        var hidden:Array=[]
        if is_equal_approx(until,1.64):
            for v in views:
                var hand=v.handle.components.effect.get_node('Donor/punch/Skeleton3D/demonhand')
                for piece in v.handle.geometry:
                    if piece.node!=hand and piece.node.visible:
                        hidden.append(piece.node);piece.node.hide()
            await frame()
        var a:Image=views[0].view.get_texture().get_image();var b:Image=views[1].view.get_texture().get_image()
        a.save_png('res://.captures/sandbox-scale/native-%.2f.png'%until);b.save_png('res://.captures/sandbox-scale/scaled-%.2f.png'%until)
        var mismatch=0;var occupied=0
        for y in a.get_height():
            for x in a.get_width():
                var p=a.get_pixel(x,y);var q=b.get_pixel(x,y)
                if maxf(p.a,q.a)<.05:continue
                occupied+=1
                if absf(p.a-q.a)+absf(p.r*p.a-q.r*q.a)+absf(p.g*p.a-q.g*q.a)+absf(p.b*p.a-q.b*q.a)>.2:mismatch+=1
        var fraction=float(mismatch)/maxi(1,occupied)
        rows.append({'hand_only':not hidden.is_empty(),'source_seconds':until,'occupied_pixels':occupied,'mismatch_fraction':fraction})
        if occupied<20 or fraction>.12:failures.append('Scale equivalence at%.2fs'%until)
        if not hidden.is_empty() and occupied<100:failures.append('Spectral hand itself must be visible, independently of contact particles')
        for node in hidden:node.show()
    for v in views:Source.close(v.handle)
    var report={'comparisons':rows,'failures':failures}
    FileAccess.open('res://.runtime/sandbox-scale-checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_SCALE_CHECKS ',JSON.stringify(report));quit(0 if failures.is_empty() else 1)
