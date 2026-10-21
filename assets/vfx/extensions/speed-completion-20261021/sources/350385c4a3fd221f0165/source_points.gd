extends RefCounted
## Current receiver optical source equations, copied read-only as pure data.
static func measure(images:Dictionary,frame:Vector4,units:float,elevation:float,origin:Vector2,depth_range:Vector2,pivot:Vector2,ground:float,camera_basis:Basis)->Array:
	var result:Array=[]
	var colour:Image=images.colour
	var offset:Vector2i=Vector2i(roundi(frame.x*colour.get_width()),roundi(frame.y*colour.get_height()))
	var size:Vector2i=Vector2i(roundi(frame.z*colour.get_width()),roundi(frame.w*colour.get_height()))
	var toward:Vector3=camera_basis.z
	var horizontal:Vector3=Vector3(toward.x,0,toward.z).normalized()
	var normal_basis:Basis=camera_basis.inverse()*Basis(camera_basis.x,Vector3(0,cos(elevation),0)-horizontal*sin(elevation),horizontal*cos(elevation)+Vector3(0,sin(elevation),0))
	for y in size.y:
		for x in size.x:
			var pixel:Vector2i=Vector2i(x,y);var sheet_pixel:Vector2i=pixel+offset
			if colour.get_pixelv(sheet_pixel).a<.99:continue
			var depth:Color=images.depth.get_pixelv(sheet_pixel)
			var normal:Color=images.normal.get_pixelv(sheet_pixel)
			if depth.a<.5 or normal.a<.5 or images.support.get_pixelv(sheet_pixel).r<.5 or images.normal_valid.get_pixelv(sheet_pixel).r<.5:continue
			var centre:Vector2=Vector2(x+.5,y+.5)
			var decoded:float=depth_range.x+(depth.r*255.0-32.0)*(depth_range.y-depth_range.x)/192.0
			var height:float=((origin.y-centre.y)*cos(elevation)+decoded*sin(elevation)-ground)*units
			var painted:Vector3=Vector3(centre.x-pivot.x,pivot.y-centre.y,0)*units
			var ray:float=(height-(camera_basis*painted).y)/toward.y
			var direction:Vector3=Vector3(normal.r,normal.g,normal.b)*2.0-Vector3.ONE
			result.append({"local":painted+Vector3(0,0,ray),"normal":(normal_basis*direction.normalized()).normalized(),"uv":centre/Vector2(size),"pixel":pixel})
	return result
