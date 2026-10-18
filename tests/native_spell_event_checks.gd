extends SceneTree
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);push_error(label)

func recording(path:String,sequence:int,spell:String,expected_deliveries:int,expected_hits:int)->void:
    var journal=Journal.new()
    var opened=journal.open(path,true,false)
    check(opened.ok,path+": recorded protocol admitted")
    if not opened.ok:return
    var replayed=journal.replay(sequence-1)
    check(replayed.ok,path+": actual preceding state reduced")
    if not replayed.ok:print(replayed);return
    var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path.path_join("%016d.json"%sequence)))
    check(decoded.ok,path+": recorded operation admitted")
    if not decoded.ok:print(decoded);return
    var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
    var cache:Dictionary={}
    var result=Compiler.compile(journal.state,packet,cache)
    check(result.ok,path+": production compiler accepts operation")
    if not result.ok:print(result);return
    var native:Array=[];var hits:Array=[]
    var events:Dictionary={}
    for lineage in packet.lineages:
        for event in lineage.events:events[event.uuid]=event
    var state=journal.state.duplicate(true)
    for group in result.value.groups:
        var last:=-1.0
        for commit in group.commits:
            check(commit.at_ms>=last,path+": ordered state commits")
            last=commit.at_ms;Compiler.apply_delta(state,commit.delta)
        for row in group.components:
            if row.get("native_spell",false) and row.spell_id==spell:
                native.append(row)
                check(events.has(row.source_event_uuid),"Native phase keeps its real source event")
                check(row.status=="available" and row.duration_ms>0,"Native phase has selected source and finite duration")
                check(row.native_cue.begin==0 and is_equal_approx(row.native_cue.end*1000.0,row.duration_ms),"Native phase uses the component presentation clock")
                check(not row.native_clip.get("approaches",[]).is_empty(),"Native phase names its VFX package clip and approaches")
            if row.kind=="material_flash" and row.has("native_hit"):
                hits.append(row)
                var fact:Dictionary=events[row.source_event_uuid].fact
                check(not events[row.source_event_uuid].canceled and fact.kind=="damage" and fact.stage=="applied" and fact.applied_damage>0,"Native receiver material comes only from positive applied damage")
                check(row.actor_uuid==fact.target_entity_uuid and row.duration_ms==150,"Shared150ms receiver flash follows actual recipient")
        var timeline=Timeline.new()
        timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":sequence-1})
        timeline.accept({"kind":"operation","groups":[group]})
        timeline.advance(group.duration_ms)
        var remaining=group.components.filter(func(row):return row.get("native_spell",false) and row.start_ms+row.duration_ms>group.duration_ms)
        if not remaining.is_empty():
            var sampled=timeline.component_samples(cache)
            for row in remaining:check(sampled.any(func(sample):return sample.id==row.id),"Native tail remains after the group's authoritative commits")
    check(state==result.value.final_state,path+": presentation commits equal SDK reduction")
    var flights=native.filter(func(row):return row.native_cue.role=="flight")
    check(flights.size()==expected_deliveries,path+": exactly the actual number of deliveries")
    check(hits.size()==expected_hits,path+": exactly the actual number of damaging receivers")
    check(native.filter(func(row):return row.native_cue.role=="cast").size()==1,path+": one preparation for the cast")
    for hit in hits:
        check(flights.any(func(flight):return flight.target_uuid==hit.actor_uuid and hit.start_ms>=flight.start_ms+flight.native_cue.contact*1000.0-.001),"Damage feedback follows projectile contact on that recipient")
    observations.append({"journal":path,"sequence":sequence,"spell":spell,"native_phases":native.size(),"deliveries":flights.size(),"damage_flashes":hits.size()})

func run()->void:
    recording("res://.runtime/compact-magic-missile-20261013/amber/journal",29,"fire_bolt",1,1)
    recording("res://.runtime/studio-cases/magic_missile-seed3/amber/journal",2,"magic_missile",3,0)
    recording("res://.runtime/gallery-route/journal",22,"magic_missile",3,3)
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/native-spell-event-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_EVENTS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
