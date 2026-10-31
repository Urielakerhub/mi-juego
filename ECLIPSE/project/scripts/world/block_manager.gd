extends RefCounted
## Datos del mundo: chunks de bloques, generación de terreno y raycast.
## Un chunk = 16 x 48 x 16 bytes (0 = aire). Índice: (y*16 + z)*16 + x

const CS := 16
const HEIGHT := 48
const WORLD := 6  # mundo finito de 6x6 chunks (96x96 bloques)

var chunks := {}
var mode := 0
var noise := FastNoiseLite.new()
var cave := FastNoiseLite.new()


func setup(m: int) -> void:
    mode = m
    noise.seed = randi()
    noise.frequency = 0.018
    noise.fractal_octaves = 3
    cave.seed = noise.seed + 7
    cave.frequency = 0.06


func in_world(x: int, z: int) -> bool:
    return x >= 0 and z >= 0 and x < CS * WORLD and z < CS * WORLD


func chunk_of(x: int, z: int) -> Vector2i:
    return Vector2i(floori(float(x) / CS), floori(float(z) / CS))


func ensure_chunk(c: Vector2i) -> PackedByteArray:
    if not chunks.has(c):
        chunks[c] = _generate(c)
    return chunks[c]


func get_block(x: int, y: int, z: int) -> int:
    if y < 0:
        return 3
    if y >= HEIGHT:
        return 0
    if not in_world(x, z):
        return 3
    var c := chunk_of(x, z)
    var d: PackedByteArray = ensure_chunk(c)
    return d[(y * CS + (z - c.y * CS)) * CS + (x - c.x * CS)]


func set_block(x: int, y: int, z: int, id: int) -> void:
    if y < 0 or y >= HEIGHT or not in_world(x, z):
        return
    var c := chunk_of(x, z)
    var d: PackedByteArray = ensure_chunk(c)
    d[(y * CS + (z - c.y * CS)) * CS + (x - c.x * CS)] = id
    chunks[c] = d


func surface_y(x: int, z: int) -> int:
    for y in range(HEIGHT - 1, -1, -1):
        if get_block(x, y, z) != 0:
            return y
    return 0


## Raycast por voxeles (Amanatides-Woo). Devuelve {"block": Vector3i, "prev": Vector3i} o {}.
func raycast(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
    var pos := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
    var prev := pos
    var step := Vector3i(1 if dir.x > 0.0 else -1, 1 if dir.y > 0.0 else -1, 1 if dir.z > 0.0 else -1)
    var t_max := Vector3(INF, INF, INF)
    var t_delta := Vector3(INF, INF, INF)
    for a in 3:
        if dir[a] != 0.0:
            var edge := float(pos[a] + (1 if step[a] > 0 else 0))
            t_max[a] = (edge - origin[a]) / dir[a]
            t_delta[a] = absf(1.0 / dir[a])
    for i in 80:
        var axis := 0
        if t_max.y < t_max[axis]:
            axis = 1
        if t_max.z < t_max[axis]:
            axis = 2
        if t_max[axis] > max_dist:
            break
        prev = pos
        pos[axis] += step[axis]
        t_max[axis] += t_delta[axis]
        if get_block(pos.x, pos.y, pos.z) != 0:
            return {"block": pos, "prev": prev}
    return {}


# ---------- generación ----------
func _generate(c: Vector2i) -> PackedByteArray:
    var d := PackedByteArray()
    d.resize(CS * HEIGHT * CS)
    for lz in CS:
        for lx in CS:
            var wx := c.x * CS + lx
            var wz := c.y * CS + lz
            if mode == 0:
                _column_adventure(d, lx, lz, wx, wz)
            else:
                _column_battle(d, lx, lz, wx, wz)
    return d


func _i(lx: int, y: int, lz: int) -> int:
    return (y * CS + lz) * CS + lx


func _column_adventure(d: PackedByteArray, lx: int, lz: int, wx: int, wz: int) -> void:
    var h := 16 + int(noise.get_noise_2d(wx, wz) * 12.0)
    var arena := absi(wx - 80) <= 7 and absi(wz - 80) <= 7
    if arena:
        h = 18
    for y in range(0, h + 1):
        var b := 3
        if y == h:
            b = 3 if arena else 1
        elif y > h - 4:
            b = 2
        elif y > 3 and y < h - 2 and cave.get_noise_3d(wx, y * 1.5, wz) > 0.5:
            b = 0
        elif absi(hash(Vector3i(wx, y, wz))) % 70 == 0:
            b = 4
        d[_i(lx, y, lz)] = b
    if arena:
        # pilares con cristal en las esquinas de la arena del guardián
        if absi(wx - 80) == 5 and absi(wz - 80) == 5:
            for y in range(h + 1, h + 6):
                d[_i(lx, y, lz)] = 3
            d[_i(lx, h + 6, lz)] = 4
        return
    if lx >= 2 and lx <= 13 and lz >= 2 and lz <= 13 and h < 30 and absi(hash(Vector2i(wx, wz))) % 90 == 0:
        for t in 4:
            d[_i(lx, h + 1 + t, lz)] = 5
        for ax in range(-1, 2):
            for az in range(-1, 2):
                for ty in range(4, 6):
                    if d[_i(lx + ax, h + ty, lz + az)] == 0:
                        d[_i(lx + ax, h + ty, lz + az)] = 1
    elif absi(hash(Vector2i(wz, wx))) % 200 == 1:
        d[_i(lx, h + 1, lz)] = 4  # cristal en superficie


func _column_battle(d: PackedByteArray, lx: int, lz: int, wx: int, wz: int) -> void:
    var h := 10
    var dx := wx - 48
    var dz := wz - 48
    var r2 := dx * dx + dz * dz
    if r2 <= 36:
        h = 12
    var edge := wx < 2 or wz < 2 or wx >= CS * WORLD - 2 or wz >= CS * WORLD - 2
    for y in range(0, h + 1):
        d[_i(lx, y, lz)] = 1 if (y == h and r2 > 324) else 3
    if edge:
        for y in range(h + 1, h + 7):
            d[_i(lx, y, lz)] = 3
    elif wx % 12 == 6 and wz % 12 == 6 and r2 > 100:
        for y in range(h + 1, h + 4):
            d[_i(lx, y, lz)] = 3
