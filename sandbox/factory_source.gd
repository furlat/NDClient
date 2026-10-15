extends "res://presentation/native_factory_source.gd"
## Offline sandbox construction keeps its existing synchronous source API.
## Production callers admit prepared resources through Factory.prepare first.
const SharedFactory=preload("res://presentation/native_factory_source.gd")

static func make(parent:Node3D,clip:Dictionary,layer_mask:int=DEFAULT_LAYER,use_prepared:bool=false)->Dictionary:
    return SharedFactory.make(parent,clip,layer_mask,use_prepared)
