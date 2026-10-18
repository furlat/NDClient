extends "res://assets/vfx/sources/9741d79e4578df647fec/intervention.gd"
## Alternate Sunder contact fitted per row to current visible recipient depth.
## Native plume shading is retained; no body-mean plane or opaque cage.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/0b4876fb9ba8ecd707ea/sunder_clefts.gd", input)

func _paths() -> Array:
	var result: Array = []
	for cleft in 5:
		var across: float = (float(cleft) - 2.0) * frame.half_width * .34
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for index in 49:
			var progress: float = float(index) / 48.0
			# Source fragment feathers at UV .3-.9; extending its path lets that
			# native visible interval cover nearly the complete receiving height.
			var rise: float = (-.85 + progress * 1.70) * frame.height
			var split: float = sin(progress * TAU) * frame.half_width * .07
			var support: Dictionary = Frame.tangent_support(frame, frame.centre, across + split, rise)
			points.append(support.position + support.normal * .070)
			normals.append(support.normal)
		result.append(ribbon(points, normals, minf(.095, frame.half_width * .29)))
	return result
