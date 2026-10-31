extends Node
## Autoload "Game": constantes, bloques, entrada y señales globales.

signal feed_message(text: String)
signal eclipse_cast

enum Mode { ADVENTURE, BATTLE }

var mode: int = Mode.ADVENTURE
var world: Node = null

const BLOCK_NAMES: Array = ["", "Césped", "Tierra", "Piedra", "Cristal", "Madera"]
const BLOCK_COLORS: Array = [
    Color(0, 0, 0), Color(0.37, 0.68, 0.24), Color(0.54, 0.35, 0.21),
    Color(0.5, 0.52, 0.56), Color(0.69, 0.42, 1.0), Color(0.72, 0.53, 0.29)]


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_input()


func _setup_input() -> void:
    var keys := {
        "move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
        "jump": KEY_SPACE, "sprint": KEY_SHIFT, "dash": KEY_Q, "block": KEY_F,
        "spell_1": KEY_1, "spell_2": KEY_2, "spell_3": KEY_3, "spell_4": KEY_4,
        "forge": KEY_R, "use_crystal": KEY_G, "pause": KEY_P}
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var ev := InputEventKey.new()
        ev.physical_keycode = keys[action]
        InputMap.action_add_event(action, ev)
    var mouse := {"attack": MOUSE_BUTTON_LEFT, "place": MOUSE_BUTTON_RIGHT}
    for action in mouse:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var ev := InputEventMouseButton.new()
        ev.button_index = mouse[action]
        InputMap.action_add_event(action, ev)


## Pausa breve al impactar (sensación de golpe).
func hitstop(t: float) -> void:
    Engine.time_scale = 0.15
    await get_tree().create_timer(t, true, false, true).timeout
    Engine.time_scale = 1.0
