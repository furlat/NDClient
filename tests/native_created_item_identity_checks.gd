extends "res://tests/native_vampiric_touch_render_checks.gd"
## Exact created-item lifetime ownership through ordinary published sprites.
const ROOT="res://tests/fixtures/schema16/created-flame-blade"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:await inspect_item(seat)
    finish()
func inspect_item(seat:String)->void:
    var index:Dictionary=Recording.read(ROOT.path_join(seat))
    check(index.ok,seat+": actual original creation journal opens")
    if not index.ok:return
    var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and not row.owner.get("creation_binding",{}).is_empty())
    check(spans.size()==1,seat+": one actual lifetime retains its independent creation proof or precise gap")
    if spans.size()!=1:return
    var span:Dictionary=spans[0];var at:float=index.presentation_end_ms+350.0
    var actor:String=span.owner.actor_uuid;var owner:String=span.owner.id
    var view:=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=at
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var position:Array=Recording.restore(index,at).state.actors[actor].last_visual_position
    world.camera_focus=Vector3(position[0],0,position[1]);world.initial_focus=true;world.camera.size=4;world.position_camera();world.grid_visible=false
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    for quarter in [0,1,2,3]:
        world.install_playback(Recording.restore(index,at));world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        if not await settle(world):break
        var renderer:RefCounted=world.component_renderer.native_spells
        var ids:Array=renderer.handles.keys().filter(func(id):return renderer.handles[id].component.get("condition_uuid")==owner and "created_item_identity" in renderer.handles[id].clip.get("inputs",[]))
        check(ids.size()==1,seat+": exact owner selects one complete created-item lifecycle")
        if ids.size()!=1:break
        if seat=="amber" and not await settle(world,ids[0]):break
        var handle:Dictionary=renderer.handles[ids[0]];var bindings:Dictionary=renderer.diagnostics.get(ids[0],{}).get("input_bindings",{})
        if renderer.diagnostics.get(ids[0],{}).get("status")=="missing":
            print("CREATED_IDENTITY_DIAGNOSTIC ",JSON.stringify({"seat":seat,"at_ms":at,"native":renderer.diagnostics[ids[0]],"pose":world.visual_actors.get(actor,{}).get("sampled_pose",{}),"entries":world.visual_actors.get(actor,{}).get("entries",[]).map(func(entry):return {"slot":entry.actor_layer.slot,"item":entry.actor_layer.get("item_uuid"),"visible":entry.node.is_visible_in_tree()})}))
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        if seat=="amber":
            check(bindings.get("unavailable",{}).is_empty() and "created_item_identity" in bindings.get("supplied",[]),seat+": actual source identity and exact weapon packet are admitted together")
            var identity:Dictionary=handle.component.creation_binding.identity
            check(handle.get("created_item_identity_input",{})==identity,seat+": source receives actual same-cast item/lifetime/caster UUIDs")
            var layers:Array=world.visual_actors[actor].entries.filter(func(row):return row.actor_layer.get("item_uuid")==identity.created_item_uuid and row.actor_layer.slot=="weapon")
            check(layers.size()==1 and layers[0].node.is_visible_in_tree(),seat+": ordinary equipped weapon sprite remains present")
            await frame();await frame();world.set_process(false)
            var shown:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var pixels:int=changed(shown,view.get_texture().get_image())
            check(pixels>0,seat+": native decoration contributes pixels on quarter"+str(quarter))
            evidence.append({"seat":seat,"quarter":quarter,"pixels":pixels,"bindings":bindings,"identity":identity})
            world.set_process(true)
        else:
            check(bindings.get("unavailable",{}).get("created_item_identity")=="creation_item_ancestry_not_disclosed",seat+": missing subjective ancestry is explicit, not borrowed from other faction")
            check(not handle.root.is_visible_in_tree(),seat+": an unproven creation cannot display the source's offline fixture")
            evidence.append({"seat":seat,"quarter":quarter,"bindings":bindings})
        check(var_to_bytes(world.timeline.state)==canonical,seat+": native binding preserves canonical state")
    world.component_renderer.native_spells.close(world)
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+": native lifetime path has no presentation errors")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,seat+": original independent recording remains immutable")
    view.queue_free();await frame();await frame()
func finish()->void:
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Original created-item lifetime and exact current modular weapon: native output in all quarters, independent unproven-seat refusal, original state/sprite retention and teardown. No native wielded body, fabricated removal or art approval."}
    FileAccess.open("res://.runtime/native-created-item-identity.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_CREATED_IDENTITY ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
