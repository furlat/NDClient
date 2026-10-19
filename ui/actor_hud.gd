extends Control
## Displayed snapshot -> native portrait banks and compact resource indicators.
const UI = preload("res://presentation/ui_catalog.gd")
const Portrait = preload("res://ui/actor_portrait.gd")
signal inspected(actor_uuid: String)
signal focused(actor_uuid: String)
var initiative = HFlowContainer.new()
var party = VBoxContainer.new()
var economy = HFlowContainer.new()
var initiative_buttons: Dictionary = {}
var party_buttons: Dictionary = {}
var resource_buttons: Dictionary = {}
var party_ids: Array = []
var layout_values: Array = []
var layout_pending = false
var layout_dirty = true

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for bank in [initiative,party,economy]:
        bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bank.add_theme_constant_override("separation",7)
        bank.add_theme_constant_override("h_separation",7)
        bank.add_theme_constant_override("v_separation",7)
        bank.minimum_size_changed.connect(_settle_layout)
        add_child(bank)

func sync(state: Dictionary, action_actor: Dictionary, selected: String, cache: Dictionary) -> void:
    var snapshot = state.get("hud_snapshot")
    if snapshot==null: return
    layout_dirty = true
    var actors: Dictionary = state.get("actors",{})
    var controlled: Array = state.get("audience",{}).get("controlled",[])
    party_ids = []
    for sheet in snapshot.get("sheets",[]):
        if sheet.actor_uuid in controlled and actors.has(sheet.actor_uuid): party_ids.append(sheet.actor_uuid)
    var turn_ids: Array = []
    for id in snapshot.get("initiative",[]):
        if actors.has(id) and actors[id].get("present",false): turn_ids.append(id)
    _bank(initiative,initiative_buttons,turn_ids,state,selected,controlled,cache,false)
    _bank(party,party_buttons,party_ids,state,selected,controlled,cache,true)
    var sheet = UI.sheet(state,str(action_actor.get("uuid","")))
    var live = {}
    var order = 0
    for resource in sheet.get("resources",[]):
        var key: String = resource.key
        var button: Button = resource_buttons.get(key)
        if button==null:
            button = Button.new()
            button.flat = true; button.focus_mode = Control.FOCUS_NONE
            button.mouse_filter = Control.MOUSE_FILTER_STOP
            button.add_theme_font_size_override("font_size",14)
            economy.add_child(button); resource_buttons[key] = button
        var maximum = maxi(0,int(resource.maximum))
        var current = maxi(0,int(resource.current))
        var colour = Color("8dc7b0")
        var glyph = "◆"
        if key=="bonus_actions": glyph="▲"; colour=Color("dfbf79")
        elif key=="reactions": glyph="●"; colour=Color("91b7dc")
        elif key.begins_with("spell_slot_"): glyph="●"; colour=Color("a3b7ef")
        elif key.begins_with("resource:"): glyph="✦"; colour=Color("c8a1db")
        if key=="movement": button.text=str(current)+" ft"
        elif key.begins_with("resource:") or maxi(maximum,current)>8: button.text=glyph+" "+str(current)+"/"+str(maximum)
        else:
            button.text=(key.trim_prefix("spell_slot_")+"  " if key.begins_with("spell_slot_") else "")+glyph.repeat(current)+"·".repeat(maxi(0,maximum-current))
        button.add_theme_color_override("font_color",colour)
        button.tooltip_text = str(resource.label)+": "+str(resource.current)+" / "+str(resource.maximum)
        economy.move_child(button,order); order+=1; live[key]=true
    for key in resource_buttons.keys():
        if not live.has(key):
            var button: Button=resource_buttons[key]
            economy.remove_child(button); button.queue_free(); resource_buttons.erase(key)

func _bank(bank: Container, buttons: Dictionary, ids: Array, state: Dictionary, selected: String, controlled: Array, cache: Dictionary, party_role: bool) -> void:
    for id in buttons.keys():
        if id not in ids:
            var button: Button=buttons[id]
            bank.remove_child(button); button.queue_free(); buttons.erase(id)
    for index in ids.size():
        var id: String=ids[index]
        if not buttons.has(id):
            # Original Pygame artwork dimensions; frame/HP padding belongs to
            # the control, not to the portrait image's role or aspect ratio.
            var button = Portrait.new(Vector2(48,64) if party_role else Vector2(36,48),party_role)
            button.pressed.connect(func(): inspected.emit(id))
            button.gui_input.connect(func(event):
                if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click: focused.emit(id))
            bank.add_child(button); buttons[id]=button
        var actor: Dictionary=state.actors[id]
        var sheet=UI.sheet(state,id)
        buttons[id].bind(actor,sheet,UI.texture(UI.portrait_key(actor,sheet,state,cache),cache,true),id==state.current_actor_uuid,id==selected,id in controlled)
        bank.move_child(buttons[id],index)

func layout_in(viewport_size: Vector2, bar_y: float, log_rect: Rect2, targeting_rect: Rect2 = Rect2()) -> void:
    var next_layout = [viewport_size,bar_y,log_rect,targeting_rect]
    if not layout_dirty and layout_values == next_layout: return
    layout_values = next_layout
    layout_dirty = false
    var right = minf(viewport_size.x-12,log_rect.position.x-12) if log_rect.has_area() else viewport_size.x-12
    right = maxf(12,right)
    _flow_width(initiative,viewport_size.x,right)
    initiative.position.y = 12
    _flow_width(economy,viewport_size.x,right)
    var economy_height = economy.get_combined_minimum_size().y
    economy.position.y = bar_y-(34 if economy_height<=34 else economy_height+8)
    if targeting_rect.has_area() and economy.get_rect().intersects(targeting_rect):
        economy.position.y = targeting_rect.position.y-economy_height-8
    party.position = Vector2(20,maxf(96,initiative.get_rect().end.y+12))

func _flow_width(bank: HFlowContainer, viewport_width: float, right: float) -> void:
    var natural = 0.0
    for child in bank.get_children():
        if natural>0: natural += 7
        natural += child.get_combined_minimum_size().x
    var width = minf(natural,maxf(0,right-12))
    # The native FlowContainer measures wrapped height after sorting at this
    # width. Its minimum-size signal settles the other banks without scaling.
    bank.size = Vector2(width,0)
    bank.position.x = maxf(12,minf((viewport_width-natural)*.5,right-width))

func _settle_layout() -> void:
    layout_dirty = true
    if layout_pending or layout_values.is_empty(): return
    layout_pending = true
    _finish_layout.call_deferred()

func _finish_layout() -> void:
    layout_pending = false
    if not layout_values.is_empty(): layout_in(layout_values[0],layout_values[1],layout_values[2],layout_values[3])

func contains(point: Vector2) -> bool:
    for bank in [initiative,party,economy]:
        if bank.is_visible_in_tree() and bank.get_child_count()>0 and bank.get_global_rect().has_point(point): return true
    return false
