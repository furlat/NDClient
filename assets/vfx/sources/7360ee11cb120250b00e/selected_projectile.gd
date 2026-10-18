extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Approved source edits; donor shader clocks and exports use shared owners.
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/7360ee11cb120250b00e/selected_projectile.gd", input)
func apply_scene_edits(node: Node) -> void:
 match settings.edit:
  "guiding_travel":
   node.scale = Vector3.ONE * .9
   var sparks = node.get_node("Small Sparks")
   sparks.amount=18;sparks.lifetime=.45;sparks.explosiveness=.14;sparks.randomness=.3
   var trail = node.get_node("Trail1_static")
   var length = trail.transform.basis.x.length()
   trail.scale.x *= 1.05;trail.position.z += length * .05 * .5
  "guiding_impact":
   node.get_node("torus").hide()
   var expansion = node.get_node("Pruple Expansion")
   var material = expansion.material_override
   var shader = Shader.new()
   shader.code=material.shader.code.replace("float n_out3p1 = n_out3p0.r;", "float n_out3p1 = clamp((n_out3p0.r - 0.094117647) / 0.905882353, 0.0, 1.0);")
   material.shader=shader
  "acid_impact":
   node.rotation.x=-PI/2.;node.scale=Vector3.ONE*.5
   node.get_node("Core").hide();node.get_node("Smoke").hide()
   for particle in node.find_children("*", "GPUParticles3D", true, false):particle.local_coords=true
   node.get_node("Sparks").process_material.gravity=Vector3.ZERO
