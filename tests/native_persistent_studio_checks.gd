extends SceneTree
## Actual server journals -> shared reducer/Studio rows. No rendering claim.
const Recording=preload("res://studio/recording.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const Native=preload("res://presentation/native_persistent.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Channels=preload("res://presentation/native_spell_channels.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PERSISTENT_STUDIO_FAIL ",label)

func inspect_case(case:Dictionary)->void:
    var spell:String=case.spell_id
    var index=Recording.read(case.perspectives[0].journal)
    check(index.ok,spell+": real SDK journal indexes")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("persistent_owner",false))
    check(not rows.is_empty(),spell+": real disclosed owner produces native rows")
    var ids={};var registered={};var owners={}
    for row in index.rows:ids[row.id]=row
    for item in index.groups:
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
        check(row.component.native_cue.owner_end_seconds==(row.owner.end_ms-row.owner.start_ms)/1000.0,spell+": source clock closes only at actual owner removal")
        if not is_inf(row.owner.end_ms):
            var window:Dictionary=component.lifecycle
            var close_end:float=row.owner.end_ms+(float(window.exit_end_seconds)-float(window.exit_start_seconds))*1000.0
            check(row.end_ms<=close_end+.00001,spell+": native track stops at its own source close, not a retained sibling's fade")
        check(registered.has(row.trace_track_id),spell+": actual condition application or sensory commit registers exact native witness ID")
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
        var selected=Native.Spells.condition(entry.id,index.cache)
        var replaced:Array=selected.lifecycle.replaces_media
        check(not entry.requirements.any(func(requirement):return requirement.get("asset_id","") in replaced),spell+": replaced sprite media creates no obsolete requirements")
        var phases:Array=entry.requirements.filter(func(requirement):return requirement.mechanism.begins_with("native:"))
        check(phases.size()==Native.Spells.condition_phases(selected).size() and not phases.is_empty(),spell+": every native owner phase has source coverage")
        check(phases.all(func(requirement):return requirement.status=="implemented" and requirement.availability=="available" and not requirement.rendered),spell+": actual resolved native rows qualify implementation only")
        if entry.id=="condition.spell.shield":shield_requirements(index,entry)
    if not rows.is_empty():
        var first:Dictionary=rows[0]
        var at:float=(first.start_ms+first.end_ms)*.5
        var restored=Recording.restore(index,at)
        var samples:Array=restored.component_samples(index.cache)
        check(samples.any(func(sample):return sample.id==first.component.id),spell+": seek restores the same shared native occurrence")
        if first.component.get("spatial_owner",false):
            var owner:Dictionary=restored.spatial_effect_owners.get(first.owner.id,{})
            check(not owner.is_empty() and owner.start_ms==first.source_start_ms,spell+": seek reconstructs spatial lifetime from real ordered commits")
        var closed:Array=rows.filter(func(row):return not is_inf(row.owner.end_ms) and row.start_ms>=row.owner.end_ms)
        if spell!="web":check(not closed.is_empty(),spell+": real removal exposes source-close interval")
        if not closed.is_empty():
            var close:Dictionary=closed[0]
            var begin:float=(close.start_ms-close.source_start_ms)/1000.0
            var finish:float=(close.end_ms-close.source_start_ms)/1000.0
            check(Playback.source_time(close.component.native_cue,finish)>Playback.source_time(close.component.native_cue,begin),spell+": removal source clock progresses when seeking within close interval")
    observations.append({"spell":spell,"native_owner_rows":rows.size(),"condition_types":owners.keys(),"journal":case.perspectives[0].journal})

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
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_spell_case_inventory.json"))
    var wanted=["bane","command","guidance","light","mage_armor","resistance","sanctuary","shield","shield_of_faith","web"]
    for id in wanted:
        var matches:Array=inventory.cases.filter(func(case):return case.id=="native-spell-"+id)
        check(matches.size()==1,id+": actual recording is registered")
        if not matches.is_empty():inspect_case(matches[0])
    area_trace(inventory)
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Actual SDK recordings, shared owner lifetimes, source coverage and Studio inspection/seek; no GPU or artistic proof"}
    FileAccess.open("res://.runtime/native-persistent-studio-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PERSISTENT_STUDIO_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func area_trace(inventory:Dictionary)->void:
    var matches:Array=inventory.cases.filter(func(case):return case.id=="native-spell-ice_knife")
    check(matches.size()==1,"Ice Knife actual burst case exists")
    if matches.is_empty():return
    var index=Recording.read(matches[0].perspectives[0].journal)
    check(index.ok,"Ice Knife burst trace indexes")
    if not index.ok:return
    var cast_owners={};var spells:Array=[];var bodies=0
    for item in index.groups:
        for event in item.group.events:
            if event.kind!="spell" or event.behavior_id!="spell.ice_knife":continue
            spells.append(event);cast_owners[event.cast_owner_event]=true
            bodies+=event.components.filter(func(component):return component.kind=="body" and not component.trace_track_id.is_empty()).size()
            check(not event.components.any(func(component):return component.reason in ["missing_authored_cast_body","authored_cast_layer_not_implemented","authored_projectile_not_implemented"]),"Ice Knife area applications do not demand a duplicate cast/projectile")
    check(spells.size()>=3 and cast_owners.size()==1 and bodies==1,"Actual Ice Knife cast, burst and recipient applications retain one cast owner")

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
