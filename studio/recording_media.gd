extends RefCounted
## Exact admitted recording sources, prepared by the Studio loader worker.
## Residency, budget selection, decoding and upload stay in MediaWarmup.
const MediaWarmup=preload("res://presentation/media_warmup.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const EncounterMedia=preload("res://presentation/encounter_media.gd")
const Catalog=preload("res://source_catalog.gd")
const Compiler=preload("res://presentation/compiler.gd")

static func plan(index:Dictionary)->Dictionary:
    var cache=Catalog.source_snapshot(index.cache)
    var groups:Array=index.groups.map(func(item):return item.group)
    var actors=MediaWarmup.plan(index.initialization.state,groups,cache)
    # The prefix walk below already collects every later group's environment.
    # An all-groups walk here duplicated it and then rewound its mutable index.
    var world=EnvironmentMedia.plan(index.initialization.state,groups.slice(0,1),cache)
    var priority:Dictionary=actors.required.duplicate()
    priority.merge(world.required)
    var paths=priority.duplicate()
    paths.merge(actors.upcoming);paths.merge(world.upcoming)
    var environment:Dictionary=world.required.duplicate()
    environment.merge(world.upcoming)
    var cpu_required:Dictionary=actors.cpu_required.duplicate()
    cpu_required.merge(environment)
    var gpu_only:Dictionary=actors.gpu_only.duplicate()
    # Each replay cut can cross several groups. Prepare their closures against
    # their own admitted prefixes now, without putting all of them in residency.
    var group_plans={}
    var prefix:Dictionary=index.initialization.state.duplicate(true)
    for group in groups:
        var character=MediaWarmup.plan(prefix,[group],cache)
        var surroundings=EnvironmentMedia.plan(prefix,[group],cache)
        var exact={"character":character.required,"environment":surroundings.required,
            "fixtures":surroundings.fixtures,"errors":character.errors}
        exact.merge(MediaWarmup.roles_for(character,character.required))
        var publication:Dictionary={"source_records":MediaWarmup.source_records(character,surroundings,[group],cache),
            "required":character.required,"normal_sets":character.normal_sets,
            "character_timeline":character.character_timeline,"environment_timeline":surroundings.environment_timeline,
            "source_sizes":{}}
        MediaWarmup._source_publications(publication,cache)
        exact.source_records=publication.source_records[group.id]
        exact.source_cuts=publication.source_cuts[group.id]
        exact.source_families=publication.source_families[group.id]
        exact.character_profiles=publication.character_profiles[group.id]
        exact.character_timeline=character.character_timeline[group.id]
        exact.environment_timeline=surroundings.environment_timeline[group.id]
        exact.cpu_required.merge(surroundings.required)
        for path in exact.cpu_required:exact.gpu_only.erase(path)
        group_plans[group.id]=exact
        paths.merge(exact.character);paths.merge(exact.environment)
        environment.merge(exact.environment);world.fixtures.merge(exact.fixtures)
        cpu_required.merge(exact.cpu_required);gpu_only.merge(exact.gpu_only)
        for commit in group.commits:Compiler.apply_delta(prefix,commit.delta)
    for path in cpu_required:gpu_only.erase(path)
    for path in paths:paths[path]=Catalog.media_path(path)
    for path in priority:priority[path]=paths[path]
    var errors:Array=actors.errors.duplicate()
    errors.append_array(actors.upcoming_errors)
    for exact in group_plans.values():
        for issue in exact.errors:
            if issue not in errors:errors.append(issue)
    var result={"revision":1,"paths":paths,"priority":priority,"environment":environment,"fixtures":world.fixtures,
        "cpu_required":cpu_required,"gpu_only":gpu_only,"errors":errors,"group_plans":group_plans}
    result.estimates=EncounterMedia.estimates(paths,cpu_required,gpu_only,cache)
    result.estimate_bytes=EncounterMedia.estimate_bytes(result.estimates)
    result.estimate_summary=EncounterMedia.estimate_summary(result)
    for estimate in result.estimates.values():
        if estimate.has("error"):errors.append(estimate.error)
    result.ordered_paths=paths.keys();result.ordered_paths.make_read_only()
    result.source_files=Catalog.source_snapshot(cache)
    return result
