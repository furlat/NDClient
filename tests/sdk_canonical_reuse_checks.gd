extends SceneTree
# Real Gallery operations compare complete retained state/event captures with
# the detached reducer, preserving every preceding committed/captured value.
const Reducer=preload("res://sdk/reducer.gd")
const Protocol=preload("res://sdk/protocol.gd")
var checks:int=0
var failures:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CANONICAL_REUSE_FAIL ",label)

func _poison(value:Variant)->void:
    if value is Dictionary:
        for child in value.values():_poison(child)
        value["canonical_reuse_mutation"]=true
    elif value is Array:
        for child in value:_poison(child)
        value.append("canonical_reuse_mutation")

func _initialize()->void:
    var recording:String="res://.runtime/player-runs/20261016T121313.010271Z/journal"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recording=arg.trim_prefix("--recording=")
    var protocol=Protocol.new()
    var state:Dictionary={};var context:Dictionary={}
    var held:Array=[];var frozen:Array=[];var measurements:Array=[]
    for sequence in range(7):
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(recording.path_join("%016d.json"%sequence))
        var root_name:String="InitializationResponse" if sequence==0 else "PlayerOperation"
        var decoded:Dictionary=protocol.decode(root_name,raw)
        check(decoded.ok,"Real sequence strictly admitted: "+str(sequence))
        if not decoded.ok:break
        var packet:Dictionary=protocol.normalize(root_name,decoded.value)
        if sequence==0:
            var initial:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,"Real initialization reduced")
            if not initial.ok:break
            state=initial.value
            continue
        var before:Dictionary=state.duplicate(true)
        var packet_before:Dictionary=packet.duplicate(true)
        var reference:Dictionary=Reducer._reduce_operation_recorded(state,packet)
        var profile:Dictionary={}
        var started:int=Time.get_ticks_usec()
        var retained:Dictionary=Reducer._reduce_operation_retained(state,packet,true,profile,context)
        measurements.append({"sequence":sequence,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"phases_ms":profile})
        check(reference.ok and retained.ok,"Both reduction boundaries accept real sequence: "+str(sequence))
        if not reference.ok or not retained.ok:break
        check(reference.value==retained.value,"Entire canonical state matches detached result: "+str(sequence))
        check(reference.transitions==retained.transitions,"Every ordered event input/delta matches detached result: "+str(sequence))
        check(state==before and packet==packet_before,"Reduction preserves its previous state and input packet: "+str(sequence))
        for index in held.size():check(held[index]==frozen[index],"Later real sequence preserves earlier state/captures: "+str(sequence)+"/"+str(index))
        state=retained.value;context=retained.sensory_context
        held.append(retained);frozen.append(retained.duplicate(true))
        _poison(packet)
        check(retained==frozen[-1],"Caller packet mutation cannot alter retained result: "+str(sequence))
        _poison(reference)
        check(retained==frozen[-1],"Detached public result mutation cannot alter retained result: "+str(sequence))
    var report:Dictionary={"checks":checks,"failures":failures,"recording":recording,"measurements":measurements,
        "scope":"Six actual Gallery operations; exact canonical/event-time parity and prior-state, input and public-result isolation. Isolated CPU timings only."}
    FileAccess.open("res://generated/sdk_canonical_reuse_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_CANONICAL_REUSE_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
