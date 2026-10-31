#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>

namespace godot {

// Mallador de chunks en C++: convierte un chunk de 16x48x16 bloques en
// vértices/normales/colores/índices (solo caras expuestas). Mismo resultado
// que el mallador GDScript de chunk_manager.gd, pero mucho más rápido.
class ChunkMesher : public RefCounted {
    GDCLASS(ChunkMesher, RefCounted)

    PackedColorArray palette;

protected:
    static void _bind_methods();

public:
    static constexpr int CS = 16;
    static constexpr int HEIGHT = 48;

    void set_palette(const PackedColorArray &p_palette);
    // neighbors: [+x, -x, +z, -z] (PackedByteArray vacío = fuera del mundo = sólido)
    Dictionary build(const PackedByteArray &p_data, const Array &p_neighbors) const;
};

} // namespace godot
