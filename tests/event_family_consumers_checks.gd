extends "res://tests/support_spell_event_checks.gd"
## One family batch through original independent seats and the ordinary compiler.
const FIXTURES="res://tests/fixtures/schema16/event-families"
const PORTABLE_FIXTURE="res://tests/fixtures/schema16/current-production-0c/freezing-sphere-portable"
const CURRENT_EVENT_FIXTURES={"spell.freezing_sphere__portable_detonation":PORTABLE_FIXTURE,
    "spell.vitriolic_sphere__delayed_end_results":"res://tests/fixtures/schema16/current-production-0c/vitriolic-sphere-delayed"}
const PAYLOAD_COLD="high-level-22/freezing-sphere/launch_target_packet"
const PAYLOAD_FIRE="high-level-22/delayed-blast-fireball/native_target_packet"
const DIVINE="review/divine_word/back/target_release"
const TICK="high-level-22/vitriolic-sphere/target_native_next_end_packet"
const BLAST="high-level-22/freezing-sphere/launch_blast"
const RETIRED_BLAST="high-level-22/delayed-blast-fireball/native_retirement_blast"
const ICE="high-level-22/freezing-sphere/launch_observed_ice"
const INITIAL_ACID="high-level-22/vitriolic-sphere/native_target_initial"
const RELEASE_CLIPS={"spell.freezing_sphere__launch_detonation":"high-level-22/freezing-sphere/launch_delivery",
    "spell.delayed_blast_fireball__concentration_end_detonation":"high-level-22/delayed-blast-fireball/native_place_from_hand",
    "spell.vitriolic_sphere__delayed_end_results":"high-level-22/vitriolic-sphere/native_delivery"}
const Spatial=preload("res://presentation/spatial_inputs.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Report=preload("res://studio/capability_report.gd")
const Replay=preload("res://studio/recording.gd")
var totals:Dictionary={}
func run()->void:
    var spells:Dictionary={};var spell_paths:Dictionary={};var actions:Dictionary={};var action_paths:Dictionary={}
    for name in ["freezing_sphere","delayed_blast_fireball","dragons_breath","divine_word","vitriolic_sphere"]:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        spells[id]=load(path);spell_paths[id]=path
    for id in ["action.spell.payload.throw","action.drop_concentration","action.spell.delayed_blast_fireball.touch","action.spell.dragons_breath.exhale"]:
        var path:String="res://authoring/abilities/actions/"+id+".tres"
        actions[id]=load(path);action_paths[id]=path
    var ice:Resource=load("res://authoring/abilities/conditions/spatial_effect.material.ice.tres")
    var built:Dictionary=Build.documents({"spells":spells,"actions":actions,"conditions":{ice.id:ice},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},
        {"spells":spell_paths,"actions":action_paths})
    var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    var clips:Dictionary={}
    for clip in package.clips:clips[str(clip.clip_id)]=clip
    var validation:Dictionary={"errors":[],"warnings":[]}
    Build._check_constructor(actions["action.drop_concentration"].effects[1],"retained delayed blast",clips,validation)
    var ground:Resource=load("res://authoring/environment/surfaces/spatial_effect.material.ice.tres")
    var ice_cue:Dictionary=Records.cue_from_effect(ground.lasting,0)
    var selected_ice:Dictionary=Effects.for_cue(ice_cue)
    Build._check_constructor(ground.lasting,"observed ice",clips.merged({selected_ice.id:selected_ice},true),validation)
    check(ice.effects.is_empty() and not ice.play_package_lifecycle and ice.surface==ground.id,"Canonical Ground alone owns ice; the ability condition delegates instead of replaying its old finite probe")
    check(validation.errors.is_empty(),"Registered retained blast satisfies the actual selected readable source interface: "+JSON.stringify(validation.errors))
    var cache:Dictionary=source_cache(built,spell_paths)
    var conditions:Dictionary=Compiler.Authoring.load_data("catalog/condition_recipes.json",cache).duplicate()
    conditions.merge(built.docs["catalog/condition_recipes.json"],true);cache["catalog/condition_recipes.json"]=conditions
    var bindings:Dictionary=Compiler.Authoring.load_data("catalog/body_action_bindings.json",cache).duplicate()
    bindings.merge(built.docs["catalog/body_action_bindings.json"],true)
    cache["catalog/body_action_bindings.json"]=bindings
    check(Array(spells["spell.divine_word"].excluded_cues)==[2,3,4],"Fixed second recipient and held condition duplicates delegate to actual recipient/condition lifecycles")
    var grants:Array=spells["spell.dragons_breath"].effects
    var exhales:Array=actions["action.spell.dragons_breath.exhale"].effects.filter(func(use):return use.constructor_input.get("projection")=="breath_exhale")
    check(grants.size()==5 and exhales.size()==5 and grants.all(func(use):return use.unbound_constructor_inputs.is_empty() and use.constructor_input.projection=="breath_grant"),"All five actual elemental grant and exhale contracts are authored; old assembled alternatives remain separate")
    var cases:PackedStringArray=DirAccess.get_directories_at(FIXTURES);cases.sort()
    check(cases.size()==13,"Exactly thirteen real payload, grant, outcome and delayed-result cases are retained")
    for case_id in cases:
        for seat in ["amber","blue"]:read_case(case_id,seat,cache)
    var portable:Dictionary=current_portable_original()
    check(not portable.is_empty() and portable.get("status")=="recorded" and not portable.get("engine",{}).is_empty(),
        "One completed current portable original has its actual per-case producer identity")
    if not portable.is_empty() and portable.get("status")=="recorded":
        for seat in ["amber","blue"]:
            var directory:String=portable.get("journals",{}).get(seat,"")
            check(not directory.is_empty(),seat+" current portable original journal is explicit")
            if not directory.is_empty():read_case("spell.freezing_sphere__portable_detonation",seat,cache,directory)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"components":totals,
        "scope":"Thirteen preserved archived two-seat families retain their exact positive contacts and unavailable old portable operands. A separate completed current two-seat portable original exercises the public observed-explosion source. Source/setter/ancestry/canonical checks do not qualify native pixels or human approval."}
    FileAccess.open("res://.runtime/event-family-consumers-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("EVENT_FAMILY_CONSUMERS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

static func current_portable_original()->Dictionary:
    return current_family_original("spell.freezing_sphere__portable_detonation")

static func current_family_original(case_id:String)->Dictionary:
    # Exact same-ID originals supply new public operands. Older packets remain
    # unchanged negative controls; this selection never uses a mutable Library.
    var directory:String=str(CURRENT_EVENT_FIXTURES.get(case_id,""))
    if directory.is_empty():return {}
    var receipt:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("recording.json")))
    var scenario:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("scenario.json")))
    if not receipt is Dictionary or not scenario is Dictionary or scenario.get("id")!=case_id.replace("__","/"):return {}
    return {"id":scenario.id,"status":"recorded" if receipt.get("ok",false) else "failed","engine":receipt.get("engine",{}),
        "scenario":directory.path_join("scenario.json"),
        "journals":{"amber":directory.path_join("amber"),"blue":directory.path_join("blue")}}

static func wanted(case_id:String)->String:
    if case_id.begins_with("spell.freezing_sphere"):return PAYLOAD_COLD
    if case_id.begins_with("spell.delayed_blast_fireball"):return PAYLOAD_FIRE
    if case_id.begins_with("spell.divine_word"):return DIVINE
    if case_id.begins_with("spell.vitriolic_sphere"):return TICK
    var element:String=case_id.get_slice("__",1).get_slice("_",0)
    return "bg3-36/dragons-breath/"+element+"_native_receiver"

## Use only real component rows and nonempty exact phase identities. Timeline
## scaffolding/property channels cannot masquerade as a source occurrence.
static func family_rows(index:Dictionary,case_id:String)->Array:
    var clips:Array=[wanted(case_id)]
    if RELEASE_CLIPS.has(case_id):clips.append(RELEASE_CLIPS[case_id])
    if case_id.begins_with("spell.freezing_sphere"):clips.append(ICE)
    if case_id.begins_with("spell.vitriolic_sphere"):clips.append(INITIAL_ACID)
    if case_id=="spell.delayed_blast_fireball__concentration_end_detonation":clips.append(RETIRED_BLAST)
    if case_id in ["spell.freezing_sphere__launch_detonation","spell.freezing_sphere__portable_detonation"]:clips.append(BLAST)
    return index.rows.filter(func(row):return row.kind=="native_effect" \
        and row.get("component",{}).get("native_clip",{}).get("id","") in clips)

func read_case(case_id:String,seat:String,cache:Dictionary,current_directory:String="")->void:
    var current_portable:bool=not current_directory.is_empty()
    var label:String=case_id+("/current" if current_portable else "/archived")+"/"+seat
    var directory:String=FIXTURES.path_join(case_id).path_join(seat) if not current_portable else current_directory
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" original opens")
    var timeline:RefCounted=Timeline.new();var elapsed:float=0.0;var contacts:Array=[];var raw_results:Dictionary={};var graphs:Dictionary={};var blasts:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file));var sequence:int=int(file.get_basename())
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,label+" decode "+str(sequence));if not decoded.ok:return
        var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence));if not folded.ok:return
        if sequence==0:timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        for lineage in folded.normalized.lineages:
            var native:Dictionary=Occurrences.group(lineage)
            var graph:Dictionary=graph_for(native.events)
            graph.application_results=Results.index(native.events,graph.nodes);graph.original_events=native.events
            graph.object_inputs={}
            for actual in native.events:
                var fact:Variant=actual.get("fact")
                if fact==null:continue
                if fact.kind=="spatial" and fact.get("change_type")=="object_removed":
                    graph.object_inputs[str(actual.id)]=before.objects.get(fact.object_uuid,{})
                if fact.kind!="actor_change":continue
                for actor in fact.get("actors",[]):
                    for row in actor.rows:
                        if row.get("field")!="condition" or row.get("member")!=null:continue
                        for member in before.actors.get(actor.actor_uuid,{}).get("conditions",[]):
                            if member.condition_uuid!=row.condition_uuid:continue
                            if not graph.condition_cues.has(str(actual.id)):graph.condition_cues[str(actual.id)]=[]
                            graph.condition_cues[str(actual.id)].append({"phase":"removal","actor_uuid":actor.actor_uuid,"condition":member})
            if case_id=="spell.freezing_sphere__portable_detonation":
                for actual in native.events:
                    if actual.get("fact")==null or actual.fact.kind!="spell" or actual.fact.get("resolved_area_positions",[]).is_empty():continue
                    check(Results.observed(actual,{"projection":"immediate_blast","outcome":"cast","geometry_actor":"caster"},graph).is_empty(),
                        label+" actual retained portable detonation ancestry cannot masquerade as an immediate launch")
                    var retained:Dictionary=actual.duplicate(true);retained.fact.behavior_id="spell.freezing_sphere"
                    check(Results.observed(retained,{"projection":"immediate_blast","outcome":"cast","geometry_actor":"caster"},graph).is_empty(),
                        label+" private spell-ID alias retains real portable ancestry and still cannot bypass item/lifetime retirement")
            for node in lineage.events:
                if node.get("fact")!=null:raw_results[str(node.occurrence)]=node.fact
                graphs[str(node.occurrence)]=graph
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" ordinary compile "+str(sequence));if not compiled.ok:return
        for group in compiled.value.groups:
            elapsed+=float(group.duration_ms)
            for component in group.components:
                if component.get("native_clip",{}).get("id")==BLAST and component.status=="available":
                    blasts+=1
                    if component.native_cue.constructor_input.projection=="portable_payload_blast":check_portable_blast(component,raw_results,graphs,label)
                    else:check_blast(component,raw_results,graphs,label)
                if component.get("native_clip",{}).get("id")==RETIRED_BLAST and component.status=="available":
                    blasts+=1;check_retired_blast(component,raw_results,graphs,label)
                if component.get("native_clip",{}).get("id")!=wanted(case_id):continue
                contacts.append(component)
                check(component.status=="available",label+" actual family packet admits a finite component: "+str(component.get("reason","")))
                if component.status!="available":continue
                check(not component.get("persistent_owner",false) and is_finite(component.duration_ms) and component.duration_ms>0.0,label+" finite result never acquires a guessed held lifetime")
                var actual:Dictionary=raw_results.get(str(component.source_event_uuid),{})
                check(not actual.is_empty(),label+" component keeps its actual original occurrence")
                if wanted(case_id)==DIVINE:
                    var outcome:String=case_id.get_slice("__",1).trim_suffix("_outcome")
                    check(component.native_inputs.observation.outcome==outcome,label+" outcome follows actual child memberships/life, without HP logic")
                    check(component.native_constructor_evidence.death_observed==(outcome=="death"),label+" lethal outcome has an actual death fact")
                else:
                    check(actual.get("kind")=="damage" and actual.get("stage")=="applied" and actual.applied_damage>0,label+" contact belongs to an actual positive applied result")
                    var packet:Dictionary=component.native_inputs.get("damage_event",component.native_inputs.get("native_state",{}))
                    check(packet.event_uuid==str(component.source_event_uuid) and packet.recipient_uuid==actual.target_entity_uuid,label+" result identity and actual receiving actor are unchanged")
                    if wanted(case_id)==TICK:
                        check(packet.condition_uuid==actual.source_condition_uuid and packet.reason=="recipient_end_residue_packet",label+" only explicitly attributed residue END packet is admitted")
                    else:check(packet.saved==component.native_constructor_evidence.saved,label+" saved-half is the exact observed saving throw")
                source_contract(component,label)
                if component.native_cue.constructor_input.projection=="finite_contact":
                    finite_controls(component,graphs[str(component.source_event_uuid)],label)
                elif wanted(case_id)==TICK:
                    tick_controls(component,graphs[str(component.source_event_uuid)],before,label)
                evidence.append({"case":case_id,"seat":seat,"clip":wanted(case_id),"evidence":component.native_constructor_evidence})
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        check(var_to_bytes(folded.normalized)==immutable and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,label+" projection never changes original packets")
    var expected:int=4 if wanted(case_id) in [PAYLOAD_COLD,PAYLOAD_FIRE] else 1
    check(contacts.size()==expected,label+" exactly "+str(expected)+" actual family components, with no root/application or review-target duplication; got "+str(contacts.size()))
    totals[label]=contacts.size()
    var expected_blast:bool=case_id in ["spell.freezing_sphere__launch_detonation","spell.delayed_blast_fireball__concentration_end_detonation"] or current_portable
    check(blasts==int(expected_blast),label+" exact disclosed native explosion admits a blast only when its required public operands exist")
    if case_id=="spell.freezing_sphere__portable_detonation" and not current_portable:
        var throws:Array=raw_results.values().filter(func(fact):return fact.get("kind")=="action" and fact.get("behavior_id")=="action.spell.payload.throw")
        var explosions:Array=raw_results.values().filter(func(fact):return fact.get("kind")=="spell" and fact.get("behavior_id")=="action.spell.payload.throw")
        check(throws.size()==1 and throws[0].get("target_position")==null and explosions.size()==1 \
            and explosions[0].get("aoe_position")==null and explosions[0].get("area_geometry")==null,
            label+" archived null throw destination/area geometry remains an explicit unavailable public-source control")
    timeline.advance(elapsed+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" final playback equals its independent canonical fold")
    var index:Dictionary=Replay.read(directory,{}, {},cache)
    check(index.ok,label+" ordinary Studio case is seekable")
    if not index.ok:return
    if case_id=="spell.vitriolic_sphere__delayed_end_results" and current_directory.is_empty():
        var casts:Array=raw_results.values().filter(func(fact):return fact.get("kind")=="spell" and fact.get("behavior_id")=="spell.vitriolic_sphere")
        var missing_blasts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")=="high-level-22/vitriolic-sphere/native_initial_blast")
        check(casts.size()==1 and casts[0].get("resolved_area_positions",[]).is_empty() and missing_blasts.size()==1 \
            and missing_blasts[0].component.status=="missing" and missing_blasts[0].component.reason=="native_observed_event_recipient_not_disclosed",
            label+" archived absent blast footprint stays an explicit unavailable source control")
    var expected_gate:int=expected+int(RELEASE_CLIPS.has(case_id))+int(case_id.begins_with("spell.freezing_sphere")) \
        +int(expected_blast) \
        +(4 if case_id.begins_with("spell.vitriolic_sphere") else 0)
    var gate_rows:Array=family_rows(index,case_id)
    check(gate_rows.size()==expected_gate and gate_rows.all(func(row):return row.component.status=="available"),label+" native cohort selects exact actual source rows without empty clips or property/scaffold duplicates")
    inspection(index,label)
    if case_id.begins_with("spell.freezing_sphere"):check_ice(index,journal.state,label)
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==wanted(case_id))
    check(rows.size()==expected,label+" ordinary Studio retains the same finite components")
    for row in rows:
        var midpoint:float=(row.start_ms+row.end_ms)*.5
        for at in [midpoint,index.presentation_end_ms,midpoint]:
            var restored:RefCounted=Replay.restore(index,at)
            var active:Array=restored.component_samples(index.cache).filter(func(component):return component.id==row.component.id)
            check(active.size()==(0 if at==index.presentation_end_ms else 1),label+" seek/loop respects actual finite result interval")

func source_contract(component:Dictionary,label:String)->void:
    var descriptor:Dictionary=component.native_cue.constructor_input
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var parts:Array=clip.components;var supplied:Dictionary={};var script:String=""
    for part in descriptor.component_path:
        var found:Array=parts.filter(func(value):return value.id==part)
        check(found.size()==1,label+" exact sealed source constructor path exists")
        if found.size()!=1:return
        supplied=found[0].input;script=found[0].script;parts=supplied.get("components",[])
    var program:Node3D=load(script).new()
    if component.native_clip.id==DIVINE:
        program.settings=supplied;program.observation=component.native_inputs.observation
        check(program.admitted(),label+" actual sealed Divine recipient program admits its observed outcome")
        var wrong:Dictionary=program.observation.duplicate();wrong.cast_uuid="foreign-cast"
        check(not program.matches(wrong),label+" foreign cast cannot borrow the original outcome")
        check(supplied.observation.is_empty(),label+" successful review observation is cleared before construction")
    else:
        program.specification=supplied
        var packet:Dictionary=component.native_inputs.get("damage_event",component.native_inputs.get("native_state",{}))
        var accepted:bool=program.set_native_state(packet) if component.native_clip.id==TICK else program.set_damage_event(packet)
        check(accepted,label+" sealed native source admits the actual factual packet")
        var wrong:Dictionary=packet.duplicate();wrong.source_owner_uuid="foreign-owner"
        check(not (program.set_native_state(wrong) if component.native_clip.id==TICK else program.set_damage_event(wrong)),label+" wrong owner cannot retain successful review data")
        check(supplied.get("event",supplied.get("state",{})).is_empty(),label+" successful review packet is cleared before construction")
    program.free()
    check(var_to_bytes(phase.to_clip())==immutable,label+" Factory source remains immutable")

func finite_controls(component:Dictionary,graph:Dictionary,label:String)->void:
    var descriptor:Dictionary=component.native_cue.constructor_input
    var owner_id:String=str(component.native_constructor_evidence.source_occurrence)
    var original:Array=graph.original_events
    var owners:Array=original.filter(func(node):return str(node.id)==owner_id)
    check(owners.size()==1,label+" source result owner is unambiguous")
    if owners.size()!=1:return
    for control in ["canceled_owner","missing_save","ambiguous_save","zero_damage","foreign_target"]:
        var events:Array=original.duplicate(true)
        var owner:Dictionary=events.filter(func(node):return str(node.id)==owner_id)[0]
        if control=="canceled_owner":owner.canceled=true
        elif control in ["missing_save","ambiguous_save"]:
            var save:Dictionary=events.filter(func(node):return str(node.id)==str(component.native_constructor_evidence.save_occurrence))[0]
            if control=="missing_save":save.fact.effect_id="different-native-save"
            else:events.append(save.duplicate(true))
        else:
            var damage:Dictionary=events.filter(func(node):return str(node.id)==str(component.source_event_uuid))[0]
            if control=="zero_damage":damage.fact.applied_damage=0
            else:damage.fact.target_entity_uuid="foreign-recipient"
        var changed:Dictionary=graph_for(events);changed.application_results=Results.index(events,changed.nodes)
        check(not Results.observed(owner,descriptor,changed).any(func(row):return str(row.node.id)==str(component.source_event_uuid)),
            label+" private "+control+" cannot borrow an applied packet")
    var wrong:Dictionary=descriptor.duplicate();wrong.damage_type="unrelated-type"
    check(Results.observed(owners[0],wrong,graph).is_empty(),label+" actual damage family cannot be substituted")

func tick_controls(component:Dictionary,graph:Dictionary,before:Dictionary,label:String)->void:
    var descriptor:Dictionary=component.native_cue.constructor_input
    var evidence:Dictionary=component.native_constructor_evidence
    var members:Array=before.actors[component.target_uuid].conditions.filter(func(member):return member.condition_uuid==evidence.source_condition_uuid)
    check(members.size()==1,label+" delayed packet has one actual pre-row residue member")
    if members.size()!=1:return
    var member:Dictionary=members[0]
    for control in ["missing_source","wrong_source","wrong_boundary","zero_damage"]:
        var events:Array=graph.original_events.duplicate(true)
        var node:Dictionary=events.filter(func(row):return str(row.id)==str(component.source_event_uuid))[0]
        if control=="missing_source":node.fact.erase("source_condition_uuid")
        elif control=="wrong_source":node.fact.source_condition_uuid="foreign-condition"
        elif control=="zero_damage":node.fact.applied_damage=0
        else:events.filter(func(row):return str(row.id)==str(evidence.recipient_end_occurrence))[0].fact.event_type="turn_start"
        check(Results.condition_contact(node,member,descriptor,graph_for(events)).is_empty(),label+" private "+control+" cannot manufacture a residue END event")

func check_blast(component:Dictionary,raw_results:Dictionary,graphs:Dictionary,label:String)->void:
    var fact:Dictionary=raw_results[str(component.source_event_uuid)]
    var packet:Dictionary=component.native_inputs.blast_event
    var origin:Array=component.native_constructor_evidence.source_position
    check(fact.kind=="spell" and fact.behavior_id=="spell.freezing_sphere" and fact.resolved_area_positions.size()==49 \
        and origin==[6,7],label+" blast belongs to the actual nested explosion with49 resolved cells and disclosed origin")
    check(packet.event_uuid==str(component.source_event_uuid) and packet.source_owner_uuid==packet.event_uuid \
        and packet.original_caster_uuid==fact.source_entity_uuid and packet.blast_committed and packet.immediate_launch,
        label+" finite blast has actual native identity and immediate phase, without a held payload owner")
    var restored:Array=[]
    for cell in packet.admitted_cells:restored.append([cell[0]+origin[0],cell[1]+origin[1]])
    check(restored==fact.resolved_area_positions,label+" source-relative footprint exactly translates the admitted cells without solving area")
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var program:Node3D=load(clip.components[0].script).new();program.specification=clip.components[0].input
    check(program.specification.event.is_empty() and program.set_blast_event(packet),label+" sealed immediate blast source admits only the actual packet")
    check(not program.set_blast_event(packet),label+" exact same native blast event cannot be consumed twice")
    var changed:Dictionary=packet.duplicate(true);changed.event_uuid="private-control";changed.admitted_cells=[]
    check(not program.set_blast_event(changed),label+" absent admitted cells cannot borrow review geometry")
    program.free()
    check(var_to_bytes(phase.to_clip())==immutable,label+" native blast source resource remains immutable")
    var graph:Dictionary=graphs[str(component.source_event_uuid)]
    var owner:Dictionary=graph.original_events.filter(func(row):return str(row.id)==str(component.source_event_uuid))[0]
    for control in ["canceled","unresolved"]:
        var changed_owner:Dictionary=owner.duplicate(true)
        if control=="canceled":changed_owner.canceled=true
        else:changed_owner.fact.erase("resolved_area_positions")
        check(Results.observed(changed_owner,component.native_cue.constructor_input,graph).is_empty(),label+" private "+control+" cannot admit an immediate blast")

func check_portable_blast(component:Dictionary,raw_results:Dictionary,graphs:Dictionary,label:String)->void:
    var fact:Dictionary=raw_results[str(component.source_event_uuid)]
    var supplied:Dictionary=component.native_inputs.observed_explosion
    var phase:Resource=load(Effects.choice(Effects.occurrence_clip(component)).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var input:Dictionary=clip.components[0].input
    check(fact.kind=="spell" and fact.behavior_id=="action.spell.payload.throw" and supplied.explosion.fact==fact,
        label+" public portable source keeps the actual explosion occurrence independently of its thrower")
    check(input.source_owner_uuid==str(component.source_event_uuid) and input.original_caster_uuid==fact.source_entity_uuid \
        and not ["item_uuid","lifetime_uuid","immediate_launch","event"].any(func(field):return input.has(field)),
        label+" public source uses actual explosion/caster identity without a fabricated retained item/lifetime")
    var program:Node3D=load(clip.components[0].script).new();program.specification=input
    check(program.set_observed_explosion(supplied) and program.observed.explosion_occurrence==str(component.source_event_uuid),
        label+" delivered public portable source admits the unchanged completed throw ancestry")
    check(not program.set_observed_explosion(supplied),label+" the same portable explosion cannot be consumed twice")
    program.free()
    for control in ["canceled_explosion","missing_cells","canceled_throw","broken_ancestry","foreign_owner"]:
        var wrong:Dictionary=supplied.duplicate(true)
        if control=="canceled_explosion":wrong.explosion.canceled=true
        elif control=="missing_cells":wrong.explosion.fact.resolved_area_positions=[]
        elif control=="canceled_throw":wrong.ancestors[-1].canceled=true
        elif control=="broken_ancestry":wrong.explosion.parent_lineage="foreign-lineage"
        else:wrong.explosion.id="foreign-explosion"
        var source:Node3D=load(clip.components[0].script).new();source.specification=input
        check(not source.set_observed_explosion(wrong),label+" private "+control+" cannot admit a portable source")
        source.free()
    check(var_to_bytes(phase.to_clip())==immutable,label+" public portable source stays immutable")

func check_retired_blast(component:Dictionary,raw_results:Dictionary,graphs:Dictionary,label:String)->void:
    var fact:Dictionary=raw_results[str(component.source_event_uuid)]
    var packet:Dictionary=component.native_inputs.blast_event
    var evidence:Dictionary=component.native_constructor_evidence
    check(fact.kind=="spell" and fact.behavior_id=="action.drop_concentration" and fact.resolved_area_positions.size()==49 \
        and evidence.source_position==[6,7],label+" retained blast preserves actual explosion/canonical removed-object origin")
    check(packet.event_uuid==str(component.source_event_uuid) and packet.source_owner_uuid==evidence.lifetime_uuid \
        and packet.lifetime_uuid==evidence.lifetime_uuid and packet.item_uuid==evidence.item_uuid \
        and packet.event_uuid!=packet.lifetime_uuid and packet.item_retirement_committed \
        and packet.lifetime_removal_committed and not packet.immediate_launch,label+" actual item/lifetime retirement admits without substituting a finite occurrence owner")
    var restored:Array=[]
    for cell in packet.admitted_cells:restored.append([cell[0]+evidence.source_position[0],cell[1]+evidence.source_position[1]])
    check(restored==fact.resolved_area_positions,label+" retained blast footprint is exactly the disclosed cells")
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var program:Node3D=load(clip.components[0].script).new();program.specification=clip.components[0].input
    check(program.specification.event.is_empty() and program.set_blast_event(packet),label+" sealed retained blast accepts actual retirement packet and clears review state")
    for field in ["item_retirement_committed","lifetime_removal_committed"]:
        var rejected:Dictionary=packet.duplicate(true);rejected.event_uuid="private-"+field;rejected[field]=false
        check(not program.set_blast_event(rejected),label+" absent actual "+field+" cannot bypass retained ownership")
    program.free();check(var_to_bytes(phase.to_clip())==immutable,label+" retained blast source remains immutable")
    var graph:Dictionary=graphs[str(component.source_event_uuid)]
    for control in ["canceled_blast","missing_lifetime","foreign_lifetime_actor","canceled_removal","missing_object","foreign_item","foreign_origin","foreign_action","unrelated_removal"]:
        var events:Array=graph.original_events.duplicate(true)
        var owner:Dictionary=events.filter(func(row):return str(row.id)==str(component.source_event_uuid))[0]
        var removed:Dictionary=events.filter(func(row):return str(row.id)==str(evidence.item_removal_occurrence))[0]
        if control=="canceled_blast":owner.canceled=true
        elif control=="canceled_removal":removed.canceled=true
        elif control=="foreign_origin":owner.fact.source_position=[0,0]
        elif control=="foreign_action":events.filter(func(row):return str(row.id)==str(evidence.accepted_action_occurrence))[0].fact.behavior_id="unrelated-action"
        elif control=="unrelated_removal":removed.parent_lineage=evidence.accepted_action_lineage
        var changed:Dictionary=graph_for(events);changed.application_results=Results.index(events,changed.nodes)
        changed.condition_cues=graph.condition_cues.duplicate(true);changed.object_inputs=graph.object_inputs.duplicate(true)
        if control=="missing_lifetime":changed.condition_cues.erase(str(evidence.lifetime_removal_occurrence))
        elif control=="foreign_lifetime_actor":changed.condition_cues[str(evidence.lifetime_removal_occurrence)][0].actor_uuid="foreign-caster"
        elif control=="missing_object":changed.object_inputs.erase(str(evidence.item_removal_occurrence))
        elif control=="foreign_item":changed.object_inputs[str(evidence.item_removal_occurrence)].item.item_id="unrelated-item"
        check(Results.observed(owner,component.native_cue.constructor_input,changed).is_empty(),label+" private "+control+" cannot borrow a retained blast")

func check_ice(index:Dictionary,state:Dictionary,label:String)->void:
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" \
        and row.get("component",{}).get("native_clip",{}).get("id")==ICE)
    check(rows.size()==1,label+" one actual spatial lifetime owns ice, with no cast duplicate")
    if rows.size()!=1:return
    var component:Dictionary=rows[0].component
    var effect:Dictionary=state.senses.spatial_effects[str(component.spatial_effect_uuid)]
    check(component.status=="available" and effect.positions.size()==49 and component.spatial_source_cells==effect.positions \
        and component.from_position==effect.anchor_position,label+" all49 disclosed cells and exact anchor admit the delivered128-cell source")
    check(component.actor_uuid==null and component.target_uuid==null and not component.has("condition"),label+" independent ice owner invents no actor/condition UUID")
    var packet:Dictionary=Spatial.owner_state(component,state)
    check(packet.ready and packet.value.owner_uuid==component.spatial_effect_uuid \
        and packet.value.present and packet.value.observed and not packet.value.suppressed,
        label+" exact current unsuppressed optical membership supplies the public owner-state gate")
    var descriptor:Dictionary=component.native_cue.constructor_input
    check(descriptor.cell_input=="partitioned_surface" and component.has("spatial_surface_partition"),label+" current selected source uses full-owner topology with an independent bounded draw")
    var partition:Dictionary=component.spatial_surface_partition
    check(partition.owner_uuid==component.spatial_effect_uuid and partition.capacity==128 and partition.draw_count==49,label+" one bounded draw owns all49 real cells without changing source identity")
    var physical:Dictionary=Effects.choice(Effects.occurrence_clip(component))
    var phase:Resource=load(physical.approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var input:Dictionary=clip.components[0].input
    check(input.surface_uuid==component.spatial_effect_uuid and not input.has("state") \
        and not input.has("retire_at_seconds"),label+" constructor supplies only the real UUID; no review membership or retirement enters the public partition source")
    # Exercise the actual setters with its exact bank/material and one private
    # draw receiver. This does not claim asynchronous construction or pixels.
    var program:Node3D=load(clip.components[0].script).new()
    program.bank=load(input.surface_bank);program.owner_uuid=input.surface_uuid
    program.material=program.bank.partition_material.duplicate(false)
    program.plane=MeshInstance3D.new();program.add_child(program.plane)
    check(program.set_surface_partition(partition) and program.set_owner_state(packet.value),label+" actual selected source accepts the real topology and owner packet")
    var suppressed:Dictionary=state.duplicate(true);suppressed.senses.spatial_effects[str(component.spatial_effect_uuid)].suppressions=[{"positions":effect.positions}]
    var hidden:Dictionary=Spatial.owner_state(component,suppressed)
    check(hidden.ready and hidden.value.present and hidden.value.suppressed \
        and program.set_owner_state(hidden.value),label+" full suppression disables optical admission without inventing retirement")
    var absent:Dictionary=Spatial.owner_state(component,{"senses":{"spatial_effects":{}}})
    check(absent.ready and not absent.value.observed and not absent.value.present and program.set_owner_state(absent.value),label+" missing current view sends absent state rather than retaining previous visibility")
    var foreign:Dictionary=packet.value.duplicate();foreign.owner_uuid="foreign-surface"
    check(not program.set_owner_state(foreign),label+" foreign spatial UUID cannot borrow this source state")
    var large:Array=[]
    for cell in 129:large.append([component.from_position[0]+cell,component.from_position[1]])
    var planned:Dictionary=Spatial.surface_partitions(str(component.spatial_effect_uuid),large,component.from_position,descriptor)
    var drawn:Dictionary={};var total:int=0
    for draw in planned.partitions:
        check(draw.owner_uuid==component.spatial_effect_uuid and draw.count<=128 and draw.draw_count<=128,label+" private129-cell capacity control preserves the real owner and bounded neighbor support")
        for index_in_draw in int(draw.count):
            if draw.draw_flags[index_in_draw]==0.0:continue
            var point:Vector2=draw.points[index_in_draw]
            check(not drawn.has(point),label+" partition draw subsets never overlap")
            drawn[point]=true;total+=1
    check(planned.error.is_empty() and planned.partitions.size()>1 and total==129,label+" public full-topology API covers a larger owner with disjoint bounded draws")
    var invalid:Dictionary=descriptor.duplicate();invalid.capacity=31
    check(not Spatial.surface_partitions(str(component.spatial_effect_uuid),large,component.from_position,invalid).get("error","").is_empty(),label+" an unsupported source capacity is refused instead of silently dropping cells")
    program.free();check(var_to_bytes(phase.to_clip())==immutable,label+" selected partition source remains immutable")
    for at in [0.0,float(index.presentation_end_ms)+4100.0,0.0,float(index.presentation_end_ms)+4100.0]:
        var restored:RefCounted=Replay.restore(index,at)
        var samples:Array=restored.component_samples(index.cache).filter(func(row):return row.get("spatial_effect_uuid")==component.spatial_effect_uuid)
        check(samples.size()==(0 if at==0.0 else 1),label+" actual ice membership/seek/loop outlives the discarded fixture clock")

func inspection(index:Dictionary,label:String)->void:
    for row in index.rows:
        var component:Dictionary=row.get("component",{})
        if not component.get("native_spell",false) or component.get("native_clip",{}).is_empty():continue
        var receipt:Dictionary=Report._row(row)
        var method:Dictionary=receipt.native_method
        check(method.required_channels==component.native_clip.get("inputs",[]) \
            and method.input_setters==component.native_clip.get("input_setters",{}),label+" inspection preserves the actual selected source interface")
        check(method.constructor==component.native_cue.get("constructor_input",{}) \
            and method.constructor_evidence==component.get("native_constructor_evidence",{}),label+" actual projection/evidence remain inspectable")
        check(method.runtime_binding=="not_examined" and receipt.rendered=="not_witnessed",label+" method/source indexing cannot promote current binding or pixels")
        check(receipt.reason==row.get("reason",component.get("reason","")),label+" missing phase retains its exact original reason")
