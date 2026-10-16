extends SceneTree
## Authored outline source assembly and lifetime through the public prepare/sample
## boundary. Allocation checks qualify the explicit no-construction sample rule.
const Outline=preload("res://presentation/condition_outline.gd")
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
    var outline=Outline.new()
    var material={"outline":{"color":16777215,"pulseColor":16777215},"outline_age_ms":0,"outline_initial":true,"outline_alpha":1.0}
    var no_budget={"used_usec":0,"limit_usec":0}
    check(not outline.prepare(host,"a",no_budget).ready,"Exhausted account keeps required owner pending")
    check(host.actor_entries.is_empty(),"Private preparation publishes no draw entry")
    var before:int=get_node_count()
    check(not outline.sample(host,"a",material),"Unprepared sample reports pending")
    check(get_node_count()==before,"Unprepared sample constructs nothing")
    for id in ["a","b"]:check(not outline.prepare(host,id).ready,"First assembled draw remains pending: "+id)
    check(host.actor_entries.is_empty(),"Prepared owners remain unpublished")
    await draw()
    for id in ["a","b"]:check(outline.prepare(host,id).ready,"Quiet first assembly prepares: "+id)
    for id in ["a","b"]:outline.sample(host,id,material)
    await draw()
    for id in ["a","b"]:check(outline.sample(host,id,material),"Prepared assembly is drawn: "+id)
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
    var report={"checks":checks,"failures":failures,"scope":"Real outline assembly frames, quiet/private preparation, reuse, independent same-sheet owners and release. No gameplay timing claim."}
    FileAccess.open("res://generated/condition_outline_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_OUTLINE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
