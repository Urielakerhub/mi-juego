extends CharacterBody3D
## Jugador en primera persona: movimiento, cámara, esquiva, bloques y estadísticas.

signal died

const InventoryScript := preload("res://scripts/inventory/inventory.gd")
const CombatScript := preload("res://scripts/combat/combat_system.gd")
const SpellScript := preload("res://scripts/combat/spell_system.gd")

const WALK := 5.0
const RUN := 7.5
const JUMP := 9.0
const GRAVITY := 26.0

var hp := 100.0
var mp := 100.0
var ult := 0.0
var has_sword := false
var selected_block := 3
var inventory = InventoryScript.new()
var combat: Node
var spells: Node
var head: Node3D
var cam: Camera3D
var sword: MeshInstance3D
var sword_mat := StandardMaterial3D.new()
var inv_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var swing_t := 0.0
var shake := 0.0
var flash := 0.0


func _ready() -> void:
    add_to_group("player")
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)
    head = Node3D.new()
    head.position.y = 1.6
    add_child(head)
    cam = Camera3D.new()
    cam.fov = 75.0
    cam.far = 200.0
    head.add_child(cam)
    cam.make_current()
    sword = MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.07, 0.07, 0.95)
    sword.mesh = bm
    sword_mat.albedo_color = Color(0.81, 0.84, 0.88)
    sword.material_override = sword_mat
    sword.position = Vector3(0.38, -0.32, -0.9)
    cam.add_child(sword)
    combat = CombatScript.new()
    combat.player = self
    add_child(combat)
    spells = SpellScript.new()
    spells.player = self
    add_child(spells)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    var mm := event as InputEventMouseMotion
    if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-mm.relative.x * 0.0025)
        head.rotation.x = clampf(head.rotation.x - mm.relative.y * 0.0025, -1.5, 1.5)
        return
    var mb := event as InputEventMouseButton
    if mb != null and mb.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            return
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            selected_block = selected_block % 5 + 1
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            selected_block = (selected_block + 3) % 5 + 1
    if event.is_action_pressed("place"):
        place_block()
    if event.is_action_pressed("dash"):
        dash()
    if event.is_action_pressed("forge"):
        forge()
    if event.is_action_pressed("use_crystal"):
        use_crystal()


func _physics_process(delta: float) -> void:
    inv_t = maxf(0.0, inv_t - delta)
    dash_cd = maxf(0.0, dash_cd - delta)
    dash_t = maxf(0.0, dash_t - delta)
    swing_t = maxf(0.0, swing_t - delta * 4.0)
    shake = maxf(0.0, shake - delta * 1.5)
    flash = maxf(0.0, flash - delta * 4.0)
    mp = minf(100.0, mp + 7.0 * delta)
    if Game.mode == Game.Mode.ADVENTURE:
        hp = minf(100.0, hp + 0.8 * delta)
    var in_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var wish := transform.basis * Vector3(in_dir.x, 0.0, in_dir.y)
    var speed := RUN if Input.is_action_pressed("sprint") else WALK
    if Input.is_action_pressed("block"):
        speed *= 0.4
    if dash_t <= 0.0:
        var k := 1.0 - exp(-(12.0 if is_on_floor() else 3.0) * delta)
        velocity.x = lerpf(velocity.x, wish.x * speed, k)
        velocity.z = lerpf(velocity.z, wish.z * speed, k)
    velocity.y -= GRAVITY * (0.2 if dash_t > 0.0 else 1.0) * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP
    move_and_slide()
    cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.1
    cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.1
    var a := sin(swing_t * PI)
    sword.rotation = Vector3(0.3 - a * 1.5, 0.0, -swing_t * 0.8)
    sword.position.z = -0.9 - a * 0.25


func dash() -> void:
    if dash_cd > 0.0:
        return
    var in_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var d := transform.basis * Vector3(in_dir.x, 0.0, in_dir.y)
    if d.length() < 0.1:
        d = -transform.basis.z
    d = d.normalized()
    velocity.x = d.x * 19.0
    velocity.z = d.z * 19.0
    dash_t = 0.18
    inv_t = 0.3
    dash_cd = 1.2


## Rompe el bloque apuntado y lo guarda en el inventario. Devuelve true si rompió algo.
func mine() -> bool:
    var hit: Dictionary = Game.world.blocks.raycast(cam.global_position, -cam.global_transform.basis.z, 5.0)
    if hit.is_empty():
        return false
    var p: Vector3i = hit["block"]
    if p.y <= 0:
        return false
    var id: int = Game.world.blocks.get_block(p.x, p.y, p.z)
    inventory.add(id)
    Game.world.set_block(p.x, p.y, p.z, 0)
    return true


func place_block() -> void:
    if inventory.count(selected_block) < 1:
        return
    var hit: Dictionary = Game.world.blocks.raycast(cam.global_position, -cam.global_transform.basis.z, 5.0)
    if hit.is_empty():
        return
    var q: Vector3i = hit["prev"]
    if Game.world.blocks.get_block(q.x, q.y, q.z) != 0:
        return
    var body := AABB(global_position + Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.8, 0.7))
    if body.intersects(AABB(Vector3(q), Vector3.ONE)):
        return
    inventory.remove(selected_block)
    Game.world.set_block(q.x, q.y, q.z, selected_block)


func forge() -> void:
    if Game.mode != Game.Mode.ADVENTURE or has_sword:
        return
    if inventory.craft("runic_sword"):
        has_sword = true
        sword_mat.albedo_color = Color(0.73, 0.61, 1.0)
        sword_mat.emission_enabled = true
        sword_mat.emission = Color(0.48, 0.24, 1.0)
        Game.feed_message.emit("⚔️ Espada rúnica forjada")
    else:
        Game.feed_message.emit("Necesitas 3 cristales y 5 piedra")


func use_crystal() -> void:
    if inventory.remove(4):
        mp = minf(100.0, mp + 50.0)


func spend_mana(n: float) -> bool:
    if mp < n:
        return false
    mp -= n
    return true


func add_ultimate(a: float) -> void:
    ult = minf(100.0, ult + a)


func hurt(amount: float, from: Vector3) -> void:
    if inv_t > 0.0 or hp <= 0.0:
        return
    if Input.is_action_pressed("block"):
        amount *= 0.2
        Game.feed_message.emit("🛡️ Bloqueo")
    hp -= amount
    flash = 0.5
    shake = 0.2
    var away := global_position - from
    away.y = 0.0
    velocity += away.normalized() * 6.0 + Vector3.UP * 3.0
    if hp <= 0.0:
        died.emit()
