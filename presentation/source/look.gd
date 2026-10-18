class_name PresentationLook
extends Resource
## One vocabulary for every colour, material and layer change ("swap"): a look
## is an ordered list of steps; each step kind is one runtime shader feature.
const Step = preload("res://presentation/source/look_step.gd")
@export var id: String = ""
@export var steps: Array[Step] = []
