extends Button
## One displayed actor's portrait; this control never changes turn authority.
var portrait: Texture2D
var health: Variant = null
var maximum = 0
var current_turn = false
var inspected = false
var friendly = false
var initials = "?"
var show_health_value = false

func _init(art_size: Vector2 = Vector2(36,48), health_value: bool = false) -> void:
    show_health_value = health_value
    custom_minimum_size = art_size+Vector2(4,25 if health_value else 9)
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    flat = true
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)

func bind(actor: Dictionary, sheet: Dictionary, image: Texture2D, turn: bool, selected: bool, ally: bool) -> void:
    if portrait!=image:
        if portrait!=null: portrait.changed.disconnect(queue_redraw)
        portrait = image
        if portrait!=null: portrait.changed.connect(queue_redraw)
    health = actor.get("normal_hp",sheet.get("normal_hp"))
    maximum = int(actor.get("maximum_hp",sheet.get("maximum_hp",0)))
    current_turn = turn; inspected = selected; friendly = ally
    var label = str(actor.get("name",sheet.get("name","Unknown")))
    initials = label.left(1).to_upper()
    tooltip_text = label
    if health!=null and maximum>0: tooltip_text += "\n"+str(health)+" / "+str(maximum)+" HP"
    if actor.get("armor_class")!=null: tooltip_text += " · AC "+str(actor.armor_class)
    if current_turn: tooltip_text += "\nCurrent turn"
    if actor.get("life_state")!=null and actor.life_state!="alive": tooltip_text += "\n"+str(actor.life_state).capitalize()
    tooltip_text += "\nClick to inspect · Double-click to focus"
    queue_redraw()

func _draw() -> void:
    var label_height = 16 if show_health_value else 0
    var body = Rect2(Vector2(2,2),Vector2(size.x-4,size.y-9-label_height))
    draw_rect(body,Color(0.025,0.035,0.045,.85))
    if portrait!=null:
        var source = portrait.get_size()
        var scale = maxf(body.size.x/maxf(1,source.x),body.size.y/maxf(1,source.y))
        var crop = body.size/scale
        draw_texture_rect_region(portrait,body,Rect2((source-crop)*.5,crop))
    else:
        var font = get_theme_default_font()
        draw_string(font,Vector2(size.x*.5-6,size.y*.5+5),initials,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("bfccd2"))
    var border = Color("e9c87e") if current_turn else (Color("d5edf2") if inspected else (Color("738b98") if is_hovered() else Color("33444f")))
    draw_rect(body,border,false,2.0 if current_turn or inspected else 1.0)
    var hp = Rect2(2,size.y-5-label_height,size.x-4,4)
    draw_rect(hp,Color("253039"))
    if health!=null and maximum>0:
        hp.size.x *= clampf(float(health)/maximum,0,1)
        draw_rect(hp,Color("77b6a0") if friendly else Color("c36c69"))
    if show_health_value:
        var value = str(health)+" / "+str(maximum) if health!=null and maximum>0 else "?"
        draw_string(get_theme_default_font(),Vector2(0,size.y-3),value,HORIZONTAL_ALIGNMENT_CENTER,size.x,12,Color("d5e0df"))
