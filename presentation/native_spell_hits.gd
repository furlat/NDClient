extends RefCounted
## Prepares native materials for existing applied-damage flashes. No event,
## recipient selection, envelope, or independent presentation clock lives here.
const Effects=preload("res://presentation/effect_package.gd")
const Surface=preload("res://presentation/native_material_surface.gd")
const Native=preload("res://presentation/native_effects.gd")
var records:Dictionary={}
var admitted:Dictionary={}
var active:Dictionary={}
var ready=true
var issues:Array=[]
var pending_occurrences:Array=[]
const MAX_TEMPLATES=64
# Age-zero materials are immutable sources. Each occurrence still owns its
# Surface, shader parameters and clock; no rendered texture is shared.
var material_templates:Dictionary={}
# Closed hit surfaces of this owner, reused by the next hit instead of a new viewport.
var spare_surfaces:Array=[]

static func _key(component:Dictionary)->String:
    return str(component.id)+"\u001f"+str(component.actor_uuid)

static func _issue(component:Dictionary,status:String,reason:String)->Dictionary:
    return {"id":component.id,"actor_uuid":component.actor_uuid,
        "spell_id":component.native_hit.get("spell_id",""),"status":status,"reason":reason}

func prepare(world:Node,components:Array,cache:Dictionary,prefetch:Array=[],budget:Dictionary={},allow_optional:bool=true)->Dictionary:
    var admission_started:int=Time.get_ticks_usec();var charged_before:int=budget.get("used_usec",0)
    admitted.clear()
    var candidates:Array=[];var optional:Array=[];var clips:Array=[];var required:Dictionary={}
    for pair in [[components,candidates],[prefetch,optional]]:
        for component in pair[0]:
            if component.get("kind")!="material_flash" or component.get("native_hit",{}).is_empty():continue
            admitted[_key(component)]=true;pair[1].append(component)
    for component in candidates:
        required[_key(component)]=true
        var hit:Dictionary=component.native_hit
        if not records.has(_key(component)) and hit.get("definition",{}).get("status")=="available" and hit.has("clip"):clips.append(hit.clip)
    _retire()
    var started:int=Time.get_ticks_usec()
    var loading:Dictionary
    if not clips.is_empty() and not budget.is_empty() and budget.used_usec>=budget.limit_usec:
        Effects.Admission.can_mutate() # Poll existing work without admitting a new source.
        loading={"ready":false,"pending":clips.size(),"errors":[]}
    else:loading=Effects.prepare_hits(clips,cache)
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    issues=[]
    for error in loading.errors:issues.append({"status":"missing","reason":error})
    var pending:int=0
    for component in candidates:
        var key=_key(component)
        var definition:Dictionary=component.native_hit.get("definition",{})
        if not records.has(key):
            if definition.get("status")!="available":records[key]={"issue":_issue(component,"unsupported",definition.get("reason","Native hit material is not assigned"))}
            elif not component.native_hit.has("clip"):records[key]={"issue":_issue(component,"missing","Selected native hit clip is unavailable")}
            elif loading.ready and (budget.is_empty() or budget.used_usec<budget.limit_usec):
                started=Time.get_ticks_usec();records[key]=_make(world,component)
                if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
        if not records.has(key):pending+=1;continue
        var record:Dictionary=records[key]
        if record.has("issue"):issues.append(record.issue)
        elif not record.surface.ready:pending+=1
    ready=pending==0 and not issues.any(func(issue):return issue.status=="missing")
    if allow_optional and ready:
        for component in optional:
            var key=_key(component)
            if records.has(key) or required.has(key):continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:break
            var hit:Dictionary=component.native_hit
            if hit.get("definition",{}).get("status")!="available" or not hit.has("clip"):continue
            started=Time.get_ticks_usec();var source=Effects.prepare_hits([hit.clip],cache)
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
            if not source.ready:continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:break
            started=Time.get_ticks_usec();records[key]=_make(world,component)
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    return {"ready":ready,"pending":pending,"issues":issues}

func _make(world:Node,component:Dictionary)->Dictionary:
    var hit:Dictionary=component.native_hit
    var definition:Dictionary=hit.definition
    var key:Array=[hit.clip,definition]
    var template:Dictionary=material_templates.get(key,{})
    if template.is_empty():
        template=_material_template(world,hit)
        if template.has("error"):return {"issue":_issue(component,"missing",template.error)}
        if material_templates.size()>=MAX_TEMPLATES:material_templates.erase(material_templates.keys()[0])
        material_templates[key.duplicate(true)]=template
    var surface=Surface.make(world,template.material,true,spare_surfaces)
    var finishing:Dictionary=hit.get("finish_profile",{})
    var ramp:Texture2D
    if not finishing.get("ramp",[]).is_empty():ramp=Native._palette_texture(finishing.ramp)
    Surface.sample(surface,0.0,template.clock)
    return {"surface":surface,"clock":template.clock,"finishing":finishing,"ramp":ramp}

func _material_template(world:Node,hit:Dictionary)->Dictionary:
    var definition:Dictionary=hit.definition
    var extracted:Dictionary=Effects.hit_material(world,hit.clip,str(definition.get("node","")),int(definition.get("surface",-1)))
    if extracted.has("error"):return {"error":extracted.error}
    var material:Material=extracted.material
    for parameter in definition.get("parameter_overrides",{}):
        if not material is ShaderMaterial:
            return {"error":"Native hit parameter override requires its selected shader material"}
        material.set_shader_parameter(parameter,definition.parameter_overrides[parameter])
    var clock:String=definition.get("clock_parameter","")
    if not clock.is_empty() and (not material is ShaderMaterial or material.shader==null or not material.shader.get_shader_uniform_list().any(func(uniform):return str(uniform.name)==clock)):
        return {"error":"Selected native hit clock is unavailable: "+clock}
    return {"material":material,"clock":clock}

func decorate(_world:Node,samples:Array,full_material:bool=true,spell_colours:bool=true)->Dictionary:
    active.clear();issues=[];pending_occurrences=[];var pending=0
    for sample in samples:
        if sample.get("kind")!="material_flash":continue
        # Repeated mode changes on the same sampled array must clear the old
        # native texture too; underlying colour/condition fields remain intact.
        for field in ["native_surface","native_ramp","native_finishing"]:sample.erase(field)
        if sample.get("native_hit",{}).is_empty():continue
        var key=_key(sample);active[key]=true
        if not full_material:continue
        if not records.has(key):
            # A newly installed replay can expose its real retained component
            # before the host has completed that epoch's private preparation.
            # Only prepare diagnoses unavailable inputs; this is a readiness wait.
            pending_occurrences.append(_issue(sample,"pending","Native hit occurrence awaits preparation"));pending+=1;continue
        var record:Dictionary=records[key]
        if record.has("issue"):issues.append(record.issue);continue
        if not record.surface.ready:
            pending_occurrences.append(_issue(sample,"pending","Native hit material awaits its first draw"));pending+=1;continue
        Surface.sample(record.surface,float(sample.age_ms)/1000.0,record.clock)
        sample.native_surface=record.surface.viewport.get_texture()
        if spell_colours and record.ramp!=null:
            sample.native_ramp=record.ramp;sample.native_finishing=record.finishing
    _retire()
    ready=pending==0 and not issues.any(func(issue):return issue.status=="missing")
    return {"ready":ready,"pending":pending,"issues":issues,"pending_occurrences":pending_occurrences}

## A capture duplicates this exact source surface and sets its private clock.
## It never samples/rewinds this owner's current viewport or reads it to CPU.
func history_material(sample:Dictionary)->Dictionary:
    var record:Dictionary=records.get(_key(sample),{})
    if record.is_empty():return {"ready":false,"reason":"history_native_hit_source_not_prepared"}
    if record.has("issue"):return {"ready":false,"reason":record.issue.reason}
    var surface:Dictionary=record.surface
    if surface.closed:return {"ready":false,"reason":"history_native_hit_source_retired"}
    var texture:Texture2D=surface.viewport.get_texture()
    var identity:Dictionary={"component_id":sample.id,"actor_uuid":sample.actor_uuid,
        "source_event_uuid":sample.get("source_event_uuid",""),"spell_id":sample.native_hit.get("spell_id",""),
        "clip_id":sample.native_hit.clip.id}
    return {"ready":true,"surface":texture,"ramp":record.ramp,"finishing":record.finishing,
        "dependency":{"texture":texture,"surface":surface,"clock_parameter":record.clock,
            "seconds":float(sample.age_ms)/1000.0,"identity":identity}}

func _retire()->void:
    for key in records.keys():
        if admitted.has(key) or active.has(key):continue
        if records[key].has("surface"):Surface.close(records[key].surface,spare_surfaces)
        records.erase(key)

func close()->void:
    for record in records.values():
        if record.has("surface"):Surface.close(record.surface)
    for parked in spare_surfaces:
        if is_instance_valid(parked.viewport):parked.viewport.queue_free()
    spare_surfaces.clear()
    records.clear();admitted.clear();active.clear();material_templates.clear();issues=[];pending_occurrences=[];ready=true
