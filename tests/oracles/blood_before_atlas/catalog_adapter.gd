extends RefCounted
## Test-only API closure for f77f83d1's single original residue source lookup.
## The producer's immutable region artwork is unchanged; only its Resource
## owner moved from generic NativePresentationSources to the environment index.
## All field math, kernels, timing, geometry and shaders remain the old source.
const Catalog=preload("res://source_catalog.gd")
static func asset(id:String,cache:Dictionary)->Dictionary:
    if id!="particles.region.blood":push_error("The frozen blood oracle has no other asset");return {}
    return Catalog.residue_asset(cache)
static func prepared_asset(id:String,cache:Dictionary)->Dictionary:
    if id!="particles.region.blood":push_error("The frozen blood oracle has no other prepared asset");return {}
    return Catalog.prepared_residue_asset(cache)
