extends "res://tests/basic_condition_render_checks.gd"
## Actual finite activation and retained child owner through the shared Studio.
const ONSET="res://authoring/abilities/actions/action.class.barbarian.frenzy.tres"
const HELD="res://authoring/abilities/conditions/class_feature.barbarian.frenzied.tres"

func visible_source(studio:Control,id:String)->bool:
    var renderer=studio.world.component_renderer.native_spells
    return renderer.witnesses.any(func(witness):return witness.id==id and witness.status=="rendered")

func source_projection(studio:Control,row:Dictionary,parent:Dictionary,child:Dictionary,label:String)->void:
    var component:Dictionary=row.component
    var renderer=studio.world.component_renderer.native_spells
    check(renderer.handles.has(component.id),"Actual selected native occurrence is prepared "+label)
    if not renderer.handles.has(component.id):return
    var handle:Dictionary=renderer.handles[component.id]
    var packet:Dictionary=handle.get("owner_projection_input",handle.get("native_input_packets",{}).get("owner_projection",{}))
    var linked:Dictionary=packet.get("frenzied_child",{})
    check(packet.get("owner_uuid")==parent.id and packet.get("actor_uuid")==parent.actor_uuid \
        and packet.get("behavior_id")==parent.condition.behavior_id,"Delivered projection uses the actual same-actor Rage parent "+label)
    check(linked.get("owner_uuid")==child.id and linked.get("parent_owner_uuid")==parent.id \
        and linked.get("behavior_id")==child.condition.behavior_id,"Delivered projection uses the actual Frenzied child and its public parent link "+label)
    check(handle.clip.id==component.native_clip.id and handle.component.actor_uuid==child.actor_uuid,"Current source and recipient stay on this recorded occurrence "+label)
    check(visible_source(studio,component.id),"Actual native post-draw witness acknowledges this source "+label)

func inspect_source(studio:Control,row:Dictionary,at:float,parent:Dictionary,child:Dictionary,label:String)->void:
    if not await seek(studio,at):return
    var original:Dictionary=studio.world.timeline.state.duplicate(true)
    var id:String=str(row.component.id)
    for quarter in 4:
        if quarter!=studio.world.quarter:studio.world.request_view(quarter)
        if not await settle(studio):return
        source_projection(studio,row,parent,child,label+"-q"+str(quarter))
        var shown=await capture(studio,label+"-q"+str(quarter)+"-shown")
        studio.selected_row=row
        check(studio._diagnostic_id()==id,"Direct source menu targets this presenter, not its parent event "+label)
        studio._menu_selected(7)
        if not await settle(studio):return
        var plain=await capture(studio,label+"-q"+str(quarter)+"-muted")
        var changed:int=difference(shown,plain)
        check(changed>0,"Selected original native source changes actual scene pixels "+label+"-q"+str(quarter))
        check(not visible_source(studio,id),"Mute withdraws only this native source witness "+label+"-q"+str(quarter))
        studio._menu_selected(7)
        if not await settle(studio):return
        check(difference(shown,await capture(studio,label+"-q"+str(quarter)+"-restored"))==0,"Native source restores exact same-clock pixels "+label+"-q"+str(quarter))
        check(studio.world.timeline.state==original and is_equal_approx(studio.world.timeline.display_ms,at),"Diagnostics preserve authoritative state and source clock "+label+"-q"+str(quarter))
        evidence.append({"phase":label,"quarter":quarter,"at_ms":at,"changed_pixels":changed,"source":row.source,
            "component_id":id,"clip":row.component.native_clip.id,"parent_uuid":parent.id,"child_uuid":child.id,"actor_uuid":child.actor_uuid})

func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Use --recording=<actual Frenzy lifecycle journal with public parent link>");quit(2);return
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var action:Resource=load(ONSET);var held:Resource=load(HELD)
    var onsets:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("ability_id")==action.id)
    var children:Array=studio.index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id==held.id)
    check(onsets.size()==1 and children.size()==1,"Actual Frenzy contains one selected activation and one real child lifetime")
    if onsets.size()!=1 or children.size()!=1:await finish(studio);return
    var onset:Dictionary=onsets[0];var child:Dictionary=children[0].owner
    var parent_id:Variant=child.condition.get("state",{}).get("parent_condition_uuid")
    var parents:Array=studio.index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==parent_id)
    check(parents.size()==1,"Original public child identifies one recorded Rage parent UUID")
    if parents.size()!=1:await finish(studio);return
    var parent:Dictionary=parents[0].owner
    check(parent.actor_uuid==child.actor_uuid and parent.condition.behavior_id==action.effects[0].owner_projection.parent_behavior_id,"Original parent and child share the authored actor/family")
    check(onset.status=="available" and onset.component.native_clip.id==action.effects[0].clip,"Actual action admits the currently authored finite source")
    check(is_equal_approx(float(onset.component.duration_ms),float(action.effects[0].source_end)*1000.0),"Onset uses its existing authored finite duration")
    var spans:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("owner",{}).get("id")==child.id \
        and row.component.get("native_clip",{}).get("id")==held.effects[0].clip)
    var after_onset:Array=spans.filter(func(row):return row.end_ms>onset.end_ms and row.start_ms<float(child.end_ms))
    check(not after_onset.is_empty(),"Actual retained source continues under its child UUID after the finite onset")
    if after_onset.is_empty():await finish(studio);return
    var holding:Dictionary=after_onset[0]
    var hold_begin:float=maxf(float(holding.start_ms),float(onset.end_ms))
    var hold_end:float=minf(float(holding.end_ms),float(child.end_ms))
    check(hold_end>hold_begin,"Actual original has a nonempty held interval after activation and before membership retirement")
    if hold_end<=hold_begin:await finish(studio);return
    await inspect_source(studio,onset,(float(onset.start_ms)+float(onset.end_ms))*.5,parent,child,"onset")
    await inspect_source(studio,holding,(hold_begin+hold_end)*.5,parent,child,"held")
    if await seek(studio,maxf(0.0,float(onset.start_ms)-.01)):
        check(not visible_source(studio,onset.component.id),"No activation draw precedes the actual authored onset boundary")
    if await seek(studio,float(onset.end_ms)+.01):
        check(not visible_source(studio,onset.component.id),"Finite activation draw ends at its authored boundary")
    check(is_finite(float(child.end_ms)),"Original lifecycle includes actual child retirement")
    if is_finite(float(child.end_ms)):
        var end:float=float(child.end_ms)
        for span in spans:end=maxf(end,float(span.end_ms))
        if await seek(studio,end+.01):check(not visible_source(studio,holding.component.id),"Retained source withdraws after real membership removal and its authored tail")
    await finish(studio)

func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Frenzy finite activation plus retained same-actor Rage/Frenzied UUID ownership, four-view positive source pixels and exact renderer mute restoration, real onset/removal boundaries. Actual source menu targets are exercised; no retired class ground presenter, invented parent/timing or artwork acceptance."}
    FileAccess.open("res://generated/frenzy_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FRENZY_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
