extends "res://assets/vfx/sources/84acbc5d392c75dc0e5f/bound_surface.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Caster-owned warm blessing. Compact open sun-stroke inscriptions sit on the
## current real weapon; an explicitly applied hit component owns contact rays.
var contact_rays: Array[MeshInstance3D] = []
var contact_material: ShaderMaterial
var hit_input: Dictionary = {}
var admitted_hit := false

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_9e80f76781.resource("res://assets/vfx/sources/9e80f76781257e6a4d5d/divine_favor.gd").new()
	component.configure(input, _motif(), "\nALPHA=(0.28+0.72*clamp(ALPHA,0.0,1.0))*favor_inscription(UV2)*weapon_envelope*0.58;\n")
	component.contact_material = NativeMaterial.make(input.material, "", "\nALPHA=clamp(ALPHA,0.0,1.0)*sin(UV.x*3.14159265)*pow(sin(UV.y*3.14159265),0.6)*weapon_envelope*0.76;\n")
	for index in 3:
		component.contact_rays.append(component.make_mesh("AppliedRadiantContactStroke" + str(index), component.contact_material))
	if input.has("hit"):
		component.set_hit_input(input.hit)
	return component

func set_hit_input(value: Dictionary) -> void:
	hit_input = value.duplicate(true)
	admitted_hit = ownership.admits_hit(hit_input)
	if not admitted_hit:
		for ray in contact_rays:
			ray.hide()

func set_weapon_binding(value: Dictionary) -> bool:
	var accepted := super.set_weapon_binding(value)
	# A delayed contact from the former item or holder cannot light a new one.
	hit_input.clear()
	admitted_hit = false
	return accepted

func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = phase_envelope(seconds) if ownership.visible() else 0.0
	var hit_phase := str(settings.phase) == "hit"
	if hit_phase:
		admitted_hit = ownership.admits_hit(hit_input)
		if not admitted_hit:
			envelope = 0.0
	for material in [imprint_material, contact_material]:
		material.set_shader_parameter("weapon_clock", seconds)
		material.set_shader_parameter("weapon_envelope", envelope)
		material.set_shader_parameter("weapon_application", 1.0 if str(settings.phase) == "application" else 0.0)
	_rebuild()
	for ray in contact_rays:
		ray.hide()
	if not hit_phase or not admitted_hit or envelope <= .0001 or endpoints.size() < 2:
		return
	# Contact is an explicit target/socket input, not a fabricated extra attack.
	var contact: Vector3 = endpoints[1].point
	var start: Vector3 = measurement.get("tip", _hand())
	var direction := (contact-start).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var side := direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var up := side.cross(direction).normalized()
	var progress := clampf(seconds / float(settings.seconds),0.0,1.0)
	# Three short connected arcs open out of the actual hit, then recede. They do
	# not fill the target silhouette or send a fresh projectile from the caster.
	for index in 3:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		var angle := (float(index)-1.0)*.72
		var ray_direction := (up*cos(angle)+side*sin(angle)).normalized()
		for vertex_index in 13:
			var along := float(vertex_index)/12.0
			var radius := (.10+.23*progress)*along
			points.append(contact + ray_direction*radius - direction*(.015+.06*sin(along*PI)))
			widths.append(.018*sin(along*PI)*(.8+.2*float(index==1)))
		contact_rays[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(contact_rays[index],points,widths)
		contact_rays[index].show()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result["divine_favor_hit"] = {"admitted":admitted_hit, "input":hit_input.duplicate(true),
		"visible_contact_strokes":contact_rays.filter(func(ray: MeshInstance3D) -> bool: return ray.visible).size(),
		"extra_attacks":0, "critical_rules_owned_by_backend":true}
	return result

static func _motif() -> String:
	return """
float favor_line(vec2 p,vec2 a,vec2 b,float width) {
 vec2 delta=b-a;
 float t=clamp(dot(p-a,delta)/dot(delta,delta),0.0,1.0);
 return 1.0-smoothstep(width*.35,width,length(p-a-delta*t));
}
float favor_inscription(vec2 p) {
 // Two separated open sun-strokes, rather than a full edge film. Stable in
 // the item's measured long-axis coordinates during the real attack pose.
 float root=favor_line(p,vec2(.5,.12),vec2(.5,.38),.075);
 root=max(root,favor_line(p,vec2(.18,.22),vec2(.5,.31),.065));
 root=max(root,favor_line(p,vec2(.82,.22),vec2(.5,.31),.065));
 float tip=favor_line(p,vec2(.5,.69),vec2(.5,.86),.065);
 tip=max(tip,favor_line(p,vec2(.28,.76),vec2(.5,.69),.055));
 tip=max(tip,favor_line(p,vec2(.72,.76),vec2(.5,.69),.055));
 float breathe=.73+.08*sin(weapon_clock*1.4);
 float apply=exp(-pow((p.y-clamp(weapon_clock/.62,0.0,1.0))/.12,2.0));
 return clamp(max(root,tip)*breathe+apply*weapon_application*.32,0.0,.9);
}
"""

const VfxPackageIO_9e80f76781 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
