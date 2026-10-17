extends "res://tests/native_demo_parity_checks.gd"
# End-to-end original demo preset, including authored component order/tint, direct
# native Canvas lighting and the production lit sprite -> spatial framebuffer path.
const PRESETS=[{"name":"Knight","items":["Chain Mail","Longsword","Shield"]},
    {"name":"Wizard","items":["Robes","Quarterstaff","Wizard's Hat"]}]
var assembled_rows:Array=[]
func outfit(preset:Dictionary)->Array:
    var selected={"body":{"category":"NakedBody","tint":0xDDAA88,"alpha":1.0},
        "head":{"category":"Head1","tint":0xFFFFFF,"alpha":1.0}}
    var index=Catalog.read_file("items/index.json",cache)
    var visuals=Catalog.read_file(index.item_visuals,cache)
    var appearances=Catalog.read_file(index.item_appearances,cache)
    for item in preset.items:
        for category in visuals.categories:
            if category.base_category!=item:continue
            var layers:Array=category.base_presentation.equipment_layers
            for hand in appearances.hands:
                if hand.category==item and hand.variant==null and hand.slot==category.equipment_slot:
                    layers=hand.layers;break
            for layer in layers:
                selected[layer.render_layer]={"category":layer.sprite_key,"tint":int(layer.tint_rgb),"alpha":1.0}
    var catalog=Catalog.read_file("catalog-index.json",cache)
    var rig=Catalog.read_file(catalog.rigs,cache)["neuroclient.modular"]
    var result:Array=[]
    for slot in rig.slot_order:
        if not selected.has(slot):continue
        var layer:Dictionary=selected[slot]
        var fixture=modular(layer.category,slot,int(rig.facing_rows.SW),"reference",false)
        fixture.family="modular";fixture.crop=Rect2i(0,0,128,128)
        fixture.category=layer.category;fixture.slot=slot;fixture.tint_rgb=layer.tint
        var t:int=layer.tint
        fixture.material.set_shader_parameter("tint",Vector3((t>>16)&255,(t>>8)&255,t&255)/255.0)
        fixture.material.set_shader_parameter("layer_alpha",1.0)
        result.append(fixture)
    check(result.size()==7,preset.name+" exact seven visible demo components; generated shadow is separate")
    return result

func assemble(fixture_layers:Array,zoom:float,lit:bool)->Dictionary:
    var offset=Vector2(91.37,83.23)
    var reference=page(false);reference.size=VIEW
    reference.get_child(0).color=Color(AMBIENT,AMBIENT,AMBIENT,1) if lit else Color.WHITE
    if lit:native_lights(reference,demo_lights(offset+Vector2(64,87)*zoom,zoom))
    var final_view=lit_view(VIEW)
    var original_shader=Shader.new();original_shader.code=FileAccess.get_file_as_string(DEMO)
    var accepted={}
    for u in original_shader.get_shader_uniform_list():accepted[u.name]=true
    for i in fixture_layers.size():
        var fixture:Dictionary=fixture_layers[i]
        var mat=ShaderMaterial.new();mat.shader=original_shader
        for u in fixture.material.shader.get_shader_uniform_list():
            if accepted.has(u.name):mat.set_shader_parameter(u.name,fixture.material.get_shader_parameter(u.name))
        var direct_node=Sprite2D.new();direct_node.texture=fixture.material.get_shader_parameter("sheet");direct_node.centered=false;direct_node.hframes=15;direct_node.vframes=8;direct_node.frame_coords=Vector2i(0,3);direct_node.position=offset;direct_node.scale=Vector2.ONE*zoom;direct_node.material=mat;direct_node.z_index=i;reference.add_child(direct_node)
        # Authored slot order is the painter order: one render priority per layer.
        var layer:ShaderMaterial=fixture.material.duplicate();layer.render_priority=i
        lit_quad(final_view,layer,Rect2(offset,Vector2(128,128)*zoom))
    publish_receiving(demo_lights(offset+Vector2(64,87)*zoom,zoom) if lit else [],AMBIENT if lit else 1.0)
    return {"reference":reference,"final":final_view}

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DirAccess.make_dir_recursive_absolute("res://.captures/assembled-demo")
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    for preset in PRESETS:
        var layers=outfit(preset)
        for zoom in [1.0,1.37,3.0]:
            for lit in [false,true]:
                var views=assemble(layers,zoom,lit)
                var actual=await capture(views.final);var expected=await capture(views.reference)
                var comparison=compare(actual,expected)
                check(comparison.alpha_mismatches==0,preset.name+" assembled final alpha matches direct demo at "+str(zoom))
                check(comparison.maximum_byte_error<=3,preset.name+" assembled final colour matches exact demo fixture within3RGBbytes: "+str(comparison))
                var stem=preset.name+"-"+str(zoom)+("-lit" if lit else "-raw")
                actual.save_png("res://.captures/assembled-demo/"+stem+"-final.png");expected.save_png("res://.captures/assembled-demo/"+stem+"-demo.png")
                var names:Array=[]
                for layer in layers:names.append({"slot":layer.slot,"category":layer.category,"tint":layer.tint_rgb})
                assembled_rows.append({"preset":preset.name,"layers":names,"zoom":zoom,"lit":lit,"comparison":comparison})
                for view in views.values():view.queue_free()
                await process_frame
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"rows":assembled_rows,"fixture":{"clip":"Idle","frame":0,"facing":"SW","normal_profile":"reference","light_height_source_px":56,"offset_source_px":[14,42],"cookie_scale":19.36,"energy":2,"colour":[.809372,.429306,.269121],"ambient":.176419},"scope":"Seven visible components per original Knight/Wizard preset, assembled in authored order with exact item tints. One original warm comparison light; generated ground shadows and gameplay source radii are separate from this receiving-colour comparison."}
    FileAccess.open("res://generated/native_assembled_demo_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ASSEMBLED_DEMO ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
