extends RefCounted
## Source producers own uniforms; receiving materials consume explicit values.
## Changes are retained until all atlas targets acknowledge the same sample.
static var declared_parameters:Dictionary={}

static func initialize(entry:Dictionary)->void:
    entry.erase("bound_condition_parameters")
    var shader:Shader=entry.material.shader
    if not declared_parameters.has(shader):
        var names:Dictionary={}
        for row in shader.get_shader_uniform_list():names[StringName(row.name)]=null
        declared_parameters[shader]=names
    var parameters:Dictionary=declared_parameters[shader].duplicate()
    entry.source_parameters=parameters
    entry.source_changes={}
    entry.source_version=int(entry.get("source_version",0))+1
    entry.source_change_base=entry.source_version
    entry.source_binding_revision=int(entry.get("source_binding_revision",0))+1

static func structural_change(entry:Dictionary)->void:
    entry.source_binding_revision=int(entry.get("source_binding_revision",0))+1
    entry.source_version=int(entry.get("source_version",0))+1

static func set_parameter(entry:Dictionary,name:StringName,value:Variant,structural:bool=false)->void:
    if not entry.has("source_parameters"):initialize(entry)
    if entry.source_parameters.has(name) and entry.source_parameters[name]==value:return
    entry.source_parameters[name]=value
    entry.source_changes[name]=value
    if structural:structural_change(entry)
    else:entry.source_version+=1
    entry.material.set_shader_parameter(name,value)

static func apply(entry:Dictionary,values:Dictionary,structural:bool=false)->void:
    for name in values:set_parameter(entry,name,values[name],structural)

static func value(entry:Dictionary,name:StringName)->Variant:
    assert(entry.has("source_parameters"),"Source material has no producer-owned operands")
    return entry.source_parameters.get(name)

static func changes_since(entry:Dictionary,version:int)->Variant:
    assert(entry.has("source_parameters"),"Source material has no producer-owned operands")
    if version==entry.source_version:return {}
    return entry.source_changes if version==entry.source_change_base else null

static func acknowledge(entry:Dictionary)->void:
    entry.source_changes.clear()
    entry.source_change_base=entry.source_version
