extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"
## The delivered occurrence's normal public sampler/setters/clock/teardown,
## with actual construction operands supplied before Source.make samples zero.
var source_input_revision:int=0
var sampled_input_revision:int=-1
static func make_component(input:Dictionary)->Node3D:
    var instance:Node3D=load("res://presentation/native_constructed_occurrence.gd").new()
    instance.parameters=input
    return instance

static func clip_with_inputs(phase:Resource,operands:Array)->Dictionary:
    # to_clip returns private component/input data. Never mutate a shared
    # Factory Resource, a live component's settings or the canonical records.
    var clip:Dictionary=phase.to_clip()
    for operand in operands:
        var components:Array=clip.components
        var input:Dictionary={}
        for id in operand.component_path:
            var selected:Dictionary=components.filter(func(component):return component.id==id)[0]
            input=selected.input
            components=input.get("components",[])
        var values:Dictionary=input if str(operand.get("input_field","" )).is_empty() else input[operand.input_field]
        values.merge(operand.values,true)
    return clip

func construction_clip()->Dictionary:
    return clip_with_inputs(parameters.phase,parameters.operands)

## The sealed sampler caches an age. Actual changed operands can invalidate
## its component geometry at that same age, without another native delta step.
func forward(method:String,value:Variant)->void:
    forward_arguments(method,[value])

## Some sealed spatial sources require cells plus their observed source clock.
## Reuse the occurrence's prepared receiver index; no traversal during sample.
func forward_arguments(method:String,arguments:Array)->void:
    if handle.is_empty() or not is_instance_valid(handle.get("root")):return
    if inputs_dirty:refresh_input_bindings()
    var forwarded:bool=false
    for node in input_receivers.get(method,[]):
        if is_instance_valid(node):node.callv(method,arguments);forwarded=true
    if forwarded:source_input_revision+=1

func sample(seconds:float)->void:
    if not construction_error.is_empty():return
    var same_clock:bool=handle.get("initialized",false) and is_equal_approx(seconds,float(handle.age))
    if same_clock and source_input_revision!=sampled_input_revision:
        # Restore the source-owned envelope before component sampling, then
        # retain its new value for the caller's ordinary attenuation. Never
        # advance/restart particles, players or native callbacks a second time.
        for binding in handle.opacity_bindings:binding.material.set_shader_parameter(binding.uniform,binding.native)
        for binding in handle.clip.bindings:
            if binding.kind=="sample":handle.components[binding.component].sample(seconds*float(binding.rate)+float(binding.offset_seconds))
        for binding in handle.opacity_bindings:binding.native=float(binding.material.get_shader_parameter(binding.uniform))
        _ensure_material_bindings()
        clock.sample(seconds)
        previous_age=seconds
    else:super.sample(seconds)
    sampled_input_revision=source_input_revision
