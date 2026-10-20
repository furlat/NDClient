extends SceneTree
## Unchanged server journals -> current production sources and canonical replay.
## This qualifies logical ownership/retirement, never native pixels or rider art.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Native=preload("res://presentation/native_persistent.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT="res://tests/fixtures/schema16/weapon-enchantment-lifecycle"
const CASES={
    "shillelagh":{"spell":"shillelagh","actor":"7a6ae75d-e0fa-439a-bc1c-88515e4b09cc",
        "owner":"90693c04-e891-4d61-b10c-e8d03a9e0b6b","admission":18,"removal":{"amber":89,"blue":88},
        "staff":"1a1a0c16-f5f9-4ea5-92b1-bdba449bf793","sword":"9037f983-219c-42a8-9bd9-4819c695b320",
        "held_attack":60,"held_outcome":"Hit","last_attack":{"amber":157,"blue":156},
        "unequip":12,"equip":17,"last":22,"commands":13,"owner_cues":[0]},
    "divine-favor":{"spell":"divine_favor","actor":"7e2c178d-50ac-430b-862b-1efe0620d7c2",
        "owner":"cb23fb5c-34ed-4488-a2eb-a6632d4a45e4","admission":22,"removal":{"amber":83,"blue":82},
        "staff":"fb2ced07-91a5-4c96-82c5-b8d377161d58","sword":"609052a9-b8fa-457f-9c24-240fde3439a1",
        "held_attack":52,"held_outcome":"Miss","last_attack":{"amber":197,"blue":196},
        "unequip":18,"equip":23,"last":28,"commands":17,"owner_cues":[1,2,3]},
    "magic-weapon":{"spell":"magic_weapon","actor":"a4d3daa3-785a-42d4-beee-078b5a2fb450",
        "owner":"","admission":-1,"removal":{},
        "staff":"c9b7213a-ab09-4be2-a4a0-9cc6d2a17964","sword":"2bce8acb-6986-4941-aa85-65e062df960f",
        "held_attack":51,"held_outcome":"Miss","last_attack":{"amber":195,"blue":195},
        "unequip":18,"equip":23,"last":28,"commands":17,"owner_cues":[2,3]}}
var checks:int=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("WEAPON_ENCHANTMENT_LIFECYCLE_FAIL ",label)

func run()->void:
    for name in CASES:
        var spec:Dictionary=CASES[name]
        command_evidence(name,spec)
        var identities:Array=[]
        for seat in ["amber","blue"]:
            var identity:Dictionary=inspect_original(name,seat,spec)
            if not identity.is_empty():identities.append(identity)
        check(identities.size()==2 and identities[0].game_id==identities[1].game_id \
            and identities[0].game_epoch==identities[1].game_epoch and identities[0].audience_id!=identities[1].audience_id,
            name+": both independent audiences belong to the same original encounter")
    var report={"checks":checks,"failures":failures,"observations":observations,
        "scope":"Current production Resources and unchanged original journals, both audiences: exact condition UUIDs, real equipped item use/replacement, ordered removal data, canonical prefix seeks and source lifecycle clocks. No GPU/native output, positive Divine Favor rider, missing Magic Weapon owner, performance or visual acceptance qualification."}
    FileAccess.open("res://.runtime/weapon-enchantment-lifecycle-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WEAPON_ENCHANTMENT_LIFECYCLE_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)

func command_evidence(name:String,spec:Dictionary)->void:
    var root_path:String=ROOT.path_join(name)
    var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("recording.json")))
    var commands:Array=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("commands.json")))
    check(commands.size()==spec.commands and commands.all(func(row):return row.get("command_issued",false) and row.receipt.kind=="committed"),name+": every original legal command actually committed")
    check(receipt.ok==(not spec.owner.is_empty()),name+": original successful lifecycle or failed required-owner receipt is retained")
    if spec.owner.is_empty():
        check(receipt.failure=="required_conditions absent from actual journal: condition.spell.magic_weapon",name+": missing public owner remains the original failed requirement")
    var unequip:Array=commands.filter(func(row):return row.request.do=="unequip")
    var equip:Array=commands.filter(func(row):return row.request.do=="equip")
    check(unequip.size()==1 and unequip[0].command.intent=={"kind":"unequip","item":{"slot":"MELEE_MAIN"}} \
        and int(unequip[0].receipt.cursor.sequence)==spec.unequip,name+": retirement/equipment change is an actual committed Unequip command")
    check(equip.size()==1 and equip[0].command.intent=={"kind":"equip","item":{"item_uuid":spec.sword,"slot":"MELEE_MAIN"}} \
        and int(equip[0].receipt.cursor.sequence)==spec.equip,name+": actual replacement command names this exact Longsword UUID")
    var drops:Array=commands.filter(func(row):return row.request.do=="action.drop_concentration")
    check(drops.is_empty() if name=="shillelagh" else drops.size()==1 and int(drops[0].receipt.cursor.sequence)==12,
        name+": concentration is dropped only by the real applicable action")

func inspect_original(name:String,seat:String,spec:Dictionary)->Dictionary:
    var label:String=name+"/"+seat
    var directory:String=ROOT.path_join(name).path_join(seat).path_join("journal")
    var independent:Dictionary=fold_original(directory,spec,label)
    if not independent.ok:return {}
    var index:Dictionary=Recording.read(directory)
    check(index.ok,label+": ordinary Studio indexes the actual journal using current production Resources: "+str(index.get("error",{})))
    if not index.ok:return {}
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var condition_id:String="condition.spell."+str(spec.spell)
    var spell:Resource=load("res://authoring/abilities/spells/spell."+str(spec.spell)+".tres")
    var condition:Resource=load("res://authoring/abilities/conditions/"+condition_id+".tres")
    check(spell.owner_kind=="condition" and Array(spell.owner_ids)==[condition_id] and Array(spell.owner_cues)==spec.owner_cues \
        and condition.play_package_lifecycle,label+": actual typed source delegates its held cues to this exact condition lifecycle")
    var selected:Dictionary=Spells.selection("spell."+str(spec.spell),index.cache)
    check(not selected.is_empty() and Spells.owned_cues(selected)==spec.owner_cues,label+": built production selection retains the same handover")
    var casts:Array=independent.events.filter(func(event):return event.fact.kind=="spell" and event.fact.get("behavior_id")=="spell."+str(spec.spell))
    check(casts.size()==1 and casts[0].sequence==2 and casts[0].fact.source_entity_uuid==spec.actor,label+": one actual completed cast does not imply a held condition")
    var held:Array=independent.events.filter(func(event):return event.fact.kind=="attack" and event.sequence==7)
    var replacement:Array=independent.events.filter(func(event):return event.fact.kind=="attack" and event.sequence==spec.last)
    check(held.size()==1 and held[0].occurrence==spec.held_attack and held[0].fact.attack_outcome==spec.held_outcome \
        and equipped_attack(held[0].fact,spec.actor,spec.staff,"weapon.quarterstaff"),label+": held-phase actual attack uses the exact equipped staff and original outcome")
    check(replacement.size()==1 and replacement[0].occurrence==spec.last_attack[seat] and replacement[0].fact.attack_outcome=="Hit" \
        and equipped_attack(replacement[0].fact,spec.actor,spec.sword,"weapon.longsword"),label+": later actual attack uses the replacement Longsword after retirement")
    check(layer_item(independent.states[7],spec.actor)==spec.staff and layer_item(independent.states[spec.unequip],spec.actor).is_empty() \
        and layer_item(independent.states[spec.equip],spec.actor)==spec.sword,label+": canonical loadout changes staff -> empty slot -> actual replacement")
    # Exact prefixes remain inspectable even when distinct ordered commits
    # share a presentation timestamp. No artificial delay creates a fake cut.
    for sequence in [1,2,7,12,spec.unequip,spec.equip,spec.last]:
        var boundary:Dictionary=operation_boundary(index,sequence)
        check(not boundary.is_empty(),label+": original operation boundary exists "+str(sequence))
        if boundary.is_empty():continue
        var restored:RefCounted=Recording.restore_boundary(index,boundary.group_index,boundary.commit_prefix)
        check(restored!=null and Compare.difference(restored.state,independent.states[sequence]).is_empty(),
            label+": canonical seek equals independent Journal at exact operation "+str(sequence)+(": "+Compare.difference(restored.state,independent.states[sequence]) if restored!=null else ""))
    var end:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(Compare.difference(end.state,independent.states[spec.last]).is_empty(),label+": ordinary end seek drains to the independent final canonical state")
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("persistent_owner",false) \
        and row.get("owner",{}).get("condition",{}).get("behavior_id")==condition_id)
    if spec.owner.is_empty():missing_owner(index,independent,rows,spec,label)
    else:actual_lifecycle(index,independent,rows,spec,seat,label)
    if name=="divine-favor":
        check(not independent.events.any(func(event):return event.sequence==7 and event.fact.kind=="damage" \
            and event.fact.get("damage_type")=="Radiant" and float(event.fact.get("applied_damage",0))>0),label+": original held Miss supplies no invented positive Radiant rider")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,label+": seeks and inspection leave source cuts and recorded facts immutable")
    observations.append({"case":name,"seat":seat,"journal":directory,"condition_uuid":spec.owner,
        "held_attack_outcome":spec.held_outcome,"native_source_rows":rows.size(),"rendered":false,"visual_approval":false,
        "gap":"public_magic_weapon_owner_absent" if spec.owner.is_empty() else ("positive_divine_favor_rider_unobserved" if name=="divine-favor" else "native_output_not_examined")})
    return index.identity

func fold_original(directory:String,spec:Dictionary,label:String)->Dictionary:
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,label+": independent audience journal opens")
    if not opened.ok:return {"ok":false}
    var result:Dictionary={"ok":true,"states":{},"events":[],"changes":[],"item_members":[]}
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for filename in files:
        if filename.get_basename().length()!=16 or not filename.get_basename().is_valid_int():continue
        var sequence:int=int(filename.get_basename())
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,label+": independent original decode "+str(sequence))
        if not decoded.ok:return {"ok":false}
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+": independent original fold "+str(sequence))
        if not folded.ok:return {"ok":false}
        if sequence in [0,1,2,7,12,spec.unequip,spec.equip,spec.last]:result.states[sequence]=journal.snapshot()
        for item in journal.state.items.values():
            for member in item.effects:
                if member.get("behavior_id")=="condition.spell."+str(spec.spell):result.item_members.append(member)
        for lineage in decoded.value.get("lineages",[]):
            for node in lineage.events:
                if node.get("canceled",false) or node.get("fact")==null:continue
                result.events.append({"sequence":sequence,"occurrence":int(node.occurrence),"fact":node.fact})
        for lineage in folded.get("transitions",{}).get("lineages",[]):
            for event in lineage.events:
                for change in event.get("condition_rows",[]):
                    result.changes.append({"sequence":sequence,"occurrence":int(event.occurrence),"change":change})
    check(result.states.has(spec.last) and int(journal.cursor.sequence)==spec.last,label+": whole original contiguous packet prefix is folded")
    return result

func actual_lifecycle(index:Dictionary,original:Dictionary,rows:Array,spec:Dictionary,seat:String,label:String)->void:
    var changes:Array=original.changes.filter(func(entry):return entry.change.row.get("condition_uuid")==spec.owner and entry.change.row.field=="condition")
    var admissions:Array=changes.filter(func(entry):return entry.change.before==null and entry.change.after!=null)
    var removals:Array=changes.filter(func(entry):return entry.change.before!=null and entry.change.after==null)
    check(admissions.size()==1 and admissions[0].sequence==2 and admissions[0].occurrence==spec.admission \
        and admissions[0].change.actor_uuid==spec.actor,label+": original member UUID is admitted once by the expected actor fact")
    check(removals.size()==1 and removals[0].sequence==12 and removals[0].occurrence==spec.removal[seat] \
        and removals[0].change.actor_uuid==spec.actor,label+": exact UUID retires once at the real disclosed removal")
    if admissions.size()!=1 or removals.size()!=1:return
    var admitted:Dictionary=admissions[0].change.after
    var removed:Dictionary=removals[0].change.before
    check(not removals[0].change.row.has("member") and removed.condition_uuid==admitted.condition_uuid \
        and removed.behavior_id==admitted.behavior_id,label+": bare removal retains actual prior member data instead of constructing another owner")
    check(admitted.state.affected_item_uuid==(spec.staff if spec.spell=="shillelagh" else null) \
        and removed.state.affected_item_uuid==admitted.state.affected_item_uuid,label+": real affected item survives removal; actor-wide Divine Favor stays unbound to an item")
    check(member(original.states[1],spec.actor,spec.owner).is_empty() and not member(original.states[2],spec.actor,spec.owner).is_empty() \
        and not member(original.states[7],spec.actor,spec.owner).is_empty() and member(original.states[12],spec.actor,spec.owner).is_empty(),
        label+": canonical before/admitted/held/retired membership follows only actual original facts")
    if spec.spell=="divine_favor":
        var drops:Array=original.events.filter(func(event):return event.sequence==12 and event.fact.kind=="action" and event.fact.get("behavior_id")=="action.drop_concentration")
        check(drops.size()==1 and drops[0].fact.source_entity_uuid==spec.actor and layer_item(original.states[12],spec.actor)==spec.staff,
            label+": actual Drop Concentration retires the benefit while its staff is still equipped")
    check(not rows.is_empty(),label+": current production condition produces native source lifecycle rows")
    var phases:Dictionary={};var component_ids:Dictionary={}
    var admission_cut:Dictionary=event_boundary(index,2,spec.admission)
    var removal_cut:Dictionary=event_boundary(index,12,spec.removal[seat])
    check(not admission_cut.is_empty() and not removal_cut.is_empty(),label+": source clocks have exact native commit anchors")
    if admission_cut.is_empty() or removal_cut.is_empty():return
    for row in rows:
        var component:Dictionary=row.component
        phases[str(row.get("lifecycle_phase",""))]=true;component_ids[component.id]=true
        check(row.owner.id==spec.owner and row.owner.actor_uuid==spec.actor and component.condition_uuid==spec.owner \
            and component.actor_uuid==spec.actor,label+": every source span belongs to the disclosed condition/actor UUID")
        check(row.owner.start_ms==admission_cut.at_ms and row.source_start_ms==admission_cut.at_ms \
            and row.owner.end_ms==removal_cut.at_ms and component.duration_ms==removal_cut.at_ms-admission_cut.at_ms,
            label+": one private source clock starts and ends at actual ordered commits")
        check(component.lifecycle_key=="condition_"+str(spec.spell)+"_persistent" and component.status=="available" \
            and row.coverage.rendered=="not_witnessed",label+": genuine installed source availability remains distinct from rendered evidence")
        if row.get("lifecycle_phase")=="removal":
            check(row.owner.condition==removed and component.condition==removed,label+": native removal retains this seat's exact pre-removal member data")
            var age:float=(removal_cut.at_ms-admission_cut.at_ms)/1000.0+float(component.lifecycle_phases.removal.seconds)*.5
            var sampled:Dictionary=Native.lifecycle_state(component,age)
            check(sampled.phase=="removal" and sampled.phase_age_seconds>0.0,label+": removal advances its own delivered phase after real retirement")
    check(component_ids.size()==1 and phases.has("application") and phases.has("sustain") and phases.has("removal"),
        label+": one UUID-owned native occurrence exposes application, hold and actual removal")
    # Ordinary seek/back/loop retains the same actual source owner; exact
    # canonical prefix comparisons above also cover coincident ordered cuts.
    var held_at:float=(admission_cut.at_ms+removal_cut.at_ms)*.5
    for at in [held_at,0.0,held_at,removal_cut.at_ms+1000.0,held_at]:
        var restored:RefCounted=Recording.restore(index,at)
        if at==held_at:
            check(not member(restored.state,spec.actor,spec.owner).is_empty() and layer_item(restored.state,spec.actor)==spec.staff \
                and restored.condition_owners.has(spec.owner) and restored.condition_owners[spec.owner].start_ms==admission_cut.at_ms,
                label+": seek/loop restores the actual held UUID, staff and original owner clock")
        elif at==0.0:check(member(restored.state,spec.actor,spec.owner).is_empty() and not restored.condition_owners.has(spec.owner),label+": reverse seek before admission creates no future owner")
        else:check(member(restored.state,spec.actor,spec.owner).is_empty(),label+": seek after real removal does not restore a held member")

func missing_owner(index:Dictionary,original:Dictionary,rows:Array,spec:Dictionary,label:String)->void:
    var id:String="condition.spell."+str(spec.spell)
    check(original.changes.all(func(entry):return entry.change.after==null or entry.change.after.behavior_id!=id) \
        and original.item_members.is_empty(),label+": completed Magic Weapon never disclosed an actor or item-effect owner")
    check(rows.is_empty(),label+": current production does not manufacture a Magic Weapon native lifetime from its cast")
    for sequence in [1,2,7,12,spec.last]:
        check(not original.states[sequence].actors[spec.actor].conditions.any(func(value):return value.behavior_id==id),label+": absent Magic Weapon owner stays absent at canonical stage "+str(sequence))
    var concentration:Array=original.changes.filter(func(entry):return entry.change.after!=null and entry.change.after.behavior_id=="condition.concentrating")
    check(not concentration.is_empty(),label+": actual Concentrating is retained separately from the missing enchantment")
    var after:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(not after.condition_owners.values().any(func(owner):return owner.condition.behavior_id==id) \
        and not after.item_effect_owners.values().any(func(owner):return owner.member.get("behavior_id")==id),label+": absent held item membership is never replaced with a fabricated owner at end seek")

func operation_boundary(index:Dictionary,sequence:int)->Dictionary:
    for i in index.groups.size():
        var item:Dictionary=index.groups[i]
        if item.group.operation_sequence==sequence and item.group.operation_end:
            return {"group_index":i,"commit_prefix":item.group.commits.size()}
    return {}

func event_boundary(index:Dictionary,sequence:int,occurrence:int)->Dictionary:
    for i in index.groups.size():
        var item:Dictionary=index.groups[i]
        if item.group.operation_sequence!=sequence:continue
        for n in item.group.commits.size():
            var commit:Dictionary=item.group.commits[n]
            if str(commit.get("event_uuid",""))==str(occurrence):
                return {"group_index":i,"commit_prefix":n+1,"at_ms":item.start_ms+commit.at_ms}
    return {}

func member(state:Dictionary,actor_id:String,identity:String)->Dictionary:
    for value in state.actors[actor_id].conditions:
        if value.condition_uuid==identity:return value
    return {}

func layer_item(state:Dictionary,actor_id:String)->String:
    for layer in state.actors[actor_id].visual_loadout.layers:
        if layer.slot=="MELEE_MAIN":return str(layer.item_uuid)
    return ""

func equipped_attack(fact:Dictionary,actor_id:String,item_id:String,content_id:String)->bool:
    return fact.source_entity_uuid==actor_id and fact.source_item_uuid==item_id and fact.source_item_id==content_id \
        and fact.weapon_slot=="MELEE_MAIN" and fact.attack_source_kind=="equipped"
