extends Node
## Combate cuerpo a cuerpo: combo de 4 golpes (el 4º lanza al enemigo) o minería.

var player: Node
var combo := 0
var combo_t := 0.0
var cd := 0.0


func _process(delta: float) -> void:
    cd = maxf(0.0, cd - delta)
    combo_t -= delta
    if combo_t <= 0.0:
        combo = 0
    if Input.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        attack()


func attack() -> void:
    if cd > 0.0:
        return
    cd = 0.26
    player.swing_t = 1.0
    var n := (combo % 4 + 1) if combo_t > 0.0 else 1
    var f: Vector3 = -player.global_transform.basis.z
    f.y = 0.0
    f = f.normalized()
    var hit := false
    for e in get_tree().get_nodes_in_group("enemies"):
        var to: Vector3 = e.global_position - player.global_position
        if absf(to.y) > 2.6:
            continue
        var l := Vector2(to.x, to.z).length()
        if l < 3.2 + e.radius and (to.x * f.x + to.z * f.z) / maxf(l, 0.001) > 0.2:
            hit = true
            var finisher := n == 4
            var dmg: float = (15.0 if player.has_sword else 9.0) * (1.8 if finisher else 1.0)
            var kb := f * (14.0 if finisher else 3.0) + Vector3.UP * (7.0 if finisher else 1.5)
            e.take_damage(dmg, kb)
    if hit:
        combo = n
        combo_t = 0.75
        if n == 4:
            cd = 0.55
        player.shake = 0.15
    elif player.mine():
        cd = 0.18
