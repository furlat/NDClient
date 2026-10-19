extends Node3D
## Original solar cloud/detail/palette compressed into a maintained full orb.
## Constructors run offline; recipient hand routing belongs to live_pose.
var material: ShaderMaterial
static func make_component(_input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_68ed2fb507.resource("res://assets/vfx/sources/68ed2fb507d85984d5b3/sunbeam_hand.gd").new()
 var draw:=MeshInstance3D.new()
 draw.name="MaintainedSolarHandOrb"
 var sphere:=SphereMesh.new()
 sphere.radius=1.0
 sphere.height=2.0
 sphere.radial_segments=32
 sphere.rings=16
 draw.mesh=sphere
 draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.material=ShaderMaterial.new()
 node.material.shader=VfxPackageIO_68ed2fb507.resource("res://assets/vfx/sources/008f4aab805beb16fef0/sunbeam_hand.gdshader")
 node.material.set_shader_parameter("noise_tex",preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").raw_texture("res://assets/vfx/sources/79ea8307f7adab9ec44f/texture.res"))
 node.material.set_shader_parameter("detail_tex",preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").raw_texture("res://assets/vfx/sources/5b0a18fdc09c1fcdd677/texture.res"))
 draw.material_override=node.material
 node.add_child(draw)
 return node
func sample(seconds: float) -> void:
 material.set_shader_parameter("owned_clock",seconds)

const VfxPackageIO_68ed2fb507 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
