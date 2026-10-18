extends RefCounted
## Supplied native resolved cells only; no radius, reach, faction or area solver.
const Source=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static func topology(cells: Array) -> Dictionary:
 assert(not cells.is_empty() and cells.size()<=128,"Explicit observed footprint must contain 1–128 cells")
 var points=PackedVector2Array();var edges=PackedVector4Array();var members={};var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
 for cell in cells:
  var point=Vector2(float(cell[0]),float(cell[1]));points.append(point);members[point]=true;low=low.min(point-Vector2.ONE*.5);high=high.max(point+Vector2.ONE*.5)
 for point in points:edges.append(Vector4(0.0 if members.has(point+Vector2.LEFT) else 1.0,0.0 if members.has(point+Vector2.RIGHT) else 1.0,0.0 if members.has(point+Vector2.UP) else 1.0,0.0 if members.has(point+Vector2.DOWN) else 1.0))
 var count=points.size()
 while points.size()<128:points.append(Vector2.ZERO);edges.append(Vector4.ZERO)
 return {"points":points,"edges":edges,"count":count,"minimum":low,"maximum":high}
static func bind(material: ShaderMaterial,cells: Array) -> void:
 var code=material.shader.code.replace("shader_type spatial;","""shader_type spatial;
varying vec3 payload_actual_world;
uniform vec3 payload_footprint_origin=vec3(0.0);
uniform vec2 payload_cells[128];
uniform vec4 payload_open_edges[128];
uniform int payload_cell_count=0;
float payload_membership(vec2 point){
 float coverage=0.0;
 for(int i=0;i<128;i++){
  if(i>=payload_cell_count)break;
  vec2 relative=point-payload_cells[i];vec2 distance=abs(relative);vec4 edges=payload_open_edges[i];
  float edge_x=relative.x<0.0?edges.x:edges.y;float edge_y=relative.y<0.0?edges.z:edges.w;
  float inside=1.0-step(0.50001,max(distance.x,distance.y));
  float soft_x=mix(1.0,smoothstep(0.015,0.13,0.5-distance.x),edge_x);
  float soft_y=mix(1.0,smoothstep(0.015,0.13,0.5-distance.y),edge_y);
  vec2 corner=max(distance-vec2(0.25),vec2(0.0));float rounding=1.0-smoothstep(0.20,0.25,length(corner));
  coverage=max(coverage,inside*soft_x*soft_y*mix(1.0,rounding,edge_x*edge_y));
 }
 return coverage;
}
""")
 var record="\nvec4 payload_world4=MODEL_MATRIX*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;\n"
 if code.contains("void vertex()"):code=Source.finish_function(code,"vertex",record)
 else:code+="\nvoid vertex(){"+record+"}\n"
 code=Source.finish_fragment(code,"\nALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);set_cells(material,cells)
static func set_cells(material: ShaderMaterial,cells: Array) -> void:
 var data=topology(cells);material.set_shader_parameter("payload_cells",data.points);material.set_shader_parameter("payload_open_edges",data.edges);material.set_shader_parameter("payload_cell_count",data.count)
static func move(material: ShaderMaterial,origin: Vector3) -> void:material.set_shader_parameter("payload_footprint_origin",origin)
static func plane(cells: Array) -> PlaneMesh:
 var data=topology(cells);var mesh=PlaneMesh.new();mesh.size=data.maximum-data.minimum;mesh.center_offset=Vector3((data.minimum.x+data.maximum.x)*.5,.02,(data.minimum.y+data.maximum.y)*.5);mesh.subdivide_width=32;mesh.subdivide_depth=32;return mesh
