extends Node3D
## Native psychic material layers on open folds/ear echoes. The caller supplies
## admitted outcomes, owner lifetime, receiving geometry and live voice heading.
const SourceMaterials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Values=preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const GpuRibbon=preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
const Ribbon=preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var settings:Dictionary={}
var surface:Dictionary={}
var endpoints:Array=[]
var pieces:Array[MeshInstance3D]=[]
var materials:Array[ShaderMaterial]=[]
var local_clock:=0.0
var envelope:=0.0
var centre:=Vector3.ZERO
var heading:=Vector3.FORWARD
var side:=Vector3.RIGHT
var radius:=.12
var head_points:=0
var owner_visibility:=1.0
var measured_key: Array=[]
var relative_centre:=Vector3.ZERO
var support_cache: Dictionary={}
var fallback_normal:=false

static func make_component(input:Dictionary)->Node3D:
	return construct("res://assets/vfx/sources/d7989287f3e6aecf6110/head_accent.gd",input)

static func construct(path: String,input: Dictionary) -> Node3D:
	var instance:Node3D=VfxPackageIO_d7989287f3.resource(path).new()
	instance.settings=input.duplicate(true)
	for layer in input.layers:
		var scene:PackedScene=VfxPackageIO_d7989287f3.resource(layer.scene)
		var donor:Node3D=scene.instantiate()
		var original:ShaderMaterial=donor.get_node(layer.node).material_override
		var material:ShaderMaterial=original.duplicate(true)
		var code:String=original.shader.code.replace("TIME","psychic_clock")
		var begin:=code.find("void vertex()")
		var fragment:=code.find("void fragment()")
		assert(begin>=0 and fragment>begin)
		code=code.substr(0,begin)+"void vertex() {}\n"+code.substr(fragment)
		code=code.replace("blend_add","blend_mix").replace("cull_back","cull_disabled")
		code=code.replace("diffuse_toon, specular_toon","unshaded")
		code=SourceMaterials.stable_proximity(code)
		code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float psychic_clock=0.0;\nuniform float psychic_envelope=0.0;\nuniform float psychic_opacity=1.0;\nuniform vec4 psychic_tint:source_color=vec4(1.0);\n")
		var finish: String = "\nALBEDO*=psychic_tint.rgb;\n"
		if input.shape=="folds":
			# The source's sharp mask vanished on thin receiving folds. Preserve
			# moving source structure but give the actual narrow geometry a bounded,
			# continuous energy body, with softly tapered transverse/longitudinal UVs.
			finish+="ALPHA=(0.30+0.70*clamp(ALPHA,0.0,1.0))*pow(max(0.0,sin(UV.x*3.14159265)),0.65)*pow(max(0.0,sin(UV.y*3.14159265)),0.4);\n"
		finish+="ALPHA*=psychic_envelope*psychic_opacity*"+str(float(layer.get("alpha",.65)))+";\n"
		code=SourceMaterials.finish_fragment(code,finish)
		assert(not code.contains("ALPHA_SCISSOR_THRESHOLD"))
		var shader:=Shader.new()
		shader.code=code
		SourceMaterials.replace_shader(material,shader)
		if input.has("colour"):
			# This donor's fragment graph never multiplies vertex COLOR. Its
			# removed particle vertex stage used COLOR only to scale geometry.
			material.set_shader_parameter("psychic_tint",Color.html(input.colour))
		for name in layer.get("uniforms",{}):material.set_shader_parameter(name,Values.uniform_value(layer.uniforms[name]))
		instance.materials.append(material)
		for index in int(input.count):
			var piece:=MeshInstance3D.new()
			piece.name="PsychicLayer"+str(instance.materials.size()-1)+"Piece"+str(index)
			piece.top_level=true
			piece.mesh=ArrayMesh.new()
			piece.material_override=material
			piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.hide()
			instance.add_child(piece)
			instance.pieces.append(piece)
		donor.free()
	return instance

func set_live_endpoints(value:Array)->void:
	endpoints=value
	if envelope>.0001:_rebuild()
func set_entity_geometry(value:Dictionary)->void:
	surface=value
	if envelope>.0001:_rebuild()
func set_owner_visibility(value:float)->void:
	# Admission/suppression/removal arrives from the owner. No native countdown
	# can consume an actual attack or infer a recipient turn boundary.
	owner_visibility=clampf(value,0.0,1.0)
	sample(local_clock)
func sample(seconds:float)->void:
	local_clock=seconds
	var lifetime:=float(settings.seconds)
	envelope=smoothstep(0.0,float(settings.get("apply_seconds",.08)),seconds)*(1.0-smoothstep(lifetime-float(settings.get("retire_seconds",.3)),lifetime,seconds))
	if settings.get("mode","")=="condition":
		envelope=smoothstep(0.0,float(settings.get("apply_seconds",.14)),seconds)
	envelope*=owner_visibility
	for material in materials:
		material.set_shader_parameter("psychic_clock",seconds)
		material.set_shader_parameter("psychic_envelope",envelope)
	_rebuild()
func _hide()->void:
	for piece in pieces:piece.hide()
func _frame()->bool:
	if endpoints.size()<2 or surface.get("points",[]).is_empty():return false
	heading=(endpoints[1].point-endpoints[0].point).normalized()
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var key: Array=[pose,heading if fallback_normal else Vector3.ZERO]
	if not pose.is_empty() and key==measured_key:
		centre=surface.origin+relative_centre
		return true
	support_cache.clear()
	var points:Array=surface.points
	head_points=points.size()
	centre=Vector3.ZERO
	var average_normal:=Vector3.ZERO
	for point in points:
		centre+=point.position
		average_normal+=point.normal
	centre/=float(points.size())
	heading=(endpoints[1].point-endpoints[0].point).normalized()
	var horizontal:=Vector3(average_normal.x,0,average_normal.z).normalized()
	fallback_normal=horizontal.is_zero_approx()
	if fallback_normal:horizontal=-Vector3(heading.x,0,heading.z).normalized()
	side=Vector3.UP.cross(horizontal).normalized()
	if side.is_zero_approx():side=Vector3.RIGHT
	radius=.035
	for point in points:radius=maxf(radius,absf((point.position-centre).dot(side)))
	measured_key=[pose,heading if fallback_normal else Vector3.ZERO]
	relative_centre=centre-surface.get("origin",Vector3.ZERO)
	return true
func _support(sign_value:float)->Dictionary:
	if support_cache.has(sign_value):return {"position":support_cache[sign_value][0]+centre,"normal":support_cache[sign_value][1]}
	var chosen:Dictionary=surface.points[0]
	var best:float=-INF
	for point in surface.points:
		var extent:float=(point.position-centre).dot(side)*sign_value
		if extent>best:
			best=extent
			chosen=point
	support_cache[sign_value]=[chosen.position-centre,chosen.normal]
	return chosen
func _rebuild()->void:
	if envelope<=.0001 or not _frame():
		_hide()
		return
	var count:=int(settings.count)
	for index in pieces.size():
		var layer:=index/count
		var number:=index%count
		var sign_value:float=-1.0 if number%2==0 else 1.0
		var contact:Dictionary=_support(sign_value)
		var anchor:Vector3=contact.position+contact.normal*.035
		if settings.get("mode","")=="voice":anchor=endpoints[0].point+heading*.055
		var path:Array[Vector3]=[]
		var widths:Array[float]=[]
		var amount:=float(settings.get("intensity",1.0))
		for station in 33:
			var u:=float(station)/32.0
			var position:Vector3
			if settings.shape=="folds":
				var outward:=side*sign_value
				# A short pressure fold travels tangentially along the temple.
				# The former outward V made pointed ear/horn silhouettes in v62.
				# Ends now bend down and back into this open, cambered strip;
				# material motion still comes from the two original source graphs.
				var pulse:float=sin(local_clock*3.0-u*TAU+float(number))
				position=anchor+outward*(.028+.018*sin(u*PI)+.008*pulse)
				position+=heading*((u-.5)*.17+float(number/2)*.026)
				position+=Vector3.UP*(.038*sin(u*TAU+.35*sign_value)+.006*pulse)
				position+=contact.normal*(.012*sin(u*PI)+.006*sin(local_clock*2.0+u*PI+number))
			else:
				# Four partial ear-side curls; never a closed ring around the head.
				var angle:=lerpf(-1.2,1.2,u)+.12*sin(local_clock*3.0+number)
				var r:=.11+float(number/2)*.045
				position=anchor+side*sign_value*(.025+r*(1.0-cos(angle)))
				position+=Vector3.UP*(sin(angle)*r)+heading*(.05*sin(u*PI+local_clock*1.4+number))
			if settings.get("mode","")=="voice":
				position=anchor+heading*(u*.16)+side*((u-.5)*.06)+Vector3.UP*(.035*sin(u*PI+number))
			elif settings.get("mode","")=="saved":
				position+=contact.normal*(.10*smoothstep(0.0,.3,local_clock))
			path.append(position-centre)
			widths.append(float(settings.get("width_cells",.025))*pow(maxf(0.0,sin(u*PI)),.75)*amount*(1.0+.12*sin(local_clock*4.0-u*TAU+number))*(1.0+float(layer)*.25))
		var piece:MeshInstance3D=pieces[index]
		piece.global_transform=Transform3D(Basis.IDENTITY,centre)
		var colour:=Color.WHITE
		if settings.has("colour"):
			colour=Color.html(settings.colour).srgb_to_linear()
			colour.a=float(settings.get("source_alpha",.7))
		GpuRibbon.assign(piece,path,widths,colour)
		piece.show()
func capture_observation()->Dictionary:
	return {"psychic":{"shape":settings.shape,"mode":settings.get("mode"),"owner":surface.get("actor"),
		"clock":local_clock,"envelope":envelope,"head_points":head_points,"measured_centre":centre,
		"measured_half_width":radius,"heading":heading,"pieces":pieces.size(),"visible":pieces[0].is_visible_in_tree(),"lights":0}}

const VfxPackageIO_d7989287f3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
