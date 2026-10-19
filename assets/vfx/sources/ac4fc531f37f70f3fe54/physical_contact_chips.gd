extends Node3D
## Small native stone fragments; the actual committed miss-damage contact owns
## their measured point packet and envelope. This component never plays a hit.


static func make_component(input: Dictionary) -> Node3D:
	var source: StandardMaterial3D = VfxPackageIO_ac4fc531f3.resource(input.source_material)
	var mesh: Mesh = VfxPackageIO_ac4fc531f3.resource(input.source_mesh)
	assert(source != null and source.albedo_texture != null and mesh != null)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix,cull_disabled,depth_draw_never;
uniform sampler2D native_rock_colour:source_color,filter_linear,repeat_enable;
uniform vec4 native_rock_tint:source_color=vec4(1.0);
void fragment(){
 ALBEDO=texture(native_rock_colour,UV).rgb*native_rock_tint.rgb;
 ROUGHNESS=1.0;
 ALPHA=.88;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("native_rock_colour", source.albedo_texture)
	material.set_shader_parameter("native_rock_tint", source.albedo_color)
	var root: Node3D = VfxPackageIO_ac4fc531f3.resource("res://assets/vfx/sources/ac4fc531f37f70f3fe54/physical_contact_chips.gd").new()
	for index in int(input.count):
		var draw := MeshInstance3D.new()
		draw.name = "PhysicalChip" + str(index)
		draw.mesh = mesh
		draw.material_override = material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(draw)
	return root


func sample(_seconds: float) -> void:
	pass

const VfxPackageIO_ac4fc531f3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
