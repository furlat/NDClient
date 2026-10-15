extends SceneTree
## Real admitted recordings -> compiler/Studio inspection rows. Evidence below
## exercises the trace contract only; this headless test makes no GPU claim.
const Recording=preload("res://studio/recording.gd")
const Trace=preload("res://presentation/event_trace.gd")
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

func source_keys(row:Dictionary,label:String)->void:
    var component:Dictionary=row.component
    var phase:String=component.native_cue.role
    var spell:String=component.spell_id
    var light:Dictionary=component.native_light
    check(light.node_type=="OmniLight3D" and is_equal_approx(light.range,5.0),label+": metadata preserves the actual native source type and range")
    check(not row.has("light_keys"),label+": native source is not represented as authoritative gameplay light membership")
    var expected:Dictionary={}
    if spell=="fire_bolt" and phase=="impact":
        expected={"light_energy":[[0.0,2.5],[.3,2.5],[.5,0.0]],"visible":[[0.0,true],[.4,true],[.6,false]]}
    elif spell=="magic_missile" and phase=="cast" and str(light.path).begins_with("cast/"):
        expected={"light_energy":[[0.0,8.0],[.3,8.0],[.6,0.0]],"visible":[[.1,true],[.6,true],[.8,false]]}
    elif spell=="magic_missile" and phase=="impact":
        expected={"light_energy":[[0.0,1.8],[.4,.5],[.6,0.0]],"visible":[[0.0,true],[.5,true],[.8,false]]}
    if expected.is_empty():
        check(light.tracks.is_empty() and row.markers.is_empty(),label+": static donor light has no invented animated keys")
        return
    check(light.tracks.size()==expected.size(),label+": exact active light-property tracks are exposed")
    var total:=0
    for track in light.tracks:
        var property:String=str(track.path).get_slice(":",1)
        check(expected.has(property),label+": track is a real selected source property")
        if not expected.has(property):continue
        var keys:Array=expected[property]
        total+=keys.size()
        check(track.active_animation and track.enabled,label+": inactive/reset source animations do not become Studio keys")
        check(track.get("update_mode",-1)==(1 if property=="visible" else 0),label+": visibility is discrete and energy continuous")
        check(track.keys.size()==keys.size(),label+": exact source key count for "+property)
        for key in keys:
            var matches:Array=track.keys.filter(func(actual):return absf(float(actual.time)-float(key[0]))<.00001)
            check(matches.size()==1,label+": source key retained for "+property+" at "+str(key[0]))
            if matches.is_empty():continue
            check(matches[0].value==key[1] if key[1] is bool else absf(float(matches[0].value)-float(key[1]))<.00001,
                label+": original property value retained for "+property)
            # These selected cast/impact bindings are offset0/rate1. The
            # independent source times above must become absolute track times.
            var marker_source=str(track.player)+":"+str(track.animation)+"/"+str(track.path)
            var markers:Array=row.markers.filter(func(marker):return marker.source==marker_source and absf(float(marker.source_seconds)-float(key[0]))<.00001)
            check(markers.size()==1,label+": actual source key has one Studio marker for "+property+" at "+str(key[0]))
            if not markers.is_empty():
                check(absf(float(markers[0].at_ms)-(row.start_ms+float(key[0])*1000.0))<.002,
                    label+": marker uses the phase clock and recording offset exactly once")
    check(row.markers.size()==total,label+": no extra source-property markers are fabricated")

func recording(path:String,sequence:int,spell:String,phase_count:int,light_count:int,hit_count:int)->void:
    var started=Time.get_ticks_usec()
    var index=Recording.read(path)
    var label=spell+" sequence "+str(sequence)
    check(index.ok,label+": real SDK journal admits into Studio")
    if not index.ok:observations.append({"case":label,"error":index.get("error","")});return
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
        var children:Array=rows.filter(func(row):return row.kind in ["native_light","native_material"])
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
                source_keys(child,label+" "+parent.component.native_cue.role+" "+child.component.native_light.path)
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
    recording("res://.runtime/compact-magic-missile-20261013/amber/journal",29,"fire_bolt",3,2,1)
    recording("res://.runtime/studio-cases/magic_missile-seed3/amber/journal",2,"magic_missile",7,8,0)
    recording("res://.runtime/gallery-route/journal",22,"magic_missile",7,8,3)
    var report={"checks":checks,"failures":failures,"observations":observations,
        "scope":"Actual SDK journals through production compiler/Studio; phase-child hierarchy, native source key timing/update modes, real blocked-hit absence, passive trace registration and intentional inactive mode. Injected trace evidence is not a GPU rendering claim."}
    FileAccess.open("res://.runtime/native-spell-channel-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_CHANNELS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
