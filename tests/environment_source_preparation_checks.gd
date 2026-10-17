extends SceneTree
## Constructor ownership/operands only. Tiny prepared textures deliberately do
## not stand in for the separate native authored-image framebuffer oracle.
const Sources=preload("res://presentation/sprite_sources.gd")
const Description=preload("res://presentation/environment_source.gd")
const Resources=preload("res://presentation/environment_resources.gd")
const Placement=preload("res://placement.gd")
var checks:int=0
var failures:Array=[]
class FixtureSources extends Sources:
    var pixels:Texture2D
    var player_policy:bool=false
    func texture(_path:String)->Texture2D:return pixels
    func _light_entry(entry:Dictionary)->void:
        if player_policy:SourceMaterial.apply(entry,SourceMaterial.environment_policy(entry.placement.kind,entry.role))
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ENVIRONMENT_PREPARATION_FAIL ",label)
func owner(quarter:int,pixels:Texture2D,cache:Dictionary)->FixtureSources:
    var value:=FixtureSources.new();value.pixels=pixels;value.quarter=quarter
    value.camera=Camera3D.new();value.add_child(value.camera);root.add_child(value)
    value.camera.transform=Placement.camera_transform(Vector3.ZERO,quarter)
    value.catalog_cache=Sources.Catalog.source_snapshot(cache)
    return value
func compare(a:Dictionary,b:Dictionary)->void:
    var label:String=a.id
    check(a.id==b.id and a.placement==b.placement and a.role==b.role and a.layer==b.layer,label+" selected draw")
    check(a.source_parameters==b.source_parameters and a.source_changes==b.source_changes,label+" exact parameter operands")
    check(a.source_version==b.source_version and a.source_binding_revision==b.source_binding_revision,label+" source revision provenance")
    check(a.node.transform==b.node.transform and a.node.mesh.size==b.node.mesh.size and a.node.mesh.center_offset==b.node.mesh.center_offset,label+" native quad")
    check(a.node.custom_aabb==b.node.custom_aabb and a.screen_rect==b.screen_rect and a.node.visible==b.node.visible,label+" receiver and painted bounds")
    check(a.get("wall_picks")==b.get("wall_picks") and a.get("wall_variant")==b.get("wall_variant"),label+" joined/member ownership")
    for name in a.source_parameters:
        check(a.material.get_shader_parameter(name)==b.material.get_shader_parameter(name),label+" native uniform "+str(name))
func run()->void:
    var pixels:Texture2D=ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
    var authored:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json"))
    var rows:Array=[];var cache:Dictionary={}
    for row in authored.scenes[0].placements:
        if row.kind=="actor" or row.has("lit_animation") or row.get("water_surface",false):continue
        if Sources.Catalog.environment(row,0,cache).has("water"):continue
        rows.append(row)
    check(not rows.is_empty(),"Real authored environment rows selected")
    check(not Description.row_packet({"water_surface":true},0,Basis.IDENTITY,cache,true,true).eligible,"Water clock stays with scene owner")
    # A fixture's static body is prepared like any prop; its animated flame
    # (layer 100) and clock stay with the scene owner.
    # Live WorldRows add lit_animation to a disclosed lit prop; use a real
    # authored prop row with and without it.
    var body_row:Dictionary={}
    for row in rows:
        if row.kind not in ["terrain","wall","cliff","door"]:body_row=row;break
    check(not body_row.is_empty(),"Real authored prop row selected for the fixture contract")
    if not body_row.is_empty():
        var lit_row:Dictionary=body_row.duplicate(true);lit_row.lit_animation="torch.flame"
        var plain_packet:Dictionary=Description.row_packet(body_row,0,Basis.IDENTITY,cache,true,true)
        var lit_packet:Dictionary=Description.row_packet(lit_row,0,Basis.IDENTITY,cache,true,true)
        check(lit_packet.eligible and lit_packet.entries.size()==plain_packet.entries.size(),"Fixture static body has the same prepared operands")
        check(lit_packet.paths==plain_packet.paths,"Fixture static body requests the same body sources")
        check(not lit_packet.get("entries",[]).any(func(entry):return entry.layer==100),"Fixture flame and clock stay with scene owner")
    var names:Dictionary=Sources.environment_parameter_names()
    for quarter in 4:
        var reference:FixtureSources=owner(quarter,pixels,cache)
        var prepared:FixtureSources=owner(quarter,pixels,cache)
        var packets:Dictionary={};var textures:Dictionary={}
        for row in rows:
            var packet:Dictionary=Description.row_packet(row,quarter,prepared.camera.basis,prepared.catalog_cache,true,true)
            check(packet.eligible,"Authoritative static row has prepared operands")
            if not packet.eligible:continue
            packets[row.id]=packet
            for path in packet.paths:textures[path]=pixels
            reference._environment_row(row.duplicate(true))
        var output:Dictionary={}
        var task:int=WorkerThreadPool.add_task(Resources.build_private.bind(packets,textures,names,output),false,"Environment constructor qualification")
        while not WorkerThreadPool.is_task_completed(task):await process_frame
        WorkerThreadPool.wait_for_task_completion(task)
        check(output.get("complete",false) and output.get("error","").is_empty(),"Finite resource worker completes")
        check(prepared.entries.is_empty() and prepared.get_child_count()==1,"Resource preparation creates no scene Nodes")
        if not output.get("complete",false):reference.free();prepared.free();continue
        for id in packets:
            for entry in output.rows[id]:
                check(not entry.has("node") and entry.mesh is QuadMesh and entry.material is ShaderMaterial,"Worker owns only private native resources")
            prepared.adopt_environment_row({},output.rows[id])
        check(reference.entries.size()==prepared.entries.size(),"Exact draw membership after main adoption")
        for i in reference.entries.size():compare(reference.entries[i],prepared.entries[i])
        reference.free();prepared.free()
    # Generic Sources above deliberately has no Play lighting policy. Exercise
    # the real policy as an explicit producer operand as well, including its
    # final hidden visibility, without changing the ordinary constructor oracle.
    var policy_row:Dictionary={}
    for row in rows:
        if row.kind in ["wall","door"]:policy_row=row;break
    check(not policy_row.is_empty(),"Actual authored wall/door supplies the player-policy case")
    if not policy_row.is_empty():
        var reference:FixtureSources=owner(0,pixels,cache);reference.player_policy=true
        var prepared:FixtureSources=owner(0,pixels,cache);prepared.player_policy=true
        var packet:Dictionary=Description.row_packet(policy_row,0,prepared.camera.basis,prepared.catalog_cache,true,true)
        var textures:Dictionary={}
        for path in packet.paths:textures[path]=pixels
        for selected in packet.entries:
            selected.light_parameters=Sources.SourceMaterial.environment_policy(selected.placement.kind,selected.role)
            if not selected.descriptor.get("empty",false):selected.descriptor.parameters.current_visibility=0.0
        var output:Dictionary={}
        Resources.build_private({policy_row.id:packet},textures,names,output)
        check(output.get("complete",false) and output.get("error","").is_empty(),"Explicit final player policy constructor completes")
        reference._environment_row(policy_row.duplicate(true))
        for entry in reference.entries:
            if entry.has("cell"):Sources.SourceMaterial.set_parameter(entry,"current_visibility",0.0)
        prepared.adopt_environment_row(policy_row,output.rows[policy_row.id])
        check(reference.entries.size()==prepared.entries.size(),"Player-policy constructor retains exact draw membership")
        for i in reference.entries.size():compare(reference.entries[i],prepared.entries[i])
        reference.free();prepared.free()
    var empty:Dictionary=Description.describe({"position":[0,0],"base_height_steps":0},{},1,0,Basis.IDENTITY,true,true)
    check(empty.empty and not empty.visible and not empty.has("parameters"),"Empty selected source remains hidden without fabricated geometry")
    var missing:Dictionary={}
    Resources.build_private({"missing":{"entries":[{"descriptor":{"parameters":{},"texture_parameters":{"colour_texture":"absent"}}}]}},{},names,missing)
    check(not missing.complete and not missing.error.is_empty(),"Missing actual selected texture fails private preparation")
    var report:Dictionary={"checks":checks,"failures":failures,"scope":"Exact live/private source operands and ownership in all four authored views; native uniform values, provenance, geometry/bounds; finite worker contains no Nodes, water/fixture clocks remain main. No authored-image pixel or gameplay performance claim."}
    FileAccess.open("res://generated/environment_source_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_SOURCE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
