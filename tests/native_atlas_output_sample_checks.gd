extends "res://tests/native_atlas_growth_checks.gd"
## Prepared output samples are publication operands, not a claim that the live
## source stayed unchanged. Compare the actual first receiving/output draw.

func publish(side:Dictionary,full:bool,upserts:Array)->void:
    var base:int=side.serial;side.serial+=1
    var receipt={"base":base,"serial":side.serial,"full":full,"upserts":upserts,"removed":[]}
    # Same four-field producer stamp shape as gameplay: a sparse static source
    # cannot rely on the reference fixture's deliberate full restyle polling.
    side.atlas.sync(side.world,[side.serial],[side.serial,0,0,"solid"],receipt,true)
    side.atlas.sync_output(side.world,[side.serial],true)

func output_case(cap:bool,normals:bool,mode:String)->void:
    var label:String="output-sample-"+("normals" if normals else "capped" if cap else "ldr")+"-"+mode
    var side:Dictionary=make_side(pair_source(),cap,normals)
    var reference:Dictionary={}
    publish(side,true,side.world.entries)
    if DisplayServer.get_name()!="headless":
        reference=make_side(pair_source(),cap,normals)
        publish(reference,true,reference.world.entries)
    var entry:Dictionary=side.world.entries[2]
    var tint=Color(.4,.8,.6,1)
    if mode=="retained_group_lags":
        SourceMaterial.set_parameter(entry,"source_tint",tint)
        if not reference.is_empty():SourceMaterial.set_parameter(reference.world.entries[2],"source_tint",tint)
    var snapshot:Dictionary=entry.duplicate()
    if mode=="future_visibility":snapshot.scenery_value=0.0
    var prepared:Dictionary=side.atlas.prepare_source_binding(entry,snapshot,side.world,true)
    var sample:Dictionary=prepared.output.sample
    check(sample.is_read_only(),label+" captured sample is immutable")
    check(sample.version==snapshot.source_version and sample.highlighted==SourceMaterial.value(entry,"highlighted")
        and sample.seconds==null and sample.visibility==snapshot.scenery_value
        and sample.material==entry.material and sample.shader==entry.material.shader
        and sample.binding_revision==entry.source_binding_revision,
        label+" sample contains the exact source/style operands that produced the private output")
    var bindings:Dictionary={entry.node.get_instance_id():prepared}
    var jobs:Array=[{"entry":entry,"prepared":prepared,"packet":{},"rows":[entry.placement]}]
    var prefix:Dictionary=Atlas.Delta.begin_candidate(side.atlas,jobs,{},side.world)
    while not Atlas.Delta.capture_candidate(side.atlas,prefix,side.world):pass
    Atlas.Delta.compute_candidate(prefix)
    while not Atlas.Delta.prepare_candidate_binding(side.atlas,prefix,bindings):pass
    check(prefix.get("error","")=="" and prefix.get("bound",false),label+" exact private binding is complete")
    if mode=="changed_after_prepare":
        SourceMaterial.set_parameter(entry,"source_tint",tint)
        SourceMaterial.set_parameter(entry,"highlighted",true)
        if not reference.is_empty():
            SourceMaterial.set_parameter(reference.world.entries[2],"source_tint",tint)
            SourceMaterial.set_parameter(reference.world.entries[2],"highlighted",true)
    elif mode=="hover_after_prepare":
        SourceMaterial.set_parameter(entry,"highlighted",true)
        if not reference.is_empty():SourceMaterial.set_parameter(reference.world.entries[2],"highlighted",true)
    elif mode=="future_visibility":
        SourceMaterial.set_parameter(entry,"current_visibility",snapshot.scenery_value)
        if not reference.is_empty():SourceMaterial.set_parameter(reference.world.entries[2],"current_visibility",snapshot.scenery_value)
    if mode in ["changed_after_prepare","hover_after_prepare","future_visibility"]:
        check(sample.version<entry.source_version,label+" future source mutation cannot rewrite the captured version")
    else:
        check(sample.version==snapshot.source_version,label+" version remains the captured value")
    check(Atlas.Delta.candidate_base_matches(side.atlas,prefix,side.world),label+" source/style changes preserve the structural admission proof")
    prefix.admitted=true
    check(side.atlas.adopt_source_binding(prepared),label+" exact private owner is adopted")
    side.atlas.prepared_delta=prefix
    entry.scenery_value=snapshot.scenery_value
    if not reference.is_empty():reference.world.entries[2].scenery_value=snapshot.scenery_value
    publish(side,false,[entry])
    if not reference.is_empty():publish(reference,true,reference.world.entries)
    check(side.atlas.errors.is_empty() and side.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
        label+" publication consumes the prepared transaction")
    var receiver:Dictionary=row_receiver(side.atlas,entry)
    var source:Dictionary=side.atlas.entry_specs[entry.node.get_instance_id()]
    check(receiver.visibility==snapshot.scenery_value and source.sync_visibility==entry.scenery_value,
        label+" selected visibility and final current sample agree")
    check(source.sync_version==entry.source_version and source.sync_highlighted==SourceMaterial.value(entry,"highlighted"),
        label+" the final synchronization stamp describes actual current source values")
    if mode in ["retained_group_lags","changed_after_prepare"]:
        check(receiver.group.material.get_shader_parameter("source_tint")==tint,
            label+" current source tint reaches even a retained receiving group")
    if mode in ["changed_after_prepare","hover_after_prepare"]:
        check(receiver.group.material.get_shader_parameter("highlighted")==true,
            label+" post-preparation hover reaches the current receiving group")
        if cap and not normals:
            check(entry.received_material.get_shader_parameter("highlighted")==true,
                label+" post-preparation hover reaches the capped output")
    if mode in ["hover_after_prepare","future_visibility"]:
        check(side.atlas.last_reconcile_phases.get("material_sample_versions",0)>0
            and side.atlas.last_reconcile_phases.get("material_parameter_copies",0)==0,
            label+" explicit style ownership advances source versions without empty generic parameter copies")
    if not reference.is_empty():await first_draw(side,reference,label)
    if mode=="unchanged":
        entry.scenery_value=.25;side.atlas.style_changed(entry)
        side.atlas.sync(side.world,[side.serial],[side.serial,0,0,"solid"],{},true)
        receiver=row_receiver(side.atlas,entry)
        check(receiver.visibility==.25 and source.sync_visibility==.25,
            label+" a subsequent visibility change uses ordinary style/source synchronization")
        if cap and not normals:
            check(entry.received_material.get_shader_parameter("current_visibility")==.25,
                label+" a subsequent visibility change reaches the capped output")
    if not reference.is_empty():reference.atlas.close();reference.view.queue_free()
    side.atlas.close();side.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    for render_mode in [[false,false],[true,false],[true,true]]:
        for mode in ["unchanged","future_visibility","retained_group_lags","changed_after_prepare","hover_after_prepare"]:
            await output_case(render_mode[0],render_mode[1],mode)
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"Captured static source/style publication operands; old retained receiving groups, post-preparation hover/tint and future/current visibility. Native runs compare the first received cells and final framebuffer against the complete planner. No performance claim."}
    if DisplayServer.get_name()!="headless":FileAccess.open("res://generated/native_atlas_output_sample_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_OUTPUT_SAMPLE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
