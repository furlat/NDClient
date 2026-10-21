extends "res://tests/ui_checks.gd"
# Native control boundary: a real recorded actor with small named discovery
# revisions. No backend gameplay or rendered-pixel/performance claim.
func discovery(rows: Array, actor: String, generation: int) -> Dictionary:
    var value={"entity_uuid":actor,"discovery_generation":generation,"self_actions":rows.duplicate(true),"target_sets":[[{"kind":"self","index":0}]]}
    for row in value.self_actions:
        row.discovery_actor_uuid=actor
        row.discovery_generation=generation
        row.discovery_index+=100*generation
    return value

func bar_value(subject: Control) -> Array:
    var value: Array=[]
    for button in subject.action_buttons:
        var labels: Array=[]
        for child in button.get_children():
            if child is Label: labels.append([child.text,child.position,child.size])
        value.append([button.get_meta("family").key,button.get_global_rect(),button.text,button.tooltip_text,
            button.disabled,button.has_theme_stylebox_override("normal"),button.icon,labels])
    return value

func check_fresh(label: String) -> void:
    var fresh=HUD.new();fresh.world=world;fresh.cache=hud.cache
    root.add_child(fresh);fresh.set_process(false)
    fresh.painted_discovery=hud.painted_discovery
    fresh.pages=hud.pages.duplicate()
    fresh._rebuild_bar()
    for _frame in range(80):
        fresh.prepare_bar()
        await process_frame
        if not fresh.bar_pending(): break
    check(not fresh.bar_pending(),label+": fresh native build completes")
    await process_frame
    fresh._layout()
    var expected=bar_value(fresh)
    var actual=bar_value(hud)
    if expected!=actual:
        for i in range(mini(expected.size(),actual.size())):
            if expected[i]!=actual[i]:
                print("HUD_LAYOUT_DIFFERENCE ",label," index=",i," expected=",expected[i]," actual=",actual[i])
                break
    check(expected==actual,label+": retained controls match a fresh native build")
    # Shared cache owns the active image task; only original HUD closes it.
    fresh.cache={}
    root.remove_child(fresh);fresh.free()

func settle_bar() -> void:
    # First let normal HUD processing observe the changed input, then await the
    # actual publication condition; no guessed number of build frames.
    await process_frame
    await process_frame
    for _frame in range(100):
        if not hud.bar_pending(): break
        await process_frame
    check(not hud.bar_pending(),"Queued native action bar reaches its publication boundary")
    await process_frame

func run() -> void:
    var path:String="";var recording:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--state="):path=argument.trim_prefix("--state=")
        if argument.begins_with("--recording="):recording=argument.trim_prefix("--recording=")
    var loaded:Dictionary=Fixtures.canonical(recording) if not recording.is_empty() else {"ok":not path.is_empty() and FileAccess.file_exists(path)}
    check(loaded.ok,"Supply actual --recording=<journal> or --state=<canonical state.json>")
    if not loaded.ok:quit(1);return
    root.size=Vector2i(1280,720)
    var state:Dictionary=loaded.value if not recording.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
    var actor: String=state.observer_uuid
    state.current_actor_uuid=actor
    var canonical_before=state.duplicate(true)
    world=FixtureWorld.new();world.timeline.state=state;root.add_child(world)
    var dash=fixture_row("action.dash",1,actor)
    dash.configured_action_ref=UI.descriptor(state,"action.dash").get("ref")
    var spell=fixture_row("spell.magic_missile",2,actor)
    spell.configured_action_ref=UI.descriptor(state,"spell.magic_missile").get("ref")
    spell.action_category="spell";spell.cast_at_level=1
    var upcast=spell.duplicate(true);upcast.discovery_index=3;upcast.cast_at_level=2
    var originals: Array=[dash,spell,upcast]
    world.available_actions=discovery(originals,actor,1)
    var original=world.available_actions.duplicate(true)
    hud=HUD.new();hud.world=world;root.add_child(hud)
    await settle_bar()
    var buttons=hud.action_buttons.duplicate()
    var old_row: Dictionary=buttons[0].get_meta("native_row")
    var mode: Button=hud.preference_button
    buttons[1].emit_signal("mouse_entered")
    check(hud.popup.visible,"Original generation offers its actual two variants")
    world.allow_commands=false
    await settle_bar()
    check(hud.action_buttons==buttons and hud.preference_button==mode,"Busy transition retains native controls")
    check(buttons.all(func(b):return b.disabled) and mode.disabled and not hud.popup.visible,"Busy controls disable and close variant popup")
    var issued: int=world.issued.size()
    buttons[0].emit_signal("pressed")
    check(world.issued.size()==issued,"Retained disabled control cannot spend")
    world.allow_commands=true
    await settle_bar()
    check(hud.action_buttons==buttons and buttons.all(func(b):return not b.disabled),"Ready transition re-enables same controls")
    await check_fresh("Ready-only transition")
    world.selected_action=old_row
    await settle_bar()
    check(hud.action_buttons==buttons and buttons[0].has_theme_stylebox_override("normal"),"Selection highlight changes on the retained button")
    world.selected_action={}
    await settle_bar()
    check(not buttons[0].has_theme_stylebox_override("normal"),"Selection clearing restores inherited normal style")

    var next=discovery(originals,actor,2)
    next.self_actions[0].description="New native row details"
    next.self_actions[0].costs=[{"cost":2,"cost_type":"actions"}]
    next.target_sets=[[{"kind":"self","index":17}]]
    world.available_actions=next
    buttons[0].emit_signal("pressed")
    check(world.issued.size()==issued,"Old control callback rejects new generation before repaint")
    await settle_bar()
    check(hud.action_buttons==buttons,"Same-layout discovery retains all native controls")
    check(buttons[0].tooltip_text.contains("New native row details") and buttons[0].tooltip_text.contains("2 actions"),"Retained tooltip uses current source details and cost")
    buttons[0].emit_signal("pressed")
    check(world.issued[-1]==next.self_actions[0],"Retained callback activates exact current row, target and generation")
    world.selected_action={}
    buttons[1].emit_signal("mouse_entered")
    check(hud.popup.visible and hud.popup_rows.size()==2,"Rebound family opens current native variants")
    hud.popup_rows[1].emit_signal("pressed")
    check(world.issued[-1]==next.self_actions[2],"Rebound popup dispatches current upcast, not captured former row")
    world.selected_action={}
    await settle_bar()
    await check_fresh("Same-layout generation")

    var unavailable=discovery(originals,actor,3)
    unavailable.self_actions[0].can_afford=false
    unavailable.self_actions[0].availability_status="source_unaffordable"
    world.available_actions=unavailable
    await settle_bar()
    check(hud.action_buttons==buttons and buttons[0].disabled,"Current availability updates without rebuilding")
    issued=world.issued.size();buttons[0].emit_signal("pressed")
    check(world.issued.size()==issued,"Current unavailable row cannot activate through old retained control")
    await check_fresh("Unavailable generation")
    check(original==discovery(originals,actor,1) and old_row==original.self_actions[0],"Retained grouping and rebinding preserve former admitted values")

    var changed=originals.duplicate(true)
    changed[0].weapon_slot="MELEE_MAIN"
    world.available_actions=discovery(changed,actor,4)
    await settle_bar()
    check(hud.action_buttons!=buttons,"Changed family/badge topology publishes replacement controls")
    check(hud.action_buttons[0].get_children().any(func(c):return c is Label and c.text=="M"),"Rebuilt weapon badge matches the current row")
    await check_fresh("Changed topology")
    root.size=Vector2i(960,720)
    await settle_bar()
    await check_fresh("Narrow viewport")
    # A larger named discovery requires multiple native construction slices.
    # Keep the prior complete bar visible and exercise exact callback guards
    # independently of Button.disabled while the replacement is hidden.
    var many: Array=[]
    for i in range(42):
        var row=dash.duplicate(true)
        row.behavior_id="fixture.async.%d" % i
        row.display_name="Queued action %d" % i
        row.discovery_index=i
        many.append(row)
    var old_bar: Control=hud.bar
    var old_buttons: Array=hud.action_buttons.duplicate()
    var old_weak=weakref(old_bar)
    world.available_actions=discovery(many,actor,5)
    await process_frame;await process_frame
    check(hud.bar_pending(),"Topology-changing discovery remains pending after bounded native work")
    check(hud.bar==old_bar and old_bar.visible and hud.action_buttons==old_buttons,"Preparation retains the entire previously published bar")
    check(not hud.bar_build.root.visible and hud.bar_build.root!=hud.bar,"Partially constructed bar is hidden and cannot receive native input")
    var canceled=weakref(hud.bar_build.root)
    issued=world.issued.size()
    old_buttons[0].emit_signal("pressed");key(KEY_1)
    check(world.issued.size()==issued and old_buttons.all(func(b):return b.disabled),"Pending old clicks and shortcuts cannot dispatch")
    var first_frame=Engine.get_process_frames()
    for _frame in range(3):
        await process_frame
        check(hud.bar_build_units<=HUD.BAR_BUILD_UNITS,"Each frame creates at most the bounded control units")
        check(hud.bar==old_bar,"No partial action list is published between preparation slices")
    check(Engine.get_process_frames()>first_frame and hud.bar_pending(),"Scene frame pump continues while native controls prepare")
    var newer=discovery(many,actor,6)
    newer.self_actions[0].description="Replacement generation details"
    world.available_actions=newer
    await process_frame;await process_frame
    check(hud.bar==old_bar and hud.bar_pending(),"New generation supersedes pending work without exposing its partial controls")
    hud._page("Base",1)
    check(hud.pages.Base==1 and hud.bar==old_bar,"Page change supersedes pending work while published shortcuts stay blocked")
    root.size=Vector2i(1100,760)
    world.toggle_attack_preference()
    await settle_bar()
    check(hud.bar!=old_bar and hud.action_buttons.all(func(b):return b.get_meta("native_row").discovery_generation==6),"Only the latest complete generation publishes after resize, page and preference changes")
    check(hud.preference_button.text=="Ranged · X" and hud.pages.Base==1,"Publication uses the requested page and preference")
    check(hud.bar.position.y==614,"Publication uses the latest viewport height")
    await check_fresh("Cancelled generation/page/viewport/preference")
    var current_index: int=hud.shortcuts[0].get_meta("native_row").discovery_index
    key(KEY_1)
    check(world.issued[-1].discovery_index==current_index,"Published shortcut dispatches its exact current page row")
    world.selected_action={}
    # Actor replacement during an unfinished build cannot install former rows.
    var second_actor=""
    for candidate in state.actors:
        if candidate!=actor: second_actor=candidate;break
    check(not second_actor.is_empty(),"Recorded fixture contains another actor for ownership cancellation")
    world.available_actions=discovery(many,actor,7)
    hud._page("Base",0)
    await process_frame
    state.current_actor_uuid=second_actor
    world.available_actions=discovery(originals,second_actor,8)
    await settle_bar()
    check(hud.action_buttons.all(func(b):return b.get_meta("native_row").discovery_actor_uuid==second_actor),"Actor switch cancels old ownership and publishes only the new actor's rows")
    check(hud.pages.Base==0,"Actor switch resets local pagination")
    await check_fresh("Actor ownership change")
    state.current_actor_uuid=actor
    world.available_actions=discovery(originals,actor,9)
    await settle_bar()
    # Cancelled and replaced roots retire in leaf-sized scene-thread batches.
    for _frame in range(100):
        if hud.retired_bars.is_empty():break
        await process_frame
    check(hud.retired_bars.is_empty() and old_weak.get_ref()==null and canceled.get_ref()==null,"Superseded native bars release their entire native hierarchy")
    check(world.timeline.state==canonical_before,"HUD transitions do not alter canonical state")
    root.remove_child(hud);hud.free();root.remove_child(world);world.free()
    await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Native retained and sliced action-bar construction, cancellation, exact current dispatch and fresh-build property/layout oracle; headless scene-frame progress, no GPU pixel or timing claim.","state":path}
    FileAccess.open("res://generated/hud_retention_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("HUD_RETENTION_CHECKS ",JSON.stringify(report));quit(1 if failures else 0)
