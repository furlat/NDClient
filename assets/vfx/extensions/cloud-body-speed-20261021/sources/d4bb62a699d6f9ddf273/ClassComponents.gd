extends Node3D

var kind := "mantle"
var side_name := "back"
var quadrant := 0
var age := 0.0
var ribbons: Array = []
var motes: Array = []
var donor: Node3D
var film: ShaderMaterial

func _ready():
 scale.y = .816496580927726
 if kind == "film":
  var quad = MeshInstance3D.new()
  var mesh = QuadMesh.new(); mesh.size = Vector2(3.8, 3.8)
  quad.mesh = mesh
  film = ShaderMaterial.new(); film.shader = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/90cba0a6aaf158a8eb73/Film.gdshader")
  film.set_shader_parameter("flow_tex", VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/745374b8d1de2c2b0161/flow_noise.tres"))
  quad.material_override = film; quad.position.y = .9
  quad.rotation.y = PI / 4.0 + float(quadrant) * PI / 2.0
  quad.rotation.x = -asin(1.0 / sqrt(3.0))
  add_child(quad)
  return
 if kind == "charge":
  donor = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/3b98bccd3f512746b959/arc_charge_swirl_charge.tscn").instantiate()
  add_child(donor); donor.set_process(false)
  donor.get_node("AnimationPlayer").stop()
  donor.scale = Vector3.ONE * .26
  for i in range(9):
   var n = donor.get_node("Ribbon%d" % i)
   var mat = n.material_override.duplicate()
   mat.shader = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/805f8a07d1f6c4f1814f/Charge.gdshader")
   mat.set_shader_parameter("base_color", Color(.19,.19,.19))
   mat.set_shader_parameter("core_color", Color(.62,.62,.62))
   mat.set_shader_parameter("hot_color", Color(.90,.90,.90))
   mat.set_shader_parameter("intensity", .45)
   n.material_override = mat
  for name in ["Glow", "Core"]:
   var n = donor.get_node(name); var m = ShaderMaterial.new()
   m.shader = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/4692e15424d9a501e90b/Glow.gdshader")
   m.set_shader_parameter("glow_tex", VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/0153d00f65f7d8626351/texture.res"))
   n.material_override = m
  # Deterministic replacement particles keep the native scene's ribbon/core layers.
  # GPU emitters are not advanced through wall-clock simulation in a frame export.
  donor.get_node("Embers").emitting = false; donor.get_node("Sparks").emitting = false
  donor.get_node("OmniLight3D").visible = false
 else:
  var count = 5 if kind == "mantle" else (7 if kind == "ground" or kind == "mist" else 6)
  for i in range(count):
   var n = MeshInstance3D.new(); var mat = ShaderMaterial.new()
   mat.shader = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/b6acfaeb2f0aff7b2b28/Flow.gdshader")
   mat.set_shader_parameter("flow_tex", VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/745374b8d1de2c2b0161/flow_noise.tres"))
   mat.set_shader_parameter("seed", float(i)*.173)
   mat.set_shader_parameter("side", -1.0 if side_name == "back" else (1.0 if side_name == "front" else 0.0))
   var angle = quadrant * PI / 2.0
   mat.set_shader_parameter("camera_ground", Vector2(cos(angle)+sin(angle), cos(angle)-sin(angle)))
   n.material_override = mat; add_child(n); ribbons.append(n)
 var mote_count = 14 if kind == "charge" else (19 if kind == "burst" else 12)
 for i in range(mote_count):
  var n = MeshInstance3D.new(); var mesh = SphereMesh.new()
  mesh.radius = .018 if kind != "burst" else .025; mesh.height = mesh.radius*2.0
  mesh.radial_segments = 4; mesh.rings = 2; n.mesh = mesh
  var mat = ShaderMaterial.new(); mat.shader = VfxPackageIO_d4bb62a699.resource("res://assets/vfx/sources/8840931560b79bf05339/native_effect_mote.gdshader")
  mat.set_shader_parameter("source_colour", Color(.83,.83,.83,.65))
  n.material_override = mat; add_child(n); motes.append(n)

func path_point(i: int, u: float, t: float) -> Vector3:
 var phase = TAU * t / 2.0
 var seed = float(i)
 if kind == "mantle":
  var a = u * TAU * .67 + seed * 1.26 + phase
  var r = .29 + .09*sin(u*PI + seed)
  return Vector3(cos(a)*r, .16 + u*(.85 + .16*sin(seed)) + .035*sin(phase+seed), sin(a)*r)
 if kind == "ground" or kind == "mist":
  var a = seed*.9 + u*1.6 + .12*sin(phase+seed)
  var r = .25 + u*.60
  return Vector3(cos(a)*r, .025 + .02*sin(u*PI), sin(a)*r)
 if kind == "heal":
  var a = seed*1.047 + .25*sin(phase+u*2.0)
  var r = .22 + .07*sin(u*PI)
  return Vector3(cos(a)*r, u*1.32, sin(a)*r)
 var a = seed*TAU/6.0
 var reach = .05 + clampf(t/.45,0.,1.)*.65
 return Vector3(cos(a)*reach*u, .40 + .18*sin(u*PI) + t*.18, sin(a)*reach*u)

func build_strip(i: int, t: float) -> ArrayMesh:
 var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points: Array = []; var width = .05 if kind == "mantle" else (.12 if kind == "mist" else .065)
 for k in range(33):
  var u = float(k)/32.0; var p = path_point(i,u,t)
  var next = path_point(i,minf(u+.01,1.0),t)
  var tangent = (next-p).normalized()
  var cross = tangent.cross(Vector3.UP).normalized()
  if cross.length() < .1: cross = Vector3.RIGHT
  if kind == "heal": cross = Vector3(cos(float(i)*1.047),0,sin(float(i)*1.047))
  points.append([p-cross*width,p+cross*width])
 for k in range(32):
  for idx in [[k,0],[k,1],[k+1,1],[k,0],[k+1,1],[k+1,0]]:
   st.set_uv(Vector2(float(idx[0])/32.0,float(idx[1])))
   st.add_vertex(points[idx[0]][idx[1]])
 return st.commit()

func set_age(t: float):
 age = t
 if kind == "film":
  film.set_shader_parameter("clock", t); return
 if donor != null:
  var a = donor.get_node("AnimationPlayer")
  var native_age = t*3.2/1.25
  a.assigned_animation = "erupt"; a.seek(native_age,true)
  var anim = a.get_animation("erupt")
  donor.get_node("Embers").emitting = false; donor.get_node("Sparks").emitting = false
  for i in range(9):
   var n = donor.get_node("Ribbon%d" % i)
   n.rotation = anim.value_track_interpolate(i*3,native_age)
   n.scale = anim.value_track_interpolate(i*3+1,native_age)
   n.material_override.set_shader_parameter("alpha_mult",anim.value_track_interpolate(i*3+2,native_age))
   n.material_override.set_shader_parameter("clock",native_age)
  donor.get_node("Glow").material_override.set_shader_parameter("strength",float(donor.glow_alpha)*.65)
  donor.get_node("Core").material_override.set_shader_parameter("strength",float(donor.core_alpha)*.8)
 for i in range(ribbons.size()):
  ribbons[i].mesh = build_strip(i,t)
  ribbons[i].material_override.set_shader_parameter("clock",t)
  var strength = 1.0
  if kind == "burst": strength = sin(clampf(t/.85,0.,1.)*PI)
  if kind == "heal": strength = smoothstep(0.,.16,t)*(1.-smoothstep(1.0,1.5,t))
  ribbons[i].material_override.set_shader_parameter("strength",strength)
  ribbons[i].material_override.set_shader_parameter("broad",1.0 if kind == "mist" else 0.0)
 for i in range(motes.size()):
  var p = fmod(t/2.0 + float(i)*.083333333333,1.0)
  var angle = float(i)*2.399963 + .14*sin(t*PI)
  var r = .32 if kind == "mantle" or kind == "heal" else .65
  if kind == "charge": r = .25
  var y = .06 + p*1.14
  if kind == "ground" or kind == "mist": y = .02 + .03*sin(p*PI)
  if kind == "burst": r = .05+t*.7; y = .38+t*.3-t*t*.4
  var pos = Vector3(cos(angle)*r,y,sin(angle)*r); motes[i].position=pos
  var angle_q = quadrant*PI/2.0
  var depth = pos.x*(cos(angle_q)+sin(angle_q)) + pos.z*(cos(angle_q)-sin(angle_q))
  var visible_side = (side_name != "back" or depth < 0.) and (side_name != "front" or depth >= 0.)
  var alpha = .8*sin(p*PI)
  if kind == "burst": alpha *= sin(clampf(t/.85,0.,1.)*PI)
  if kind == "charge": alpha *= smoothstep(0.,.3,t)*(1.-smoothstep(.85,1.25,t))
  motes[i].visible = visible_side
  motes[i].material_override.set_shader_parameter("source_colour", Color(.88,.88,.88,alpha))

const VfxPackageIO_d4bb62a699 = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
