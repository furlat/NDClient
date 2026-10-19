extends RefCounted
const Measured = preload("res://assets/vfx/conditions/measured.gd")
const Surface = preload("res://assets/vfx/conditions/surface.gd")
var children: Array = []
var entries: Array = []
var settings: Dictionary = {}
var uploads := 0
var admitted_geometry := false


func configure(visual: Node3D, specification: Dictionary, geometry: Array) -> void:
	for layer in specification.layers:
		var adapter: RefCounted = Measured.new() if layer.kind == "measured" else Surface.new()
		adapter.configure(visual,layer,geometry)
		children.append(adapter)
		entries.append_array(adapter.entries)


func update(surface: Dictionary) -> void:
	admitted_geometry = true
	var total := 0
	for child in children:
		child.update(surface)
		admitted_geometry = admitted_geometry and child.admitted_geometry
		total += int(child.uploads)
	uploads = total
