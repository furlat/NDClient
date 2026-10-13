extends "res://tests/sdk_transport_peer.gd"
# Reuse the existing real TCP bootstrap/attachment peer. Only this response is
# supplied by the choices trust-boundary fixture; no HTTPClient is mocked.
var choices_body: Dictionary={}
var reply_case="valid"

func _serve(connection: Dictionary,path: String,body: Variant) -> void:
    if not path.ends_with("/choices"):
        super._serve(connection,path,body)
        return
    var value=choices_body.duplicate(true)
    value.merge(scope(),true)
    value.state_revision=body.state_revision
    value.correlation_id=body.correlation_id
    value.force_attack=body.force_attack
    value.choices.entity_uuid=body.actor_uuid
    match reply_case:
        "trusted_body": value.choices.entity_actions[0].trusted_fixture_marker="nested server data"
        "foreign_game": value.game_id="foreign"
        "foreign_epoch": value.game_epoch="00000000-0000-4000-8000-000000000002"
        "foreign_audience": value.audience_id="00000000-0000-4000-8000-000000000002"
        "wrong_actor": value.choices.entity_uuid="00000000-0000-4000-8000-000000000002"
        "wrong_revision": value.state_revision="another revision"
        "wrong_correlation": value.correlation_id="00000000-0000-4000-8000-000000000002"
        "wrong_force": value.force_attack=not body.force_attack
        "invalid_actor": value.choices.entity_uuid="not a UUID"
        "invalid_family": value.choices.entity_actions={}
    _response(connection,value)
