extends "res://assets/vfx/sources/397ef2a8907055317449/smite_common.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Radiant impact stamps an open brand into the measured receiving surface.
## The separate disclosed reveal condition retains that mark; no local reveal
## of hidden actors, light creation or guessed concentration deadline occurs.
var brand: MeshInstance3D
var seal_strokes: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_36d8596898.resource("res://assets/vfx/sources/36d8596898bdb446e1e9/branding_smite.gd").new()
	component.configure(input)
	var material := SmiteMaterial.make(input.material,_brand_mask(),"\nALPHA=(.35+.65*clamp(ALPHA,0.0,1.0))*branding_mark(UV2)*smite_envelope*.60;\n")
	var stroke_material := SmiteMaterial.make(input.material,"","\nALPHA=clamp(ALPHA,0.0,1.0)*smite_envelope*.65;\n")
	component.brand = component.make_mesh("MeasuredRevealedBrand",material)
	for index in 2:
		component.seal_strokes.append(component.make_mesh("OpeningBrandStroke"+str(index),stroke_material))
	return component

func sample(seconds: float) -> void:
	_hide_all()
	var phase := str(settings.phase)
	var value := phase_envelope(seconds) if (payload_admitted() if phase == "impact" else condition_admitted()) else 0.0
	if phase == "condition":
		value *= .52
	_sample_materials(seconds,value)
	if value <= .0001:
		return
	var hit := contact()
	var patch := recipient_patch()
	if hit.is_empty() or patch.points.is_empty():
		return
	var measured := MeasuredSurface.build(patch,"recipient_patch",hit.position,.010)
	if measured.cells > 0:
		brand.global_transform = Transform3D(Basis.IDENTITY,patch.origin)
		brand.mesh = measured.mesh
		brand.show()
	if phase != "impact":
		return
	var normal: Vector3 = hit.normal
	var axes := plane_axes(normal)
	var progress := clampf(seconds/float(settings.seconds),0.0,1.0)
	# Two broad oblique strokes fold inward and press onto the actual hit plane.
	# This is a body-clipped stamp, distinct from Divine's outward impact rays.
	for index in 2:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		var direction: Vector3 = (axes[0]*(1.0 if index == 0 else -1.0)+axes[1]*.6).normalized()
		for vertex in 17:
			var along := float(vertex)/16.0
			var distance := (along-.5)*(.44-.10*progress)
			points.append(hit.position+direction*distance+normal*(.02+.12*(1.0-progress)*sin(along*PI)))
			widths.append(.034*sin(along*PI))
		seal_strokes[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(seal_strokes[index],points,widths)
		seal_strokes[index].show()

static func _brand_mask() -> String:
	return """
float branding_segment(vec2 p,vec2 a,vec2 b) {
 vec2 d=b-a;
 float t=clamp(dot(p-a,d)/dot(d,d),0.0,1.0);
 return 1.0-smoothstep(.025,.065,length(p-a-d*t));
}
float branding_mark(vec2 p) {
 // Open interlocking strokes leave the original receiving body readable.
 float mark=branding_segment(p,vec2(.24,.26),vec2(.69,.63));
 mark=max(mark,branding_segment(p,vec2(.76,.26),vec2(.31,.63)));
 mark=max(mark,branding_segment(p,vec2(.32,.73),vec2(.68,.73)));
 return mark*(.86+.08*sin(smite_clock*1.1));
}
"""

const VfxPackageIO_36d8596898 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
