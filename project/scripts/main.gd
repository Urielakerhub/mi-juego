extends Node3D
## Escena principal: crea el mundo, el jugador, los enemigos y gestiona modos y misión.

const BlockManagerScript := preload("res://scripts/world/block_manager.gd")
const ChunkManagerScript := preload("res://scripts/world/chunk_manager.gd")
const PlayerScript := preload("res://scripts/player/player_controller.gd")
const EnemyScript := preload("res://scripts/enemies/enemy_ai.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

var blocks
var chunks
var player
var hud
var env := Environment.new()
var game_root: Node3D
var running := false
var won := false
var kills := 0
var goblin_timer := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Game.world = self
    env.background_mode = Environment.BG_COLOR
    env.background_color = _sky()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1, 1, 1)
    env.ambient_light_energy = 0.7
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, 30, 0)
    sun.light_energy = 0.7
    add_child(sun)
    hud = HudScript.new()
    add_child(hud)
    hud.start_requested.connect(start)
    hud.resume_requested.connect(_resume)
    Game.eclipse_cast.connect(_on_eclipse)
    hud.show_menu("ECLIPSE", "Mundo de bloques con minería, crafteo, magia y combate.", false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _sky() -> Color:
    return Color(0.53, 0.72, 1.0) if Game.mode == Game.Mode.ADVENTURE else Color(0.29, 0.22, 0.41)


func start(mode: int) -> void:
    Game.mode = mode
    get_tree().paused = false
    Engine.time_scale = 1.0
    if game_root != null:
        game_root.queue_free()
    game_root = Node3D.new()
    game_root.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(game_root)
    env.background_color = _sky()
    kills = 0
    won = false
    blocks = BlockManagerScript.new()
    blocks.setup(mode)
    chunks = ChunkManagerScript.new()
    chunks.blocks = blocks
    game_root.add_child(chunks)
    var sx := 20.0 if mode == Game.Mode.ADVENTURE else 48.0
    chunks.preload_area(Vector3(sx, 0, sx), 2)
    player = PlayerScript.new()
    player.position = Vector3(sx, blocks.surface_y(int(sx), int(sx)) + 2.0, sx)
    game_root.add_child(player)
    player.died.connect(_on_player_died)
    hud.player = player
    if mode == Game.Mode.ADVENTURE:
        for i in 6:
            _spawn("goblin", randf_range(24.0, 90.0), randf_range(24.0, 90.0))
        _spawn("guardian", 80.0, 80.0)
    else:
        for i in 5:
            _spawn_bot_ring()
        player.inventory.add(3, 20)
    chunks.update_around(player.position)
    running = true
    hud.hide_menu()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn(kind: String, x: float, z: float) -> void:
    var e = EnemyScript.new()
    e.setup(kind, player)
    e.position = Vector3(x, blocks.surface_y(int(x), int(z)) + 2.0, z)
    game_root.add_child(e)
    e.died.connect(_on_enemy_died)


func _spawn_bot_ring() -> void:
    var a := randf() * TAU
    _spawn("bot", 48.0 + cos(a) * 15.0, 48.0 + sin(a) * 15.0)


func _process(delta: float) -> void:
    if Input.is_action_just_pressed("pause") and running and not hud.menu.visible:
        get_tree().paused = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        hud.show_menu("Pausa", "Juego en pausa", true)
    if not running or get_tree().paused:
        return
    chunks.update_around(player.global_position)
    hud.mission_text = _mission()
    if Game.mode == Game.Mode.ADVENTURE:
        goblin_timer -= delta
        if goblin_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 8:
            goblin_timer = 8.0
            var a := randf() * TAU
            var r := randf_range(15.0, 30.0)
            var p: Vector3 = player.global_position
            _spawn("goblin", clampf(p.x + cos(a) * r, 4.0, 91.0), clampf(p.z + sin(a) * r, 4.0, 91.0))


func _mission() -> String:
    if Game.mode == Game.Mode.BATTLE:
        return "Campo de batalla\nEliminaciones: %d" % kills
    if won:
        return "¡Misión completada!"
    if not player.has_sword:
        var c: int = player.inventory.count(4)
        if c >= 3:
            return "Forja la espada rúnica (R)\n3 cristales + 5 piedra"
        return "Misión\nEncuentra 3 cristales de eclipse (%d/3)" % c
    return "Misión\nDerrota al guardián en la arena (sureste)"


func _resume() -> void:
    get_tree().paused = false
    hud.hide_menu()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_enemy_died(e) -> void:
    kills += 1
    match e.kind:
        "guardian":
            won = true
            running = false
            get_tree().paused = true
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            hud.show_menu("¡VICTORIA!", "Derrotaste al guardián del eclipse.", false)
        "goblin":
            player.inventory.add(3, 2)
            Game.feed_message.emit("Goblin derrotado +2 piedra")
        "bot":
            player.hp = minf(100.0, player.hp + 15.0)
            Game.feed_message.emit("💀 Rival eliminado")
            get_tree().create_timer(3.0).timeout.connect(func() -> void:
                if running:
                    _spawn_bot_ring())


func _on_player_died() -> void:
    running = false
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    hud.show_menu("Has caído", "Eliminaciones: %d" % kills, false)


func _on_eclipse() -> void:
    var tw := create_tween()
    tw.tween_property(env, "background_color", Color(0.03, 0.02, 0.06), 0.3)
    tw.tween_interval(1.0)
    tw.tween_property(env, "background_color", _sky(), 1.5)


## Cambia un bloque y reconstruye los chunks afectados (incluye vecinos si está en el borde).
func set_block(x: int, y: int, z: int, id: int) -> void:
    blocks.set_block(x, y, z, id)
    var c: Vector2i = blocks.chunk_of(x, z)
    chunks.rebuild(c)
    var lx := x - c.x * 16
    var lz := z - c.y * 16
    if lx == 0:
        chunks.rebuild(c + Vector2i(-1, 0))
    elif lx == 15:
        chunks.rebuild(c + Vector2i(1, 0))
    if lz == 0:
        chunks.rebuild(c + Vector2i(0, -1))
    elif lz == 15:
        chunks.rebuild(c + Vector2i(0, 1))
