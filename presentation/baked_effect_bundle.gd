extends Resource
## One baked native clip (tools/bake_native_effects.gd). The scene has no
## AnimationPlayer, script, collision shape or particle simulation: emitters
## play recorded particle states, and the few node and material values that
## change over source time are recorded per frame.
@export var clip_id:String=""
@export var version:int=1
## Hash of the clip definition the recording was made from.
@export var clip_hash:String=""
@export var rate:float=60.0
@export var frames:int=1
@export var seconds:float=0.0
@export var scene:PackedScene
## {path:String, vat:Texture2D, amount:int}
@export var systems:Array=[]
## {kind:"node"|"material", path:String (node) or material:int, property:String, values:Array, blend:bool}
@export var tracks:Array=[]
## Material indices (BakedEffect.material_locations order) copied per occurrence.
@export var private_materials:Array=[]
## Parts of the source the recording does not reproduce (reported, not hidden).
@export var gaps:Array=[]
