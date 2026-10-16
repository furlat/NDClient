extends Resource
## Paths keep the catalog lazy: loading this cannot load textures or scenes.
@export var spells:Dictionary={}
@export var conditions:Dictionary={}
@export var asset_metadata:Dictionary={}
@export var fact_requirements:Dictionary={}
@export var revision:String=""
