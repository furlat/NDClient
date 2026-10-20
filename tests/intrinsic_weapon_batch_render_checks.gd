extends "res://tests/weapon_runtime_receiver_render_checks.gd"
## Same production receiver gate across exact item assignments and originals.
const Items=preload("res://presentation/native_items.gd")
const OUT="res://.runtime/intrinsic-weapon-batch"
func receiver_pixels(world:Node,view:SubViewport,admitted:Dictionary,label:String,_oracle:bool)->void:
    # The unchanged common program has strict light/opacity oracles in the
    # original Ember and coating gates. These check each new actual receiver.
    await super.receiver_pixels(world,view,admitted,label,false)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUT)
    require_continuous_source=false
    source_refusals=["current_source_pose_has_no_authored_axis","material_only_source_has_no_qualified_finish"]
    var cases:Array=Fixtures.catalog().keys().filter(func(key):return str(key).begins_with("intrinsic-weapon-"));cases.sort()
    check(cases.size()==11,"Eleven exact-item candidate originals, not every artistic alternative")
    for key in cases:
        case_id=key
        var scenario:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Fixtures.case_record(key).scenario))
        item_id=str(scenario.actors[0].items[0].id)
        for seat in ["amber","blue"]:
            var index:Dictionary=Fixtures.read(key,seat)
            var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(Fixtures.journal(key,seat),true)
            check(index.ok and opened.ok,key+"/"+seat+": ordinary original/fold/production index open")
            if not index.ok or not opened.ok:continue
            index.media_preload=RecordingMedia.plan(index)
            var sources:Resource=Items.Bodies.index(index.cache)
            var look:Array=sources.gear[item_id]
            var actual:Array=sources.equipment[[look[0],null if str(look[1]).is_empty() else look[1],"weapon_melee_main"]]
            weapon_part=str(actual[0].sprite_key)
            var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("intrinsic_item_effect",false))
            check(rows.size()==1,key+"/"+seat+": one intrinsic source follows the actual equipped item")
            if rows.size()!=1:continue
            var owner:Dictionary=rows[0];var component:Dictionary=owner.component
            var poses:Array=cuts(index,owner,seat)
            check(poses.size()==3,key+"/"+seat+": real Idle, movement and attack are available")
            if poses.size()!=3:continue
            var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
            for quarter in 4:await original_view(index,owner,poses,key+"/"+seat,quarter,journal.snapshot())
            await accepted_contact(index,key+"/"+seat)
            check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,key+"/"+seat+": rendering leaves all original facts and source timing unchanged")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Eleven selected intrinsic candidates, exact existing item/sheet/tint/holder and actual production native sources, independent faction originals/four views, real movement/attack/removal/replacement/seek/loop, actual contact pixels where proposed. Common receiver light/opacity oracle remains separately qualified; no new gameplay, inferred rider damage or human art acceptance."}
    FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("INTRINSIC_WEAPON_BATCH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func accepted_contact(index:Dictionary,label:String)->void:
    var contacts:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_weapon_impact",false))
    var source:Resource=Items.Bodies.index(index.cache)
    var expected:Array=source.item_impact_effects.get(item_id,[])
    check(contacts.is_empty() if expected.is_empty() else not contacts.is_empty(),label+": finite contacts follow only the actual proposed item use")
    if contacts.is_empty():return
    var row:Dictionary=contacts[0];var component:Dictionary=row.component
    check(component.weapon_impact.source_item_id==item_id and component.weapon_impact.occurrence==component.source_event_uuid,label+": contact retains exact actual item/accepted attack")
    var at:float=lerpf(row.start_ms,row.end_ms,.4)
    var view:SubViewport=viewport();var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=index.media_preload;world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world);world.install_playback(Recording.restore(index,at))
    if await settle(world,[component.id]):
        world.camera_focus=Play.Placement.contact(world.visual_actors[component.target_uuid].row);world.initial_focus=true
        world.camera.size=3;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
        await frame();await frame();world.set_process(false)
        var handle:Dictionary=world.component_renderer.native_spells.handles[component.id]
        var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
        var pixels:int=NativeSupport.changed(shown,view.get_texture().get_image())
        check(pixels>0,label+": accepted actual contact contributes native framebuffer pixels")
        evidence.append({"case":label,"kind":"accepted contact","clip":component.native_clip.id,"item_id":item_id,"changed_pixels":pixels,"event_uuid":component.source_event_uuid,"construction_ms":handle.construction_phases})
    world.component_renderer.native_spells.close(world)
    view.queue_free();await frame();await frame()
