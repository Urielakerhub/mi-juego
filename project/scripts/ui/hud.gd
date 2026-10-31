extends CanvasLayer
## HUD (vida, maná, ultimate, inventario, misión, hechizos) y menú principal/pausa.

signal start_requested(mode: int)
signal resume_requested

var player: Node = null
var mission_text := ""
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var ult_bar: ProgressBar
var info: Label
var mission: Label
var skills: Label
var combo_label: Label
var feed_box: VBoxContainer
var flash: ColorRect
var hud_root: Control
var menu: ColorRect
var title: Label
var subtitle: Label
var resume_btn: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hud_root = Control.new()
    hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hud_root)
    flash = ColorRect.new()
    flash.color = Color(1, 0, 0, 0)
    flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_root.add_child(flash)
    hp_bar = _bar(14.0, Color(0.9, 0.28, 0.3))
    mp_bar = _bar(32.0, Color(0.24, 0.55, 1.0))
    ult_bar = _bar(50.0, Color(0.69, 0.42, 1.0))
    info = _label(Vector2(14, 74))
    mission = _label(Vector2(0, 14))
    mission.anchor_left = 1.0
    mission.anchor_right = 1.0
    mission.offset_left = -330.0
    mission.offset_right = -14.0
    mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    skills = _label(Vector2(0, 0))
    skills.anchor_left = 0.5
    skills.anchor_right = 0.5
    skills.anchor_top = 1.0
    skills.anchor_bottom = 1.0
    skills.offset_left = -260.0
    skills.offset_right = 260.0
    skills.offset_top = -44.0
    skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var cross := _label(Vector2(0, 0))
    cross.text = "+"
    cross.set_anchors_preset(Control.PRESET_CENTER)
    combo_label = _label(Vector2(0, 0))
    combo_label.anchor_left = 0.5
    combo_label.anchor_right = 0.5
    combo_label.anchor_top = 0.62
    combo_label.offset_left = -100.0
    combo_label.offset_right = 100.0
    combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    combo_label.add_theme_font_size_override("font_size", 30)
    combo_label.add_theme_color_override("font_color", Color(1, 0.82, 0.29))
    feed_box = VBoxContainer.new()
    feed_box.anchor_left = 1.0
    feed_box.anchor_right = 1.0
    feed_box.anchor_top = 1.0
    feed_box.anchor_bottom = 1.0
    feed_box.offset_left = -300.0
    feed_box.offset_right = -14.0
    feed_box.offset_top = -200.0
    feed_box.offset_bottom = -60.0
    feed_box.alignment = BoxContainer.ALIGNMENT_END
    hud_root.add_child(feed_box)
    Game.feed_message.connect(_on_feed)
    _build_menu()
    hud_root.visible = false


func _bar(y: float, col: Color) -> ProgressBar:
    var b := ProgressBar.new()
    b.position = Vector2(14, y)
    b.custom_minimum_size = Vector2(220, 14)
    b.size = Vector2(220, 14)
    b.show_percentage = false
    b.max_value = 100.0
    b.value = 100.0
    var sb := StyleBoxFlat.new()
    sb.bg_color = col
    b.add_theme_stylebox_override("fill", sb)
    hud_root.add_child(b)
    return b


func _label(pos: Vector2) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 5)
    hud_root.add_child(l)
    return l


func _build_menu() -> void:
    menu = ColorRect.new()
    menu.color = Color(0.04, 0.05, 0.09, 0.88)
    menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(menu)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.custom_minimum_size = Vector2(520, 0)
    box.offset_left = -260.0
    box.offset_right = 260.0
    box.offset_top = -190.0
    box.offset_bottom = 190.0
    menu.add_child(box)
    title = Label.new()
    title.add_theme_font_size_override("font_size", 46)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    subtitle = Label.new()
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(subtitle)
    resume_btn = Button.new()
    resume_btn.text = "▶ Continuar"
    resume_btn.pressed.connect(func() -> void: resume_requested.emit())
    box.add_child(resume_btn)
    var a := Button.new()
    a.text = "⛏️ Aventura (minar, forjar, jefe)"
    a.pressed.connect(func() -> void: start_requested.emit(Game.Mode.ADVENTURE))
    box.add_child(a)
    var b := Button.new()
    b.text = "⚔️ Campo de batalla (estilo TSB)"
    b.pressed.connect(func() -> void: start_requested.emit(Game.Mode.BATTLE))
    box.add_child(b)
    var help := Label.new()
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.text = "WASD mover · Espacio saltar · Shift correr · Ratón mirar\nClic izq. atacar (combo x4) / minar · Clic der. colocar · Rueda: bloque\nF bloquear · Q esquiva · 1 Rayo · 2 Onda · 3 Carga · 4 ECLIPSE\nR forjar espada (3 cristales + 5 piedra) · G cristal → maná · P pausa"
    box.add_child(help)


func show_menu(t: String, s: String, can_resume: bool) -> void:
    title.text = t
    subtitle.text = s
    resume_btn.visible = can_resume
    menu.visible = true
    hud_root.visible = false


func hide_menu() -> void:
    menu.visible = false
    hud_root.visible = true


func _on_feed(text: String) -> void:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 5)
    feed_box.add_child(l)
    get_tree().create_timer(3.0).timeout.connect(l.queue_free)


func _process(_delta: float) -> void:
    if player == null or not is_instance_valid(player) or not hud_root.visible:
        return
    hp_bar.value = maxf(0.0, player.hp)
    mp_bar.value = player.mp
    ult_bar.value = player.ult
    flash.color.a = player.flash * 0.5
    var inv = player.inventory
    info.text = "%s\n🧱 %s x%d   💎 %d   ⬜ %d" % [
        "⚔️ Espada rúnica" if player.has_sword else "🗡️ Espada básica",
        Game.BLOCK_NAMES[player.selected_block], inv.count(player.selected_block),
        inv.count(4), inv.count(3)]
    mission.text = mission_text
    var parts := []
    for i in 4:
        var cdv: float = player.spells.cds[i]
        parts.append("[%d %s%s]" % [i + 1, player.spells.NAMES[i], (" %.1f" % cdv) if cdv > 0.0 else ""])
    skills.text = "  ".join(parts)
    var n: int = player.combat.combo
    combo_label.text = ("%d HIT%s" % [n, " 💥" if n == 4 else ""]) if n > 0 else ""
