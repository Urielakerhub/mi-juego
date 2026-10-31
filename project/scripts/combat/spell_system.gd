extends Node
## Hechizos: 1 Rayo, 2 Onda sísmica, 3 Carga relámpago, 4 ECLIPSE (ultimate).

const NAMES := ["Rayo", "Onda", "Carga", "ECLIPSE"]
const COSTS := [20.0, 30.0, 25.0, 0.0]
const CDS := [1.2, 5.0, 4.0, 0.0]

var player: Node
var cds := [0.0, 0.0, 0.0, 0.0]


func _process(delta: float) -> void:
    for i in 4:
        cds[i] = maxf(0.0, cds[i] - delta)
        if Input.is_action_just_pressed("spell_%d" % (i + 1)):
            cast(i)


func cast(i: int) -> void:
    if cds[i] > 0.0:
        return
    if i == 3:
        if player.ult < 100.0:
            return
    elif not player.spend_mana(COSTS[i]):
        return
    player.swing_t = 1.0
    match i:
        0: _bolt()
        1: _wave()
        2: _charge()
        3: _eclipse()
    cds[i] = CDS[i]


func _bolt() -> void:
    var o: Vector3 = player.cam.global_position
    var d: Vector3 = -player.cam.global_transform.basis.z
    var best: Node3D = null
    var best_t := 35.0
    for e in get_tree().get_nodes_in_group("enemies"):
        var v: Vector3 = e.global_position + Vector3(0.0, e.height * 0.5, 0.0) - o
        var t := v.dot(d)
        if t < 0.0 or t > best_t:
            continue
        if (v - d * t).length() < e.radius + 0.4:
            best = e
            best_t = t
    if best != null:
        best.take_damage(22.0, d * 8.0 + Vector3.UP * 3.0)
    var a: Vector3 = o + d * 0.6 + player.cam.global_transform.basis.x * 0.25 - Vector3(0.0, 0.2, 0.0)
    var b := o + d * best_t
    var bm := BoxMesh.new()
    bm.size = Vector3(0.08, 0.08, a.distance_to(b))
    var mi := _fx(bm, Color(0.62, 0.85, 1.0), Vector3.ZERO, 0.18, 0.0)
    mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP)


func _wave() -> void:
    for e in get_tree().get_nodes_in_group("enemies"):
        var v: Vector3 = e.global_position - player.global_position
        var l := Vector2(v.x, v.z).length()
        if l < 6.5:
            e.take_damage(26.0, Vector3(v.x, 0.0, v.z) / maxf(l, 0.001) * 10.0 + Vector3.UP * 6.0)
    var cm := CylinderMesh.new()
    cm.top_radius = 1.0
    cm.bottom_radius = 1.0
    cm.height = 0.3
    _fx(cm, Color(1.0, 0.76, 0.29), player.global_position + Vector3(0, 0.2, 0), 0.4, 7.0)
    player.shake = 0.4


func _charge() -> void:
    var f: Vector3 = -player.global_transform.basis.z
    f.y = 0.0
    f = f.normalized()
    var best: Node3D = null
    var bd := 12.0
    for e in get_tree().get_nodes_in_group("enemies"):
        var v: Vector3 = e.global_position - player.global_position
        var l := Vector2(v.x, v.z).length()
        if l < bd and (v.x * f.x + v.z * f.z) / maxf(l, 0.001) > 0.5:
            best = e
            bd = l
    if best != null:
        player.global_position = best.global_position - f * 1.6
        best.take_damage(20.0, f * 5.0 + Vector3.UP * 7.0)
    else:
        player.velocity.x = f.x * 22.0
        player.velocity.z = f.z * 22.0
        player.dash_t = 0.2
    player.inv_t = 0.4


func _eclipse() -> void:
    player.ult = 0.0
    for e in get_tree().get_nodes_in_group("enemies"):
        var v: Vector3 = e.global_position - player.global_position
        if v.length() < 13.0:
            e.take_damage(70.0, Vector3(v.x, 0.0, v.z) * 1.2 + Vector3.UP * 9.0)
    var sm := SphereMesh.new()
    _fx(sm, Color(0.48, 0.24, 1.0), player.global_position + Vector3(0, 1, 0), 0.9, 14.0)
    Game.eclipse_cast.emit()
    player.shake = 0.8
    Game.feed_message.emit("🌑 ¡ECLIPSE!")


## Efecto visual temporal: se desvanece y (opcional) crece.
func _fx(mesh: Mesh, color: Color, pos: Vector3, life: float, grow: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mi.material_override = m
    get_tree().current_scene.add_child(mi)
    mi.global_position = pos
    var tw := mi.create_tween()
    tw.set_parallel(true)
    tw.tween_property(m, "albedo_color:a", 0.0, life)
    if grow > 0.0:
        tw.tween_property(mi, "scale", Vector3.ONE * grow, life)
    tw.chain().tween_callback(mi.queue_free)
    return mi
