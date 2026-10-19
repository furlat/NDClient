extends RefCounted
## One warmed actor-shader variant, independent of condition combinations.
## The host's frame, outfit, normals, depth and lighting code remain unchanged.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var shaders: Dictionary = {}


static func prepare(original: Shader) -> Shader:
	if original.get_meta("factory_condition_body_program", false):
		return original
	var key := original.get_instance_id()
	if shaders.has(key):
		return shaders[key]
	var code := Sources.expand_shader(original.code, original.resource_path.get_base_dir())
	var begin := code.find("vec4 character_material(")
	assert(begin >= 0, "Actual actor character_material hook is required")
	var opening := code.find("{", begin)
	var end := opening + 1
	var depth := 1
	while depth > 0:
		if code[end] == "{":
			depth += 1
		elif code[end] == "}":
			depth -= 1
		end += 1
	var insertion := code.rfind("return result;", end)
	assert(insertion > opening)
	var treatment := """
for(int body_index=0;body_index<factory_body_count;body_index++){
 vec4 state=texelFetch(vfx_package_clock,ivec2(factory_body_slots[body_index],0),0);
 float strength=clamp(state.g*factory_body_strengths[body_index],0.0,1.0);
 int kind=factory_body_kinds[body_index];
 if(kind==1){
  // Original barkskin_growth.FRAGMENT, with the owner's application front.
  vec3 bark=texture(factory_body_bark,cell_uv*vec2(4.,6.)).rgb;
  float source_shade=clamp(dot(result.rgb,vec3(.2126,.7152,.0722))*1.5+.28,.28,1.);
  float bark_grain=dot(bark,vec3(.2126,.7152,.0722));
  float bark_height=1.-cell_uv.y+(bark_grain-.3)*.10;
  float bark_front=state.b*1.20-.10;
  float bark_grown=smoothstep(bark_height-.055,bark_height+.055,bark_front);
  float bark_edge=exp(-pow((bark_height-bark_front)/.05,2.));
  vec3 bark_colour=bark*source_shade+vec3(.16,.10,.025)*bark_edge;
  result.rgb=mix(result.rgb,bark_colour,strength*.82*bark_grown);
 }else if(kind==2){
  // Original Stoneskin ramp/flow; complementary source phases close its loop.
  float skin_source=max(max(result.r,result.g),result.b);
  float skin_energy=clamp(skin_source*factory_body_stone_gain,0.,1.);
  vec3 skin_base=factory_body_stone_palette[min(4,int(skin_energy*5.))];
  vec2 first_uv=cell_uv*factory_body_stone_repeats+factory_body_stone_flow*state.r;
  float other=mod(state.r+factory_body_periods[body_index]*.5,factory_body_periods[body_index]);
  vec2 second_uv=cell_uv*factory_body_stone_repeats+factory_body_stone_flow*other;
  float weight=.5-.5*cos(6.28318530718*state.r/factory_body_periods[body_index]);
  vec3 skin_grain=mix(texture(factory_body_stone,fract(second_uv)).rgb,texture(factory_body_stone,fract(first_uv)).rgb,weight);
  float skin_facet=dot(skin_grain,vec3(.2126,.7152,.0722));
  vec3 skin_colour=skin_base*mix(1.,.76+.48*skin_facet,factory_body_stone_weight);
  result.rgb=mix(result.rgb,skin_colour,strength);
 }else if(kind==3){
  // Original Petrified character-material branch; the pose is captured apart.
  float stone_luma=dot(result.rgb,vec3(.2126,.7152,.0722));
  vec3 stone_grain=texture(factory_body_petrified,fract(cell_uv*factory_body_petrified_repeats)).rgb;
  float stone_scalar=clamp(mix(stone_luma,(stone_grain.r+stone_grain.g+stone_grain.b)/3.,factory_body_petrified_weight),0.,1.);
  result.rgb=mix(result.rgb,factory_body_petrified_palette[min(4,int(stone_scalar*5.))],strength);
 }else if(kind==4){
  // Steel is an actual surface finish. Existing actor normals own its shading.
  float steel_value=clamp(dot(result.rgb,vec3(.2126,.7152,.0722)),0.,1.);
  vec3 steel=mix(vec3(.20,.27,.32),vec3(.72,.79,.81),steel_value);
  float grain=texture(factory_body_metal,cell_uv*3.).r;
  result.rgb=mix(result.rgb,steel*(.92+.12*grain),strength);
 }
}
"""
	code = code.insert(insertion, treatment)
	var header := """
uniform int factory_body_count=0;
uniform int factory_body_slots[16];
uniform int factory_body_kinds[16];
uniform float factory_body_strengths[16];
uniform float factory_body_periods[16];
uniform sampler2D factory_body_bark:repeat_enable,filter_linear;
uniform sampler2D factory_body_stone:repeat_enable,filter_linear;
uniform sampler2D factory_body_petrified:repeat_enable,filter_nearest;
uniform sampler2D factory_body_metal:repeat_enable,filter_linear;
uniform vec3 factory_body_stone_palette[5];
uniform vec3 factory_body_petrified_palette[5];
uniform float factory_body_stone_gain=1.35;
uniform float factory_body_stone_repeats=6.;
uniform float factory_body_stone_weight=.18;
uniform vec2 factory_body_stone_flow=vec2(.018,-.012);
uniform float factory_body_petrified_repeats=6.;
uniform float factory_body_petrified_weight=.35;
"""
	if not code.contains("global uniform sampler2D vfx_package_clock;"):
		header += "global uniform sampler2D vfx_package_clock;\n"
	code = code.insert(code.find(";") + 1, "\n" + header)
	var shader := Shader.new()
	shader.code = code
	shader.set_meta("factory_condition_body_program", true)
	shaders[key] = shader
	return shader
