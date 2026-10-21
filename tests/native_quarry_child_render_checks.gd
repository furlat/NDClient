extends "res://tests/native_vampiric_touch_render_checks.gd"
## Actual recipient lifecycle only. Legacy caster-root/rider gaps stay explicit.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const ORIGINALS="res://tests/fixtures/schema16/production-condition-handover"
const CASES={"hex":"20261019T143104.526336Z","hunters_mark":"20261019T144540.033289Z"}
const OUT="res://.runtime/native-quarry-child"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUT)
    for name in CASES:
        for seat in ["amber","blue"]:await child_source(name,seat)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual original both-seat Hex/HuntersMark recipient UUID application/hold source, native pixels, canonical before/held/end and seek/loop/cleanup. Missing retained caster sustain and attributed rider remain explicit; no unrecorded retirement or whole-family/visual approval claim."}
    FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_QUARRY_CHILD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func child_source(name:String,seat:String)->void:
    var label:String=name+"-"+seat
    var directory:String=ORIGINALS.path_join("spell."+name+"__baseline").path_join(CASES[name]).path_join(seat).path_join("journal")
    var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true)
    var index:Dictionary=Recording.read(directory)
    check(index.ok and opened.ok,label+": original audience and ordinary production index open")
    if not index.ok or not opened.ok:return
    index.media_preload=MEDIA.plan(index)
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("lifecycle_key")=="condition_"+name+"_persistent")
    var entry:Resource=load("res://authoring/abilities/spells/spell."+name+".tres")
    var applications:Array=entry.effects.filter(func(use):return use.constructor_input.get("projection")=="quarry_application")
    check(applications.size()==2 and applications.all(func(use):return use.unbound_constructor_inputs.is_empty() \
        and use.constructor_input.owner_condition_id=="condition.spell."+name \
        and use.constructor_input.recipient_condition_id=="condition.spell."+name+".quarry"),label+": both current finite sources require the exact real sustain and recipient pair")
    var members:Array=[]
    for actor in journal.state.actors.values():members.append_array(actor.conditions)
    check(not rows.is_empty() and members.filter(func(member):return member.behavior_id=="condition.spell."+name+".quarry").size()==1 \
        and members.filter(func(member):return member.behavior_id=="condition.spell."+name).is_empty(),label+": original child and absent distinct caster sustain remain separate actual memberships")
    check(not index.rows.any(func(candidate):return candidate.get("component",{}).get("spell_id")==name \
        and candidate.get("component",{}).get("native_quarry",false)),label+": absent original sustain cannot publish a successful quarry constructor")
    if rows.is_empty():return
    var row:Dictionary=rows[0];var component:Dictionary=row.component;var owner:Dictionary=row.owner
    var at:float=float(owner.start_ms)+float(component.lifecycle_phases.application.seconds)*1000.0+100.0
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=maxf(at,index.presentation_end_ms);world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,at))
    var ready:bool=await PREPARED.settle(self,world,[component.id])
    check(ready,label+": actual child source and required inputs prepare")
    if not ready:view.queue_free();await frame();return
    world.camera_focus=Play.Placement.contact(world.visual_actors[owner.actor_uuid].row);world.initial_focus=true;world.camera.size=3
    world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility();await frame();await frame()
    var native:RefCounted=world.component_renderer.native_spells;var handle:Dictionary=native.handles[component.id]
    check(handle.component.condition_uuid==owner.id and handle.component.actor_uuid==owner.actor_uuid and handle.lifecycle_phase=="sustain",label+": exact real recipient/member owns the held source clock")
    check(world.timeline.state.actors[owner.actor_uuid].conditions.any(func(member):return member.condition_uuid==owner.id),label+": native output has the actual canonical quarry membership")
    world.set_process(false);await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
    var hidden:Image=view.get_texture().get_image();var count:int=changed(shown,hidden)
    check(count>0,label+": actual prepared child changes framebuffer pixels")
    check(canonical==var_to_bytes(world.timeline.state),label+": source visibility control changes no canonical fact")
    shown.save_png(OUT+"/"+label+"-present.png");hidden.save_png(OUT+"/"+label+"-hidden.png")
    var previous:WeakRef=weakref(handle.root);world.set_process(true)
    world.install_playback(Recording.restore(index,maxf(0.0,owner.start_ms-.001)))
    if await settle(world):check(not world.timeline.condition_owners.has(owner.id),label+": reverse seek has no future child owner")
    world.install_playback(Recording.restore(index,at))
    if await settle(world,component.id):
        check(previous.get_ref()==null,label+": loop frees prior private draw owners")
        check(world.timeline.condition_owners[owner.id].start_ms==owner.start_ms,label+": loop restores the original UUID clock")
    world.install_playback(Recording.restore(index,maxf(at,index.presentation_end_ms)+1.0))
    if await settle(world):check(world.timeline.state==journal.snapshot(),label+": end equals the independent original canonical reducer")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+": no production source error")
    evidence.append({"spell":name,"seat":seat,"owner_uuid":owner.id,"changed_pixels":count,"retained_root":"not_disclosed","native_rider":"not_qualified",
        "finite_pair_sources":applications.map(func(use):return {"clip":str(use.clip),"constructor":use.constructor_input.duplicate(true)})})
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),label+": private native owners close")
    view.queue_free();await frame();await frame()
