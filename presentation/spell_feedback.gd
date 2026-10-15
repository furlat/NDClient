extends RefCounted
## Pure authored treatment shared by the sandbox and native spell adapter.
## No events, actors, source clocks or scene objects are created here.

static func prepare(recipe:Dictionary,profile:Dictionary,staging:Dictionary,policy:Dictionary)->Dictionary:
    var cast:Dictionary=recipe.get("cast",{}).duplicate(true)
    for field in ["weaponGlow","aura"]:
        if cast.get(field)!=null and cast[field].get("category","") not in policy.cast_categories:cast.erase(field)
    cast.effects=cast.get("effects",[]).filter(func(layer):return layer.get("category","") in policy.cast_categories)
    var layers:Array=[]
    if cast.get("enabled",true):
        for field in ["weaponGlow","aura"]:
            var layer:Dictionary=cast.get(field,{}) if cast.get(field)!=null else {}
            if layer.get("enabled",false) and not layer.get("hidden",false):layers.append(layer)
        for layer in cast.effects:
            if layer.get("enabled",true) and not layer.get("hidden",false):layers.append(layer)
    var damage:Dictionary=recipe.get("damage",{}) if recipe.get("damage")!=null else {}
    var flash:Dictionary=damage.get("hitFlash",{}).duplicate(true)
    var colors:Array=[]
    var authored:Array=staging.get("feedback_palette",{}).get("colors",[])
    # Factory's export quantizer is unordered. Only an explicit ordered ramp
    # replaces the recipe's existing receiver ramp.
    var ramp:Array=authored if not authored.is_empty() else profile.get("ramp",[])
    for value in ramp:colors.append(String(value).hex_to_int())
    if colors.is_empty():colors=flash.get("palette",{}).get("colors",[]).duplicate()
    for layer in layers:
        if not colors.is_empty():
            layer.palette=layer.get("palette",{}).duplicate(true)
            layer.palette.colors=colors.duplicate()
    if not flash.is_empty():
        var treatment:Dictionary=layers[0].get("palette",{}).duplicate(true) if policy.hit_flash.inherit_hand_material and not layers.is_empty() else {}
        treatment.merge(flash.get("palette",{}),true)
        treatment.colors=colors.duplicate()
        flash.palette=treatment
        for field in ["envelope","durationMs","holdMs","blendMode"]:flash[field]=policy.hit_flash[field]
    return {"cast":cast,"colors":colors,"flash":flash}
