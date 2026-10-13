extends "res://tests/sdk_snapshot_checks.gd"
# Canonical internal transactions preserve earlier event-time values through
# later nested actor mutations. Public detached helpers stay a separate oracle.
# godot --headless --path <client> --script res://tests/sdk_retained_transaction_checks.gd
#     -- --cases=<existing Python reducer oracle>

func _operation(state: Dictionary, template: Dictionary, facts: Array) -> Dictionary:
    var lineage: Dictionary = template.duplicate(true)
    lineage.start_cursor = state.reducer_cursor
    lineage.end_cursor = state.reducer_cursor + facts.size()
    lineage.events = []; lineage.version_rows = []; lineage.observations = []; lineage.world_updates = []
    lineage.hud_snapshot = null
    for i in range(facts.size()):
        var node: Dictionary = template.events[0].duplicate(true)
        node.uuid = "retained-event-%d-%d" % [state.reducer_cursor,i]
        node.fact = facts[i].duplicate(true)
        if node.fact.kind=="spatial": node.fact.commit_event_uuid=node.uuid
        lineage.events.append(node)
        lineage.version_rows.append({"source_index":state.reducer_cursor+i,"event_uuid":node.uuid,"lineage_uuid":node.lineage_uuid})
    lineage.root=lineage.events[0]
    return {"audience":state.audience.duplicate(true),"content_additions":[],"lineages":[lineage],"hud":null,"combat_log_appends":[]}

func _assert_events(before: Dictionary, packet: Dictionary, recorded: Dictionary) -> void:
    var reference: Dictionary = before.duplicate(true)
    var lineage: Dictionary = packet.lineages[0]
    var cursors = {}
    for row in lineage.version_rows: cursors[row.event_uuid]=row.source_index
    for index in range(lineage.events.size()):
        var node: Dictionary = lineage.events[index]
        var event: Dictionary = recorded.transitions.lineages[0].events[index]
        for identity in event.actor_inputs:
            check(event.actor_inputs[identity]==reference.actors[identity],"Actor before fact retains exact value: "+str(index)+"/"+node.fact.kind)
        var applied=Reducer.apply_committed_player_fact(reference,node.fact,cursors[node.uuid],cursors)
        check(applied.ok,"Independent fact commits: "+node.fact.kind)
        for identity in event.delta.actors:
            check(event.delta.actors[identity]==reference.actors[identity],"Actor after fact survives every subsequent fact: "+str(index)+"/"+node.fact.kind)
        if event.delta.set.has("senses"):
            check(event.delta.set.senses==reference.senses,"Senses at event preserves spatial/contact state: "+str(index))
    reference.reducer_cursor=lineage.end_cursor
    check(recorded.value==reference,"Retained final state equals independent mutable fold")

func _sparse_cells(observation: Array) -> void:
    var fact: Dictionary=observation[2].duplicate(true)
    var previous: Dictionary=observation[0].members[fact.observer_uuid].duplicate(true)
    previous.visible=[]; previous.seen=[]
    for x in range(100): previous.visible.append([x,0]);previous.seen.append([x,0])
    # Sparse front/middle/end removal and insertion, with duplicate/absent input.
    fact.visible_cells_removed=[[0,0],[50,0],[99,0],[404,0]]
    fact.visible_cells_added=[[-1,0],[50,1],[120,0],[50,1]]
    fact.seen_cells_added=[[-1,0],[50,1],[120,0]]
    var original=previous.duplicate(true)
    var result=Audience.reduce_senses(fact.observer_uuid,previous,fact)
    check(result.ok,"Public sparse cell change accepts")
    if not result.ok: return
    var expected: Array=[]
    for point in original.visible:
        if point not in fact.visible_cells_removed: expected.append(point)
    expected=Audience.points_union(expected,fact.visible_cells_added)
    check(result.value.visible==expected,"Sparse native-array moves preserve exact full sorted set")
    check(result.value.seen==Audience.points_union(original.seen,fact.seen_cells_added),"Sparse seen insertion remains sorted and monotonic")
    check(previous==original,"Sparse update preserves caller's ordered snapshot")
    var held=result.value.duplicate(true)
    fact.visible_cells_removed=[[50,1]];fact.visible_cells_added=[[50,1],[50,1]];fact.seen_cells_added=[]
    var again=Audience.reduce_senses(fact.observer_uuid,result.value,fact)
    check(again.ok and again.value.visible==held.visible,"Remove/readd with duplicate preserves exact coordinate ordering")
    check(result.value==held,"Later sparse update leaves prior returned arrays unchanged")

func _object_winners(state: Dictionary, template: Dictionary, sensory: Dictionary) -> void:
    var before: Dictionary=state.duplicate(true)
    var observers: Array=before.perception.members.keys()
    observers.sort()
    var a="00000000-0000-0000-0000-000000000090"
    var b="00000000-0000-0000-0000-000000000091"
    var c="00000000-0000-0000-0000-000000000092"
    before.perception.members[observers[0]].objects={a:{"position":[1,1],"visual":false,"special_senses":[]},b:{"position":[2,2],"visual":true,"special_senses":[]}}
    before.perception.members[observers[1]].objects={c:{"position":[3,3],"visual":true,"special_senses":[]},a:{"position":[4,4],"visual":false,"special_senses":[]}}
    before.senses=Audience.view(before.perception,before.observer_uuid)
    var facts: Array=[]
    for i in range(7):
        var fact: Dictionary=sensory.duplicate(true)
        fact.observer_uuid=observers[0 if i in [0,2,3,4] else 1]
        for key in ["entity_contacts_changed","spatial_effects_changed","object_contacts_changed","effective_light_levels_changed","hazardous_cells_changed"]: fact[key]={}
        for key in ["entity_contacts_removed","spatial_effects_removed","object_contacts_removed","visible_cells_added","visible_cells_removed","seen_cells_added"]: fact[key]=[]
        if i in [1,2]: fact.object_contacts_changed[a]={"position":[i+10,i],"visual":true,"special_senses":[]}
        if i==3 or i==5: fact.object_contacts_removed=[a]
        if i==4: fact.object_contacts_changed[c]={"position":[14,4],"visual":true,"special_senses":[]}
        if i==6:
            fact.initial=true;fact.passive_perception=10;fact.visual_access=true
        facts.append(fact)
    var overlap: Dictionary=facts[0].duplicate(true)
    overlap.observer_uuid=observers[1]
    overlap.entity_contacts_changed[a]={"position":[31,32],"visual":false,"special_senses":[]}
    facts.insert(1,overlap)
    var packet=_operation(before,template,facts)
    var result=Reducer._reduce_operation_recorded(before,packet)
    check(result.ok,"Composed object winners accept changed/removed/reintroduced/reset contacts")
    if not result.ok: return
    var perception: Dictionary=before.perception
    for i in range(facts.size()):
        var next=Audience.observe(perception,before.audience,facts[i],before.reducer_cursor+i)
        check(next.ok,"Independent public contact observation "+str(i))
        if not next.ok: return
        perception=next.value
        var exhaustive: Dictionary=Audience.view(perception,before.observer_uuid).objects
        var actual: Dictionary=result.transitions.lineages[0].events[i].delta.set.senses.objects
        check(actual==exhaustive,"Changed-ID contact winners equal exhaustive view "+str(i))
        check(actual.keys()==exhaustive.keys(),"Original first-observer contact insertion order retained "+str(i))
    check(result.transitions.lineages[0].events[1].delta.set.senses.objects[a].position==[4,4],"Entity observation updates overlapping object rank via shared cursor")
    check(result.transitions.lineages[0].events[2].delta.set.senses.objects[a].position==[11,1],"Visual contact from second observer wins")
    check(result.transitions.lineages[0].events[3].delta.set.senses.objects[a].position==[12,2],"Later visual contact supersedes earlier observer")
    check(result.transitions.lineages[0].events[4].delta.set.senses.objects[a].position==[11,1],"Removing winner restores remaining observer")
    check(not result.transitions.lineages[0].events[6].delta.set.senses.objects.has(a),"Removing last observer removes composed object")

func _initialize() -> void:
    var path="res://.runtime/sdk-study/reducer-oracle.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="): path=arg.trim_prefix("--cases=")
    var parsed=StrictJSON.new().parse(FileAccess.get_file_as_string(path))
    check(parsed.ok,"Existing independently generated oracle loads")
    if not parsed.ok: quit(1); return
    var cases={}
    for row in parsed.value.cases: cases[row.name]=row
    _sparse_cells(cases["contract/audience_observe_1"].arguments)
    var charge: Dictionary=cases["contract/fact/10_item_charge"]
    var before: Dictionary=charge.arguments[0].duplicate(true)
    _object_winners(before,charge.arguments[1],cases["contract/audience_observe_1"].arguments[2])
    var first: Dictionary=charge.arguments[1].events[0].fact.duplicate(true)
    var second: Dictionary=first.duplicate(true)
    second.charges_after=0;second.stack_count_after=0;second.item_destroyed=true
    var attack: Dictionary=cases["contract/fact/1_attack"].arguments[1].events[0].fact.duplicate(true)
    var melee: Dictionary=attack.duplicate(true);melee.weapon_slot="MAIN"
    var equip: Dictionary=cases["contract/fact/7_equipment"].arguments[1].events[0].fact
    var condition: Dictionary=cases["contract/fact/8_condition"].arguments[1].events[0].fact.duplicate(true)
    condition.target_entity_uuid=before.observer_uuid
    var removed: Dictionary=condition.duplicate(true);removed.event_type="condition_removal"
    var contact: Dictionary=cases["contract/audience_observe_1"].arguments[2].duplicate(true)
    contact.observer_uuid=before.observer_uuid
    contact.observer_position_changed=true
    contact.spatial_effects_changed={}
    contact.entity_contacts_changed={before.observer_uuid:{"position":[9,9],"visual":true,"special_senses":[]}}
    var later_contact: Dictionary=contact.duplicate(true)
    later_contact.observer_position=[11,12]
    later_contact.entity_contacts_changed[before.observer_uuid].position=[11,12]
    var departure: Dictionary=cases["contract/fact/terminal_departure"].arguments[1].events[0].fact
    var packet=_operation(before,charge.arguments[1],[first,attack,second,melee,equip,condition,removed,contact,later_contact,departure])
    var frozen_before=before.duplicate(true)
    var frozen_packet=packet.duplicate(true)
    var held: Array=[];var frozen: Array=[]
    var state=before
    for iteration in range(3):
        if iteration>0:
            packet=_operation(state,charge.arguments[1],[attack,melee,equip,condition,removed,contact,later_contact,departure])
        var public=Reducer._reduce_operation_recorded(state,packet)
        var retained=Reducer._reduce_operation_retained(state,packet,true)
        check(public.ok and retained.ok,"Both transaction boundaries accept mutation sequence "+str(iteration))
        if not public.ok or not retained.ok: continue
        check(public.value==retained.value and public.transitions==retained.transitions,"Entire detached and retained state/capture values agree "+str(iteration))
        _assert_events(state,packet,retained)
        for i in range(held.size()):
            check(held[i]==frozen[i],"Later transaction preserves all prior states and event snapshots "+str(i))
        held.append(retained);frozen.append(retained.duplicate(true))
        state=retained.value
        _poison(packet)
        check(retained==frozen[-1],"Changing caller packet cannot alter accepted state/captures")
        _poison(public)
        check(retained==frozen[-1],"Arbitrary public result mutation cannot alter retained transaction")
    check(before==frozen_before,"Three retained transactions never mutate previous published state")
    var late: Dictionary=frozen_packet.duplicate(true)
    late.hud={"generation":before.generation,"observer_uuid":before.observer_uuid,"revision":999999}
    var denied=Reducer._reduce_operation_retained(before,late,true)
    check(not denied.ok and not denied.has("transitions"),"Late HUD rejection publishes neither candidate nor captures")
    check(before==frozen_before,"Late rejection preserves all original mutable actor containers")
    for i in range(held.size()): check(held[i]==frozen[i],"Rejected transaction preserves previously retained records "+str(i))
    var report={"checks":checks,"failures":failures,"oracle":path,"scope":"Canonical actor snapshots, nested mutation sequences, detached public outputs, packet isolation and late rejection; no timing/rendering claim."}
    FileAccess.open("res://generated/sdk_retained_transaction_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_RETAINED_TRANSACTION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
