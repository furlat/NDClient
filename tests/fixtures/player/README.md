These unchanged initialization/operation bytes came from the amber seat of a
real native `combat_configuration("ranged", ..., seed=2)` encounter, captured by
headless Godot on 11 October 2026. They contain no bearer credential. The journal
tests use them as real protocol inputs and make explicit corruptions to exercise
rejection and recovery; expected gameplay state comes from the Python oracle.

Their original pre-source-lighting schema identity is retained. The journal test
opens them only through explicit offline historical replay and also checks that
current live admission rejects this old identity; no capture bytes are retagged.
