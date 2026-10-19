extends RefCounted
## Exact packed sRGB operand decoding, not palette finishing or CIE remapping.
## Same arithmetic as the pinned renderer, without its unrelated catalog IO.
static func rgb(value: int) -> Vector3:
	return Vector3((value >> 16) & 255, (value >> 8) & 255, value & 255) / 255.0
