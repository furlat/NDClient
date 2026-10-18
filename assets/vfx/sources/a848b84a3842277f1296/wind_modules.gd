extends Node3D
const CELL=2.121320344
const HEIGHT=6.363961032
const THICKNESS=.424264069
var path_points=[[-.5,0],[.5,0]]
var subject:Node3D
var mats:Array[ShaderMaterial]=[]
var CAMERA_GROUND=Vector2(1,1).normalized()
var foreground=false
var split_layers=false
var actor_ground=Vector2.ZERO
var visual_age=0.0
var removal=0.0
var hit_meshes:Array[MeshInstance3D]=[]
var hit_mats:Array[ShaderMaterial]=[]
var tick=0
var modules=[]
var debris:Array[MeshInstance3D]=[]
var debris_roots:Array[Vector3]=[]
var feed_mat:StandardMaterial3D
var feed_points:Array[Vector3]=[]
func build(node:Node3D)->void:
	subject=node
	for child in node.get_children():node.remove_child(child);child.free()
	var points:Array[Vector3]=[]
	for point in path_points:points.append(Vector3(point[0]*CELL,0,point[1]*CELL))
	var distance=0.0
	var vertices:Array[Vector3]=[]
	var arcs:Array[float]=[]
	for segment in range(points.size()-1):
		var length=points[segment].distance_to(points[segment+1])
		var steps=int(ceil(length/CELL))
		for j in range(steps):
			vertices.append(points[segment].lerp(points[segment+1],float(j)/steps));arcs.append(distance+length*float(j)/steps)
		distance+=length
	vertices.append(points[-1]);arcs.append(distance)
	var closed=points[0].is_equal_approx(points[-1])
	feed_points=vertices
	feed_mat=StandardMaterial3D.new();feed_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;feed_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;feed_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;feed_mat.albedo_color=Color(.66,.68,.61,.7)
	for j in range(12):
		var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.035,0,0),Vector3(.035,0,0),Vector3(.018,.085,.01)]);a[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]);var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		var chip=MeshInstance3D.new();chip.mesh=mesh;chip.material_override=feed_mat;node.add_child(chip);debris.append(chip)
		var slot=(j*7)%maxi(1,vertices.size()-1);debris_roots.append(vertices[slot].lerp(vertices[slot+1],fmod(float(j)*.618,1.0)))
	var normals:Array[Vector3]=[]
	for j in range(vertices.size()):
		var prev=vertices[j]-vertices[maxi(0,j-1)]
		var next=vertices[mini(vertices.size()-1,j+1)]-vertices[j]
		if closed and j==0:prev=vertices[-1]-vertices[-2]
		if closed and j==vertices.size()-1:next=vertices[1]-vertices[0]
		if prev.length()<.01:prev=next
		if next.length()<.01:next=prev
		var n0=Vector3(-prev.z,0,prev.x).normalized()
		var n1=Vector3(-next.z,0,next.x).normalized()
		var n=(n0+n1).normalized()/maxf(.5,(n0+n1).normalized().dot(n1))
		normals.append(n)
	for j in range(vertices.size()-1):
		for layer in range(3):
			var surface=MeshInstance3D.new();surface.name="WindModule_%02d_layer%d"%[j,layer]
			surface.mesh=sheet_mesh(vertices[j],vertices[j+1],normals[j],normals[j+1],arcs[j],arcs[j+1],distance,j,layer,closed)
			surface.custom_aabb=surface.mesh.get_aabb().grow(.8)
			surface.material_override=flow_material(layer,distance,closed)
			node.add_child(surface)
		modules.append({"index":j,"start":[vertices[j].x,0,vertices[j].z],"end":[vertices[j+1].x,0,vertices[j+1].z],"arcStart":arcs[j],"arcEnd":arcs[j+1],"variant":j%3,"boundaryNormalStart":[normals[j].x,0,normals[j].z],"boundaryNormalEnd":[normals[j+1].x,0,normals[j+1].z]})
	create_formation_hit(node)
func sheet_mesh(a:Vector3,b:Vector3,na:Vector3,nb:Vector3,s0:float,s1:float,total:float,index:int,layer:int,closed:bool)->ArrayMesh:
	var v=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var ix=PackedInt32Array()
	var offset=(float(layer)-1.0)*THICKNESS*.40
	for i in range(9):
		var u=float(i)/8.0
		var center=a.lerp(b,u);var side=na.lerp(nb,u)
		for j in range(25):
			var y=float(j)/24.0
			var interior=sin(PI*u)*sin(PI*u)
			var shape=sin(y*9+float(index%3)*2.1)*interior*.025
			v.append(center+Vector3.UP*(y*HEIGHT)+side*(offset+shape));normals.append(side.normalized())
			uv.append(Vector2(lerpf(s0,s1,u)/total*round(total/CELL*1.7),y))
	for i in range(8):
		for j in range(24):
			var k=i*25+j;ix.append_array(PackedInt32Array([k,k+25,k+1,k+1,k+25,k+26]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ix
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func flow_material(layer:int,total:float,closed:bool)->ShaderMaterial:
	var donor=VfxPackageIO_a848b84a38.resource("res://assets/vfx/sources/d63f0c0abc2c7e9a31cc/m_windstreaks13.tres") as ShaderMaterial
	var m=donor.duplicate(true) as ShaderMaterial
	var sh=Shader.new();var s=m.shader.code
	var re=RegEx.new();re.compile("\\bTIME\\b");s=re.sub(s,"wind_clock",true)
	s=s.replace("shader_type spatial;","shader_type spatial;uniform float wind_clock=0.0;uniform float reveal=0.0;uniform float wall_opacity=1.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;uniform bool split_layers=false;uniform float formation_pulse=0.0;")
	s=s.replace("= COLOR;","= vec4(1.0,1.0,1.0,wind_clock);")
	s=s.replace("render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_toon;","render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;")
	s=s.replace("VERTEX = n_out4p0;","VERTEX = n_out4p0; VERTEX+=NORMAL*(.045*sin(UV.x*6.2831853+UV.y*3.0-wind_clock*3.14159265)+.018*sin(UV.x*12.5663706+UV.y*7.0+wind_clock*6.2831853))*smoothstep(0.0,.2,UV.y);")
	s=s.replace("void vertex() {", "void vertex() {")
	var vertex_end=s.find("void fragment()")
	var close=s.rfind("}",vertex_end)
	s=s.insert(close,"vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;vec2 offset=wp.xz-actor_ground;float d=length(offset);float near_body=(1.0-smoothstep(.30,1.50,d))*smoothstep(0.0,.30,wp.y)*(1.0-smoothstep(2.15,3.1,wp.y));wp.xz+=offset/max(.12,d)*near_body*.32;VERTEX=(inverse(MODEL_MATRIX)*vec4(wp,1.0)).xyz;\n")
	var end=s.rfind("}")
	s=s.insert(end,"\nfloat vertical=smoothstep(0.0,.035,UV.y)*(1.0-smoothstep(.79,1.0,UV.y));float grow=1.0-smoothstep(reveal-.10,reveal,UV.y);ALPHA*=wall_opacity*vertical*grow;ALBEDO=vec3(.73,.83,.89)+vec3(.14)*clamp(ALPHA,0.0,1.0);vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;float local_hit=1.0-smoothstep(.35,1.8,length(wp-vec3(actor_ground.x,1.2,actor_ground.y)));float body_clear=(1.0-smoothstep(.35,1.0,length(wp.xz-actor_ground)))*smoothstep(.15,.50,wp.y)*(1.0-smoothstep(2.1,2.8,wp.y));ALPHA*=1.0-.68*body_clear;ALPHA*=1.0+formation_pulse*local_hit*.65;if(split_layers && ((dot(wp.xz-actor_ground,camera_ground)>0.0)!=foreground))discard;\n")
	sh.code=s;m.shader=sh
	var white=Image.create(2,2,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE);var wt=ImageTexture.create_from_image(white)
	m.set_shader_parameter("BaseTexture",wt);m.set_shader_parameter("Multiply_Mask",wt)
	m.set_shader_parameter("scale",Vector2(1,1));m.set_shader_parameter("speed",Vector2(0,-1))
	m.set_shader_parameter("wind_scale",Vector2(1,1));m.set_shader_parameter("wind_speed",Vector2(0,-1))
	m.set_shader_parameter("wind_2_scale",Vector2(1,2));m.set_shader_parameter("wind_2_speed",Vector2(0,1.5))
	m.set_shader_parameter("scroll_offset",float(layer)*.19)
	var g=Gradient.new();g.offsets=PackedFloat32Array([0,.25,.50,1]);g.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,.4),Color(1,1,1,1)])
	var gt=GradientTexture1D.new();gt.gradient=g;m.set_shader_parameter("Color1DGradient",gt)
	m.set_shader_parameter("camera_ground",CAMERA_GROUND);m.set_shader_parameter("foreground",foreground)
	mats.append(m)
	return m
func set_visual_state(age:float, ground:Vector2, retire:float=0.0)->void:
	if not is_instance_valid(subject):return
	visual_age=age
	actor_ground=ground
	removal=retire
	var fade=1.0-clampf(retire,0.0,1.0)
	var pulse=exp(-pow((age-.70)/.13,2.0))
	var hit_phase=clampf((age-.48)/.65,0.0,1.0)
	for i in range(hit_meshes.size()):
		hit_meshes[i].position=Vector3(0,1.0+float(i)*.35,0)
		hit_meshes[i].scale=Vector3.ONE*lerpf(.18,.48,hit_phase)
		hit_meshes[i].rotation=Vector3(.12*float(i),float(i)*1.9+hit_phase*.18,0)
		hit_mats[i].set_shader_parameter("phase",hit_phase)
		hit_mats[i].set_shader_parameter("envelope",smoothstep(0,.10,hit_phase)*(1.0-smoothstep(.55,1.0,hit_phase)))
		hit_mats[i].set_shader_parameter("actor_ground",ground)
	feed_mat.albedo_color=Color(.66,.68,.61,.6*smoothstep(0,.35,age)*fade)
	for j in range(debris.size()):
		var u=fmod(age*.5+float(j)/12.0,1.0)
		debris[j].position=debris_roots[j]+Vector3(.08*sin(u*6.283+float(j)),HEIGHT*u,.07*cos(u*6.283+float(j)))
		debris[j].visible=(CAMERA_GROUND.dot(Vector2(debris[j].position.x,debris[j].position.z)-ground)>0)==foreground
		debris[j].rotation=Vector3(u*5,u*9+float(j),u*6)
		debris[j].scale=Vector3.ONE*smoothstep(0,.08,u)*(1.0-smoothstep(.75,1.0,u))*smoothstep(0,.3,age)
	for m in mats:
		m.set_shader_parameter("split_layers",split_layers)
		m.set_shader_parameter("actor_ground",ground)
		m.set_shader_parameter("formation_pulse",pulse)
		m.set_shader_parameter("wind_clock",fmod(age,2.0))
		m.set_shader_parameter("reveal",lerpf(0.0,1.12,smoothstep(0,.75,age)))
		m.set_shader_parameter("wall_opacity",fade*.36)

func create_formation_hit(node:Node3D)->void:
	var authored=VfxPackageIO_a848b84a38.resource("res://assets/vfx/sources/546681adf3a962816738/VFX_WindHit_K2.tscn").instantiate()
	var particle=authored.find_child("windimpact5",true,false) as GPUParticles3D
	for i in range(2):
		var mesh=MeshInstance3D.new();mesh.mesh=particle.draw_pass_1;mesh.custom_aabb=mesh.mesh.get_aabb().grow(.1);node.add_child(mesh)
		var donor=particle.material_override as ShaderMaterial
		var m=donor.duplicate(true) as ShaderMaterial
		var shader=Shader.new();var code=m.shader.code
		code=code.replace("shader_type spatial;","shader_type spatial;uniform float phase=0.0;uniform float envelope=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;uniform bool split_layers=false;")
		code=code.replace("render_mode blend_mix, diffuse_toon, cull_disabled;","render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;")
		code=code.replace("COLOR.a * last_cell","phase * last_cell")
		code=code.replace("tex.rgb * COLOR.rgb","vec3(.78,.87,.91)")
		code=code.replace("ALPHA = tex.a;","ALPHA = tex.a*envelope*.72;vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(split_layers && ((dot(wp.xz-actor_ground,camera_ground)>0.0)!=foreground))discard;")
		shader.code=code;m.shader=shader;m.set_shader_parameter("camera_ground",CAMERA_GROUND);m.set_shader_parameter("foreground",foreground);mesh.material_override=m
		hit_meshes.append(mesh);hit_mats.append(m)
	authored.free()

# Native nearest visible surface coordinates, retaining the original alpha mask.
# RG stores a 16-bit unsigned axis value; alpha identifies valid samples.

const VfxPackageIO_a848b84a38 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
