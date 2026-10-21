extends SceneTree
## Actual server journals -> shared reducer/Studio rows. No rendering claim.
const Recording=preload("res://studio/recording.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const Native=preload("res://presentation/native_persistent.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Channels=preload("res://presentation/native_spell_channels.gd")
const Journal=preload("res://sdk/journal.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Delivery=preload("res://presentation/spell_delivery.gd")
const Compact=preload("res://studio/timeline_compact.gd")
const CASES="res://tests/fixtures/schema16/native-persistent-studio/cases.json"
const FAMILY_OWNERS={
    "bane":["condition.spell.bane"],
    "command":["condition.spell.command.grovel","condition.spell.command.halt","condition.spell.command.flee"],
    "guidance":["condition.spell.guidance"],"light":["condition.spell.light"],
    "mage_armor":["condition.spell.mage_armor"],"resistance":["condition.spell.resistance"],
    "sanctuary":["condition.spell.sanctuary"],"shield":["condition.spell.shield"],
    "shield_of_faith":["condition.spell.shield_of_faith"],
    "web":["spatial_effect.spell.web","condition.spell.web.restrained"]}
var checks:=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PERSISTENT_STUDIO_FAIL ",label)

func inspect_case(case:Dictionary,perspective:Dictionary)->void:
    var spell:String=case.spell_id
    var label:String=spell+"/"+str(perspective.id)
    var index=Recording.read(perspective.journal)
    check(index.ok,label+": real current SDK journal indexes: "+str(index.get("error",{})))
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var journal=Journal.new()
    var independently:Dictionary=journal.open(perspective.journal,true)
    check(independently.ok,label+": unchanged original journal independently folds")
    if independently.ok:
        var final=Recording.restore(index,index.presentation_end_ms+1000.0)
        check(final.state==journal.state,label+": Studio end restore equals that seat's independent canonical fold")
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("persistent_owner",false))
    check(not rows.is_empty(),spell+": real disclosed owner produces native rows")
    var family_rows:Array=rows.filter(func(row):return row.get("owner",{}).get("condition",{}).get("behavior_id") in FAMILY_OWNERS[spell] or row.component.get("spatial_content_id") in FAMILY_OWNERS[spell])
    check(not family_rows.is_empty(),label+": source rows belong to this exact required family, not a renamed alternate effect")
    var ids={};var registered={};var spatial_cuts={};var owners={}
    for row in index.rows:ids[row.id]=row
    for item in index.groups:
        for required in item.group.get("native_requirements",[]):
            if not required.get("spatial_owner",false):continue
            if not spatial_cuts.has(required.id):spatial_cuts[required.id]=[]
            spatial_cuts[required.id].append({"at_ms":item.start_ms+required.preparation_at_ms,"component":required})
        for event in item.group.events:
            for component in event.components:
                if not component.trace_track_id.is_empty():registered[component.trace_track_id]=component
        for component in item.group.components:
            if component.get("intercepted_by_condition_uuid")!=null:
                check(registered.has(component.id),spell+": actual interception remains inspectable even when the hostile event is canceled")
                if registered.has(component.id):check(registered[component.id].intercepted_by_condition_uuid==component.intercepted_by_condition_uuid,spell+": interception witness retains the actual condition UUID")
    for row in rows:
        var component:Dictionary=row.component
        check(ids.has(row.parent) and row.end_ms>row.start_ms,spell+": native row has a real lifetime parent and finite interval")
        check(row.coverage.rendered=="not_witnessed" and row.coverage.prepared=="not_examined",spell+": source indexing is not rendering evidence")
        check(row.source_start_ms==row.owner.start_ms and row.component.absolute_start_ms==row.owner.start_ms,spell+": split intervals retain actual owner start")
        if component.has("lifecycle_phases"):
            check(component.duration_ms==row.owner.end_ms-row.owner.start_ms,spell+": lifecycle removal starts only at actual owner removal")
            check(component.lifecycle_phases.keys()==["application","sustain","removal"] and component.native_clip==component.lifecycle_phases.application,spell+": one occurrence of the package lifecycle plays its three phases")
            var phase:String=Native.lifecycle_state(component,(row.start_ms-row.source_start_ms)/1000.0).phase
            if component.get("spatial_owner",false):
                # Spatial after-value spans retain one owner occurrence and
                # its three nested clips. They are not separate phase rows.
                check(row.start_ms>=row.owner.start_ms and component.native_cue.staged_clip==component.lifecycle_phases.application.id,spell+": compact spatial row retains the exact owner's phase definitions and source clock")
            else:
                check(row.get("lifecycle_phase")==phase and row.get("effect_clip")==component.lifecycle_phases[phase].id and row.label.begins_with(phase.capitalize()),spell+": condition span names its lifecycle phase and clip")
            lifecycle_clock(row,label)
            if not is_inf(row.owner.end_ms):
                check(row.end_ms<=row.owner.end_ms+float(component.lifecycle_phases.removal.seconds)*1000.0+.00001,spell+": lifecycle track stops at its removal's end, not a retained sibling's fade")
        else:
            check(row.component.native_cue.owner_end_seconds==(row.owner.end_ms-row.owner.start_ms)/1000.0,spell+": source clock closes only at actual owner removal")
            if not is_inf(row.owner.end_ms):
                var window:Dictionary=component.lifecycle
                var close_end:float=row.owner.end_ms+(float(window.exit_end_seconds)-float(window.exit_start_seconds))*1000.0
                check(row.end_ms<=close_end+.00001,spell+": native track stops at its own source close, not a retained sibling's fade")
        if component.get("spatial_owner",false):
            var cuts:Array=spatial_cuts.get(row.trace_track_id,[])
            check(cuts.any(func(cut):return cut.at_ms<=row.start_ms and cut.component.spatial_effect_uuid==row.owner.id and cut.component.source_id==component.source_id and cut.component.native_clip.id==component.native_clip.id),spell+": actual sensory preparation cut registers the exact spatial UUID/source/clip before this span")
        else:
            check(registered.has(row.trace_track_id),spell+": actual condition application registers exact native witness ID")
        if not component.get("spatial_owner",false):
            owners[row.owner.condition.behavior_id]=true
        for child in index.rows.filter(func(candidate):return candidate.parent==row.id and candidate.kind=="native_light"):
            check(child.component.id==child.trace_track_id and child.source_start_ms==row.source_start_ms,spell+": native light child shares occurrence clock")
            check(child.start_ms==row.start_ms and child.end_ms==row.end_ms and not child.has("light_keys"),spell+": native optical source is not a fabricated gameplay-light curve")
            check(registered.has(child.trace_track_id),spell+": light child witness is registered")
            check(child.component.native_light.tracks.all(func(track):return track.get("enabled",true) and (track.get("active_animation",true) or track.has("source_cue_seconds"))),spell+": only executing source animations produce native light markers")
            check(child.markers.all(func(marker):return marker.at_ms>=row.start_ms and marker.at_ms<=row.end_ms),spell+": repeated inspection spans do not display keys outside their own interval")
    var entry_report=Coverage.build(index.cache,index.rows,owners) if not owners.is_empty() else {"entries":[]}
    for entry in entry_report.entries:
        var replaced:Array=Native.replaced_media({"behavior_id":entry.id},Coverage.Authoring.load_data("catalog/condition_recipes.json",index.cache)[entry.id])
        check(not entry.requirements.any(func(requirement):return requirement.get("asset_id","") in replaced),spell+": replaced sprite media creates no obsolete requirements")
        var phases:Array=entry.requirements.filter(func(requirement):return requirement.mechanism.begins_with("native:"))
        check(phases.size()==Native.Effects.conditions(entry.id).size() and not phases.is_empty(),spell+": every package lifecycle of the owner has source coverage")
        check(phases.all(func(requirement):return requirement.status=="implemented" and requirement.availability=="available" and not requirement.rendered),spell+": actual resolved native rows qualify implementation only")
        if entry.id=="condition.spell.shield":shield_requirements(index,entry)
    if not family_rows.is_empty():
        var first:Dictionary=family_rows[0]
        var at:float=(first.start_ms+first.end_ms)*.5
        var restored=Recording.restore(index,at)
        var samples:Array=restored.component_samples(index.cache)
        check(samples.any(func(sample):return sample.id==first.component.id),spell+": seek restores the same shared native occurrence")
        if first.component.get("spatial_owner",false):
            var owner:Dictionary=restored.spatial_effect_owners.get(first.owner.id,{})
            check(not owner.is_empty() and owner.start_ms==first.source_start_ms,spell+": seek reconstructs spatial lifetime from real ordered commits")
        var closed:Array=family_rows.filter(func(row):return not is_inf(row.owner.end_ms) and row.start_ms>=row.owner.end_ms)
        if spell!="web":
            check(family_rows.any(func(row):return not is_inf(row.owner.end_ms) and row.start_ms>=row.owner.end_ms),label+": same-family actual removal exposes its own source-close interval")
        if not closed.is_empty():
            var close:Dictionary=closed[0]
            var begin:float=(close.start_ms-close.source_start_ms)/1000.0
            var finish:float=(close.end_ms-close.source_start_ms)/1000.0
            if close.component.has("lifecycle_phases"):
                var opened:Dictionary=Native.lifecycle_state(close.component,begin);var closing:Dictionary=Native.lifecycle_state(close.component,finish)
                check(opened.phase=="removal" and closing.phase=="removal" and closing.phase_age_seconds>opened.phase_age_seconds and closing.owner_age_seconds>opened.owner_age_seconds,spell+": removal plays on the owner's age when seeking within it")
            else:check(Playback.source_time(close.component.native_cue,finish)>Playback.source_time(close.component.native_cue,begin),spell+": removal source clock progresses when seeking within close interval")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,label+": owner inspection and seek preserve immutable original source cuts")
    observations.append({"spell":spell,"perspective":perspective.id,"native_owner_rows":rows.size(),"condition_types":owners.keys(),"journal":perspective.journal})

func lifecycle_clock(row:Dictionary,label:String)->void:
    var component:Dictionary=row.component
    var application:float=component.lifecycle_phases.application.seconds
    var removed:float=component.duration_ms/1000.0
    var shift:float=application if component.get("initial",false) else 0.0
    var admission:Dictionary=Native.lifecycle_state(component,0.0)
    check(admission.phase==("sustain" if component.get("initial",false) else "application") and admission.owner_age_seconds==shift,label+": actual initial/admitted owner starts at its own package phase")
    if removed>application and not component.get("initial",false):
        var held:Dictionary=Native.lifecycle_state(component,(application+removed)*.5)
        check(held.phase=="sustain" and is_equal_approx(held.phase_age_seconds,(removed-application)*.5),label+": source sustains between actual application and actual retirement")
    if not is_inf(removed):
        var at:float=removed+float(component.lifecycle_phases.removal.seconds)*.5
        var closing:Dictionary=Native.lifecycle_state(component,at)
        check(closing.phase=="removal" and is_equal_approx(closing.phase_age_seconds,at-removed) and is_equal_approx(closing.removal_started_at_owner_age_seconds,removed+shift),label+": actual removal advances the nested clip on the same UUID owner clock")

func shield_requirements(index:Dictionary,entry:Dictionary)->void:
    var recipe:Dictionary=Coverage.Authoring.load_data("catalog/condition_recipes.json",index.cache)[entry.id]
    var obsolete:Array=[]
    for effects in recipe.interceptionEffectsByDirection.values():
        for effect in effects:obsolete.append(effect.assetId)
    check(obsolete.size()==16,"Shield retains the exact eight-direction/front-back legacy interception inventory")
    check(not entry.requirements.any(func(requirement):return requirement.get("asset_id","") in obsolete),"Shield native interception replaces its sixteen old hit-sheet requirements")
    var contacts:Array=entry.requirements.filter(func(requirement):return requirement.mechanism.begins_with("native_contact:"))
    check(contacts.size()==1 and contacts[0].status=="implemented" and contacts[0].availability=="available" and not contacts[0].rendered,"Shield actual intercepted event qualifies its selected native contact source, not generic render proof")
    var actual:Array=index.rows.filter(func(row):return row.get("component",{}).has("intercepted_by_condition_uuid"))
    check(not actual.is_empty() and contacts.all(func(requirement):return not requirement.evidence.is_empty() and requirement.evidence.all(func(evidence):return actual.any(func(row):return evidence.row_id==row.id and evidence.condition_uuid==row.component.intercepted_by_condition_uuid))),"Shield contact coverage points to the actual recorded hit and intercepting condition UUID")
    var gaps:Array=entry.requirements.filter(func(requirement):return requirement.status=="missing")
    check(gaps.is_empty(),"Shield's actual native interception and authored reaction cast close their own coverage gaps")
    var reaction:Array=entry.requirements.filter(func(requirement):return requirement.mechanism=="cast_binding")
    check(reaction.size()==1 and reaction[0].status=="implemented" and not reaction[0].rendered and not reaction[0].evidence.is_empty(),"Shield reaction binding has actual track evidence, not inferred execution from source availability")
    var visible:Array=index.rows.filter(func(row):return row.get("owner",{}).get("condition",{}).get("behavior_id")==entry.id and row.kind=="requirement")
    check(visible.is_empty(),"Studio Shield row has no superseded sprites or now-implemented reaction gap")

func run()->void:
    held_light_keys()
    cast_ownership_controls()
    var source:String=CASES;var grant_case:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--cases="):source=argument.trim_prefix("--cases=")
        elif argument.begins_with("--grant-case="):grant_case=argument.trim_prefix("--grant-case=")
    # This durable corpus contains the original current-schema two-seat
    # lifecycles. Cast-only or unrelated families cannot satisfy its contract.
    var inventory:Dictionary={"cases":[]}
    if FileAccess.file_exists(source):
        var loaded:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
        check(loaded is Dictionary and loaded.get("cases") is Array,"Original current-schema lifecycle inventory is readable: "+source)
        if loaded is Dictionary and loaded.get("cases") is Array:inventory=loaded
    var wanted=["bane","command","guidance","light","mage_armor","resistance","sanctuary","shield","shield_of_faith","web"]
    var unqualified:Array=[]
    for id in wanted:
        var matches:Array=inventory.cases.filter(func(case):return case.id=="native-spell-"+id)
        check(matches.size()==1,id+": same-family current-schema application/hold/end original is registered in "+source)
        if matches.size()!=1:unqualified.append(id);continue
        var case:Dictionary=matches[0]
        var before:int=failures.size()
        check(case.spell_id==id,id+": descriptor retains the exact required spell family")
        check(case.perspectives.size()==2 and case.perspectives.any(func(view):return view.id=="amber") and case.perspectives.any(func(view):return view.id=="blue"),id+": both original independent audience journals are retained")
        for perspective in case.perspectives:inspect_case(case,perspective)
        if failures.size()>before:unqualified.append(id)
    var area_before:int=failures.size()
    area_trace(inventory)
    if failures.size()>area_before:unqualified.append("ice_knife_trace")
    if not grant_case.is_empty():grant_inspection(grant_case)
    var report={"grant_case":grant_case,"checks":checks,"failures":failures,"observations":observations,"required_families":wanted,"unqualified_families":unqualified,"inventory":source,"scope":"All ten original spell-family lifecycle contracts remain required. Actual independent current-schema SDK recordings, exact UUID clocks/retirement, canonical restores and source/Studio inspection only; no GPU, native framebuffer or artistic proof. Missing lawful same-family originals fail rather than being replaced with cast-only or unrelated families."}
    FileAccess.open("res://.runtime/native-persistent-studio-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PERSISTENT_STUDIO_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

## Optional actual-original extension of this existing inspection gate.
## It does not replace any of the ten required family originals above.
func grant_inspection(directory:String)->void:
    var scenario:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("scenario.json")))
    var receipt:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("recording.json")))
    check(scenario is Dictionary and receipt is Dictionary,"Grant study retains its actual scenario and original recording receipt")
    if not scenario is Dictionary or not receipt is Dictionary:return
    check(receipt.get("ok")==true and receipt.get("perspectives",[])==["amber","blue"],"Grant study is a successful unchanged two-seat original, not the preserved failed prefix")
    var required:Array=scenario.get("required_grant_sources",[])
    check(not required.is_empty(),"Grant study explicitly declares its real source lifecycle obligations")
    if receipt.get("ok")!=true:return
    for seat in receipt.get("perspectives",[]):
        var directory_seat:String=directory.path_join(str(seat)).path_join("journal")
        var index:Dictionary=Recording.read(directory_seat)
        var label:String=str(scenario.id)+"/"+str(seat)
        check(index.ok,label+": unchanged actual grant journal indexes")
        if not index.ok:continue
        var frozen:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
        var journal=Journal.new();var independently:Dictionary=journal.open(directory_seat,true)
        check(independently.ok,label+": same original folds independently")
        if independently.ok:
            check(Recording.restore(index,index.presentation_end_ms+1000.0).state==journal.state,label+": grant inspection preserves the independent canonical final state")
        var originals:Dictionary={}
        for file in DirAccess.get_files_at(directory_seat):
            if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
            # Use the original journal's already selected recorded contract.
            # Generic JSON parsing turns integer fact fields into floats and
            # cannot be compared as the SDK's exact Dictionary after-value.
            var decoded:Dictionary=journal.decode_record(int(file.get_basename()),FileAccess.get_file_as_bytes(directory_seat.path_join(file)))
            check(decoded.ok,label+": original grant packet retains its exact recorded scalar types")
            if not decoded.ok:continue
            var packet:Dictionary=decoded.value
            for lineage in packet.get("lineages",[]):
                for node in lineage.events:
                    var fact:Dictionary=node.fact if node.get("fact") is Dictionary else {}
                    if node.get("phase")!="completion" or fact.get("kind")!="temporary_hit_points" or not fact.get("grant") is Dictionary:continue
                    originals[str(int(node.occurrence))]=fact
        for requirement in required:
            var selected:Array=originals.keys().filter(func(id):return originals[id].grant.get("source_id")==requirement.source_id)
            check(selected.size()==1,label+": real completed source grant is unique in the unchanged original")
            if selected.size()!=1:continue
            var event_uuid:String=selected[0];var fact:Dictionary=originals[event_uuid]
            var uuid:String=str(fact.grant.instance_uuid);var actor_id:String=str(fact.entity_uuid)
            var onset:float=INF;var retired:float=INF;var retirement_event:String="";var seen:bool=false
            for item in index.groups:
                for commit in item.group.commits:
                    if commit.get("grant_fact",{})==fact:
                        check(not seen and str(commit.get("event_uuid",""))==event_uuid,label+": actual completed grant commit keeps its original occurrence")
                        seen=true;onset=float(item.start_ms)+float(commit.at_ms)
                    if not seen or not is_inf(retired):continue
                    var after:Dictionary=commit.delta.get("actors",{}).get(actor_id,{})
                    if after.is_empty():continue
                    if not after.get("present",true) or after.temporary_hp_grant!=fact.grant or int(after.temporary_hp)<=0:
                        retired=float(item.start_ms)+float(commit.at_ms);retirement_event=str(commit.get("event_uuid",""))
            check(seen and not is_inf(onset),label+": Studio owner onset has an actual compiled grant cut")
            if requirement.get("retired",false):check(not is_inf(retired),label+": actual later canonical replacement/null/zero/departure retires the grant")
            var parents:Array=index.rows.filter(func(row):return row.kind=="temporary_hp_grant" and row.get("grant_uuid")==uuid)
            check(parents.size()==1,label+": one distinct grant metadata owner exists")
            if parents.size()!=1:continue
            var parent:Dictionary=parents[0]
            check(parent.grant_source_id==requirement.source_id and parent.recipient_uuid==actor_id and parent.owner.grant==fact.grant and not parent.owner.has("condition"),label+": grant UUID/source/recipient remain distinct from ConditionRows")
            check(parent.admission_kind=="onset" and parent.source_event_uuid==event_uuid and parent.start_ms==onset and parent.owner.start_ms==onset,label+": actual grant application uses its original completed cut and clock")
            check(parent.membership_end_ms==retired and parent.removal_event_uuid==retirement_event,label+": metadata retirement comes from the actual later canonical cut")
            var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_grant",false) and row.get("grant_uuid")==uuid)
            var phases:Dictionary={};var by_id:Dictionary={};var visible:Dictionary={}
            for row in index.rows:by_id[row.id]=row;visible[row.id]=row
            var projection:Dictionary=Compact.project(index.rows,visible,by_id,["native_effect"],{})
            for row in rows:
                var component:Dictionary=row.component;var phase:String=str(row.lifecycle_phase);phases[phase]=true
                check(row.parent==parent.id and row.end_ms>row.start_ms and component.grant_uuid==uuid and component.grant_source_id==requirement.source_id and component.actor_uuid==actor_id,label+": native inspection span keeps the original owner and recipient")
                check(row.source_start_ms==onset and component.absolute_start_ms==onset and component.duration_ms==retired-onset,label+": phase splitting never restarts the grant clock")
                check(not component.has("condition_uuid") and not component.has("condition") and row.coverage.rendered=="not_witnessed",label+": source inspection neither fabricates a condition nor promotes rendered evidence")
                check(row.effect_clip==component.lifecycle_phases[phase].id and Native.lifecycle_state(component,(row.start_ms-onset)/1000.0).phase==phase,label+": phase and clip use the original selected lifecycle")
                check(component.removal_age_ms==null if phase!="removal" else component.removal_age_ms==row.start_ms-retired,label+": retirement age is absent before the actual end")
                var at:float=(float(row.start_ms)+float(row.end_ms))*.5
                var restored=Recording.restore(index,at)
                var samples:Array=restored.component_samples(index.cache)
                var matched:Array=samples.filter(func(sample):return sample.get("native_grant",false) and sample.id==row.trace_track_id and sample.grant_uuid==uuid)
                check(matched.size()==1 and matched[0].grant_source_id==requirement.source_id and Native.lifecycle_state(matched[0],float(matched[0].age_ms)/1000.0).phase==phase,label+": seek restores the same real grant occurrence and lifecycle phase")
                if restored.temporary_hp_owners.has(uuid):check(restored.temporary_hp_owners[uuid].start_ms==onset,label+": seek retains the original owner clock")
                else:check(false,label+": seek retains this active grant lifecycle owner")
                var anchor:Dictionary=Recording.navigation_anchor(index,at,row)
                check(anchor.grant_uuid==uuid and anchor.condition_uuid.is_empty() and is_equal_approx(Recording.anchor_time(index,anchor),at),label+": grant navigation roundtrips without a condition alias")
                check(projection.raw_to_display.has(row.id) and projection.owner_of[row.id]==Compact.action_id(parent,by_id),label+": compact grouping retains the original phase and real ancestry")
            for phase in requirement.get("phases",[]):check(phases.has(phase),label+": actual original exposes its required "+str(phase)+" inspection span")
            if requirement.get("retired",false):
                var final=Recording.restore(index,index.presentation_end_ms+1000.0)
                var remaining:Array=final.component_samples(index.cache)
                check(not final.temporary_hp_owners.has(uuid) and not remaining.any(func(sample):return sample.get("grant_uuid")==uuid),label+": original source return ends this owner without a retained native sample")
            observations.append({"source_id":requirement.source_id,"perspective":seat,"journal":directory_seat,"grant_uuid":uuid,"recipient_uuid":actor_id,"source_event_uuid":event_uuid,"onset_ms":onset,"retirement_ms":retired,"phases":phases.keys(),"scope":"original canonical cuts and Studio inspection only"})
        check(var_to_bytes([index.initialization,index.groups,index.rows])==frozen,label+": grant inspection and navigation leave the actual immutable index unchanged")

func area_trace(inventory:Dictionary)->void:
    var matches:Array=inventory.cases.filter(func(case):return case.id=="native-spell-ice_knife")
    check(matches.size()==1,"Ice Knife unchanged current-schema cast/burst/recipient original exists")
    if matches.is_empty():return
    for perspective in matches[0].perspectives:
        var label:String="Ice Knife/"+str(perspective.id)
        var index=Recording.read(perspective.journal)
        check(index.ok,label+": burst trace indexes")
        if not index.ok:continue
        var originals:Dictionary={};var declared:Dictionary={};var burst:Dictionary={}
        for file in DirAccess.get_files_at(perspective.journal):
            if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
            var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(perspective.journal).path_join(file)))
            for lineage in packet.get("lineages",[]):
                for node in lineage.events:
                    var fact:Variant=node.get("fact")
                    if fact==null or fact.get("kind")!="spell":continue
                    originals[str(int(node.occurrence))]=node
                    if fact.get("behavior_id")!="spell.ice_knife":continue
                    if fact.get("effect_id")=="spell.ice_knife.burst":burst=node
                    elif node.get("parent_event")==null:declared=node
        check(not declared.is_empty() and not burst.is_empty() and originals.size()==5,label+": original public stream contains one root cast, its actual burst and three recipients")
        if declared.is_empty() or burst.is_empty():continue
        var actual_caster:String=str(int(declared.occurrence));var actual_burst:String=str(int(burst.occurrence))
        var cast_owners={};var spells:Array=[];var bodies:int=0;var native:Array=[]
        for item in index.groups:
            for event in item.group.events:
                if event.kind!="spell" or event.behavior_id!="spell.ice_knife":continue
                spells.append(event);cast_owners[event.cast_owner_event]=true
                bodies+=event.components.filter(func(component):return component.kind=="body" and not component.trace_track_id.is_empty()).size()
                check(originals.has(event.event_uuid) and event.cast_owner_event==actual_caster,label+": every native occurrence retains its real identity and actual root cast owner")
                check(not event.components.any(func(component):return component.reason in ["missing_authored_cast_body","authored_cast_layer_not_implemented","authored_projectile_not_implemented"]),label+": area applications do not demand a duplicate cast/projectile")
            for component in item.group.components:
                if component.get("native_spell",false) and originals.has(component.source_event_uuid):
                    native.append(component)
                    check(component.spell_id==Native.Spells.selection("spell.ice_knife",index.cache).id,label+": actual native occurrence selects the authored Ice Knife source family")
                if component.kind=="sprite_layer":check(component.source_event_uuid==actual_caster,label+": hand-magic layers belong only to the actual casting occurrence")
                if component.kind=="audio" and component.get("assignment_source","").begins_with("audio/bindings.json:/spells/"):
                    check(component.source_event_uuid==actual_caster,label+": caster audio is never replayed by its secondary area or recipient")
            for track in item.group.actor_tracks:
                if track.activity=="cast":check(track.source_event_uuid==actual_caster and track.actor_uuid==declared.fact.source_entity_uuid,label+": only the disclosed rule caster plays a casting body")
        check(spells.size()==5 and cast_owners.keys()==[actual_caster] and bodies==1,label+": actual cast, burst and recipients retain exactly one real cast body")
        for role in ["cast","flight","area"]:
            var phases:Array=native.filter(func(component):return component.native_cue.role==role)
            check(phases.size()==1 and phases[0].source_event_uuid==(actual_burst if role=="area" else actual_caster) and phases[0].native_cast_id==actual_caster,label+": one "+role+" uses its own actual occurrence and shared cast identity")
        observations.append({"spell":"ice_knife","perspective":perspective.id,"journal":perspective.journal,"actual_cast":actual_caster,"actual_burst":actual_burst,"spell_occurrences":spells.size(),"casting_bodies":bodies,"native_roles":native.map(func(component):return component.native_cue.role)})

func cast_ownership_controls()->void:
    # Synthetic compiler controls, never server recordings or render proof.
    var source={"id":"root-control","lineage_id":"root-line","parent_lineage":null,"resolution_record":{"lineage":"root-line"},
        "fact":{"kind":"spell","behavior_id":"spell.control","source_entity_uuid":"caster-control"}}
    var secondary={"id":"area-control","lineage_id":"area-line","parent_lineage":"root-line","resolution_record":{"lineage":"area-line"},
        "fact":{"kind":"spell","behavior_id":"spell.control","source_entity_uuid":"caster-control","effect_id":"area-control-effect"}}
    var application={"id":"recipient-control","lineage_id":"recipient-line","parent_lineage":"area-line",
        "resolution_record":{"lineage":"area-line","application_id":"controlled-unit-application"},
        "fact":{"kind":"spell","target_entity_uuid":"recipient-control"}}
    var selection={"delivery":{"scope":"area","roles":["area"],"effects":{"area-control-effect":{"scope":"area","roles":["area"]},"separate-cast-effect":{"scope":"single","roles":["cast","flight"]}}}}
    var graph={"nodes":{"root-line":source,"area-line":secondary,"recipient-line":application},"spell_facts":{},
        "spell_sources":{"spell.control":{"selection":selection}}}
    var frozen:PackedByteArray=var_to_bytes([source,secondary,application,selection])
    check(Delivery.cast_key(source,graph)=="root-line","Compiler control: root area spell keeps its own native cast identity")
    check(Delivery.cast_key(secondary,graph)=="root-line" and Delivery.cast_key(application,graph)=="root-line","Compiler control: explicit secondary area and recipient share only their real same-caster ancestor")
    var projected:Dictionary=Occurrences.spell(application,graph)
    check(projected.effect_id==secondary.fact.effect_id and projected.target_entity_uuid==application.fact.target_entity_uuid,"Compiler control: sparse recipient inherits actual declaration effect selection and retains its own target")
    for change in [{"source_entity_uuid":"different-caster"},{"behavior_id":"spell.different-control"}]:
        var other:Dictionary=source.duplicate(true);other.fact.merge(change,true)
        var private:Dictionary=graph.duplicate();private.nodes=graph.nodes.duplicate();private.nodes["root-line"]=other
        check(Delivery.cast_key(secondary,private)=="area-line","Compiler control: unrelated neighboring source cannot acquire area caster ownership "+str(change))
    var own:Dictionary=secondary.duplicate(true);own.fact.effect_id="separate-cast-effect"
    var private:Dictionary=graph.duplicate();private.nodes=graph.nodes.duplicate();private.nodes["area-line"]=own
    check(Delivery.cast_key(own,private)=="area-line","Compiler control: explicit cast roles retain an independent child cast")
    private=graph.duplicate();private.nodes={"area-line":secondary}
    check(Delivery.cast_key(secondary,private)=="area-line","Compiler control: missing public ancestry never invents a shared caster")
    check(var_to_bytes([source,secondary,application,selection])==frozen,"Compiler controls preserve native operands and immutable authored effect roles")

func held_light_keys()->void:
    # Pure clock contract, not a manufactured server effect. A donor binding
    # runs at2x with.2s source offset; keys in the skipped middle do not execute.
    var cue={"lifecycle":{"hold_mode":"hold","enter_end_seconds":1.0,"hold_start_seconds":1.0,"hold_end_seconds":1.0,
        "exit_start_seconds":3.0,"exit_end_seconds":4.0},"owner_end_seconds":10.0,"initial":false}
    var keys:Array=[]
    for time in [0.2,2.2,4.2,6.2,8.2]:keys.append({"time":time,"value":time})
    var component={"kind":"native_light","start_ms":1000.0,"native_cue":cue,
        "native_light":{"bindings":[{"component":"effect","rate":2.0,"offset_seconds":.2}],
            "tracks":[{"player":"effect/Player","animation":"native","path":"Light:light_energy","keys":keys}]}}
    var marks=Channels.markers(component,0)
    check(marks.map(func(marker):return roundi(marker.at_ms))==[1000,2000,11000,12000],"Held native keys map entry and removal without fabricating keys across the hold")
    check(marks.map(func(marker):return marker.source_seconds)==[.2,2.2,6.2,8.2],"Light keys retain original source time and binding rate/offset")
    cue.initial=true
    check(Channels.markers(component,0).map(func(marker):return roundi(marker.at_ms))==[11000,12000],"Already-active owner does not replay source entry keys")
    cue.initial=false;cue.owner_end_seconds=.5
    check(Channels.markers(component,0).map(func(marker):return roundi(marker.at_ms))==[1000,1500,2500],"Early actual removal skips source entry keys beyond the removal boundary")
    cue.owner_end_seconds=INF
    check(Channels.markers(component,0).map(func(marker):return roundi(marker.at_ms))==[1000,2000],"Unremoved owner has no invented finite exit markers")
    cue.owner_end_seconds=10.0
    var light={"path":"effect/Light","bindings":[{"component":"effect","rate":1.0,"offset_seconds":0.0}],
        "tracks":[{"player":"effect/Player","animation":"Init","active_animation":true,"enabled":true,"path":"Light:light_energy","keys":[{"time":0.0,"value":1.0}]},
            {"player":"effect/Player","animation":"RESET","active_animation":false,"enabled":true,"path":"Light:light_energy","keys":[{"time":0.0,"value":0.0}]},
            {"player":"effect/Player","animation":"Close","active_animation":false,"enabled":true,"path":"Light:light_energy","keys":[{"time":0.0,"value":1.0},{"time":1.0,"value":0.0}]}]}
    var phase={"id":"clock-contract","start_ms":1000.0,"native_cue":cue,"native_lights":[light],
        "native_clip":{"animation_cues":[{"node":"effect/Player","animation":"Close","at_seconds":3.0}]}}
    var channel:Dictionary=Channels.channels(phase)[0]
    check(channel.native_light.tracks.size()==2 and channel.native_light.tracks.all(func(track):return track.animation!="RESET"),"Inactive RESET tracks remain intake metadata, not played source keys")
    check(Channels.markers(channel,0).map(func(marker):return roundi(marker.at_ms))==[1000,11000,12000],"Explicit native close animation cue maps local source keys through actual owner removal")
