extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Pinned source authoring only; shared stage owns clock/camera/export.
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/ab791b14589651dcc7e6/call_strike.gd", input)
var asset:Node3D
func apply_scene_edits(node:Node)->void:
 pass
 var stage=Node3D.new();stage.scale=Vector3(.65,.65*.816496580927726,.65);node.add_child(stage)
 asset=VfxPackageIO_ab791b1458.resource("res://assets/vfx/sources/ff6bf8e0d902a298f6f5/VFX_ElectricRay_blue.tscn").instantiate();stage.add_child(asset)
 for child in asset.find_children("*","GPUParticles3D",true,false):
  child.local_coords=true;child.fixed_fps=144;child.use_fixed_seed=true;child.seed=48219;child.one_shot=true
  # Keep both original emitters and every mesh surface/material. Only anchor
  # the main cluster to the requested contact point, rather than a random box.
  if child.name=="CPUParticles3D":
   child.process_material=child.process_material.duplicate(true)
   child.process_material.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_POINT
   child.process_material.scale_max=1.
  elif child.name=="GPUParticles3D":
   # Preserve the authored electrical chunks and erosion. Their original
   # violet HDR ramp and huge box made unrelated purple flecks across the map.
   child.process_material=child.process_material.duplicate(true)
   child.process_material.emission_box_extents=Vector3(1.4,4.8,1.4)
   child.process_material.hue_variation_min=0.
   child.process_material.hue_variation_max=0.
   child.process_material.turbulence_noise_strength=.8
   child.material_override=child.material_override.duplicate(true)
   var source_ramp=child.material_override.get_shader_parameter("Texture2DParameter2")
   var blue_ramp=source_ramp.duplicate(true)
   blue_ramp.gradient=source_ramp.gradient.duplicate(true)
   blue_ramp.gradient.colors=PackedColorArray([Color(.025,.35,4.,1.),Color(.3,2.,10.,1.)])
   child.material_override.set_shader_parameter("Texture2DParameter2",blue_ramp)
  child.restart();child.emitting=true
# Transparent native framebuffer to straight RGBA. No framebuffer recoloring,
# no shader rewriting, no removed source layers.

const VfxPackageIO_ab791b1458 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
