extends Resource
## Admitted source data only. Recipients, clocks and event counts belong to the
## compiler; scene/material instances belong to their presentation occurrence.
@export var selection:Dictionary={}
@export var recipe:Dictionary={}
@export var hit:Dictionary={}
## Static diagnostic operands are admitted with this exact recipe revision.
## Occurrences retain their own applicability, participants and coverage state.
@export var requirement_source:String=""
@export var requirements:Array=[]

## Every typed alternative is retained, including explicitly undispatched
## drafts. Each selected application borrows its own immutable record.
@export var variants:Array=[]
