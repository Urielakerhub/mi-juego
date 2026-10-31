extends Node3D
## Convierte los datos de bloques en mallas con colisión y las carga/descarga
## alrededor del jugador. Usa el mallador C++ (ChunkMesher) si está compilado;
## si no, usa el mallador GDScript de abajo (mismo resultado, más lento).

const CS := 16
const HEIGHT := 48
# normal, 4 vértices (antihorario visto desde fuera), sombreado
const FACES := [
    [Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], 0.7],
    [Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)], 0.7],
    [Vector3i(0, 1, 0), [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)], 1.0],
    [Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], 0.5],
    [Vector3i(0, 0, 1), [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)], 0.85],
    [Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)], 0.85]]

var blocks
var nodes := {}
var queue: Array = []
var view_dist := 3
var center := Vector2i(-999, -999)
var material := StandardMaterial3D.new()
var mesher = null


func _ready() -> void:
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    if ClassDB.class_exists("ChunkMesher"):
        mesher = ClassDB.instantiate("ChunkMesher")
        mesher.set_palette(PackedColorArray(Game.BLOCK_COLORS))
        print("ECLIPSE: mallador C++ activo")
    else:
        print("ECLIPSE: mallador GDScript (compila la extensión C++ para más velocidad)")


func is_ready(pos: Vector3) -> bool:
    return nodes.has(Vector2i(floori(pos.x / CS), floori(pos.z / CS)))


func preload_area(pos: Vector3, r: int) -> void:
    var c := Vector2i(floori(pos.x / CS), floori(pos.z / CS))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            var k := c + Vector2i(dx, dz)
            if blocks.in_world(k.x * CS, k.y * CS) and not nodes.has(k):
                build_chunk(k)


func update_around(pos: Vector3) -> void:
    var c := Vector2i(floori(pos.x / CS), floori(pos.z / CS))
    if c == center:
        return
    center = c
    for dx in range(-view_dist, view_dist + 1):
        for dz in range(-view_dist, view_dist + 1):
            var k := c + Vector2i(dx, dz)
            if blocks.in_world(k.x * CS, k.y * CS) and not nodes.has(k) and not queue.has(k):
                queue.append(k)
    queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
    for k in nodes.keys():
        if (k - c).length() > view_dist + 2:
            nodes[k].queue_free()
            nodes.erase(k)


func _process(_delta: float) -> void:
    for i in 2:
        if queue.is_empty():
            break
        var k: Vector2i = queue.pop_front()
        if not nodes.has(k):
            build_chunk(k)


func rebuild(c: Vector2i) -> void:
    if nodes.has(c):
        build_chunk(c)


func build_chunk(c: Vector2i) -> void:
    if nodes.has(c):
        nodes[c].queue_free()
    var holder := Node3D.new()
    holder.position = Vector3(c.x * CS, 0, c.y * CS)
    add_child(holder)
    nodes[c] = holder
    var data: PackedByteArray = blocks.ensure_chunk(c)
    var arr: Array = _mesh_cpp(c, data) if mesher != null else _mesh_gd(c, data)
    if arr.is_empty():
        return
    var m := ArrayMesh.new()
    m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    m.surface_set_material(0, material)
    var mi := MeshInstance3D.new()
    mi.mesh = m
    holder.add_child(mi)
    mi.create_trimesh_collision()


func _mesh_cpp(c: Vector2i, data: PackedByteArray) -> Array:
    var nb := []
    for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var k: Vector2i = c + off
        if blocks.in_world(k.x * CS, k.y * CS):
            nb.append(blocks.ensure_chunk(k))
        else:
            nb.append(PackedByteArray())
    var r: Dictionary = mesher.build(data, nb)
    var verts: PackedVector3Array = r["vertices"]
    if verts.is_empty():
        return []
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_NORMAL] = r["normals"]
    arr[Mesh.ARRAY_COLOR] = r["colors"]
    arr[Mesh.ARRAY_INDEX] = r["indices"]
    return arr


func _mesh_gd(c: Vector2i, data: PackedByteArray) -> Array:
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idxs := PackedInt32Array()
    var ox := c.x * CS
    var oz := c.y * CS
    for y in HEIGHT:
        for z in CS:
            for x in CS:
                var b: int = data[(y * CS + z) * CS + x]
                if b == 0:
                    continue
                var col: Color = Game.BLOCK_COLORS[b]
                for f in FACES:
                    var n: Vector3i = f[0]
                    var nx := x + n.x
                    var ny := y + n.y
                    var nz := z + n.z
                    var nb: int
                    if nx >= 0 and nx < CS and nz >= 0 and nz < CS and ny >= 0 and ny < HEIGHT:
                        nb = data[(ny * CS + nz) * CS + nx]
                    else:
                        nb = blocks.get_block(ox + nx, ny, oz + nz)
                    if nb != 0:
                        continue
                    var base := verts.size()
                    var shade: float = f[2]
                    for v in f[1]:
                        verts.append(Vector3(x, y, z) + v)
                        norms.append(Vector3(n))
                        cols.append(Color(col.r * shade, col.g * shade, col.b * shade))
                    idxs.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
    if verts.is_empty():
        return []
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_NORMAL] = norms
    arr[Mesh.ARRAY_COLOR] = cols
    arr[Mesh.ARRAY_INDEX] = idxs
    return arr
