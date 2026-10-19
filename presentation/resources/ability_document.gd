extends Resource
## One runtime record table the presentation build writes from the abilities
## source (build/presentation/abilities/docs/...): the same data the old
## authoring document held, so readers keep their shape. `items` holds a
## document that is a list.
@export var data: Dictionary = {}
@export var items: Array = []
@export var is_list: bool = false
