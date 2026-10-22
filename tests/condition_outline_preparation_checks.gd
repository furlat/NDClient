extends SceneTree
## Authored outline source assembly and lifetime through the public prepare/sample
## boundary. Allocation checks qualify the explicit no-construction sample rule.
const Outline=preload("res://presentation/condition_outline.gd")
const Construction=preload("res://presentation/actor_construction.gd")
class Host extends Node3D:
    var visual_actors:Dictionary={}
    var rigs:Dictionary={"fixture":{"cell_width":8,"cell_height":8}}
    var actor_entries:Array=[]
    var draw_order_dirty:bool=false
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("OUTLINE_PREPARATION_FAIL ",label)
func draw()->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
func run()->void:
    root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    create_timer(20).timeout.connect(func():printerr("Outline preparation deadline");quit(2))
    var host=Host.new();root.add_child(host)
    var image=Image.create(16,8,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
    image.fill_rect(Rect2i(1,1,6,6),Color.WHITE);image.fill_rect(Rect2i(10,2,4,4),Color.WHITE)
    var sheet=ImageTexture.create_from_image(image)
    for id in ["a","b"]:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();host.add_child(node)
        var entry={"id":id+":body","texture_path":"fixture","role":"body","node":node,
            "actor_layer":{"slot":"body","alpha":1.0},"source_parameters":{"sheet":sheet,"frame_uv":Vector4(0,0,.5,1)}}
        host.visual_actors[id]={"row":{"rig":"fixture"},"entries":[entry]}
    # One technical cropped-bank fixture in the actual rooted renderer gate.
    # Its source data is independent of the supplied Dragon/producer artwork.
    var rig:Dictionary={"native_banks":true,"cell_width":12,"cell_height":12,"origin_y_from_ground":3,
        "clips":{"Grid":{"bank_shapes":{"first":{"path":"first","cell":[6,4],"pivot":[2,3]},
            "second":{"path":"second","cell":[6,4],"pivot":[3,3]}}}}}
    host.rigs.native=rig
    var native_image:=Image.create(12,4,false,Image.FORMAT_RGBA8);native_image.fill(Color.TRANSPARENT)
    native_image.fill_rect(Rect2i(1,1,4,2),Color.WHITE);native_image.fill_rect(Rect2i(8,1,2,2),Color.WHITE)
    var native_sheet:=ImageTexture.create_from_image(native_image)
    var native_node:=MeshInstance3D.new();host.add_child(native_node)
    var native_material:=ShaderMaterial.new();native_material.shader=Construction.MODULAR_SHADER
    var native_entry:Dictionary={"id":"c:body","texture_path":"first","role":"body","node":native_node,
        "material":native_material,"actor_layer":{"slot":"body","alpha":1.0},"scale":1.0,
        "native_shape_rig":rig,"native_shape_scale":1.0,"native_shapes":Construction.prepare_native_shapes(rig,1.0)}
    var first:Dictionary={"cell":[6,4],"pivot":[2,3]}
    Construction.apply_source_shape(native_entry,rig,"first",first)
    Construction.SourceMaterial.apply(native_entry,{"sheet":native_sheet,"frame_uv":Vector4(0,0,.5,1)})
    host.visual_actors.c={"row":{"rig":"native"},"entries":[native_entry]}
    var outline=Outline.new()
    var material={"outline":{"color":16777215,"pulseColor":16777215},"outline_age_ms":0,"outline_initial":true,"outline_alpha":1.0}
    var no_budget={"used_usec":0,"limit_usec":0}
    check(not outline.prepare(host,"a",no_budget).ready,"Exhausted account keeps required owner pending")
    check(host.actor_entries.is_empty(),"Private preparation publishes no draw entry")
    var before:int=get_node_count()
    check(not outline.sample(host,"a",material),"Unprepared sample reports pending")
    check(get_node_count()==before,"Unprepared sample constructs nothing")
    for id in ["a","b","c"]:check(not outline.prepare(host,id).ready,"First assembled draw remains pending: "+id)
    check(host.actor_entries.is_empty(),"Prepared owners remain unpublished")
    await draw()
    for id in ["a","b","c"]:check(outline.prepare(host,id).ready,"Quiet first assembly prepares: "+id)
    for id in ["a","b","c"]:outline.sample(host,id,material)
    await draw()
    for id in ["a","b","c"]:check(outline.sample(host,id,material),"Prepared assembly is drawn: "+id)
    var native_owner:Dictionary=outline.owners.c
    check(native_owner.view.size==Vector2i(12,12) and native_owner.entry.node.mesh==native_entry.native_shapes[""].mesh
        and native_owner.entry.node.mesh!=native_entry.node.mesh,"Native contour maps the reference texture onto its actual pre-prepared reference quad")
    check(native_owner.sprites["c:body"].position==Vector2(4,6),"Native crop offset is reference contact(6,9) minus source contact(2,3)")
    var native_pixels:Image=native_owner.view.get_texture().get_image()
    check(native_pixels.get_pixel(5,7).a>.99 and native_pixels.get_pixel(8,8).a>.99
        and native_pixels.get_pixel(1,1).a==0 and native_pixels.get_pixel(9,7).a==0,"Actual native alpha is assembled at the hand-authored registered E pixels")
    var native_view:SubViewport=native_owner.view
    Construction.apply_source_shape(native_entry,rig,"second",{"cell":[6,4],"pivot":[3,3]})
    native_entry.texture_path="second"
    Construction.SourceMaterial.set_parameter(native_entry,"frame_uv",Vector4(.5,0,.5,1))
    outline.prepare(host,"c");outline.sample(host,"c",material);await draw()
    check(outline.sample(host,"c",material) and is_same(outline.owners.c,native_owner) and native_owner.view==native_view
        and native_owner.sprites["c:body"].position==Vector2(3,6),"Next actual bank/frame reuses the reference owner/viewport and updates its registered contact")
    native_pixels=native_owner.view.get_texture().get_image()
    check(native_pixels.get_pixel(5,7).a>.99 and native_pixels.get_pixel(6,8).a>.99
        and native_pixels.get_pixel(7,7).a==0,"Actual next-frame alpha occupies the independent expected registered pixels")
    var admitted_pivot:Vector2=native_entry.pivot;native_entry.pivot=Vector2(-1,-1)
    check(not outline.prepare(host,"c").ready and not native_owner.entry.node.visible,"Out-of-reference native crop refuses and withdraws rather than clipping")
    native_entry.pivot=admitted_pivot;outline.prepare(host,"c");await draw()
    check(outline.sample(host,"c",material),"Restored actual native owner readmits only after its real draw acknowledgment")
    var other:PackedByteArray=outline.owners.b.view.get_texture().get_image().get_data()
    var old:PackedByteArray=outline.owners.a.view.get_texture().get_image().get_data()
    before=get_node_count()
    host.visual_actors.a.entries[0].source_parameters.frame_uv=Vector4(.5,0,.5,1)
    outline.sample(host,"a",material);await draw()
    check(outline.sample(host,"a",material),"New authored frame draws")
    check(get_node_count()==before,"UV frame change reuses prepared sprites and materials")
    check(outline.owners.a.view.get_texture().get_image().get_data()!=old,"UV frame change updates actual assembled pixels")
    check(outline.owners.b.view.get_texture().get_image().get_data()==other,"Same-sheet peer retains independent frame")
    outline.sample(host,"a",{"outline":{}})
    check(not outline.owners.a.entry.node.visible,"Removed condition hides its output")
    check(outline.owners.a.sprites.values().all(func(sprite):return sprite.texture==null),"Inactive helper releases source texture references")
    outline.close(host);host.queue_free();await draw()
    var report={"checks":checks,"failures":failures,"scope":"Real rooted outline assembly frames, fixed-source peers and technical native crop/reference pixels, preparation/reuse/refusal/restoration and drained release. No Dragon/producer/art or gameplay timing claim."}
    FileAccess.open("res://generated/condition_outline_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_OUTLINE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
