extends RefCounted
## Resource readiness followed by the exact existing live-wall factory.
## The returned Node is the original controller; no geometry/source copy.
const Original = preload("res://assets/vfx/extensions/production-review-20261020/sources/8cae7b7f38ac851d8084/wind.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.wind_bank)]


static func make_component(input: Dictionary) -> Node3D:
	return Original.make_component(input)
