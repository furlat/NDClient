extends SceneTree
## Original and prepared native sources render in independent equal worlds.
## A second original control distinguishes native particle variance from changes.
const Before=preload("res://presentation/native_factory_source.gd")
const After=preload("res://presentation/native_factory_source.gd")
const Recording=preload("res://studio/recording.gd")
const Layer=preload("res://presentation/native_effect_layer.gd")
var checks:int=0
var failures:Array=[]
var rows:Array=[]
var cache:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("VARIANT_PIXEL_FAIL ",label)
func view(component:Dictionary,prepared:bool)->Dictionary:
    var output=SubViewport.new();output.size=Vector2i(256,256);output.disable_3d=true;output.transparent_bg=true;output.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(output)
    var viewport=SubViewport.new();viewport.size=output.size;viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;output.add_child(viewport)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3;camera.near=.01;camera.far=100;camera.cull_mask=Layer.LAYER
    camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color.BLACK;camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE
    viewport.add_child(camera);camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0));camera.position=camera.basis.z*10
    var rect=TextureRect.new();rect.size=Vector2(output.size);rect.texture=viewport.get_texture();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;output.add_child(rect)
    Layer.colours({"viewport":viewport,"output":rect},component.finish_profile,true)
    var parent=Node3D.new();viewport.add_child(parent)
    var clip:Dictionary=component.native_clip.duplicate(true)
    var handle:Dictionary=After.make(parent,clip,Layer.LAYER) if prepared else Before.make(parent,clip,Layer.LAYER,false)
    check(handle.error.is_empty(),clip.id+": native source constructed")
    handle.root.scale=Vector3.ONE*float(component.native_cue.get("scale",.18));handle.root.show()
    return {"output":output,"viewport":viewport,"handle":handle,"prepared":prepared}
func stats(a:Image,b:Image)->Dictionary:
    var changed:int=0;var covered:int=0;var max_delta:float=0;var total:float=0
    for y in a.get_height():
        for x in a.get_width():
            var c:Color=a.get_pixel(x,y);var d:Color=b.get_pixel(x,y)
            if maxf(c.r,maxf(c.g,c.b))>1.0/255:covered+=1
            var delta:float=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),maxf(absf(c.b-d.b),absf(c.a-d.a))))
            if delta>0:changed+=1
            max_delta=maxf(max_delta,delta);total+=delta
    return {"changed":changed,"covered":covered,"max_delta":max_delta,"total_delta":total}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240);Engine.max_fps=60
    create_timer(150).timeout.connect(func():printerr("Variant pixel deadline");quit(2))
    var index:Dictionary=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
    var selected:Dictionary={}
    var wanted:Array=["spells/chill_touch/impact/impact","spells/fireball/fire/lifecycle","recovered/travel","recovered/travelIce","spells/web/projectile/lifecycle","spells/magic_missile/default/impact","spells/shield/back/hit_E","spells/sanctuary/back/lifecycle","spells/thunderwave_production_xyz/whole/lifecycle","spells/produce_flame/palm_back/palm"]
    for row in index.rows:
        var c:Dictionary=row.get("component",{})
        if c.get("native_clip",{}).get("id","") in wanted:selected[c.native_clip.id]=c
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    for spell in manifest.spells:
        for clip in spell.clips:
            if clip.id=="recovered/travel" and spell.id!="ray_of_frost":continue
            if clip.id in wanted and not selected.has(clip.id):
                selected[clip.id]={"native_clip":clip,"native_cue":clip.get("placement",{}),"finish_profile":spell.palette}
    check(selected.size()==wanted.size(),"All actual selected source fixtures found")
    while true:
        var prepared:Dictionary=After.prepare(selected.values().map(func(c):return c.native_clip),cache)
        if not prepared.errors.is_empty():failures.append_array(prepared.errors);break
        if prepared.ready:break
        await process_frame
    DirAccess.make_dir_recursive_absolute("res://.captures/native-source-variants")
    if failures.is_empty():
        for source in wanted:
            var component:Dictionary=selected[source]
            var original:Dictionary=view(component,false);var prepared:Dictionary=view(component,true);var control:Dictionary=view(component,false)
            var captures:Array=[]
            for tick in 61:
                await process_frame
                var age:float=tick/60.0
                Before.sample(original.handle,age,1.0/60);After.sample(prepared.handle,age,1.0/60);Before.sample(control.handle,age,1.0/60)
                await RenderingServer.frame_post_draw
                if tick in [12,30,60]:
                    var a:Image=original.output.get_texture().get_image();var b:Image=prepared.output.get_texture().get_image();var c:Image=control.output.get_texture().get_image()
                    var actual:Dictionary=stats(a,b);var native_control:Dictionary=stats(a,c)
                    check(actual.total_delta<=native_control.total_delta,source+"@"+str(age)+": prepared pixels differ no more than two original native instances")
                    captures.append({"age":age,"prepared":actual,"original_control":native_control})
                    var name:String=source.replace("/","-")+"-"+str(tick)
                    a.save_png("res://.captures/native-source-variants/"+name+"-original.png");b.save_png("res://.captures/native-source-variants/"+name+"-prepared.png")
            check(captures.any(func(item):return item.prepared.covered>0),source+": original native source has actual visible pixels")
            rows.append({"source":source,"samples":captures});print("VARIANT_PIXELS ",JSON.stringify(rows.back()))
            Before.close(original.handle);After.close(prepared.handle);Before.close(control.handle)
            original.output.queue_free();prepared.output.queue_free();control.output.queue_free()
            await process_frame;await RenderingServer.frame_post_draw
    FileAccess.open("res://.runtime/native-source-variant-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":rows},"  "))
    print("VARIANT_PIXELS_COMPLETE ",checks," failures=",failures)
    quit(0 if failures.is_empty() else 1)
