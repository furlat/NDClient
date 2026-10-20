extends SceneTree
const Lighting=preload("res://presentation/lighting_2d.gd")
class CountLighting extends "res://presentation/lighting_2d.gd":
    var page_syncs:int=0
    var samples:int=0
    var constructors:int=0
    func _sync_page(page:Dictionary)->void:
        page_syncs+=1;super._sync_page(page)
    func _make_point(parent:Node,source:Dictionary)->PointLight2D:
        constructors+=1;return super._make_point(parent,source)
    func sample(actors:Dictionary,energy:Dictionary={},heights:Dictionary={},shadow_heights:Dictionary={})->void:
        samples+=1;super.sample(actors,energy,heights,shadow_heights)
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("LIGHT_PREPARED_PUBLICATION_FAIL ",label)
func source(x:float,z:float,appearance:String="torch",bright:float=15.0,dim:float=15.0,actor:String="")->Dictionary:
    return {"position":[x,z],"base_height_steps":0,"appearance":appearance,
        "anchor_entity_uuid":actor if not actor.is_empty() else null,"anchor_item_uuid":null,
        "actor_anchored":not actor.is_empty(),"very_bright_radius_feet":0.0,
        "bright_radius_feet":bright,"dim_radius_feet":dim}
func state(selected:Dictionary)->Dictionary:return {"light_sources":selected}
func make_side()->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var stage=Node3D.new();view.add_child(stage)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=8;stage.add_child(camera);camera.position=Vector3(0,8,8);camera.look_at(Vector3.ZERO);camera.current=true
    var canvas=Node2D.new();view.add_child(canvas)
    var image=Image.create(256,256,false,Image.FORMAT_RGBA8);image.fill(Color8(40,70,90,255))
    var normal=Image.create(1,1,false,Image.FORMAT_RGBA8);normal.fill(Color(.5,.5,1,1))
    var texture=CanvasTexture.new();texture.diffuse_texture=ImageTexture.create_from_image(image)
    texture.normal_texture=ImageTexture.create_from_image(normal)
    var sprite=Sprite2D.new();sprite.centered=false;sprite.texture=texture;canvas.add_child(sprite)
    var ambient=CanvasModulate.new();ambient.color=Color(.3,.3,.3,1);canvas.add_child(ambient)
    var lighting=CountLighting.new();lighting.attach_page(canvas)
    lighting.set_directionals({"directionalSources":[{"id":"fixed-directional","directionToSource":[0,1,1],"colorLinear":[.2,.3,.4],"intensity":.15}]})
    return {"view":view,"camera":camera,"lighting":lighting}
func finish(lighting:RefCounted,work:Dictionary)->void:
    for _step in 1000:
        if work.complete:return
        lighting.prepare_step(work)
    check(false,"Bounded emitter preparation completes")
func fields(node:PointLight2D)->Array:
    return [node.color,node.texture,node.position,node.scale,node.offset,node.texture_scale,node.height,node.energy,node.enabled]
func capture(a:Dictionary,b:Dictionary,label:String)->void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    var image:Image=a.view.get_texture().get_image()
    var reference:Image=b.view.get_texture().get_image()
    var exact:bool=image.get_data()==reference.get_data()
    check(exact,label+" first native framebuffer equals ordinary Lighting.sync")
    check(image.get_used_rect().size==Vector2i(256,256),label+" native framebuffer contains the full normal-mapped source")
    evidence.append({"case":label,"first_frame_exact":exact})
func prepare_cookies(lighting:RefCounted,desired:Dictionary)->void:
    for spec in Lighting.resolve(desired).sources:
        var deadline:int=Time.get_ticks_msec()+10000
        while lighting.prepare_cookie(spec)==null and Time.get_ticks_msec()<deadline:await process_frame
        check(lighting.prepare_cookie(spec)!=null,"Actual immutable range cookie prepares before its native source binding")

func transition(a:Dictionary,b:Dictionary,desired:Dictionary,label:String,expected:Array,actors:Dictionary={})->void:
    for side in [a,b]:await prepare_cookies(side.lighting,desired)
    var lighting:CountLighting=a.lighting
    var previous_sources:Array=lighting.sources
    var previous_colours:Dictionary=lighting._source_colours
    var old:Dictionary=lighting.nodes.duplicate()
    var old_fields:Dictionary={}
    for id in old:old_fields[id]=fields(old[id])
    var directional:Dictionary=lighting.directional_nodes.duplicate()
    var work:Dictionary=lighting.begin_preparation(Lighting.resolve(desired));finish(lighting,work)
    check(lighting.preparation_valid(work),label+" exact receiving-page base remains valid")
    check([work.nodes.size(),work.updates.size(),work.removals.size()]==expected,
        label+" preparation owns only actual new nodes, changed bindings and removals")
    check(lighting.sources==previous_sources and is_same(lighting._source_colours,previous_colours),
        label+" future source/colour membership remains private")
    for id in old:check(fields(old[id])==old_fields[id],label+" preparation leaves displayed native light "+id+" untouched")
    for record in work.nodes:
        check(not record.node.enabled and record.node.color==work.colours[record.id],
            label+" new node owns its exact future colour while disabled")
    var new_nodes:Array=work.nodes.duplicate()
    var syncs:int=lighting.page_syncs;var samples:int=lighting.samples;var constructors:int=lighting.constructors
    lighting.publish_prepared(work)
    check(lighting.page_syncs==syncs and lighting.samples==samples and lighting.constructors==constructors,
        label+" publication never traverses pages, resamples empty anchors or constructs lights")
    check(work.nodes.is_empty() and work.updates.is_empty() and work.removals.is_empty(),
        label+" publication transfers all candidate node/update ownership")
    for record in new_nodes:check(lighting.nodes[record.id]==record.node,label+" publication adopts the exact hidden node")
    for id in old:
        if lighting.nodes.has(id):check(lighting.nodes[id]==old[id],label+" unchanged identity retains its native light")
        else:check(not old[id].enabled and old[id].is_queued_for_deletion(),label+" removed light is disabled and retired")
    for id in directional:check(lighting.directional_nodes[id]==directional[id],label+" static directional owner remains unchanged")
    lighting.publish_prepared(work)
    check(lighting.page_syncs==syncs and lighting.samples==samples,label+" repeated adoption is a no-op")
    lighting.sample(actors);lighting.project(a.camera)
    b.lighting.sync(desired);b.lighting.sample(actors);b.lighting.project(b.camera)
    check(lighting.sampled==b.lighting.sampled and lighting.sources==b.lighting.sources,
        label+" normal displayed-anchor sampling preserves positions, heights, energies and ranges")
    for id in lighting.nodes:
        var left:PointLight2D=lighting.nodes[id];var right:PointLight2D=b.lighting.nodes[id]
        check([left.color,left.position,left.scale,left.offset,left.texture_scale,left.height,left.energy,left.enabled]
            ==[right.color,right.position,right.scale,right.offset,right.texture_scale,right.height,right.energy,right.enabled],
            label+" exact projected native parameters match ordinary synchronization")
    await capture(a,b,label)
func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    var a:Dictionary=make_side();var b:Dictionary=make_side()
    var initial:Dictionary=state({"a":source(-2,0),"b":source(2,0,"magic"),"d":source(0,2)})
    for side in [a,b]:
        await prepare_cookies(side.lighting,initial)
        side.lighting.sync(initial);side.lighting.sample({});side.lighting.project(side.camera)
    await capture(a,b,"initial")
    await transition(a,b,initial,"same-optics-new-array",[0,0,0])
    var changed:Dictionary=state({"a":source(-2,0,"magic",25,5),"c":source(1,0,"torch",10,10,"actor"),"d":source(0,2)})
    var actors={"actor":{"position":[-.5,1.0],"base_height_steps":1,"visual_height":.25}}
    await transition(a,b,changed,"add-remove-radius-colour",[1,1,1],actors)
    var moved:Dictionary=changed.duplicate(true);moved.light_sources.a.position=[-1,-1]
    await transition(a,b,moved,"position-only",[0,0,0],actors)
    await transition(a,b,state({}),"remove-all",[0,0,3])
    var retained:Dictionary=a.lighting.begin_preparation({"sources":a.lighting.sources,"issues":[]})
    check(retained.complete and retained.retained and a.lighting.preparation_valid(retained),"Retained exact source owner is immediately complete")
    var sample_count:int=a.lighting.samples;a.lighting.publish_prepared(retained)
    check(a.lighting.samples==sample_count,"Retained exact publication remains a no-op")
    for side in [a,b]:side.lighting.clear_pages();side.view.queue_free()
    await process_frame
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":evidence,
        "scope":"Prepared native light membership/colour/cookie deltas, hidden future nodes, unchanged identities and directional owners, actual displayed actor heights and first-draw parity against ordinary Lighting.sync. No performance claim."}
    if DisplayServer.get_name()!="headless":FileAccess.open("res://generated/light_prepared_publication_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_PREPARED_PUBLICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
