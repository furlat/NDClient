extends "res://tests/native_light_output_checks.gd"
# Original source registration through Catalog, SpriteSources, native Canvas
# receiving and the existing final3D output. The expected path comes directly
# from the delivery, independently of the client's normalized manifest.
const DELIVERY="C:/Users/tommaso/Documents/assets/fantasy-unified-catalog/environment-normal-quality-2026-10-12"
const CAPTURES="res://.captures/environment-normal-delivery"
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
var selection:Dictionary={}
var dispositions:Dictionary={}
var source_rows:Array=[]
var preview:Image
var preview_row:=0

class AuthoredPhase extends Node:
    var phase:=0
    var sample_seconds:=0.0

func prop(asset:String,state:String="default")->Dictionary:
    return {"id":asset,"kind":"prop","asset":asset,"state":state,"position":[0,0],
        "base_height_steps":0,"layer":1,"orientation":"east"}

func library(asset:String)->Dictionary:
    return {"id":asset,"kind":"library","asset":asset,"position":[0,0],
        "base_height_steps":0,"layer":0,"orientation":"east","sequence":0}

func fixture(spec:Dictionary,quarter:int)->Dictionary:
    var row:Dictionary=spec.row
    var phase:int=spec.get("phase",0)
    var original:Dictionary=Catalog._environment_source(row,quarter,cache,phase,0.0)
    var chosen:Dictionary=selection.get(Catalog.media_path(original.normal.region.path),{})
    var expected_path:String=chosen.get("path",original.normal.region.path)
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.catalog_cache=cache
    probe.camera=Camera3D.new();probe.add_child(probe.camera);probe.quarter=quarter
    var rotation=Basis(Vector3.UP,quarter*PI*.5)
    probe.camera.position=rotation*Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    if phase>0:
        var playback=AuthoredPhase.new();playback.phase=phase;probe.add_child(playback)
        probe.destruction[row.id]=playback
    probe.add_entry(row,"body",0,probe.ENVIRONMENT_SHADER,1)
    var entry:Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var selected:Dictionary=entry.record
    var label:String=spec.id+"-q"+str(quarter)
    check(selected.normal.region.path==expected_path,label+" uses independently selected delivery path")
    var required={}
    EnvironmentMedia.record_paths(selected,required,cache)
    check(required.has(expected_path),label+" mandatory environment source enumeration includes selected normal")
    var unchanged:Dictionary=selected.duplicate(true)
    unchanged.normal.region.path=original.normal.region.path
    unchanged.normal.erase("original_path");unchanged.normal.erase("receiving_qualification")
    check(unchanged==original,label+" preserves every original source/alpha/depth/support/clock/registration field")
    var nr:Array=original.normal.region.rect
    var source:Image=texture(original.normal.region.path).get_image()
    var expected:Image=texture(expected_path).get_image()
    var bound:Texture2D=entry.material.get_shader_parameter("normal_texture")
    check(bound.get_image().get_data()==expected.get_data(),label+" production material binds the actual selected packet bytes")
    check(source.get_size()==expected.get_size(),label+" packet dimensions remain unchanged")
    var region=Rect2i(nr[0],nr[1],nr[2],nr[3])
    var old_bytes:PackedByteArray=source.get_region(region).get_data()
    var new_bytes:PackedByteArray=expected.get_region(region).get_data()
    var depth_changes:=0;var normal_changes:=0;var unsupported_changes:=0
    for offset in range(0,old_bytes.size(),4):
        if old_bytes[offset]!=new_bytes[offset] or old_bytes[offset+1]!=new_bytes[offset+1]:depth_changes+=1
        var changed:bool=old_bytes[offset+2]!=new_bytes[offset+2] or old_bytes[offset+3]!=new_bytes[offset+3]
        if changed:normal_changes+=1
        if old_bytes[offset]==0 and old_bytes[offset+1]==0 and changed:unsupported_changes+=1
    check(depth_changes==0 and unsupported_changes==0,label+" normal-only selection keeps exact depth and unsupported pixels")
    if spec.retained:check(normal_changes==0 and chosen.is_empty(),label+" explicitly retained source stays original")
    elif phase!=1:check(normal_changes>0,label+" selected view really contains changed receiving normals")
    var material=ShaderMaterial.new();material.shader=EnvironmentReceiver
    for uniform in entry.material.shader.get_shader_uniform_list():material.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    material.set_shader_parameter("world_to_canvas",Basis(probe.camera.basis.x,-probe.camera.basis.y,probe.camera.basis.z).transposed())
    var rect:Array=selected.rect
    var colour:Image=probe.images[selected.path].get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
    var result={"id":label,"material":material,"colour":colour,"visible":1.0,
        "normal_changes":normal_changes,"expected_path":expected_path,"original_path":original.normal.region.path,
        "selected":not chosen.is_empty(),"retained":spec.retained}
    var asset_key:String="library/"+row.asset if row.kind=="library" else "bank/"+original.bank
    var disposition:Dictionary=dispositions.get(asset_key,{})
    source_rows.append({"id":label,"selected_path":expected_path,"original_path":original.normal.region.path,
        "label":chosen.get("label","retained original"),"qualification":chosen.get("qualification",disposition.get("reason","")),
        "disposition":disposition.get("status",""),"quality_limit":disposition.get("quality_limit",""),
        "frame":selected.frame,"normal_changes":normal_changes,"depth_changes":depth_changes,"unsupported_changes":unsupported_changes})
    probe.free()
    return result

func source_variant(value:Dictionary,path:String)->Dictionary:
    var result:Dictionary=value.duplicate()
    result.material=value.material.duplicate()
    result.material.set_shader_parameter("normal_texture",texture(path))
    return result

func native_case(value:Dictionary,zoom:float)->void:
    var expected=source_variant(value,value.expected_path)
    var original=source_variant(value,value.original_path)
    var actual_atlas=receiving(value,1,false,56,zoom,.8)
    var expected_atlas=receiving(expected,1,false,56,zoom,.8)
    var original_atlas=receiving(original,1,false,56,zoom,.8)
    var actual_output=spatial(value,actual_atlas)
    var expected_output=spatial(expected,expected_atlas)
    var original_output=spatial(original,original_atlas)
    # Exercise final spatial nearest sampling at the same fractional display
    # magnification as the receiving/light coordinates, with unclipped borders.
    var cell:Vector2i=value.colour.get_size()
    var target_size=Vector2i(ceili(cell.x*zoom)+16,ceili(cell.y*zoom)+16)
    for output in [actual_output,expected_output,original_output]:
        output.size=target_size
        var camera:Camera3D=output.get_child(1)
        camera.size=2.0*target_size.y/(cell.y*zoom)
    # The two receiving variants differ only at the selected normal sampler.
    # No native-light approximation or RGB tolerance is used for this path test.
    var actual:Image=await capture(actual_output)
    var reference:Image=await capture(expected_output)
    var before:Image=await capture(original_output)
    var difference=compare(actual,reference)
    var change=compare(actual,before)
    var id:String=value.id+"-zoom"+str(zoom)
    check(difference.changed_pixels==0,id+" final3D equals explicit delivery-path native reference byteexact")
    check(change.alpha_mismatches==0,id+" receiving replacement preserves final original alpha")
    if value.retained:check(change.changed_pixels==0,id+" retained source final output stays byteexact")
    elif value.normal_changes>0:check(change.changed_pixels>0,id+" selected normals affect native lighting")
    actual.save_png(CAPTURES+"/"+id+"-selected.png")
    before.save_png(CAPTURES+"/"+id+"-original.png")
    if is_equal_approx(zoom,1.0):
        var left:Image=before.duplicate();left.resize(128,128,Image.INTERPOLATE_NEAREST)
        var right:Image=actual.duplicate();right.resize(128,128,Image.INTERPOLATE_NEAREST)
        var quarter:int=int(value.id.right(1))
        preview.blit_rect(left,Rect2i(0,0,128,128),Vector2i(quarter*256,preview_row*128))
        preview.blit_rect(right,Rect2i(0,0,128,128),Vector2i(quarter*256+128,preview_row*128))
    cases.append({"id":id,"explicit_path_reference":difference,"original_vs_selected":change})
    for node in [actual_output,expected_output,original_output,actual_atlas,expected_atlas,original_atlas]:node.queue_free()
    await process_frame

func unlit_case(value:Dictionary)->void:
    var old=source_variant(value,value.original_path)
    var selected=receiving(value,0,true)
    var original=receiving(old,0,true)
    var size:Vector2i=value.colour.get_size()
    var a:Image=(await capture(selected)).get_region(Rect2i(Vector2i.ZERO,size))
    var b:Image=(await capture(original)).get_region(Rect2i(Vector2i.ZERO,size))
    check(compare(a,b).changed_pixels==0,value.id+" no-light source RGBA remains byteexact")
    selected.queue_free();original.queue_free();await process_frame

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var delivery:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DELIVERY+"/quality.json"))
    selection=delivery.normals;dispositions=delivery.assets
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE)
    white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var specs:Array=[
        {"id":"desk","row":prop("environment.furniture.writing_desk"),"retained":false},
        {"id":"inferred-a2","row":library("fantasy.ground.a2"),"retained":false},
        {"id":"soil-a1","row":library("fantasy.ground.a1"),"retained":true},
        {"id":"ramp-g17","row":library("fantasy.ground.g17"),"retained":true},
        {"id":"cracks-i5","row":library("fantasy.ground.i5"),"retained":true},
        {"id":"chest-original","row":prop("environment.storage_chest","false"),"retained":true},
        {"id":"crate-break-first-retained","row":prop("environment.blocker.crate"),"phase":1,"retained":true},
        {"id":"desk-break-first","row":prop("environment.furniture.writing_desk"),"phase":1,"retained":false},
        {"id":"desk-break-final","row":prop("environment.furniture.writing_desk"),"phase":2,"retained":false}]
    preview=Image.create(1024,specs.size()*128,false,Image.FORMAT_RGBA8);preview.fill(Color("121821"))
    for spec in specs:
        for quarter in 4:
            var value=fixture(spec,quarter)
            await unlit_case(value)
            for zoom in [1.0,1.375]:await native_case(value,zoom)
        preview_row+=1
    preview.save_png(CAPTURES+"/comparison.png")
    var report={"checks":checks,"failures":failures,"sources":source_rows,"cases":cases,
        "renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "capture":CAPTURES+"/comparison.png","contact_sheet_rows":specs.map(func(spec):return spec.id),
        "scope":"Production source/normal binding and final3D path versus independently selected delivery packet. Exact native RGBA; original registrations/depth/support/alpha/clocks unchanged. Source-derived, inferred and retained qualifications remain distinct. This does not certify physical inferred relief or introduce gameplay bindings."}
    FileAccess.open("res://generated/environment_normal_delivery_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_NORMAL_DELIVERY_CHECKS ",checks,"/",failures.size())
    quit(0 if failures.is_empty() else 1)
