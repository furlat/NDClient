extends RefCounted
## Installed Pygame region artwork, evaluated on the shared presentation clock.
## Regions and persistent contributions are admitted server values, never fitted
## to an actor, a light, or an inferred receiving plane.
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")

static func asset(cache:Dictionary,residue_id:String="residue.blood")->Dictionary:
    return Catalog.residue_asset(cache,residue_id)

static func bindings(cache:Dictionary)->Dictionary:
    return Catalog.read_file("catalog/body_release_media.json",cache)

static func binding(release:Dictionary,cache:Dictionary)->Dictionary:
    return bindings(cache).get(str(release.get("release_id","")),{})

static func residue_ids(cache:Dictionary)->Array:
    var result:Array=[]
    for selected in bindings(cache).values():
        if selected is Dictionary and not str(selected.get("residue_id","")).is_empty() and selected.residue_id not in result:result.append(selected.residue_id)
    for id in Catalog.environment_index(cache).get("residue_sources",{}):
        if id not in result:result.append(id)
    return result

static func key(point:Array)->String:return "%d,%d"%point

## Preserve the existing blood draw keys; additional materials own independent
## private fields in the same pool, never another canonical tile or UUID.
static func field_key(point:Array,residue_id:String="residue.blood")->String:
    return field_id(key(point),residue_id)

static func field_id(cell:String,residue_id:String="residue.blood")->String:
    return cell+("|"+residue_id if residue_id!="residue.blood" else "")

static func field_cell(id:String)->String:return id.get_slice("|",0)
static func field_residue(id:String)->String:return id.get_slice("|",1) if id.contains("|") else "residue.blood"

static func residue(tile:Dictionary,residue_id:String="residue.blood")->Dictionary:
    for value in tile.get("residues",[]):
        if value.residue_id==residue_id:return value
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

static func reveals(group:Dictionary,node:Dictionary,initial:Dictionary,previous:Dictionary,residue_id:String="residue.blood")->Array:
    var current=initial.duplicate()
    for commit in group.commits:
        for cell in commit.delta.get("tiles",{}):
            if initial.has(cell):current[cell]=commit.delta.tiles[cell]
        if commit.event_uuid==node.id:break
    var result:Array=[]
    for region in node.fact.body_release.regions:
        for point in region.positions:
            var cell=key(point)
            if not current.has(cell):continue
            var before=residue(previous.get(cell,initial.get(cell,{})),residue_id)
            var after=residue(current[cell],residue_id)
            if after.is_empty():continue
            var receives:bool=after.get("amount",0)>before.get("amount",0) or after.get("condition_uuid")!=before.get("condition_uuid")
            if not receives:
                for contribution in after.get("contributions",[]):
                    if float(contribution.amount)>contribution_amount(before,contribution.ellipses):receives=true;break
            if receives:
                result.append({"position":point,"before":before,"after":after,"elevation_steps":current[cell].get("elevation_steps",region.elevation_steps)})
            previous[cell]=current[cell]
    return result

static func flight_plan(component:Dictionary,source:Dictionary)->Array:
    # The age-independent half of particles(): every authored particle copy
    # that lands in a released tile, in emission order, with its schedule.
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
                var velocity=(goal-start)/times.y
                var vertical=(region.elevation_steps-start_height+.5*particle.gravity*times.y*times.y)/times.y
                var fragment:=PackedVector2Array()
                if style.get("primitive")=="fragments":
                    for vertex in particle.get("fragment",[]):fragment.append(landing(region.ellipse,vertex)-goal)
                result.append([times.x,times.y,velocity,vertical,particle.gravity,(region_index*selected.particles.size()+int(particle.id))*copies+copy,particle.size,region.elevation_steps,goal,fragment])
        region_index+=1
    return result

static func particles(component:Dictionary,source:Dictionary,age_seconds:float,plan=null)->Array:
    # A caller that keeps the component's flight_plan() evaluates only age.
    if plan==null:plan=flight_plan(component,source)
    if plan.is_empty():return []
    var start=Vector2(component.position[0],component.position[1])
    var start_height=float(component.elevation_steps)+float(source.region.get("sourceHeight",.65))
    var result:Array=[]
    for row in plan:
        var t=age_seconds-row[0]
        if t<0 or t>=row[1]:continue
        var velocity:Vector2=row[2];var vertical=row[3];var gravity=row[4]
        var point=start+velocity*t
        var height=start_height+vertical*t-.5*gravity*t*t
        var previous=point-velocity*source.tailSeconds
        var old_height=height-(vertical-gravity*t)*source.tailSeconds
        result.append({"id":row[5],"position":point,"height":height,"previous":previous,"previous_height":old_height,
            "size":row[6],"support_height":row[7],"goal":row[8],"fragment":row[9] if row.size()>9 else PackedVector2Array()})
    return result

static func contribution_amount(value:Dictionary,ellipses:Array)->float:
    for contribution in value.get("contributions",[]):
        if contribution.ellipses==ellipses:return float(contribution.amount)
    return 0.0

static func before_contribution(reveal:Dictionary,ellipses:Array)->float:
    # A replacement residue owner never inherits the retired owner's amount.
    if reveal.before.get("condition_uuid")!=reveal.after.get("condition_uuid"):return 0.
    return contribution_amount(reveal.before,ellipses)

static func affects_residue(value:Dictionary,reveal:Dictionary,pattern:String,source:Dictionary)->bool:
    # A future release cannot change a field that still contains only its
    # authoritative before-value. Use the same amount/ellipse rule as kernels;
    # age and authored landing thresholds are deliberately unchanged.
    if source.region.families.get(pattern,{}).is_empty() or value.get("condition_uuid")!=reveal.after.get("condition_uuid"):return false
    for contribution in value.get("contributions",[]):
        var after:float=contribution_amount(reveal.after,contribution.ellipses)
        var before:float=before_contribution(reveal,contribution.ellipses)
        if after>before and contribution.amount>=after:return true
    return false

static func prepare_landing(cache:Dictionary,reveal:Dictionary,pattern:String)->void:
    # Both finite amounts have already been prepared by the received-shape
    # worker. Keep only particles with a shape in this tile at either amount.
    # Multiple simultaneous reveals retain the general evaluator below.
    cache.erase("landing")
    var value:Dictionary=cache.value;var source:Dictionary=cache.source
    var position:Array=cache.position;var family:Dictionary=source.region.families.get(pattern,{})
    if family.is_empty():return
    var rows:Array=[];var ordinal:int=0
    for contribution in _optical_contributions(value,source):
        var after=contribution_amount(reveal.after,contribution.ellipses)
        var before=before_contribution(reveal,contribution.ellipses)
        var changed:bool=not contribution.get("retained_pool",false) and not contribution.ellipses.is_empty() and value.get("condition_uuid")==reveal.after.get("condition_uuid") and after>before and contribution.amount>=after
        var full=float(contribution.amount)
        var initial=full-(after-before) if changed else full
        var before_fraction=maxf(0.,initial)/float(value.max_amount)
        var after_fraction=maxf(0.,full)/float(value.max_amount)
        var source_ellipses:Array=contribution.ellipses
        for ellipse in source_ellipses:
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

## A source-authored local pool is optical artwork, not a fabricated public
## receiving ellipse. Admit it only for an actual matching material deposit;
## the caller's current tile after-value alone supplies visible coverage.
static func _deposit_pool(contribution:Dictionary,source:Dictionary)->Dictionary:
    var profile:Dictionary=source.get("retained_deposit",{})
    var deposit:Variant=contribution.get("deposit_source")
    if profile.get("kind")!="tile_local_pool" or not deposit is Dictionary:return {}
    if deposit.get("deposit_uuid")==null or str(deposit.deposit_uuid).is_empty() or not deposit.get("origin") is Array \
        or deposit.origin.size()!=2 or not deposit.has("radius_cells") \
        or deposit.radius_cells!=profile.radius_cells:return {}
    return profile.ellipse

## One original local-pool template represents all admitted unshaped liquid
## amounts. Actual shaped body contributions and their landing clocks stay
## separate. This private optical grouping never rewrites SDK after-values.
static func _optical_contributions(value:Dictionary,source:Dictionary)->Array:
    var rows:Array=[];var amount:float=0.;var deposits:Array=[];var pool:Dictionary={}
    for contribution in value.get("contributions",[]):
        if not contribution.ellipses.is_empty():rows.append(contribution);continue
        var selected:Dictionary=_deposit_pool(contribution,source)
        if selected.is_empty():continue
        pool=selected;amount+=float(contribution.amount);deposits.append(contribution.deposit_source)
    if amount>0.:
        rows.push_front({"ellipses":[pool],"amount":amount,"retained_pool":true,"deposit_sources":deposits})
    return rows

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
    for contribution in _optical_contributions(value,source):
        # Matching whole ellipse lists once per contribution is equivalent to
        # repeating it for every particle in every receiving tile.
        var changes:Array=[]
        for reveal in active:
            # Body-release landing clocks never animate an unrelated retained
            # material discharge, even when both contribute to this same tile.
            if contribution.get("retained_pool",false) or contribution.ellipses.is_empty():continue
            var after=contribution_amount(reveal.after,contribution.ellipses)
            var before=before_contribution(reveal,contribution.ellipses)
            if value.get("condition_uuid")!=reveal.after.get("condition_uuid") or after<=before or contribution.amount<after:continue
            var family:Dictionary=style.families.get(reveal.pattern,{})
            if not family.is_empty():changes.append({"family":family,"age":reveal.age_seconds,"amount":after-before})
        var source_ellipses:Array=contribution.ellipses
        for ellipse in source_ellipses:
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
                if style.get("primitive")=="fragments":
                    var polygon:=PackedVector2Array()
                    for vertex in particle.get("fragment",[]):polygon.append(ellipse_transform*(target+(Vector2(vertex[0],vertex[1])-target)*scale))
                    var indices:PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
                    for at in range(0,indices.size(),3):
                        var a:Vector2=polygon[indices[at]];var b:Vector2=polygon[indices[at+1]];var c:Vector2=polygon[indices[at+2]]
                        var bounds:Rect2=Rect2(a,Vector2.ZERO).expand(b).expand(c)
                        if bounds.intersects(Rect2(Vector2(-.5,-.5),Vector2.ONE)):
                            landed.append({"transform":Transform2D(b-a,c-a,a),"mass":1.,"fragment":true})
                    shapes[fraction]=landed;result.append_array(landed)
                    continue
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
        if kernel.get("fragment",false):
            var center:Vector2=transform*Vector2(1./3.,1./3.)
            var fragment_pixel:Vector2=(center+Vector2(.5,.5))*64.
            var fragment_sample:Vector2=(fragment_pixel.floor()+Vector2(.5,.5))/64.-Vector2(.5,.5)
            if fragment_sample.x<-.5 or fragment_sample.x>=.5 or fragment_sample.y<-.5 or fragment_sample.y>=.5:continue
            if is_zero_approx(transform.determinant()):continue
            var fragment_local:Vector2=transform.affine_inverse()*fragment_sample
            if fragment_local.x>=0. and fragment_local.y>=0. and fragment_local.x+fragment_local.y<=1.:return true
            continue
        var pixel=(transform.origin+Vector2(.5,.5))*64.
        var sample=(pixel.floor()+Vector2(.5,.5))/64.-Vector2(.5,.5)
        if sample.x<-.5 or sample.x>=.5 or sample.y<-.5 or sample.y>=.5:continue
        var local=transform.affine_inverse()*sample
        var q=local.length_squared()
        if q<1.5 and kernel.mass*pow(1.-q/1.5,2.)*.72>.1525:return true
    return false
