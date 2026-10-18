extends "res://assets/vfx/sources/84acbc5d392c75dc0e5f/bound_surface.gd"
## Exact equipped-item ownership and measured geometry are shared. The split
## sun etch is authored here; no unrelated full Magic Weapon art is recoloured.
var item_light: OmniLight3D

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_a004796cd3.resource("res://assets/vfx/sources/a004796cd36e972d4c2e/sacred_weapon.gd").new()
	component.configure(input, """
float sacred_etch(vec2 p,float measured_edge){
 float longitudinal=1.0-smoothstep(.035,.12,abs(p.x-.5));
 float teeth=pow(max(0.0,cos(p.y*18.8495559)),12.0);
 float cut=1.0-smoothstep(.02,.09,abs(abs(p.x-.5)-.20));
 return clamp(measured_edge*.40+longitudinal*.72+cut*teeth*.55,0.0,.90);
}
""", "\nALPHA=(.74+.26*clamp(ALPHA,0.0,1.0))*sacred_etch(UV2,COLOR.r)*weapon_envelope*.92;\n")
	component.item_light = OmniLight3D.new()
	component.item_light.name = "SuppliedExactItemLight"
	component.item_light.omni_range = float(input.light.radius_cells)
	component.item_light.light_color = Color.html(str(input.light.colour))
	component.item_light.light_energy = .14
	component.item_light.hide()
	component.add_child(component.item_light)
	return component

func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = phase_envelope(seconds) if ownership.visible() else .0
	imprint_material.set_shader_parameter("weapon_clock", seconds)
	imprint_material.set_shader_parameter("weapon_envelope", envelope)
	_rebuild()
	item_light.visible = envelope > .0001 and ownership.visible() and bool(settings.light.grant_active) and measurement.get("cells", 0) > 0
	if item_light.visible:
		item_light.global_position = measurement.base.lerp(measurement.tip, .55)

func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.divine_study = {"plan_only": true, "study_contract": "paladin.sacred_weapon", "native_light": item_light.visible,
		"radius_cells_supplied_fixture_value": settings.light.radius_cells, "mechanical_radius_not_verified": true}
	return result

const VfxPackageIO_a004796cd3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
