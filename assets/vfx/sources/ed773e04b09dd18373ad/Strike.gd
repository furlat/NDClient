extends Node3D
var kind="slash"
var heading=0
var trail:MeshInstance3D
var shards:Array[MeshInstance3D]=[]
var paths=[]
var native_path_rate=12.0
var native_scale_x=1.0
func _ready():
 scale.y=.816496580927726
 paths=JSON.parse_string(VfxPackageIO_ed773e04b0.text("res://assets/vfx/sources/9af4660f7e674a804781/StrikePaths.json")).paths
 trail=MeshInstance3D.new();add_child(trail)
 var m=ShaderMaterial.new();m.shader=VfxPackageIO_ed773e04b0.resource("res://assets/vfx/sources/58b342ee87f26dfa9134/Strike.gdshader")
 m.set_shader_parameter("impact_tex",VfxPackageIO_ed773e04b0.resource("res://assets/vfx/sources/fbde8002dad5a6cc88e8/texture.res"))
 m.set_shader_parameter("impact",kind=="impact")
 trail.material_override=m
 if kind=="impact":
  var quad=QuadMesh.new();quad.size=Vector2(.54,.54);trail.mesh=quad
  trail.rotation.y=PI/4.;trail.rotation.x=-asin(1./sqrt(3.))
  for i in range(18):
   var s=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(.017,.017,.12 if i<9 else .035);s.mesh=mesh
   var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;s.material_override=material
   add_child(s);shards.append(s)
func blade(t:float)->Vector3:
 var f=clampf(t*native_path_rate,0.,float(paths[heading].size()-1));var p0=paths[heading][int(f)];var p1=paths[heading][mini(int(f)+1,paths[heading].size()-1)]
 var p=Vector2(float(p0[0]),float(p0[1])).lerp(Vector2(float(p1[0]),float(p1[1])),f-floor(f))
 # Inverse orthographic projection onto the camera plane. Same 128×64/64px grid
 # as the native capture: a weapon-attached smear, not a second virtual weapon.
 var sx=(p.x-64.)*2.*native_scale_x;var sy=(87.-p.y)*2.
 return Vector3(1.,0.,-1.)*sx/128.+Vector3(-1.,2.,-1.)*sy/192.
func path_available(t:float)->bool:
 var f=clampf(t*native_path_rate,0.,float(paths[heading].size()-1))
 return paths[heading][int(f)]!=null and paths[heading][mini(int(f)+1,paths[heading].size()-1)]!=null
func set_age(t:float):
 trail.material_override.set_shader_parameter("clock",t)
 if kind=="slash":
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var latest=minf(t,.67);var old=maxf(.14,latest-.20)
  for j in range(25):
   var tt=lerpf(old,latest,float(j)/24.)
   if not path_available(tt) or not path_available(tt-.008) or not path_available(tt+.008):
    trail.visible=false
    return
  for j in range(24):
   for ij in [Vector2i(j,0),Vector2i(j,1),Vector2i(j+1,1),Vector2i(j,0),Vector2i(j+1,1),Vector2i(j+1,0)]:
    var u=float(ij.x)/24.;var tt=lerpf(old,latest,u);var pt=blade(tt)
    var tangent=blade(tt+.008)-blade(tt-.008);var across=tangent.cross(Vector3(1.,1.,1.)).normalized()
    st.set_uv(Vector2(u,ij.y));st.add_vertex(pt+across*(.03+.055*sin(u*PI))*(1. if ij.y else -1.))
  trail.mesh=st.commit();trail.visible=t>=.16 and t<.94
 else:
  trail.scale=Vector3.ONE*(.65+smoothstep(0.,.19,t)*.55)
  var fade=1.-smoothstep(.16,.62,t)
  for i in range(shards.size()):
   var a=i*2.399963;var velocity=Vector3(cos(a),sin(a*1.7)*.5+.35,sin(a))*(.8+(i%4)*.28)
   shards[i].position=velocity*t+Vector3(0,-1.4*t*t,0)
   if velocity.length()>.01:shards[i].look_at(shards[i].position+velocity)
   shards[i].scale=Vector3.ONE*(1.-smoothstep(.23,.7,t))
   shards[i].material_override.albedo_color=Color(.90 if i%3==0 else .46,.90 if i%3==0 else .46,.90 if i%3==0 else .46,fade)

const VfxPackageIO_ed773e04b0 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
