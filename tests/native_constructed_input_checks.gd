extends SceneTree
## Pure input/sampling boundary. Native output is a separate original-recording gate.
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
class ClockProbe extends RefCounted:
    var calls:Array=[]
    func sample(seconds:float)->void:calls.append(seconds)
class ComponentProbe extends Node3D:
    var material:ShaderMaterial
    var envelope:float=.8
    var calls:Array=[]
    var seen_envelopes:Array=[]
    var packet:Dictionary={}
    var pair:Array=[]
    func set_entity_geometry(value:Dictionary)->void:
        packet=value;envelope=float(value.envelope);hide()
    func set_pair(value:String,count:int)->void:pair=[value,count];hide()
    func sample(seconds:float)->void:
        calls.append(seconds);seen_envelopes.append(material.get_shader_parameter("opacity"))
        material.set_shader_parameter("opacity",envelope);show()
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONSTRUCTED_INPUT_FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var source:=Node3D.new();root.add_child(source)
    var material:=ShaderMaterial.new();var shader:=Shader.new()
    shader.code="shader_type spatial; uniform float opacity=1.0; void fragment(){ ALPHA=opacity; }"
    material.shader=shader;material.set_shader_parameter("opacity",.2)
    var component:=ComponentProbe.new();component.material=material;source.add_child(component)
    var emitter:=GPUParticles3D.new();emitter.emitting=false;emitter.speed_scale=1.75;source.add_child(emitter)
    var player:=AnimationPlayer.new();source.add_child(player)
    var animation:=Animation.new();animation.length=1
    var library:=AnimationLibrary.new();library.add_animation("contact",animation)
    player.add_animation_library("",library);player.play("contact");player.seek(.3,true)
    var wrapper:Node3D=Constructed.new();var clock:=ClockProbe.new();wrapper.clock=clock
    wrapper.handle={"root":source,"initialized":true,"age":.25,"motion_age":.25,
        "clip":{"bindings":[{"kind":"sample","component":"body","rate":2.0,"offset_seconds":.1}]},
        "components":{"body":component},"opacity_bindings":[{"material":material,"uniform":"opacity","native":.8}],
        "motion_trails":{},"light_units":{},"static_material_topology":true,
        "players":[player],"emitters":[emitter]}
    wrapper.sampled_input_revision=0
    wrapper.sample(.25)
    check(component.calls.is_empty(),"Unchanged same-clock sampling retains the sealed sampler's no-rebuild path")
    check(emitter.speed_scale==1.75 and is_equal_approx(player.current_animation_position,.3),"An unchanged pause preserves the pending native emitter/player advance")
    var first:Dictionary={"envelope":.6,"geometry_key":["actual-updated-pose"]}
    wrapper.set_recipient_geometry(first)
    check(component.packet==first and not component.visible and wrapper.source_input_revision==1,"The existing geometry setter forwards the exact changed packet and invalidates sampling")
    var age:float=wrapper.handle.age;var motion_age:float=wrapper.handle.motion_age
    wrapper.sample(.25)
    check(component.visible and component.calls==[.6],"Changed geometry reflows at the same actual age using the declared source rate and offset")
    check(is_equal_approx(float(component.seen_envelopes[0]),.8),"Reflow restores the last source envelope before evaluating component equations")
    check(is_equal_approx(float(wrapper.handle.opacity_bindings[0].native),.6),"Reflow retains the new source envelope independently of display attenuation")
    check(wrapper.handle.age==age and wrapper.handle.motion_age==motion_age and wrapper.previous_age==.25,"Reflow neither changes native/motion ages nor invents elapsed time")
    check(emitter.speed_scale==1.75 and is_equal_approx(player.current_animation_position,.3),"Dirty same-clock reflow does not cancel or advance pending emitter/player work")
    check(clock.calls==[.25,.25] and wrapper.sampled_input_revision==wrapper.source_input_revision,"The existing occurrence clock publishes the same age and records the consumed input revision")
    material.set_shader_parameter("opacity",.15)
    wrapper.sample(.25)
    check(component.calls.size()==1 and is_equal_approx(float(material.get_shader_parameter("opacity")),.15),"Repeated unchanged sampling neither rebuilds geometry nor compounds/restores external attenuation")
    wrapper.set_recipient_geometry({"envelope":.4,"geometry_key":["next-pose"]});wrapper.sample(.25)
    check(component.calls.size()==2 and is_equal_approx(float(component.seen_envelopes[1]),.6),"A second changed pose starts from source opacity rather than the attenuated display value")
    check(is_equal_approx(float(wrapper.handle.opacity_bindings[0].native),.4),"Successive same-age source envelopes remain independently owned")
    wrapper.forward_arguments("set_pair",["cells",2]);wrapper.sample(.25)
    check(component.pair==["cells",2] and component.visible and component.calls.size()==3,"Multi-argument public setters participate in the same changed-input reflow")
    var revision:int=wrapper.source_input_revision
    wrapper.forward("set_missing",{});wrapper.sample(.25)
    check(wrapper.source_input_revision==revision and component.calls.size()==3,"An absent source receiver does not invalidate or manufacture an input")
    check(emitter.speed_scale==1.75 and is_equal_approx(player.current_animation_position,.3),"All same-clock reflows preserve the original pending native delta")
    wrapper.free();source.free()
    print("CONSTRUCTED_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,
        "scope":"Actual client wrapper and sealed paused-source boundary with explicit setter/material/emitter/player probes; framebuffer and performance qualification remain separate."}))
    quit(0 if failures.is_empty() else 1)
