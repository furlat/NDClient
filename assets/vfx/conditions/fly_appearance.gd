extends RefCounted
## Explicit renderer appearance-provider contract. The provider resolves Bag8
## inside the actual actor outfit and samples its current body pose/facing.
## No local sprite, independent animation, body clip or fabricated wings.
var provider: Object
var occurrence_id: int
var actor_uuid: String
var admitted:=false
var last_opacity: float=-1.0

func configure(value: Object, owner_id: int, recipient_uuid: String) -> bool:
 clear()
 if value==null or recipient_uuid.is_empty():return false
 for method in ["acquire_condition_appearance","set_condition_appearance_opacity","release_condition_appearance"]:
  if not value.has_method(method):return false
 provider=value
 occurrence_id=owner_id
 actor_uuid=recipient_uuid
 admitted=bool(provider.call("acquire_condition_appearance",occurrence_id,{
  "actor_uuid":actor_uuid,"kind":"sprite_layer",
  "layer":{"id":"fly-wings","slot":"backpack","category":"Bag8","priority":90,"alpha":0.0},
  "pose_policy":"current_actor_pose_and_facing","source_policy":"actual_modular_outfit",
  "registration_policy":"actor_outfit","body_animation_override":false}))
 return admitted

func sample(opacity: float) -> void:
 if not admitted or not is_instance_valid(provider):
  admitted=false
  return
 var value:=clampf(opacity,0.0,1.0)
 if is_equal_approx(value,last_opacity):return
 provider.call("set_condition_appearance_opacity",occurrence_id,value)
 last_opacity=value

func clear() -> void:
 if admitted and is_instance_valid(provider):
  provider.call("release_condition_appearance",occurrence_id)
 admitted=false
 provider=null
 last_opacity=-1.0
