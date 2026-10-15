extends RefCounted
## Installed Pygame region artwork, evaluated on the shared presentation clock.
## Regions and persistent contributions are admitted server values, never fitted
## to an actor, a light, or an inferred receiving plane.
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")

static func asset(cache:Dictionary)->Dictionary:
    return Catalog.read_file("catalog/action_media_assets.json",cache).get("particles.region.blood",{})

static func key(point:Array)->String:return "%d,%d"%point

static func residue(tile:Dictionary)->Dictionary:
    for value in tile.get("residues",[]):
        if value.residue_id=="residue.blood":return value
    return {}

static func even_round(value:float)->int:
    var lower=int(floor(value));var fraction=value-lower
    return lower if fraction<.5 or (fraction==.5 and posmod(lower,2)==0) else lower+1

static func template(style:Dictionary,ellipse:Dictionary)->Dictionary:
    var index=even_round(ellipse.center[0]*100)*31+even_round(ellipse.center[1]*100)*17
    return style.templates[posmod(index,style.templates.size())]

static func landing(ellipse:Dictionary,target:Array)->Vector2:
    return Vector2(target[0]*ellipse.radius_x,target[1]*ellipse.radius_y).rotated(ellipse.angle)+Vector2(ellipse.center[0],ellipse.center[1])

static func schedule(particle:Dictionary,family:Dictionary,copy:int=0)->Vector2:
    return Vector2(particle.delay*family.delayScale,particle.duration*family.durationScale*(1.08 if copy else 1.0))

static func duration(release:Dictionary,source:Dictionary)->float:
    var result=0.0;var style:Dictionary=source.region
    if not style.families.has(release.get("pattern")):return result
    var copies=int(style.get("criticalCopies",2)) if release.get("critical_hit",false) else 1
    for region in release.regions:
        for particle in template(style,region.ellipse).particles:
            for copy in copies:
                var times=schedule(particle,style.families[release.pattern],copy)
                result=maxf(result,times.x+times.y)
    return result*1000.0

static func reveals(group:Dictionary,node:Dictionary,initial:Dictionary,previous:Dictionary)->Array:
    var current=initial.duplicate()
    for commit in group.commits:
        for cell in commit.delta.get("tiles",{}):
            if initial.has(cell):current[cell]=commit.delta.tiles[cell]
        if commit.event_uuid==node.uuid:break
    var result:Array=[]
    for region in node.fact.body_release.regions:
        for point in region.positions:
            var cell=key(point)
            if not current.has(cell):continue
            var before=residue(previous.get(cell,initial.get(cell,{})))
            var after=residue(current[cell])
            if after.is_empty():continue
            if after.get("amount",0)>before.get("amount",0):
                result.append({"position":point,"before":before,"after":after,"elevation_steps":current[cell].get("elevation_steps",region.elevation_steps)})
            previous[cell]=current[cell]
    return result

static func particles(component:Dictionary,source:Dictionary,age_seconds:float)->Array:
    if not component.get("flight_enabled",true):return []
    var release:Dictionary=component.body_release;var style:Dictionary=source.region
    if not style.families.has(release.get("pattern")):return []
    var start=Vector2(component.position[0],component.position[1])
    var start_height=float(component.elevation_steps)+float(style.get("sourceHeight",.65))
    var copies=int(style.get("criticalCopies",2)) if release.get("critical_hit",false) else 1
    var result:Array=[];var region_index=0
    for region in release.regions:
        var allowed={}
        for point in region.positions:allowed[key(point)]=true
        var selected=template(style,region.ellipse)
        for particle in selected.particles:
            var goal=landing(region.ellipse,particle.target)
            if not allowed.has(key([floori(goal.x+.5),floori(goal.y+.5)])):continue
            for copy in copies:
                var times=schedule(particle,style.families[release.pattern],copy)
                var t=age_seconds-times.x
                if t<0 or t>=times.y:continue
                var velocity=(goal-start)/times.y
                var vertical=(region.elevation_steps-start_height+.5*particle.gravity*times.y*times.y)/times.y
                var point=start+velocity*t
                var height=start_height+vertical*t-.5*particle.gravity*t*t
                var previous=point-velocity*source.tailSeconds
                var old_height=height-(vertical-particle.gravity*t)*source.tailSeconds
                result.append({"id":(region_index*selected.particles.size()+int(particle.id))*copies+copy,
                    "position":point,"height":height,"previous":previous,"previous_height":old_height,
                    "size":particle.size,"support_height":region.elevation_steps,"goal":goal})
        region_index+=1
    return result

static func contribution_amount(value:Dictionary,ellipses:Array)->float:
    for contribution in value.get("contributions",[]):
        if contribution.ellipses==ellipses:return float(contribution.amount)
    return 0.0

static func prepare_landing(cache:Dictionary,reveal:Dictionary,pattern:String)->void:
    # Both finite amounts have already been prepared by the received-shape
    # worker. Keep only particles with a shape in this tile at either amount.
    # Multiple simultaneous reveals retain the general evaluator below.
    cache.erase("landing")
    var value:Dictionary=cache.value;var source:Dictionary=cache.source
    var position:Array=cache.position;var family:Dictionary=source.region.families.get(pattern,{})
    if family.is_empty():return
    var rows:Array=[];var ordinal:int=0
    for contribution in value.get("contributions",[]):
        var after=contribution_amount(reveal.after,contribution.ellipses)
        var before=contribution_amount(reveal.before,contribution.ellipses)
        var changed:bool=after>before and contribution.amount>=after
        var full=float(contribution.amount)
        var initial=full-(after-before) if changed else full
        var before_fraction=maxf(0.,initial)/float(value.max_amount)
        var after_fraction=maxf(0.,full)/float(value.max_amount)
        for ellipse in contribution.ellipses:
            var world=ellipse.duplicate();world.center=[ellipse.center[0]+position[0],ellipse.center[1]+position[1]]
            for particle in template(source.region,world).particles:
                var shapes:Dictionary=cache.particles.get(ordinal,{})
                # Missing preparation is not an empty clipped shape. Keep the
                # general evaluator if either finite amount was not prepared.
                if (before_fraction>0. and not shapes.has(before_fraction)) or (after_fraction>0. and not shapes.has(after_fraction)):return
                var first:Array=shapes.get(before_fraction,[])
                var last:Array=shapes.get(after_fraction,[])
                if not first.is_empty() or not last.is_empty():
                    var time= schedule(particle,family) if changed else Vector2(-INF,0.)
                    rows.append([time.x+time.y,first,last])
                ordinal+=1
    cache.landing={"before":reveal.before,"after":reveal.after,"pattern":pattern,"rows":rows}

static func kernels(value:Dictionary,position:Array,active:Array,source:Dictionary,cache:Dictionary={}) -> Array:
    # Residue after-values are immutable. Each field keeps only its current
    # value's exact particle shapes; a new value/source discards those shapes.
    if not is_same(cache.get("value"),value) or cache.get("position")!=position or not is_same(cache.get("source"),source):
        cache.clear();cache.merge({"value":value,"position":position.duplicate(),"source":source,"particles":{}})
    var prepared:Dictionary=cache.get("landing",{})
    if active.size()==1 and not prepared.is_empty():
        var reveal:Dictionary=active[0]
        if reveal.pattern==prepared.pattern and (is_same(reveal.before,prepared.before) or reveal.before==prepared.before) \
                and (is_same(reveal.after,prepared.after) or reveal.after==prepared.after):
            var landed:Array=[];var age:float=reveal.age_seconds
            for row in prepared.rows:landed.append_array(row[1] if age<row[0] else row[2])
            return landed
    var result:Array=[];var style:Dictionary=source.region;var ordinal:int=0
    for contribution in value.get("contributions",[]):
        # Matching whole ellipse lists once per contribution is equivalent to
        # repeating it for every particle in every receiving tile.
        var changes:Array=[]
        for reveal in active:
            var after=contribution_amount(reveal.after,contribution.ellipses)
            var before=contribution_amount(reveal.before,contribution.ellipses)
            if after<=before or contribution.amount<after:continue
            var family:Dictionary=style.families.get(reveal.pattern,{})
            if not family.is_empty():changes.append({"family":family,"age":reveal.age_seconds,"amount":after-before})
        for ellipse in contribution.ellipses:
            var world=ellipse.duplicate();world.center=[ellipse.center[0]+position[0],ellipse.center[1]+position[1]]
            var selected=template(style,world)
            var ellipse_transform=Transform2D(Vector2(cos(ellipse.angle),sin(ellipse.angle))*ellipse.radius_x,
                Vector2(-sin(ellipse.angle),cos(ellipse.angle))*ellipse.radius_y,Vector2(ellipse.center[0],ellipse.center[1]))
            for particle in selected.particles:
                var index:int=ordinal;ordinal+=1
                var units=float(contribution.amount)
                for change in changes:
                    var times=schedule(particle,change.family)
                    if change.age<times.x+times.y:units-=change.amount
                var fraction=maxf(0,units)/float(value.max_amount)
                if fraction<=0:continue
                if not cache.particles.has(index):cache.particles[index]={}
                var shapes:Dictionary=cache.particles[index]
                if shapes.has(fraction):
                    result.append_array(shapes[fraction]);continue
                var landed:Array=[]
                var scale=sqrt(fraction);var target=Vector2(particle.target[0],particle.target[1])
                for kernel in particle.kernels:
                    var center=target+(Vector2(kernel.x,kernel.y)-target)*scale
                    var local=Transform2D(Vector2(cos(kernel.angle),sin(kernel.angle))*kernel.rx*scale,
                        Vector2(-sin(kernel.angle),cos(kernel.angle))*kernel.ry*scale,center)
                    var transformed=ellipse_transform*local
                    var extent=(transformed.x.abs()+transformed.y.abs())*sqrt(1.5)
                    if not Rect2(transformed.origin-extent,extent*2.).intersects(Rect2(Vector2(-.5,-.5),Vector2.ONE)):continue
                    landed.append({"transform":transformed,"mass":kernel.mass})
                shapes[fraction]=landed;result.append_array(landed)
    return result

static func landing_step(source:Dictionary,pattern:String,age:float)->int:
    var count=0
    for selected in source.region.templates:
        for particle in selected.particles:
            var times=schedule(particle,source.region.families[pattern])
            if age>=times.x+times.y:count+=1
    return count

static func has_coverage(kernels:Array)->bool:
    # Conservative native-coverage witness. At the nearest source texel to an
    # authored kernel center, its own additive density exceeds the maximum
    # liquid threshold even at the minimum noise multiplier. Other kernels can
    # only add density. Empty/clipped/subpixel fields never claim a rendered dot.
    for kernel in kernels:
        var transform:Transform2D=kernel.transform
        var pixel=(transform.origin+Vector2(.5,.5))*64.
        var sample=(pixel.floor()+Vector2(.5,.5))/64.-Vector2(.5,.5)
        if sample.x<-.5 or sample.x>=.5 or sample.y<-.5 or sample.y>=.5:continue
        var local=transform.affine_inverse()*sample
        var q=local.length_squared()
        if q<1.5 and kernel.mass*pow(1.-q/1.5,2.)*.72>.1525:return true
    return false
