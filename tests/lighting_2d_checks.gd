extends SceneTree
const Lighting = preload("res://presentation/lighting_2d.gd")
const Existing = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
var checks=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("ADAPTER_FAIL ",label)
func same_world_samples(actual:Dictionary,expected:Dictionary)->bool:
    if actual.keys()!=expected.keys():return false
    for id in expected:
        for field in ["position","energy","range"]:
            if actual[id][field]!=expected[id][field]:return false
    return true
func _initialize()->void:run.call_deferred()
func run()->void:
    var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    var state=original.duplicate(true)
    var adapter=Lighting.new()
    adapter.fire_light_flicker=true
    var baseline=Existing.new()
    baseline.sources=Existing.resolve(state).sources
    baseline.sample({})
    var display=SubViewport.new();display.size=Vector2i(768,512);root.add_child(display)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12;display.add_child(camera)
    var page=SubViewport.new();page.size=Vector2i(1024,1024);page.disable_3d=true;root.add_child(page)
    var second=SubViewport.new();second.size=Vector2i(1024,1024);second.disable_3d=true;root.add_child(second)
    adapter.attach(page);adapter.attach_page(second);adapter.sync(state)
    check(state==original,"Source adapter does not mutate actual displayed state")
    check(adapter.sources==baseline.sources,"Actual admitted Crypt sources/radius fields equal unchanged canonical resolver")
    check(same_world_samples(adapter.sampled,baseline.sampled),"Actual world emitter samples equal existing world-anchor convention")
    check(adapter.nodes.size()==4 and adapter.nodes.values().all(func(n):return n is PointLight2D),"Actual four sources own only native PointLight2D nodes")
    check(second.get_child_count()==4,"Second atlas page receives one light per actual source, not per receiver")
    check(page.get_children().all(func(n):return not n is Light3D),"Atlas page has no physical 3D receiving light")
    var carried:Dictionary=adapter.sources.filter(func(s):return not s.actor_uuid.is_empty())[0]
    var fixed:Dictionary=adapter.sources.filter(func(s):return s.actor_uuid.is_empty())[0]
    var held:PointLight2D=adapter.nodes[carried.item_uuid]
    var rows={carried.actor_uuid:{"position":[2.25,3.5],"base_height_steps":2.5,"visual_height":.25}}
    var energies={carried.item_uuid:.5}
    var heights={fixed.item_uuid:1.75}
    adapter.sample(rows,energies,heights);baseline.sample(rows,energies,heights)
    check(same_world_samples(adapter.sampled,baseline.sampled),"Displayed movement/jump/fixture centroid and energy have identical world values")
    var quarter_rows:Array=[]
    for q in 4:
        var angle=PI/4+q*PI/2
        camera.position=Vector3(cos(angle)*10,10/sqrt(3.0),sin(angle)*10)
        camera.look_at(Vector3.ZERO)
        for size in [12.0,6.0]:
            camera.size=size
            adapter.project(camera,2.0)
            var values=adapter.canvas_sources()
            check(values.size()==4 and adapter.issues.is_empty(),"All actual sources project at quarter%d/size%.0f"%[q,size])
            var basis_point=camera.position-camera.basis.z*10
            var ppu=camera.unproject_position(basis_point+camera.basis.x).distance_to(camera.unproject_position(basis_point))
            for value in values:
                var node:PointLight2D=adapter.nodes[value.id]
                check(node.position.is_equal_approx(camera.unproject_position(value.world_position)),"Exact projected world position: "+value.id)
                check(is_equal_approx(value.span.x,value.outer*ppu*2) and is_equal_approx(value.span.y,value.outer*ppu*2),"Native cookie diameter follows exact disclosed outer radius: "+value.id)
                check(is_equal_approx(node.height,56.0*2.0/Placement.PIXELS_PER_UNIT*ppu),"Native normal height follows source pixels and orthographic zoom: "+value.id)
                check(node.energy==adapter.sampled[value.id].energy and node.texture==adapter.cookie and node.enabled,"Native energy/cookie/activation retain actual sampled values")
                check(node.color==Lighting.TORCH_COLOUR,"Only known actual Torch/Wall Torch semantic IDs use reference warm colour")
            quarter_rows.append({"quarter":q,"camera_size":size,"source_count":values.size(),"pixels_per_unit":ppu})
    check(adapter.nodes[carried.item_uuid]==held,"Reprojection retains original native source identity")
    adapter.sync(state);check(adapter.nodes[carried.item_uuid]==held,"Equal displayed state retains original native source identity")
    var item=state.actors[carried.actor_uuid].controlled_items.filter(func(i):return i.item_uuid==carried.item_uuid)[0]
    item.item_id="fixture.unknown_emitter"
    adapter.sync(state);adapter.project(camera)
    check(adapter.nodes[carried.item_uuid].color==Color.WHITE,"Typed unknown light item remains white, without name-based fire inference")
    state.senses.objects[fixed.item_uuid].visual=false
    adapter.sync(state);adapter.project(camera)
    check(not adapter.nodes.has(fixed.item_uuid) and adapter.canvas_sources().all(func(row):return row.id!=fixed.item_uuid),"Loss of current fixture sight removes both native light and shadow-source exposure")
    item.is_lit=false;adapter.sync(state);adapter.project(camera)
    check(not adapter.nodes.has(carried.item_uuid),"Extinguished carried source is removed on every page")
    check(second.get_child_count()>=2,"Remaining disclosed lights survive independent source removal")
    adapter.set_directionals({"directionalSources":[{"id":"up","directionToSource":[0,1,0],"colorLinear":[.2,.3,.4],"intensity":.7}]})
    for q in 4:
        var angle=PI/4+q*PI/2
        camera.position=Vector3(cos(angle)*10,10/sqrt(3.0),sin(angle)*10);camera.look_at(Vector3.ZERO)
        adapter.project(camera)
        var lamp:DirectionalLight2D=adapter.directional_nodes.up
        var native_direction=Vector3(-lamp.transform.y.x*(1-lamp.height),-lamp.transform.y.y*(1-lamp.height),lamp.height).normalized()
        var expected=Vector3(camera.basis.x.dot(Vector3.UP),-camera.basis.y.dot(Vector3.UP),camera.basis.z.dot(Vector3.UP))
        check(native_direction.is_equal_approx(expected) and lamp.enabled,"Native directional equation preserves authored source direction quarter%d"%q)
        check(lamp.color.srgb_to_linear().is_equal_approx(Color(.2,.3,.4)) and is_equal_approx(lamp.energy,.7),"Authored directional colour and intensity preserved")
    var original_sources=adapter.sources.duplicate(true)
    adapter.light_strength=1.0;adapter.sample(rows);adapter.project(camera)
    var original_samples=adapter.sampled.duplicate(true)
    for factor in [0.0,.5,1.0,1.5]:
        adapter.light_strength=factor;adapter.sample(rows);adapter.project(camera)
        for id in adapter.nodes:
            var light:PointLight2D=adapter.nodes[id]
            check(is_equal_approx(light.energy,original_samples[id].energy*factor) and light.enabled==(factor>0),"Light strength scales each native point and zero disables it")
            check(adapter.sampled[id].position==original_samples[id].position and adapter.sampled[id].range==original_samples[id].range,"Light strength changes neither canonical footprint nor displayed position")
        check(is_equal_approx(adapter.directional_nodes.up.energy,.7*factor) and adapter.directional_nodes.up.enabled==(factor>0),"Light strength also scales the native directional source")
        check(adapter.sources==original_sources,"Optical strength leaves admitted source records unchanged")
    adapter.light_strength=1.0
    adapter.set_directionals({"directionalSources":[{"id":"away","directionToSource":[0,-1,0],"colorLinear":[1,1,1],"intensity":1}]})
    adapter.project(camera)
    check(not adapter.directional_nodes.away.enabled and adapter.issues.size()==1,"Behind-plane native directional limitation is explicit, never silently mirrored")
    adapter.set_directionals({})
    adapter.sync({});adapter.project(camera)
    check(adapter.nodes.is_empty() and adapter.canvas_sources().is_empty() and adapter.issues.is_empty(),"Empty disclosed state clears all light and shadow-source rows")
    adapter.detach_page(second);adapter.clear_pages()
    await process_frame
    check(page.get_child_count()==0 and second.get_child_count()==0,"Page release retires all owned native emitters")
    check(original==JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/player-runs/20261011T223103.996259Z/state.json")),"Actual source fixture remains unchanged")
    var report={"checks":checks,"failures":failures,"camera_cases":quarter_rows,"scope":"Actual admitted Crypt source rows plus named typed unknown/extinguish/loss-of-sight and directional variations; no backend outcomes invented. Native node contract and projection checks are headless; atlas RGBA proof is the separate native probe."}
    var f=FileAccess.open("res://generated/lighting_2d_checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
    print("LIGHTING_2D_ADAPTER ",JSON.stringify(report))
    adapter=null;baseline=null
    for node in [display,page,second]:node.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
