extends Node3D
## Exact original Counterspell sphere fragments, extracted from preserved
## abjuration-review/native/counter adapters. No legacy recorder or scene script.

const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Stage = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")

var settings: Dictionary = {}
var fragment: MeshInstance3D
var material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_6e25e2b7f8.resource("res://assets/vfx/sources/6e25e2b7f8fcbfdb10c7/counter_fragments.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	fragment = MeshInstance3D.new()
	fragment.name = "OriginalUnequalOpposingShieldFragments"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	fragment.mesh = sphere
	fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = VfxPackageIO_6e25e2b7f8.resource(settings.material).duplicate(true)
	var code: String = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	code = code.replace("shadow_to_opacity, ", "")
	code = code.replace("TIME", "vfx_clock")
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc\"\nuniform float vfx_clock=0.0;\nuniform float vfx_alpha=0.0;\nuniform sampler2D original_palette:filter_nearest,repeat_disable;\n")
	var expression := RegEx.new()
	expression.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var found: RegExMatch = expression.search(code)
	assert(found != null, "Original Counterspell shield shader fragment is required")
	code = code.insert(found.get_end(), "\nif(!((UV.x > 0.04 && UV.x < 0.24) || (UV.x > 0.53 && UV.x < 0.79)) || UV.y < 0.20 || UV.y > 0.80) discard;\n")
	code = SourceMaterials.finish_fragment(code, "\nALPHA=max(ALPHA,(0.42+smoothstep(0.30,0.68,n_out77p0.r)*0.43))*vfx_alpha; float strength=clamp(n_out77p0.r*0.9+length(ALBEDO)*0.15,0.0,1.0); ALBEDO=mix(vec3(0.35,0.10,0.12),vec3(0.95,0.42,0.32),strength);\nvec3 original_encoded=cie_nearest(clamp(ALBEDO*1.08,vec3(0.0),vec3(1.0)),original_palette,4,0.0,0.0); ALBEDO=vec3(cie_linear_channel(original_encoded.r),cie_linear_channel(original_encoded.g),cie_linear_channel(original_encoded.b)); EMISSION=vec3(0.0);\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("original_palette", Stage.palette_texture(settings.palette))
	material.set_shader_parameter("Proximity_light", 0.0)
	material.set_shader_parameter("Gradient_Line", 1.0)
	material.set_shader_parameter("fresnel_power", 0.9)
	fragment.material_override = material
	add_child(fragment)
	sample(0.0)


func sample(seconds: float) -> void:
	var phase: float = clampf(seconds / 0.36, 0.0, 1.0)
	var succeeded: bool = settings.succeeded
	fragment.scale = Vector3.ONE * (lerpf(0.65, 0.10, phase) if succeeded else lerpf(0.48, 0.62, phase)) * float(settings.scale_cells_per_source_unit)
	fragment.rotation.y = 0.4 + phase
	var opacity: float = smoothstep(0.0, 0.035, seconds) * (1.0 - smoothstep(0.23, 0.42, seconds)) if succeeded else 0.58 * smoothstep(0.0, 0.035, seconds) * (1.0 - smoothstep(0.17, 0.32, seconds))
	material.set_shader_parameter("vfx_clock", seconds * 0.9)
	material.set_shader_parameter("vfx_alpha", opacity)
	fragment.visible = seconds >= 0.0 and seconds < 0.43

const VfxPackageIO_6e25e2b7f8 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
