extends SceneTree
const Graphs = preload("res://animation/graphs.gd")
const Catalog = preload("res://source_catalog.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var rig = Catalog.read_file("catalog/rigs.json",{})["neuroclient.modular"]
    var actor = Graphs.build_character(root,rig)
    Graphs.save_scene(actor,"res://generated/modular_animation.tscn")
    var prop = Graphs.build_destruction(root,1.0)
    Graphs.save_scene(prop,"res://generated/destruction_animation.tscn")
    print("Native AnimationPlayer / AnimationTree scenes saved from source clocks.")
    quit()
