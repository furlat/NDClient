extends SceneTree
## Recorded SDK journals -> inspectable graphical methods and recipients.
## This is a semantic Studio contract, not a GPU rendering qualification.
const Recording=preload("res://studio/recording.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_MATERIAL_METHOD_FAIL ",label)

func recorded_name(index:Dictionary,actor_id:String,at_ms:float)->String:
    var name:String=index.initialization.state.actors.get(actor_id,{}).get("name","")
    for item in index.groups:
        for commit in item.group.commits:
            if item.start_ms+commit.at_ms>at_ms:continue
            if commit.delta.get("actors",{}).has(actor_id):name=commit.delta.actors[actor_id].get("name","")
    return name

func run()->void:
    var cases={
        "dodge-seed3":["bodyOutline"],
        "hide-seed3-v3":["alphaMultiplier"],
        "poisoned-seed3-v2":["bodyColor"],
        "invisibility-seed3-v2":["bodyColor","alphaMultiplier"],
        "rage-seed3-v3":["bodyColor","bodyRamp"]
    }
    for case_name in cases:
        var index=Recording.read("res://.runtime/studio-cases/"+case_name+"/amber/journal")
        check(index.ok,case_name+" actual journal admits")
        if not index.ok:continue
        var methods=index.rows.filter(func(row):return row.kind=="condition_material")
        var by_id={};var observed={};var conditions={}
        for row in index.rows:by_id[row.id]=row
        for row in methods:conditions[row.owner.condition.behavior_id]=true
        var requirements:Array=[]
        for entry in Coverage.build(index.cache,[],conditions).entries:
            requirements.append_array(entry.requirements)
        var samples={}
        for row in methods:
            var label=case_name+" "+row.mechanism
            observed[row.mechanism]=true
            check(row.operations.size()==1 and row.operations.has(row.mechanism),label+" is individually inspectable")
            check(row.operations[row.mechanism]==row.component.recipe.persistent[row.mechanism],label+" retains exact resolved authored parameters")
            check(row.source_fields.size()==1 and row.source_fields.get(row.mechanism)==row.source,label+" has its exact authoring field")
            check(row.trace_track_id=="condition:"+row.owner.id+":"+row.mechanism,label+" links the existing runtime method witness")
            check(row.recipient_uuid==row.owner.actor_uuid and row.actor_uuid==row.recipient_uuid,label+" names the actual affected body")
            check(row.recipient_name==recorded_name(index,row.recipient_uuid,row.start_ms) and not row.recipient_name.is_empty(),label+" has the disclosed recipient name at that time")
            var parent:Dictionary=by_id[row.parent]
            check(parent.owner.id==row.owner.id and row.start_ms>=parent.start_ms and row.end_ms<=parent.end_ms,label+" retains its actual owner lifetime")
            check(row.source_start_ms==row.component.get("absolute_start_ms",row.component.start_ms),label+" keeps its owner source clock")
            var at:float=(row.start_ms+row.end_ms)*.5
            if not samples.has(at):samples[at]=Recording.restore(index,at).component_samples(index.cache)
            check(samples[at].any(func(sample):return sample.id==row.component.id),label+" references a production sampled component")
            check(row.render_method.surface==("outline" if row.mechanism=="bodyOutline" else "body"),label+" identifies the rendered surface")
            for field in ["renderer","shader"]:
                check(FileAccess.file_exists(row.render_method[field].get_slice("::",0)),label+" links an existing "+field+" implementation")
            check(row.preview_scope=="composed_actor" and row.diagnostic_scope=="condition_owner",label+" declares composed preview and owner-level mute scope")
            check(row.coverage.rendered=="not_witnessed",label+" does not claim GPU rendering from indexing")
            var requirement:Dictionary={}
            for candidate in requirements:
                if candidate.mechanism==row.mechanism and candidate.source==row.source:requirement=candidate;break
            check(not requirement.is_empty(),label+" shares the authoring requirement")
            if not requirement.is_empty():
                check((row.status=="missing")== (requirement.status=="missing"),label+" cannot hide a missing source or implementation")
                check(row.coverage.implementation==requirement.implementation and row.coverage.source==requirement.availability,label+" preserves independent implementation/source readiness")
                check(not index.rows.any(func(other):return other.kind=="requirement" and other.parent==row.parent and other.get("required_kind")==row.mechanism and other.source==row.source),label+" is not duplicated by a generic missing placeholder")
        for mechanism in cases[case_name]:check(observed.has(mechanism),case_name+" exercises "+mechanism)
        for row in index.rows:
            var actor_id:String=row.get("track",row.get("component",{})).get("actor_uuid",row.get("actor_uuid",row.get("owner",{}).get("actor_uuid","")))
            if actor_id.is_empty():continue
            var name=recorded_name(index,actor_id,row.start_ms)
            if not name.is_empty():check(row.get("actor_name","")==name,case_name+" "+row.kind+" names its actual actor")
            if row.get("component",{}).get("target_uuid")!=null:
                check(row.get("target_name","")==recorded_name(index,row.component.target_uuid,row.start_ms),case_name+" component target is separate from its source actor")
        evidence.append({"case":case_name,"methods":observed.keys(),"method_intervals":methods.size(),"recipients":methods.map(func(row):return row.recipient_name)})
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual recorded condition/body/component rows, per-method identity, owner intervals, parameters, shader/source links, shared availability and disclosed participant names. No native framebuffer claim."}
    FileAccess.open("res://generated/studio_material_method_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_MATERIAL_METHOD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
