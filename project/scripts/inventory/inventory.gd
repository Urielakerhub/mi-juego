extends RefCounted
## Inventario de materiales (id de bloque -> cantidad) y recetas.

signal changed

# receta -> { id_material: cantidad }
const RECIPES := {"runic_sword": {4: 3, 3: 5}}

var items := {}


func count(id: int) -> int:
    return int(items.get(id, 0))


func add(id: int, n: int = 1) -> void:
    items[id] = count(id) + n
    changed.emit()


func remove(id: int, n: int = 1) -> bool:
    if count(id) < n:
        return false
    items[id] = count(id) - n
    changed.emit()
    return true


func can_craft(recipe: String) -> bool:
    var r: Dictionary = RECIPES[recipe]
    for id in r:
        if count(id) < int(r[id]):
            return false
    return true


func craft(recipe: String) -> bool:
    if not can_craft(recipe):
        return false
    var r: Dictionary = RECIPES[recipe]
    for id in r:
        items[id] = count(id) - int(r[id])
    changed.emit()
    return true
