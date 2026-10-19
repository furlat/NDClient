extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Blood=preload("res://presentation/blood.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("BLOOD_RESIDUE_FAIL ",label)
func compile_recording(path:String,sequence:int)->Dictionary:
    var journal=Journal.new();var opened=journal.open(path,true,false)
    check(opened.ok,"Real recording opens "+path)
    if not opened.ok:return {}
    var replay=journal.replay(sequence-1);check(replay.ok,"Exact before prefix admits: "+str(replay.get("error","")))
    if not replay.ok:return {}
    var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path.path_join("%016d.json"%sequence)))
    check(decoded.ok,"Real raw operation admits")
    if not decoded.ok:return {}
    var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
    var old=journal.state.duplicate(true);var original=packet.duplicate(true)
    var cache={};var result=Compiler.compile(journal.state,packet,cache)
    check(result.ok,"Shared compiler accepts real operation")
    check(old==journal.state and original==packet,"Compile retains caller state and packet")
    if not result.ok:return {}
    return {"result":result.value,"cache":cache}
func run()->void:
    var injuries:Array=Fixtures.fact_rows("dash","damage").filter(func(row):return row.fact.get("body_release")!=null)
    check(injuries.size()==1,"Actual Dash reaction has one admitted injury result")
    if injuries.is_empty():quit(1);return
    var compiled=compile_recording(Fixtures.journal("dash"),injuries[0].sequence)
    if compiled.is_empty():quit(1);return
    var rows:Array=[]
    for group in compiled.result.groups:
        for component in group.components:
            if component.kind=="residue_deposit":rows.append(component)
        for event in group.events:
            if event.kind=="damage":check(not event.components.any(func(c):return c.kind=="residue_deposit" and c.status=="missing"),"Implemented actual residue has no false missing renderer requirement")
    check(rows.size()==1,"Actual Dash opportunity hit owns one ground-capable release")
    if rows.is_empty():quit(1);return
    var component:Dictionary=rows[0];var source=Blood.asset(compiled.cache)
    check(component.body_release.position==[4,6],"Actual impact position comes from admitted release")
    check(component.reveals.size()==20,"Exactly twenty disclosed residue tile increments retained")
    check(component.duration_ms>0 and component.duration_ms<3000,"Finite authored particle lifetime resolved")
    var allowed={}
    for region in component.body_release.regions:
        for point in region.positions:allowed[Blood.key(point)]=true
    var counts=[]
    for age in [0.,.1,.3,.5,.8,1.2]:
        var particles=Blood.particles(component,source,age)
        counts.append(particles.size())
        check(particles==Blood.particles(component,source,age),"Absolute-age particles repeat exactly at "+str(age))
        for particle in particles:check(allowed.has(Blood.key([floori(particle.goal.x+.5),floori(particle.goal.y+.5)])),"Particle lands only in an explicit receiving cell")
    check(counts.max()>20,"Actual authored spray produces a nonempty trajectory")
    var total_kernels=0
    for reveal in component.reveals:
        check(allowed.has(Blood.key(reveal.position)),"No residue position fabricated")
        check(reveal.before.is_empty() and reveal.after.amount==1,"Actual prior empty/after amount retained")
        var active=reveal.duplicate();active.pattern=component.body_release.pattern;active.age_seconds=-.01
        check(Blood.kernels(reveal.after,reveal.position,[active],source).is_empty(),"Future deposit suppressed before source release "+Blood.key(reveal.position))
        active.age_seconds=component.duration_ms/1000.+.01
        var final=Blood.kernels(reveal.after,reveal.position,[],source)
        total_kernels+=final.size()
        check(Blood.kernels(reveal.after,reveal.position,[active],source)==final,"Completed reveal equals actual settled contribution "+Blood.key(reveal.position))
        active.age_seconds=.3;var first=Blood.kernels(reveal.after,reveal.position,[active],source)
        active.age_seconds=.8;Blood.kernels(reveal.after,reveal.position,[active],source)
        active.age_seconds=.3
        check(Blood.kernels(reveal.after,reveal.position,[active],source)==first,"Reverse age recreates exact liquid field inputs")
    var example:Dictionary=component.reveals[0]
    var twice=example.after.duplicate(true);twice.amount=2;twice.contributions[0].amount=2
    var addition={"before":example.after,"after":twice,"pattern":component.body_release.pattern,"age_seconds":-.1}
    check(Blood.kernels(twice,example.position,[addition],source)==Blood.kernels(example.after,example.position,[],source),"Second landing retains previous stain exactly before new droplets arrive")
    addition.age_seconds=10.
    check(Blood.kernels(twice,example.position,[addition],source)==Blood.kernels(twice,example.position,[],source),"Second landing resolves to authoritative accumulated amount")
    var airborne:Array=Fixtures.fact_rows("oa-jump-late-lethal","damage").filter(func(row):return row.fact.get("body_release")!=null and row.fact.body_release.regions.is_empty())
    check(not airborne.is_empty(),"Actual late lethal airborne injury has no receiving ground region")
    if airborne.is_empty():quit(1);return
    var air=compile_recording(Fixtures.journal("oa-jump-late-lethal"),airborne[0].sequence)
    if not air.is_empty():
        var effects:Array=[]
        for group in air.result.groups:
            for item in group.components:
                if item.get("body_release",{}).get("release_id")=="body.blood":effects.append(item)
        check(not effects.is_empty(),"Actual late lethal airborne injury retains blood source")
        check(effects.all(func(item):return item.kind=="native_effect" and item.body_release.regions.is_empty() and not item.residue_deposition),"Actual airborne lethal injury never fabricates a floor deposit")
    evidence.append({"recording":Fixtures.journal("dash"),"sequence":injuries[0].sequence,"event":component.source_event_uuid,"tiles":component.reveals.size(),"kernel_instances":total_kernels,"particle_counts":counts,"duration_ms":component.duration_ms})
    FileAccess.open("res://generated/blood_residue_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real recorded ground and airborne injury, exact authority/clock/reverse/retained-field inputs; native framebuffer qualification separate."},"  "))
    print("BLOOD_RESIDUE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
