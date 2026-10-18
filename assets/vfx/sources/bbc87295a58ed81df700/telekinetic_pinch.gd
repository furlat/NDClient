extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
var ap: AnimationPlayer


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/bbc87295a58ed81df700/telekinetic_pinch.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	var doc = VfxPackageDocument_bbc87295a5.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(parameters.model, state)
	if err != OK:
		push_error("Pinch rig unavailable")
		return
	var hand = doc.generate_scene(state)
	node.add_child(hand)
	hand.scale.y = .81649658
	descend(hand)
	ap = find_anim(hand)
	for m in mats:
		m.set_shader_parameter("side", -1. if side == "back" else 1.)


func advance_lifecycle(_d: float) -> void:
	tick += 1
	var frame = maxi(0, int(floor(float(tick - 1) * 32. / float(parameters.simulation_hz))))
	var an = ""
	for a in ap.get_animation_list():
		if a.ends_with(settings.clip):
			an = a
	ap.play(an)
	ap.pause()
	ap.seek(minf(float(frame) / 32., .96875), true)
	for m in mats:
		m.set_shader_parameter("clock", float(frame) / 64.)


var mats = []


func hand_material():
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded,cull_back,depth_prepass_alpha;
uniform float clock=0.; uniform float side=0.; varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
	vec3 w=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;
	if(side!=0. && dot(w,vec3(.70710678,0.,.70710678))*side<0.)discard;
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
	float lit=clamp(dot(normalize(NORMAL),normalize(vec3(-.3,.8,.5)))*.5+.45,0.,1.);
	float veins=pow(.5+.5*sin(p.x*22.+p.y*15.+sin(p.z*24.)-clock*6.283185),18.);
	vec3 c=mix(vec3(.025,.045,.095),vec3(.11,.27,.42),lit);
	c=mix(c,vec3(.38,.85,.96),rim*.82+veins*.36);
	ALBEDO=c;EMISSION=c*.2; ALPHA=(.58+rim*.35)*smoothstep(2.12,2.40,p.z);
}"""
	var m = ShaderMaterial.new()
	m.shader = sh
	mats.append(m)
	return m


func descend(n: Node):
	if n is MeshInstance3D:
		n.material_override = hand_material()
	for c in n.get_children():
		descend(c)


func find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a = find_anim(c)
		if a:
			return a
	return null

const VfxPackageDocument_bbc87295a5 = preload("res://assets/vfx/sources/55f3fdb093ba9d7c2784/scene_document.gd")
