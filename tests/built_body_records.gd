extends RefCounted
## Test helper: the built body descriptors' geometry records by colour path
## (build/presentation/characters), standing in for the geometry tables the
## build replaced. files and reference are relative to the record's _source_root.
const BodySources = preload("res://presentation/body_sources.gd")

static func records(cache: Dictionary, rig: String = "neuroclient.modular") -> Dictionary:
    var result := {}
    var index: Resource = BodySources.index(cache)
    if index == null:return result
    for category in index.layers.get(rig, {}):
        var layer: Resource = BodySources.prepare_layer(index.layers[rig][category], cache)
        for clip in layer.clip_sources:
            var source: Resource = BodySources.prepare_clip(layer, clip, cache)
            for slot in source.descriptors:
                var descriptor: Dictionary = source.descriptors[slot]
                if not descriptor.geometry.is_empty() and not result.has(descriptor.path):result[descriptor.path] = descriptor.geometry
    return result
