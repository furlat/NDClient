extends Node3D
## A source swatch owns the same renderer and admitted occurrence values. It
## never submits commands or changes a live/Studio Timeline's canonical state.
const Renderer=preload("res://presentation/blood_renderer.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
var renderer=Renderer.new()
var source_lighting=Lighting.new()
var catalog_cache:Dictionary={}
var timeline:Dictionary={"state":{"tiles":{},"senses":{}},"current":null,"queue":[],"world_revision":0}
var scenery_visible_cells:Dictionary={}
var camera:Camera3D
var visual_actors:Dictionary={}
var actor_entries:Array=[]
var draw_order_dirty=false
var light_cap_enabled=false
var normals_visible=false
var samples:Array=[]
func configure(component:Dictionary,cache:Dictionary,age_ms:float,quarter:int,lighting:RefCounted)->void:
    catalog_cache=cache;source_lighting=lighting
    camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.5;camera.current=true;add_child(camera)
    camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
    camera.position=Vector3(component.position[0],.4,component.position[1])+camera.basis.z*12.
    for reveal in component.reveals:
        var key=Renderer.Blood.key(reveal.position)
        timeline.state.tiles[key]={"position":reveal.position,"elevation_steps":reveal.elevation_steps,"residues":[reveal.after]}
        scenery_visible_cells[key]=true
    var sampled=component.duplicate();sampled.age_ms=age_ms
    samples=[sampled]
    sample()
    for page in renderer.pages.values():
        for child in page.view.get_children():
            if child is CanvasModulate:child.color=Color.WHITE
    # Swatch uses the same floor/air ordering, with no unrelated scene actors.
    for entry in actor_entries:entry.material.render_priority=0 if entry.role=="covering" else 1
func sample()->void:renderer.sample(self,samples)
func close()->void:renderer.close(self)
