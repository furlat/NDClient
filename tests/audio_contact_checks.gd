extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Authored source contacts must survive rate changes, split tracks and real journals.
const Cues=preload("res://presentation/audio_cues.gd")
const Recording=preload("res://studio/recording.gd")
const Tracks=preload("res://presentation/tracks.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("AUDIO_CONTACT_FAIL ",label)
func equal_times(actual:Array,expected:Array,label:String)->void:
    check(actual.size()==expected.size() and actual.all(func(value):return expected.any(func(want):return is_equal_approx(value,want))),label+" "+str(actual))
func body(start:float,duration:float,first:float,last:float,loop:bool=true)->Dictionary:
    return {"actor_uuid":"actor","start_ms":start,"duration_ms":duration,"source_start_seconds":first,"source_end_seconds":last,"loop":loop}
func run()->void:
    var full=body(100,1250,0,1.25)
    equal_times(Cues.source_frame_times(full,3,12,15),[350.0],"Run frame3 at source quarter-second")
    equal_times(Cues.source_frame_times(body(100,625,0,1.25),3,12,15),[225.0],"Faster body clock shifts foot contact without changing sound pitch")
    var warped=body(100,1000,0,1.25);warped.source_time_keys=[[0,0],[.2,.5],[.6,.5],[1,1.25]]
    equal_times(Cues.source_frame_times(warped,6,12,15),[300.0],"Held planted source frame emits once on entry")
    equal_times(Cues.source_frame_times(warped,10,12,15),[877.7777777778],"Piecewise source clock is inverted past a hold")
    var boundary=Cues.source_frame_times(body(100,250,0,.25),3,12,15)
    boundary.append_array(Cues.source_frame_times(body(350,1000,.25,1.25),3,12,15))
    equal_times(boundary,[350.0],"A foot contact exactly between chunks belongs once to arriving segment")
    equal_times(Cues.source_frame_times(body(0,2500,0,2.5),3,12,15),[250.0,1500.0],"Repeated loops preserve every genuine contact")
    equal_times(Cues.source_frame_times(body(0,1250,1.25,0,false),3,12,15,"forward"),[],"Forward marker does not fire on reverse recovery")
    equal_times(Cues.source_frame_times(body(0,1250,1.25,0,false),3,12,15,"reverse"),[1000.0],"Authored reverse marker follows reverse crossing")
    var clip={"frames":15,"fps":12}
    for marker in [{"frame":NAN},{"frame":INF},{"frame":-1},{"frame":16},{"frame":3.5},{"frame":3,"direction":"any"},{"frame":15,"direction":"forward"},{"frame":11,"direction":"forward","boundary":"clip_end"}]:
        marker.binding="landing";marker.id="contact"
        check(not Cues.contact_marker_error(marker,clip,false).is_empty(),"Invalid contact authoring is rejected explicitly: "+str(marker))
    check(Cues.contact_marker_error({"frame":3,"direction":"forward","binding":"path"},clip,true)=="contact_id_not_authored","Missing stable contact ID remains an explicit authoring gap")
    check(Cues.contact_marker_error({"id":"foot","frame":3,"direction":"forward","binding":"path","boundary":"guess"},clip,true)=="invalid_contact_boundary","Unknown source boundary is not silently treated as a contact")
    check(Cues.contact_marker_error({"id":"touchdown","frame":15,"direction":"forward","boundary":"clip_end","binding":"landing"},clip,false).is_empty(),"Explicit nonlooping clip-end boundary is valid")
    check(not Cues.contact_marker_error({"id":"touchdown","frame":15,"direction":"forward","boundary":"clip_end","binding":"landing"},clip,true).is_empty(),"Loop endpoint cannot duplicate next cycle's frame0")
    var landing=Cues.resolve("landing","fixture",0,950)
    check(landing.status=="available" and is_equal_approx(landing.start_ms,870),"Authored landing prelude starts80ms before touchdown")
    check(is_equal_approx(Cues.source_seconds(landing,landing.contact_ms-landing.start_ms),.08),"Waveform and native playback put source impact at contact")
    check(is_equal_approx(landing.duration_ms,landing.clip_duration_s*1000),"Transient sync retains full source including prelude and tail")
    check(Cues.resolve("landing","short-owner",0,40).reason=="source_sync_requires_unavailable_preroll","Unavailable lead-in stays an authoring gap instead of late/clamped impact")
    var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/audio/cues.json"))
    catalog.cues.condition_loop.source_sync_s=[.08]
    check(Cues.resolve("condition_loop","unsupported-loop",0,100,500,{}, {"audio/cues.json":catalog}).reason=="loop_source_sync_not_supported","Loop sync requires explicit interval semantics")
    for path in ["interaction-media","jump","oa-jump-lethal","oa-jump-late-lethal"]:
        var index=Fixtures.read(path)
        check(index.ok,"Actual contact recording compiles: "+path)
        if not index.ok:continue
        var rows=[];var landings=0;var steps=0
        for item in index.groups:
            for row in item.group.components:
                if row.kind!="audio" or not row.has("source_frame"):continue
                rows.append({"cue":row.cue_id,"frame":row.source_frame,"start_ms":item.start_ms+row.start_ms,"contact_ms":item.start_ms+row.contact_ms,"body_track_id":row.body_track_id})
                check(row.status=="available" and row.timing_source.begins_with("audio/contacts.json:"),"Actual contact uses readable executable source authoring")
                check(is_equal_approx(row.contact_ms-row.start_ms,row.source_sync_s*1000),"Actual sound transient shares native contact clock")
                if row.cue_id=="landing":
                    landings+=1
                    check(row.source_frame==15 and row.source_track.motion_fraction_to==1,"Only completed world arc owns landing")
                    var before=Tracks.samples([row.source_track],row.contact_ms-.001)
                    check(not before.is_empty() and absf(before.values()[0].lift_pixels)<.01,"Native spatial path reaches ground at authored landing boundary")
                if row.cue_id=="footstep":
                    steps+=1
                    var pose=Tracks.samples([row.source_track],row.contact_ms-.000001)
                    check(not pose.is_empty() and absf(fposmod(pose.values()[0].source_seconds*12,15)-row.source_frame)<.001,"Recorded footstep matches actually sampled source pose")
        if path=="interaction-media":check(steps==3,"Real diagonal Move has three source-stride contacts")
        if path=="jump":check(landings==1,"Full Jump has exactly one touchdown sound")
        if path=="oa-jump-lethal":check(landings==0,"Early interrupted Jump has no invented touchdown sound")
        if path=="oa-jump-late-lethal":check(landings==1,"Late reaction retains its actual completed world touchdown")
        evidence.append({"recording":path,"rows":rows})
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Source clock inversion, authored contact/sound transient alignment and actual replay compilation; native rendered/PCM qualification is separate."}
    FileAccess.open("res://generated/audio_contact_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("AUDIO_CONTACT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
