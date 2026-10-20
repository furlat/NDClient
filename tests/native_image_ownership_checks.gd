extends SceneTree
## Real descriptor cold-admission plus a private optical-owner control. These
## are resource ownership checks, not a replacement server journal or pixels.
const Renderer=preload("res://presentation/native_spell_renderer.gd")
const Sources=preload("res://presentation/body_sources.gd")
const Support=preload("res://presentation/native_scene_support.gd")
const Effects=preload("res://presentation/effect_package.gd")
const PATH="res://assets/art/media/smallscale/modular/Melee19/Idle.png"
class OpticalHost extends Node3D:
    var catalog_cache:Dictionary={}
    var character_light_profile:String="reference"
    var visual_actors:Dictionary={}
    var playbacks:Dictionary={}
    var displayed_components:Array=[]
    var textures:Dictionary={}
    var texture_revision:int=7
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_IMAGE_OWNERSHIP_FAIL ",label)
func run()->void:
    var host:=OpticalHost.new()
    var admitted:Dictionary=Sources.admission(host.catalog_cache)
    check(admitted.loaded.is_empty() and Sources.descriptor(PATH,"weapon",host.catalog_cache).is_empty(),"Actual optical Clip starts unadmitted in a fresh metadata owner")
    host.visual_actors={"lease-control":{"entries":[{"role":"body","texture_path":PATH,"actor_layer":{"slot":"weapon","effect":{},"paths":{"Idle":PATH}}}]}}
    var component:Dictionary={"id":"private-optical-owner-control","kind":"native_effect","native_spell":true,
        "status":"available","native_clip":Effects.clip("bg3-36/goodberry/goodberry_eat_native"),"native_cue":{},
        "actor_uuid":"lease-control","target_uuid":null,"cast_recipe":{}}
    var renderer:RefCounted=Renderer.new();renderer._required_ids={component.id:component}
    renderer._image_requirements(host)
    var receiver:RefCounted=Support.new()
    check(receiver.adopt(host).ready and receiver.solid_masks.is_empty(),"A pre-admission receiver does not invent a solid descriptor")
    var descriptor:Dictionary=Sources.prepare_descriptor(PATH,"weapon",host.catalog_cache)
    check(not descriptor.get("optical_paths",{}).is_empty(),"Actual offline metadata admission publishes the source's optical paths")
    if descriptor.get("optical_paths",{}).is_empty():host.free();quit(1);return
    var solid:String=descriptor.optical_paths.solid
    var image:Image=Image.load_from_file(ProjectSettings.globalize_path(solid))
    check(image!=null and not image.is_empty(),"Independent control loads the actual authored solid mask")
    if image!=null and not image.is_empty():
        host.textures[solid]=ImageTexture.create_from_image(image)
        check(receiver.adopt(host).ready and receiver.solid_masks.get(PATH)==host.textures[solid],"Metadata arrival re-adopts an already resident mask without a texture revision change")
    renderer._image_requirements(host)
    check(renderer.required_images.has(solid),"A cold descriptor miss cannot permanently cache an absent solid lease")
    host.displayed_components=[component];renderer._required_ids={}
    renderer._image_requirements(host)
    check(renderer.required_images.has(solid),"Current displayed native owner retains receiver mask when the next plan has no native source")
    var held:Dictionary=renderer.required_images
    renderer._image_requirements(host)
    check(is_same(held,renderer.required_images),"Unchanged immutable metadata and optical owners reuse the admitted image set")
    host.displayed_components=[];renderer._image_requirements(host)
    check(renderer.required_images.is_empty(),"No displayed or prepared source releases its image demand")
    renderer.groups={"private-prepared-layer-control":{}}
    renderer._image_requirements(host)
    check(renderer.required_images.has(solid),"A retained receiver pass owns the same current layer masks that adoption still requires")
    renderer.groups.clear();renderer._image_requirements(host)
    check(renderer.required_images.is_empty(),"Retiring the last private pass releases that mask demand")
    check(is_same(admitted.index,Sources.admission(host.catalog_cache).index),"Descriptor admission retains the immutable body index; no art or gameplay value changes")
    host.free()
    print("NATIVE_IMAGE_OWNERSHIP ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual unadmitted→admitted optical metadata, displayed/prepared receiver ownership and empty-owner release. No gameplay, source-mask generation, pixel/performance approval or separate resource registry."}))
    quit(0 if failures.is_empty() else 1)
