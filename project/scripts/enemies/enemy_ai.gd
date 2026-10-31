extends CharacterBody3D
## IA de enemigos: patrulla, detecta, persigue, ataca (con anticipación) y recibe daño.
## Tipos: "goblin", "guardian" (jefe), "bot" (rival del campo de batalla).

signal died(enemy)

const CFG := {
    "goblin": {"hp": 40.0, "speed": 3.4, "dmg": 8.0, "scale": 1.0, "color": Color(0.3, 0.69, 0.31), "range": 2.2, "cd": 1.4},
    "guardian": {"hp": 260.0, "speed": 3.0, "dmg": 24.0, "scale": 2.2, "color": Color(0.48, 0.24, 1.0), "range": 4.2, "cd": 2.0},
    "bot": {"hp": 90.0, "speed": 4.8, "dmg": 7.0, "scale": 1.0, "color": Color(0.9, 0.5, 0.2), "range": 2.3, "cd": 0.9}}

var kind := "goblin"
var cfg: Dictionary
var hp := 40.0
var max_hp := 40.0
var radius := 0.4
var height := 1.8
var player: Node3D
var stun := 0.0
var atk := 0.0
var cd := 1.0
var hurt_t := 0.0
var wander_t := 0.0
var wander_dir := Vector3.ZERO
var moving := false
var visual: Node3D
var bar: MeshInstance3D
var mats: Array = []


func setup(k: String, p: Node3D) -> void:
    kind = k
    cfg = CFG[k]
    player = p
    hp = cfg["hp"]
    max_hp = hp
    var s: float = cfg["scale"]
    radius = 0.4 * s
    height = 1.8 * s
    add_to_group("enemies")
    var col: Color = cfg["color"]
    if k == "bot":
        col = Color.from_hsv(randf(), 0.7, 0.8)
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35 * s
    cap.height = 1.8 * s
    shape.shape = cap
    shape.position.y = 0.9 * s
    add_child(shape)
    visual = Node3D.new()
    visual.scale = Vector3.ONE * s
    add_child(visual)
    _box(Vector3(0.5, 0.7, 0.3), Vector3(0, 0.35, 0), col)
    _box(Vector3(0.6, 0.7, 0.35), Vector3(0, 1.05, 0), col)
    _box(Vector3(0.45, 0.45, 0.45), Vector3(0, 1.6, 0), col)
    _box(Vector3(0.18, 0.7, 0.18), Vector3(0.4, 1.05, 0), col)
    _box(Vector3(0.18, 0.7, 0.18), Vector3(-0.4, 1.05, 0), col)
    _box(Vector3(0.12, 0.12, 0.12), Vector3(0, 1.6, -0.27), Color(1, 1, 1))
    bar = MeshInstance3D.new()
    var q := QuadMesh.new()
    q.size = Vector2(1.0, 0.12)
    bar.mesh = q
    var bm := StandardMaterial3D.new()
    bm.albedo_color = Color(1.0, 0.23, 0.23)
    bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    bar.material_override = bm
    bar.position.y = 2.15 * s
    add_child(bar)


func _box(size: Vector3, pos: Vector3, col: Color) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    mi.material_override = m
    mi.position = pos
    visual.add_child(mi)
    mats.append(m)


func _physics_process(delta: float) -> void:
    if not Game.world.chunks.is_ready(global_position):
        return  # espera a que exista el suelo
    hurt_t -= delta
    stun -= delta
    var to := player.global_position - global_position
    var flat := Vector3(to.x, 0.0, to.z)
    var dist := flat.length()
    var rng: float = cfg["range"]
    var spd: float = cfg["speed"]
    var desired := Vector3.ZERO
    if stun <= 0.0:
        if atk > 0.0:
            atk -= delta
            if atk <= 0.0:
                if dist < rng + 0.6 and absf(to.y) < 2.5:
                    player.hurt(cfg["dmg"], global_position)
                cd = cfg["cd"]
        else:
            cd -= delta
            var aggro := Game.mode == Game.Mode.BATTLE or dist < (26.0 if kind == "guardian" else 16.0)
            if aggro and dist > 0.01:
                var dir := flat / dist
                if dist > rng * 0.8:
                    desired = dir * spd
                visual.rotation.y = atan2(-dir.x, -dir.z)
                if dist < rng and cd <= 0.0:
                    atk = 0.8 if kind == "guardian" else 0.5
            else:
                wander_t -= delta
                if wander_t <= 0.0:
                    wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
                    wander_t = randf_range(2.0, 5.0)
                    moving = randf() < 0.6
                if moving:
                    desired = wander_dir * spd * 0.3
                    visual.rotation.y = atan2(-wander_dir.x, -wander_dir.z)
        var k := 1.0 - exp(-(10.0 if is_on_floor() else 3.0) * delta)
        velocity.x = lerpf(velocity.x, desired.x, k)
        velocity.z = lerpf(velocity.z, desired.z, k)
    elif is_on_floor():
        var f := exp(-5.0 * delta)
        velocity.x *= f
        velocity.z *= f
    velocity.y = maxf(-40.0, velocity.y - 26.0 * delta)
    if is_on_floor() and is_on_wall() and stun <= 0.0:
        velocity.y = 8.0  # salta obstáculos de 1 bloque
    move_and_slide()
    bar.scale.x = maxf(0.01, hp / max_hp) * (cfg["scale"] as float)
    for m in mats:
        var sm := m as StandardMaterial3D
        sm.emission_enabled = atk > 0.0 or hurt_t > 0.0
        sm.emission = Color(0.55, 0.0, 0.0) if atk > 0.0 else Color(0.45, 0.45, 0.45)


func take_damage(amount: float, knock: Vector3) -> void:
    if kind == "bot" and randf() < 0.25:
        amount *= 0.3
        Game.feed_message.emit("🛡️ bloqueado")
    var boss := kind == "guardian"
    hp -= amount
    hurt_t = 0.15
    stun = 0.12 if boss else 0.35
    velocity += knock * (0.3 if boss else 1.0)
    player.add_ultimate(amount * 0.6)
    player.shake = 0.15
    Game.hitstop(0.06)
    if hp <= 0.0:
        died.emit(self)
        queue_free()
