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

static func mask(points: Array) -> Dictionary:
    if points.is_empty():return EMPTY.duplicate()
    var low:Array=points[0].duplicate();var high:Array=low.duplicate()
    for value in points:
        low=[mini(low[0],value[0]),mini(low[1],value[1])];high=[maxi(high[0],value[0]),maxi(high[1],value[1])]
    var width=int(high[0]-low[0]+1);var height=int(high[1]-low[1]+1);var data=PackedByteArray();data.resize((width*height+7)/8);data.fill(0)
    for value in points:
        var index=int(value[0]-low[0])*height+int(value[1]-low[1]);data[index/8]|=1<<(index%8)
    return {"x0":low[0],"y0":low[1],"width":width,"height":height,"bits":encoded(data)}

static func row_indices(bits: Dictionary, count: int) -> Dictionary:
    var result:Array=[];var data=bytes(bits.get("bits",""));var start=int(bits.get("start",0))*8
    for i in range(data.size()*8):
        if (int(data[i/8])&(1<<(i%8)))!=0:
            if start+i>=count:return {"ok":false,"error":{"kind":"reducer","message":"A row subset names a row outside its table"}}
            result.append(start+i)
    return {"ok":true,"value":result}

static func values_map(values: Dictionary) -> Dictionary:
    var points=mask_points(values.get("cells",{}));var data=bytes(values.get("values",""));var result={}
    for i in range(points.size()):result[key(points[i])]=int(data[i])
    return result

static func values(points: Array, held: Dictionary) -> Dictionary:
    var data=PackedByteArray()
    for value in points:data.append(int(held.get(key(value),0)))
    return {"cells":mask(points),"values":encoded(data)}

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
