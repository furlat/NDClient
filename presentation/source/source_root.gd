class_name PresentationSourceRoot
extends Resource
## The root of one presentation source (characters, environment or abilities):
## the single place that says what exists. Each section maps an id to its
## entry file; an entry no root lists is a build error.
@export_enum("characters", "environment", "abilities", "common") var domain: String = ""
## section name -> {id -> res path of the entry .tres}
@export var sections: Dictionary[String, Dictionary] = {}
## Small shared records that need no file of their own (palettes, looks, contexts).
@export var shared: Dictionary[String, Resource] = {}
@export var version: int = 1
