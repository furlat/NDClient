extends RefCounted
## Schema-16 cell/row codecs. Canonical stores keep masks; consumers decode only their requested view.
const EMPTY = {"x0":0,"y0":0,"width":0,"height":0,"bits":""}

static func bytes(value: String) -> PackedByteArray:
    return Marshalls.base64_to_raw(value.replace("-","+").replace("_","/")) if not value.is_empty() else PackedByteArray()

static func encoded(value: PackedByteArray) -> String:
    return "" if value.is_empty() else Marshalls.raw_to_base64(value).replace("+","-").replace("/","_")

static func key(point: Array) -> String:
    return "%d,%d" % [point[0],point[1]]

static func point(value: String) -> Array:
    var parts=value.split(",");return [int(parts[0]),int(parts[1])]

static func mask_points(mask: Dictionary) -> Array:
    var result:Array=[];var height=int(mask.get("height",0));var data=bytes(mask.get("bits",""))
    if height==0:return result
    for i in range(int(mask.get("width",0))*height):
        if i/8<data.size() and (int(data[i/8])&(1<<(i%8)))!=0:result.append([int(mask.x0)+i/height,int(mask.y0)+i%height])
    return result

static func point_set(points: Array) -> Dictionary:
    var result={}
    for value in points:result[key(value)]=value
    return result

static func sorted_points(values: Dictionary) -> Array:
    var result:Array=values.values();result.sort_custom(func(a,b):return a[1]<b[1] if a[0]==b[0] else a[0]<b[0]);return result

static func _point_lower_bound(points:Array,point:Array)->int:
    var first:int=0;var last:int=points.size()
    while first<last:
        var middle:int=(first+last)>>1;var held:Array=points[middle]
        if held[0]<point[0] or (held[0]==point[0] and held[1]<point[1]):first=middle+1
        else:last=middle
    return first

static func updated_points(prior:Array,members:Dictionary,added:Array,removed:Array)->Array:
    # The caller owns this membership fork. Published point arrays remain
    # immutable; small changes use native array moves instead of a full sort.
    var incremental:bool=(added.size()+removed.size())*8<prior.size()
    var points:Array=prior.duplicate() if incremental else []
    for point in removed:
        if members.erase(key(point)) and incremental:points.remove_at(_point_lower_bound(points,point))
    for point in added:
        var identity:String=key(point)
        if incremental and not members.has(identity):points.insert(_point_lower_bound(points,point),point)
        members[identity]=point
    return points if incremental else sorted_points(members)

static func mask(points: Array) -> Dictionary:
    if points.is_empty():return EMPTY.duplicate()
    var low:Array=points[0].duplicate();var high:Array=low.duplicate()
    for value in points:
        low=[mini(low[0],value[0]),mini(low[1],value[1])];high=[maxi(high[0],value[0]),maxi(high[1],value[1])]
    var width=int(high[0]-low[0]+1);var height=int(high[1]-low[1]+1);var data=PackedByteArray();data.resize((width*height+7)/8);data.fill(0)
    for value in points:
        var index=int(value[0]-low[0])*height+int(value[1]-low[1]);data[index/8]|=1<<(index%8)
    return {"x0":low[0],"y0":low[1],"width":width,"height":height,"bits":encoded(data)}

static func union_points(prior: Dictionary, added: Array) -> Dictionary:
    # A canonical mask's occupied bounds are tight. Adding points only expands
    # those bounds, so the union needs no coordinate population or trim pass.
    if added.is_empty():return prior.duplicate()
    var prior_width=int(prior.width);var prior_height=int(prior.height)
    if prior_width==0:return mask(added)
    var x0=int(prior.x0);var y0=int(prior.y0);var x1=x0+prior_width-1;var y1=y0+prior_height-1
    for value in added:
        x0=mini(x0,value[0]);y0=mini(y0,value[1]);x1=maxi(x1,value[0]);y1=maxi(y1,value[1])
    var width=x1-x0+1;var height=y1-y0+1;var data=bytes(prior.bits)
    if x0!=prior.x0 or y0!=prior.y0 or width!=prior_width or height!=prior_height:
        var expanded=PackedByteArray();expanded.resize((width*height+7)/8);expanded.fill(0)
        # Each old column is a contiguous bit span. Copy byte fragments into its
        # new column, preserving little-endian bits and zero tail padding.
        for column in range(prior_width):
            var source=column*prior_height
            var target=(column+int(prior.x0)-x0)*height+int(prior.y0)-y0
            var remaining=prior_height
            while remaining>0:
                var span=mini(8-source%8,remaining)
                var fragment=(int(data[source/8])>>(source%8))&((1<<span)-1)
                var shift=target%8
                expanded[target/8]|=(fragment<<shift)&255
                if shift+span>8:expanded[target/8+1]|=fragment>>(8-shift)
                source+=span;target+=span;remaining-=span
        data=expanded
    for value in added:
        var index=(int(value[0])-x0)*height+int(value[1])-y0
        data[index/8]|=1<<(index%8)
    return {"x0":x0,"y0":y0,"width":width,"height":height,"bits":encoded(data)}

static func row_indices(bits: Dictionary, count: int) -> Dictionary:
    var result:Array=[];var data=bytes(bits.get("bits",""));var start=int(bits.get("start",0))*8
    for i in range(data.size()*8):
        if (int(data[i/8])&(1<<(i%8)))!=0:
            if start+i>=count:return {"ok":false,"error":{"kind":"reducer","message":"A row subset names a row outside its table"}}
            result.append(start+i)
    return {"ok":true,"value":result}

static func values_map(values: Dictionary, cell_points: Array = []) -> Dictionary:
    var points=mask_points(values.get("cells",{})) if cell_points.is_empty() else cell_points
    var data=bytes(values.get("values",""));var result={}
    for i in range(points.size()):result[key(points[i])]=int(data[i])
    return result

static func values(points: Array, held: Dictionary, cell_mask: Dictionary = {}) -> Dictionary:
    var data=PackedByteArray()
    for value in points:data.append(int(held.get(key(value),0)))
    # A sensory fold already encoded this exact ordered cell population.
    return {"cells":mask(points) if cell_mask.is_empty() else cell_mask,"values":encoded(data)}

static func value_indices(prior: Array, points: Array) -> PackedInt64Array:
    # Both canonical point populations are sorted by x then y. Share this
    # linear alignment across the light and hazard bytes on that same lattice.
    var result:=PackedInt64Array();result.resize(points.size());result.fill(-1)
    var old:int=0;var next:int=0
    while old<prior.size() and next<points.size():
        var a:Array=prior[old];var b:Array=points[next]
        if a[0]<b[0] or (a[0]==b[0] and a[1]<b[1]):old+=1
        elif a[0]==b[0] and a[1]==b[1]:result[next]=old;old+=1;next+=1
        else:next+=1
    return result

static func value_edits(prior:Array,points:Array,added:Array,removed:Array)->Dictionary:
    # Use the net population change: a removed then re-added cell retains its
    # old byte unless a value row explicitly replaces it.
    var erased:Dictionary={};var inserted:Dictionary={}
    for point in removed:
        var old:int=_point_lower_bound(prior,point);var next:int=_point_lower_bound(points,point)
        if old<prior.size() and prior[old]==point and (next==points.size() or points[next]!=point):erased[old]=true
    for point in added:
        var old:int=_point_lower_bound(prior,point);var next:int=_point_lower_bound(points,point)
        if next<points.size() and points[next]==point and (old==prior.size() or prior[old]!=point):inserted[next]=true
    var removals:Array=erased.keys();removals.sort();removals.reverse()
    var insertions:Array=inserted.keys();insertions.sort()
    return {"removed":removals,"added":insertions}

static func reindexed_values(prior: Dictionary, prior_count: int, points: Array, changed: Array, cell_mask: Dictionary, indices: PackedInt64Array, edits:Dictionary={}) -> Dictionary:
    var source:PackedByteArray=bytes(prior.get("values",""))
    # Preserve the old helper boundary for malformed short byte populations;
    # the fast merge must not conceal an invalid old row by dropping its cell.
    if source.size()<prior_count:
        var held:Dictionary=values_map(prior)
        for row in changed:held[key(row.position)]=row.value
        return values(points,held,cell_mask)
    if not edits.is_empty():
        # Decoding owns these bytes. Native moves still copy population-sized
        # memory, but small changes need no scripted full-column projection.
        source.resize(prior_count)
        for index in edits.removed:source.remove_at(index)
        for index in edits.added:source.insert(index,0)
        for row in changed:
            var index:int=_point_lower_bound(points,row.position)
            if index<points.size() and points[index]==row.position:source[index]=int(row.value)
        return {"cells":cell_mask,"values":encoded(source)}
    var patches:Dictionary={}
    # Arrays preserve the wire's full integer coordinates. Vector2i would
    # truncate them, while string keys would repeat the old hot-path work.
    for row in changed:patches[row.position]=row.value
    var data:=PackedByteArray();data.resize(points.size());data.fill(0)
    for i in points.size():
        if patches.has(points[i]):data[i]=int(patches[points[i]])
        elif indices[i]>=0:data[i]=source[indices[i]]
    return {"cells":cell_mask,"values":encoded(data)}

static func selected(rows: Array, bits: Dictionary) -> Dictionary:
    var indices=row_indices(bits,rows.size())
    if not indices.ok:return indices
    var result:Array=[]
    for index in indices.value:result.append(rows[index])
    return {"ok":true,"value":result}

static func layered(layers: Array) -> Array:
    var result:Array=[]
    for rank in range(layers.size()):
        var points=mask_points(layers[rank].cells);var data=bytes(layers[rank].values)
        for i in range(points.size()):result.append({"position":points[i],"value":int(data[i]),"rank":rank})
    result.sort_custom(func(a,b):
        if a.position[0]!=b.position[0]:return a.position[0]<b.position[0]
        if a.position[1]!=b.position[1]:return a.position[1]<b.position[1]
        return a.rank<b.rank)
    return result

static func contains(mask:Dictionary,value:Array)->bool:
    var height=int(mask.get("height",0));var x=int(value[0])-int(mask.get("x0",0));var y=int(value[1])-int(mask.get("y0",0))
    if x<0 or y<0 or x>=int(mask.get("width",0)) or y>=height:return false
    var index=x*height+y;var data=bytes(mask.get("bits",""));return index/8<data.size() and (int(data[index/8])&(1<<(index%8)))!=0
