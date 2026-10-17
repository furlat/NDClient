extends Resource
## One layer-clip's cropped cells packed into fixed square pages (L8 prepack).
## Every channel (colour and its companions) shares one cell table and page
## layout, so one Texture2DArray per channel has identical layer indices.
## Not used by the runtime yet; tools/prepack_sheets.gd writes it and
## tests/sheet_prepack_checks.gd proves it reproduces the original sheets.
const STRIDE=7
@export var source:String=""
@export var sheet_size:=Vector2i.ZERO
@export var cell:=Vector2i(128,128)
@export var page_size:int=128
@export var page_count:int=0
## Per cell (row-major over the sheet grid, column = frame, row = facing row):
## page (-1: nothing readable), page x, page y, box x, box y, box w, box h.
## The box is cell-relative and covers the one-texel ring the shaders can
## address outside the cell (-1 .. cell), so box x/y may be -1.
@export var cells:=PackedInt32Array()
## Channel name -> absolute source file, and channel name -> Array of page Images
## (decoded format of that source, unchanged: no conversion, no compression).
@export var sources:Dictionary={}
@export var pages:Dictionary={}

## The one cell-texel mapping the runtime shaders and CPU readers will share:
## t is the cell-relative texel the original sampler addressed (floor of the
## sheet coordinate minus the cell origin, -1 .. cell). Outside the box the
## original colour alpha is 0 (proved by the prepack oracle): transparent.
static func packed_texel(bundle:Resource,channel:String,index:int,t:Vector2i)->Color:
    var i:int=index*STRIDE;var at:=t-Vector2i(bundle.cells[i+3],bundle.cells[i+4])
    if bundle.cells[i]<0 or at.x<0 or at.y<0 or at.x>=bundle.cells[i+5] or at.y>=bundle.cells[i+6]:return Color(0,0,0,0)
    return (bundle.pages[channel][bundle.cells[i]] as Image).get_pixel(bundle.cells[i+1]+at.x,bundle.cells[i+2]+at.y)

static func cell_index(bundle:Resource,frame:int,row:int)->int:
    return row*(bundle.sheet_size.x/bundle.cell.x)+frame
