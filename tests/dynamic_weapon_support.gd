extends RefCounted
## Shared test staging and native replay helpers; no production art assignment.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const ITEM="4df65b6b-e8c4-42e6-928d-26e74b579ea1"
const EFFECT="f13a6583-c3c4-42d8-9fb9-eeff69686626"
static func cache()->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged:Resource=BodyIndex.new()
    var fixture:Resource=load("res://tests/fixtures/dynamic_weapon_overlay.tres")
    Builder._equipment({"index":staged},{fixture.id:fixture})
    selected.item_effects=staged.item_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}

## Same draw/settle policy as the original native Vampiric replay gate.
static func frame(tree:SceneTree)->void:
    await tree.process_frame
    await RenderingServer.frame_post_draw

static func settle(tree:SceneTree,world:Node,ids:Array=[])->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        var native:RefCounted=world.component_renderer.native_spells
        var ready:bool=ids.all(func(id):return native.diagnostics.get(id,{}).get("status")=="rendered" and native.diagnostics[id].get("input_bindings",{}).get("unavailable",{}).is_empty())
        if world.playback_prepared() and ready:
            await frame(tree)
            if world.playback_prepared():return true
        await frame(tree)
    return false

static func changed(a:Image,b:Image)->int:
    a=a.duplicate();b=b.duplicate();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var count:int=0
    for pixel in a.get_width()*a.get_height():
        var at:int=pixel*4
        if absi(int(left[at])-int(right[at]))+absi(int(left[at+1])-int(right[at+1]))+absi(int(left[at+2])-int(right[at+2]))>3:count+=1
    return count
