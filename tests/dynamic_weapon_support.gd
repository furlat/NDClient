extends RefCounted
## Shared test staging and native replay helpers; no production art assignment.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const Equipment=preload("res://tests/weapon_effect_support.gd")
const ITEM="4df65b6b-e8c4-42e6-928d-26e74b579ea1"
const EFFECT="f13a6583-c3c4-42d8-9fb9-eeff69686626"
static func cache()->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged:Resource=BodyIndex.new()
    var fixture:Resource=load("res://tests/fixtures/dynamic_weapon_overlay.tres")
    Equipment.equipment(staged,{fixture.id:fixture})
    selected.item_effects=staged.item_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}

## Same draw/settle policy as the original native Vampiric replay gate.
static func frame(tree:SceneTree)->void:
    await tree.process_frame
    await RenderingServer.frame_post_draw

static func settle(tree:SceneTree,world:Node,ids:Array=[],source_refusals:Array=[])->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        # Drive ordinary preparation, but observe this published cut rather
        # than waiting for an unrelated future queue entry while paused.
        world.playback_prepared()
        # The source's exact receiver program table is immutable in this run.
        # A missing offline artifact cannot become ready by waiting more frames.
        if world.displayed_components.any(func(component):
            var diagnostic:Dictionary=world.component_renderer.native_spells.diagnostics.get(component.id,{})
            return diagnostic.get("status")=="partial" and is_equal_approx(float(diagnostic.get("requested_age_ms",-1.0)),float(component.get("age_ms",-2.0))) \
                and str(diagnostic.get("reason","")).begins_with("actual_receiver_program_needs_offline_preparation:")):
            return false
        if displayed_ready(world,ids,source_refusals):
            await frame(tree)
            if displayed_ready(world,ids,source_refusals):return true
        await frame(tree)
    return false

static func displayed_ready(world:Node,ids:Array,source_refusals:Array=[])->bool:
    if world.timeline.state.is_empty() or world.world_prepare_epoch!=world.timeline.initialization_revision \
        or world.world_revision!=world.timeline.world_revision or world.actor_revision!=world.timeline.revision \
        or not world.component_renderer.ready:return false
    var native:RefCounted=world.component_renderer.native_spells
    return ids.all(func(id):
        var diagnostic:Dictionary=native.diagnostics.get(id,{})
        var current:Array=world.displayed_components.filter(func(component):return component.id==id)
        return current.size()==1 and native.handles.has(id) and native.handles[id].root.is_visible_in_tree() \
            and is_equal_approx(float(diagnostic.get("age_ms",-1.0)),float(current[0].age_ms)) \
            and (diagnostic.get("status")=="rendered" or diagnostic.get("status")=="partial" and diagnostic.get("reason") in source_refusals) \
            and diagnostic.get("input_bindings",{}).get("unavailable",{}).is_empty())

static func changed(a:Image,b:Image)->int:
    a=a.duplicate();b=b.duplicate();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var count:int=0
    for pixel in a.get_width()*a.get_height():
        var at:int=pixel*4
        if absi(int(left[at])-int(right[at]))+absi(int(left[at+1])-int(right[at+1]))+absi(int(left[at+2])-int(right[at+2]))>3:count+=1
    return count
