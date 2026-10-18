extends "res://assets/vfx/sources/84acbc5d392c75dc0e5f/bound_surface.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Exact-item cool edge inscription. Native marble/Fresnel flow remains the
## material mechanism; measured contour and a travelling temper line own shape.
var application_thread: MeshInstance3D
var thread_material: ShaderMaterial

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_186eba16e1.resource("res://assets/vfx/sources/186eba16e1adfb8bd821/magic_weapon.gd").new()
	component.configure(input, _motif(), "\nALPHA=clamp(ALPHA,0.0,1.0)*magic_inscription(UV2,COLOR.r)*weapon_envelope*0.52;\n")
	component.thread_material = NativeMaterial.make(input.material, "", "\nALPHA=clamp(ALPHA,0.0,1.0)*sin(UV.x*3.14159265)*weapon_envelope*0.60;\n")
	component.application_thread = component.make_mesh("HandToExactItemTemperThread", component.thread_material)
	return component

func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = phase_envelope(seconds) if ownership.visible() else 0.0
	var application := 1.0 if str(settings.phase) == "application" else 0.0
	for material in [imprint_material, thread_material]:
		material.set_shader_parameter("weapon_clock", seconds)
		material.set_shader_parameter("weapon_envelope", envelope)
		material.set_shader_parameter("weapon_application", application)
	_rebuild()
	application_thread.hide()
	if envelope <= .0001 or measurement.get("cells",0) == 0 or not str(settings.phase) in ["windup", "application"]:
		return
	var hand := _hand()
	var destination: Vector3 = measurement.base.lerp(measurement.tip, clampf(seconds / float(settings.seconds),0.0,1.0))
	var length := hand.distance_to(destination)
	if length > 1.8:
		return
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	for index in 17:
		var progress := float(index)/16.0
		points.append(hand.lerp(destination, progress) + Vector3.UP * sin(progress*PI) * minf(.08,length*.1))
		widths.append(.008 * sin(progress*PI))
	application_thread.global_transform = Transform3D.IDENTITY
	GpuRibbon.assign(application_thread,points, widths)
	application_thread.show()

static func _motif() -> String:
	return """
float magic_inscription(vec2 p,float measured_edge) {
 // The item's connected boundary carries a restrained continuous temper line.
 // Two open chevrons travel on the real surface, never around a body cage.
 float edge=measured_edge*(.28+.12*sin(weapon_clock*1.35+p.y*5.0));
 float chevron=1.0-smoothstep(.035,.085,abs(abs(p.x-.5)*.40-abs(fract(p.y*2.0-weapon_clock*.08)-.5)*.42));
 float etched=chevron*(.18+.10*sin(p.y*6.2831853));
 float front=fract(weapon_clock*.24);
 float temper=exp(-pow((p.y-front)/.085,2.0));
 float application=exp(-pow((p.y-clamp(weapon_clock/.62,0.0,1.0))/.14,2.0));
 return clamp(edge+etched*.28+temper*.22+application*weapon_application*.65,0.0,.85);
}
"""

const VfxPackageIO_186eba16e1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
