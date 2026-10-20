extends SceneTree
## Real admitted recordings -> compiler/Studio inspection rows. Evidence below
## exercises the trace contract only; this headless test makes no GPU claim.
const Recording=preload("res://studio/recording.gd")
const Trace=preload("res://presentation/event_trace.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_SPELL_CHANNEL_FAIL ",label)

func selected_component(trace:Dictionary,event_id:String,component_id:String)->Dictionary:
    var selected:Dictionary=Trace.snapshot(trace,2000,event_id,0).selected
    for component in selected.get("components",[]):
        if component.id==component_id:return component
    return {}

func trace_channels(group:Dictionary,start:float,rows:Array,label:String)->void:
    for row in rows:
        var trace=Trace.create()
        Trace.activate(trace,group.events,start)
        for event in group.events:Trace.commit(trace,int(group.operation_sequence),event.event_uuid)
        var event_id="%s:%s"%[group.operation_sequence,row.source_event_uuid]
        var before=selected_component(trace,event_id,row.id)
        check(not before.is_empty(),label+": channel is registered under its actual source event: "+row.kind)
        if before.is_empty():continue
        check(before.status=="playing" and before.sample_count==0,label+": source availability alone is not presented evidence")
        var at:float=(row.start_ms+row.end_ms)*.5
        if row.kind=="native_material":
            Trace.record(trace,[{"trace_track_id":row.id,"display_ms":at,"inactive":true,"reason":"colour_treatment_selected"}])
            var inactive=selected_component(trace,event_id,row.id)
            check(inactive.status=="inactive" and inactive.reason=="colour_treatment_selected" and inactive.sample_count==0,
                label+": selecting Colour does not claim the native material was rendered or missing")
            Trace.tick(trace,group.events,maxf(group.duration_ms,row.end_ms-start)+1.0)
            inactive=selected_component(trace,event_id,row.id)
            check(inactive.status=="inactive" and inactive.sample_count==0,label+": completion preserves intentional inactive coverage")
        # Injected evidence tests registration/time admission, not real rendering.
        Trace.record(trace,[{"trace_track_id":row.id,"display_ms":row.start_ms-1.0,"visible":true}])
        check(selected_component(trace,event_id,row.id).sample_count==0,label+": no witness before the component interval")
        Trace.record(trace,[{"trace_track_id":row.id,"display_ms":at,"visible":true}])
        var presented=selected_component(trace,event_id,row.id)
        check(presented.status=="presented" and presented.sample_count==1 and is_equal_approx(presented.first_sample_ms,at),
            label+": exact child witness ID reaches its source-event channel")
        Trace.record(trace,[{"trace_track_id":row.id,"display_ms":row.end_ms+1.0,"visible":true}])
        check(selected_component(trace,event_id,row.id).sample_count==1,label+": no witness beyond the component interval")

func phase_time(cue:Dictionary,source:float)->float:
    # Independent inverse of the authored formation/travel/tail clock.
    if cue.role=="flight":
        if source<float(cue.source_launch):return float(cue.begin)+(float(cue.launch)-float(cue.begin))*source/maxf(.001,float(cue.source_launch))
        if source<float(cue.source_contact):return float(cue.launch)+(float(cue.contact)-float(cue.launch))*(source-float(cue.source_launch))/maxf(.001,float(cue.source_contact)-float(cue.source_launch))
        return float(cue.contact)+source-float(cue.source_contact)
    return float(cue.begin)+source/float(cue.get("source_rate",1.0))

func source_keys(row:Dictionary,intakes:Dictionary,label:String)->void:
    var component:Dictionary=row.component
    var cue:Dictionary=component.native_cue
    var light:Dictionary=component.native_light
    var sources:Array=intakes.get(cue.staged_clip,{}).get("lights",[]).filter(func(value):return value.path==light.path)
    check(sources.size()==1,label+": channel names exactly one light in the independently read typed source intake")
    if sources.size()!=1:return
    var original:Dictionary=sources[0]
    check(light.node_type==original.node_type and is_equal_approx(float(light.range),float(original.range)),label+": metadata retains the selected donor type and exact range")
    check(light.color==original.color and is_equal_approx(float(light.energy),float(original.energy)),label+": selected source colour and energy are unchanged")
    check(not row.has("light_keys"),label+": decorative native source is not authoritative gameplay light membership")
    var expected:Array=original.tracks.filter(func(track):return track.get("active_animation",true) and track.get("enabled",true))
    check(light.tracks.size()==expected.size(),label+": exact active source-property track count; inactive RESET does not execute")
    var total:int=0
    for original_track in expected:
        var matches:Array=light.tracks.filter(func(track):return track.player==original_track.player and track.animation==original_track.animation and track.path==original_track.path)
        check(matches.size()==1,label+": actual selected property track retains player/animation/path identity")
        if matches.size()!=1:continue
        var track:Dictionary=matches[0]
        check(track.active_animation and track.enabled,label+": only the active original animation supplies keys")
        check(track.update_mode==original_track.update_mode and track.interpolation==original_track.interpolation,label+": original discrete/continuous and interpolation modes are retained")
        check(track.keys.size()==original_track.keys.size(),label+": exact original property-key count")
        var bindings:Array=original.bindings.filter(func(binding):return str(track.player).begins_with(str(binding.component)+"/"))
        check(not bindings.is_empty() and float(bindings[0].rate)>0,label+": original source has a positive phase clock binding")
        if bindings.is_empty() or float(bindings[0].rate)<=0:continue
        var binding:Dictionary=bindings[0]
        for key in original_track.keys:
            var keys:Array=track.keys.filter(func(value):return absf(float(value.time)-float(key.time))<.00001)
            check(keys.size()==1,label+": original property key time is retained")
            if keys.size()!=1:continue
            check(keys[0].value==key.value if key.value is bool else absf(float(keys[0].value)-float(key.value))<.00001,label+": original selected property value is retained")
            var source:float=(float(key.time)-float(binding.offset_seconds))/float(binding.rate)
            var at:float=phase_time(cue,source)
            if at<float(cue.begin)-.000001 or at>float(cue.end)+.000001:continue
            total+=1
            var marker_source:String=str(track.player)+":"+str(track.animation)+"/"+str(track.path)
            var markers:Array=row.markers.filter(func(marker):return marker.source==marker_source and absf(float(marker.source_seconds)-float(key.time))<.00001)
            check(markers.size()==1,label+": one Studio marker for each in-range original source key")
            if markers.size()==1:check(absf(float(markers[0].at_ms)-(row.start_ms+at*1000.0))<.002,label+": key uses the selected phase clock and recording offset exactly once")
    check(row.markers.size()==total,label+": no source-property markers are invented or omitted")

func recording(path:String,sequence:int,behavior:String,deliveries:int,hit_count:int)->void:
    var started=Time.get_ticks_usec()
    var index=Recording.read(path)
    var label=behavior+" sequence "+str(sequence)
    check(index.ok,label+": real SDK journal admits into Studio")
    if not index.ok:observations.append({"case":label,"error":index.get("error","")});return
    var selected:Dictionary=Spells.selection(behavior,index.cache)
    check(not selected.is_empty(),label+": current typed selection exists")
    if selected.is_empty():return
    var spell:String=selected.id
    var root_source:Resource=load("res://authoring/abilities.tres")
    var typed:Resource=load(root_source.sections.spells[behavior])
    var intakes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+typed.bounds))
    var phase_count:int=0;var light_count:int=0
    for cue in Spells.event_cues(selected):
        var count:int=1 if cue.role=="cast" else deliveries
        phase_count+=count;light_count+=count*intakes.get(str(cue.clip),{}).get("lights",[]).size()
    var groups:Array=index.groups.filter(func(item):return int(item.group.operation_sequence)==sequence)
    check(not groups.is_empty(),label+": actual operation appears in the index")
    var phases:Array=[];var lights:Array=[];var materials:Array=[];var hits:Array=[]
    var ids:Dictionary={}
    for row in index.rows:ids[row.id]=row
    for wrapped in groups:
        var group:Dictionary=wrapped.group
        var immutable=group.duplicate(true)
        check(not group.components.any(func(component):return component.kind in ["native_light","native_material"]),
            label+": inspection channels do not become extra scheduled gameplay components")
        var rows:Array=index.rows.filter(func(row):return row.get("group_id")==group.id)
        var children:Array=rows.filter(func(row):return row.kind in ["native_light","native_material"] and row.component.get("spell_id",row.component.get("native_hit",{}).get("spell_id",""))==spell)
        for row in rows:
            var component:Dictionary=row.get("component",{})
            if row.kind=="native_effect" and component.get("native_spell",false) and component.spell_id==spell:
                phases.append(row)
                check(row.status=="available" and row.end_ms>row.start_ms,label+": native phase is available with its full presentation interval")
                check(absf(row.start_ms-wrapped.start_ms-component.start_ms)<.00001 and absf(row.end_ms-row.start_ms-component.duration_ms)<.00001,
                    label+": native phase uses the same compiler timing as playback")
            if row.kind=="material_flash" and component.get("native_hit",{}).get("spell_id")==spell:hits.append(row)
        for child in children:
            check(ids.has(child.parent),label+": renderer channel has its actual owning component row")
            if not ids.has(child.parent):continue
            var parent:Dictionary=ids[child.parent]
            check(child.source_event_uuid==parent.source_event_uuid and child.group_id==parent.group_id,label+": child cannot change event/group ownership")
            check(child.start_ms==parent.start_ms and child.end_ms==parent.end_ms,label+": child cannot introduce a second presentation interval")
            check(child.coverage.rendered=="not_witnessed" and child.coverage.prepared=="not_examined",label+": reading a recording never claims rendering/preparation")
            if child.kind=="native_light":
                lights.append(child)
                check(parent.kind=="native_effect",label+": native source light stays below its native phase")
                source_keys(child,intakes,label+" "+parent.component.native_cue.role+" "+child.component.native_light.path)
            else:
                materials.append(child)
                check(parent.kind=="material_flash" and child.component.actor_uuid==parent.component.actor_uuid,label+": body material stays below its actual damage recipient")
                check(parent.component.duration_ms==150,label+": child preserves the existing150ms receiver envelope")
                check(child.get("preview_scope")=="live_composed_actor" and not child.component.get("preview_reason","").is_empty(),
                    label+": unavailable composed thumbnail is explicit, not a fabricated source preview")
        trace_channels(group,wrapped.start_ms,children,label)
        check(group==immutable,label+": inspection/evidence leaves compiled playback and state commits unchanged")
    check(phases.size()==phase_count,label+": exact native phase count from actual recorded deliveries")
    check(lights.size()==light_count,label+": exact source-light child count")
    check(hits.size()==hit_count and materials.size()==hit_count,label+": only real damaging deliveries have a receiver material channel")
    if hit_count==0:check(materials.is_empty(),label+": Shield-blocked Magic Missile invents no hit-material track")
    observations.append({"journal":path,"sequence":sequence,"native_phases":phases.size(),"native_lights":lights.size(),
        "native_materials":materials.size(),"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0})

func run()->void:
    for seat in ["amber","blue"]:
        recording(Fixtures.journal("fire-bolt",seat),8,"spell.fire_bolt",1,1)
        recording(Fixtures.journal("shield",seat),6,"spell.magic_missile",3,0)
        recording(Fixtures.journal("magic-missile",seat),2,"spell.magic_missile",3,3)
    var report={"checks":checks,"failures":failures,"observations":observations,
        "retired_oracle":"Universal hardcoded donor range/energy/key values: current exact typed intake metadata is read independently instead; donor OmniLight metadata remains distinct from the PointLight2D renderer channel.",
        "scope":"Actual SDK journals through production compiler/Studio; phase-child hierarchy, native source key timing/update modes, real blocked-hit absence, passive trace registration and intentional inactive mode. Injected trace evidence is not a GPU rendering claim."}
    FileAccess.open("res://.runtime/native-spell-channel-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_CHANNELS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
