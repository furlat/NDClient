extends SceneTree
## Headless regression for the current rolling/recorded frame-profile contract.
## Renderer counters in a dummy viewport are availability metadata, not GPU proof.
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]
var paths:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("FRAME_PROFILE_FAIL ",label)

func read_dump(data:Dictionary,label:String,use_recording:bool=true)->Dictionary:
    var path:String=Profile.save(data,root,"frame-profile-unit-"+str(Time.get_ticks_usec())+"-"+label,use_recording)
    paths.append(path)
    check(FileAccess.file_exists(path),label+" dump is written by the production serializer")
    if not FileAccess.file_exists(path):return {}
    var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    check(value!=null,label+" dump is valid JSON")
    return value if value!=null else {}

func run()->void:
    var data:Dictionary=Profile.create()
    check(data.frames.is_empty() and data.recorded.is_empty() and data.recorded_total==0,"Fresh profile has no invented frame samples")
    Profile.frame(data,root,{"cut":"prime"})
    check(data.frames.is_empty() and data.last_usec>0,"First real callback primes the interval without inventing an elapsed frame")
    data.recording=true
    for i in 6:
        await process_frame
        Profile.end_phase(data,"unit_phase",Time.get_ticks_usec())
        Profile.frame(data,root,{"cut":"recording","index":i})
        check(data.phases.is_empty(),"Each sampled callback consumes its own phase accumulators")
    check(data.frames.size()==6 and data.recorded.size()==6 and data.recorded_total==6,"Recording and rolling history receive the same six actual callbacks")
    var recorded_end:int=int(data.recorded.back().frame)
    var frozen_recording:PackedByteArray=var_to_bytes(data.recorded)
    data.recording=false
    for i in 4:
        await process_frame
        Profile.frame(data,root,{"cut":"after_stop","index":i})
    check(var_to_bytes(data.recorded)==frozen_recording and data.recorded_total==6,"Stopped recording remains immutable while rolling sampling continues")
    check(data.frames.size()==10 and data.frames.back().frame>recorded_end,"Rolling history holds later callbacks after the recording stopped")
    var frozen_frames:PackedByteArray=var_to_bytes(data.frames)
    var recorded:Dictionary=read_dump(data,"recorded")
    var recent:Dictionary=read_dump(data,"recent",false)
    if not recorded.is_empty() and not recent.is_empty():
        check(recorded.schema_version==1 and recent.schema_version==1,"Both dumps retain the current versioned profile format")
        check(recorded.sample_count==6 and recorded.frames.size()==6 and recorded.frames.back().frame==recorded_end,"Default dump preserves the exact stopped recording endpoint")
        check(recent.sample_count==10 and recent.frames.size()==10 and recent.frames.back().frame>recorded_end,"Explicit recent dump includes frames after stopped recording instead of reusing the old recording")
        check(recent.frames.map(func(frame):return int(frame.frame))==data.frames.map(func(frame):return int(frame.frame)),"Recent dump contains the actual rolling frame identities in chronological order")
        check(recent.frames.back().view.cut=="after_stop" and recorded.frames.back().view.cut=="recording","Saved context belongs to each actual sampled interval endpoint")
        check(recorded.recording_total==6 and recent.recording_total==6 and recent.recording_evicted==0,"Dump metadata describes the independent recording without counting later rolling frames as recorded")
        check(recent.summary.cpu_ms.has("unit_phase") and recent.timing_notes.contains("inclusive"),"Inclusive CPU phase semantics remain explicit in the current serialized profile")
        recent.frames.clear()
    check(var_to_bytes(data.frames)==frozen_frames and var_to_bytes(data.recorded)==frozen_recording,"Serialization and decoded diagnostic edits cannot mutate the source histories")
    var rolling_only:Dictionary=Profile.create()
    rolling_only.frames=data.frames.duplicate(true)
    var fallback:Dictionary=read_dump(rolling_only,"no-recording")
    if not fallback.is_empty():
        check(fallback.frames.size()==10 and fallback.frames.back().frame>recorded_end,"With no recording the default dump uses the available rolling history")
    var report:Dictionary={"checks":checks,"failures":failures,"paths":paths,"scope":"Actual headless process callbacks and production FrameProfile serialization; no native GPU or gameplay performance claim."}
    FileAccess.open("res://generated/frame_profile_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FRAME_PROFILE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
