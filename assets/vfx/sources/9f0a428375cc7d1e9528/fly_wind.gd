extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Exact native/fly/source/{0,1} selected components at their authored .6 scale.
## No actor body or invented wing geometry is built by this component.
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_9f0a428375.resource("res://assets/vfx/sources/9f0a428375cc7d1e9528/fly_wind.gd").new()
 node.definition=input.duplicate(true)
 return node

const VfxPackageIO_9f0a428375 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
