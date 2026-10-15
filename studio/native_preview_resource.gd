extends Resource
## Exact native source swatches; local derived data, never gameplay state.
@export var format_version:int=1
@export var signature:String=""
@export var specification:Dictionary={}
@export var dependencies:Dictionary={}
@export var quarter:int=0
@export var hz:float=32.0
@export var ticks:PackedInt32Array=[]
@export var textures:Array[Texture2D]=[]
@export var sizes:PackedInt32Array=[]
@export var texture_bytes:int=0
