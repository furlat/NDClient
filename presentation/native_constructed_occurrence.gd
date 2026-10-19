extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"
## The delivered occurrence's normal public sampler/setters/clock/teardown,
## with actual construction operands supplied before Source.make samples zero.
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
