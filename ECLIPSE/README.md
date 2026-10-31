# ECLIPSE — Combat Prototype 0.1 (Godot 4 + GDScript + C++)

Juego de bloques en primera persona con minería, crafteo, magia y combate.
Dos modos: **Aventura** (minar → forjar espada rúnica → derrotar al guardián)
y **Campo de batalla** (estilo TSB: combos, esquiva, habilidades, ultimate, rivales).

## Estructura
```
project/            Proyecto Godot 4.3 (abre project/project.godot)
  scripts/core/       game.gd (autoload: bloques, entrada, señales)
  scripts/world/      block_manager.gd (datos, terreno, raycast) · chunk_manager.gd (mallas, carga/descarga)
  scripts/player/     player_controller.gd (movimiento, cámara, bloques)
  scripts/combat/     combat_system.gd (combo x4) · spell_system.gd (4 hechizos)
  scripts/enemies/    enemy_ai.gd (goblin, guardián, bot)
  scripts/inventory/  inventory.gd (materiales y recetas)
  scripts/ui/         hud.gd (HUD + menú)
  eclipse.gdextension carga la librería C++
gdextension/        C++ (godot-cpp): ChunkMesher = mallador de chunks rápido
SConstruct          compila la extensión
.github/workflows/  compila C++ + exporta Windows/Linux/Android en GitHub
```

## Cómo se reparte GDScript y C++
- **GDScript**: toda la jugabilidad (jugador, combate, hechizos, IA, HUD, misión).
- **C++**: `ChunkMesher`, la parte más pesada (convertir 12.288 bloques por chunk en malla).
- Si la extensión C++ NO está compilada, el juego **funciona igual** con un mallador
  GDScript equivalente (solo más lento al romper/colocar bloques).

## Jugar ya (solo GDScript)
1. Instala Godot 4.3 (godotengine.org).
2. Importa `project/project.godot` y pulsa ▶.

## Compilar la extensión C++ (opcional, recomendado)
```
git clone --depth 1 --branch godot-4.3-stable https://github.com/godotengine/godot-cpp.git
pip install scons
scons platform=linux target=template_release arch=x86_64      # Linux
scons platform=windows target=template_release arch=x86_64    # Windows
```
Genera `project/bin/libeclipse.<plataforma>.x86_64.(so|dll)`. Al abrir el juego verás en la
consola "mallador C++ activo". Android usa el mallador GDScript (no se compila C++ para Android).

## Compilar instaladores en la nube
Sube TODO esto a un repositorio de GitHub (incluida la carpeta oculta `.github`).
En la pestaña **Actions** se compila la extensión C++ y se exporta el juego.
Descarga `eclipse-juego` desde *Artifacts* (.exe, .x86_64, .apk de depuración).

## Controles
WASD mover · Espacio saltar · Shift correr · Ratón mirar · Clic izq. atacar (combo x4) / minar ·
Clic der. colocar bloque · Rueda elegir bloque · F bloquear · Q esquiva · 1 Rayo · 2 Onda ·
3 Carga · 4 ECLIPSE (barra morada llena) · R forjar espada rúnica · G cristal→maná · P pausa

## Siguientes versiones (según el plan)
0.2 guardado del mundo, mundo mayor · 0.3 reinos, aldeas, mazmorras · 0.4 multijugador con
servidor autoritativo (el estado de bloques ya está separado en `BlockManager`) · 0.5 guerras de reinos.
