#include "chunk_mesher.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

namespace {

struct Face {
    int n[3];
    int v[4][3]; // vértices antihorarios vistos desde fuera
    float shade;
};

const Face FACES[6] = {
    {{1, 0, 0}, {{1, 0, 0}, {1, 1, 0}, {1, 1, 1}, {1, 0, 1}}, 0.7f},
    {{-1, 0, 0}, {{0, 0, 1}, {0, 1, 1}, {0, 1, 0}, {0, 0, 0}}, 0.7f},
    {{0, 1, 0}, {{0, 1, 1}, {1, 1, 1}, {1, 1, 0}, {0, 1, 0}}, 1.0f},
    {{0, -1, 0}, {{0, 0, 0}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}}, 0.5f},
    {{0, 0, 1}, {{1, 0, 1}, {1, 1, 1}, {0, 1, 1}, {0, 0, 1}}, 0.85f},
    {{0, 0, -1}, {{0, 0, 0}, {0, 1, 0}, {1, 1, 0}, {1, 0, 0}}, 0.85f},
};

} // namespace

void ChunkMesher::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_palette", "palette"), &ChunkMesher::set_palette);
    ClassDB::bind_method(D_METHOD("build", "data", "neighbors"), &ChunkMesher::build);
}

void ChunkMesher::set_palette(const PackedColorArray &p_palette) {
    palette = p_palette;
}

Dictionary ChunkMesher::build(const PackedByteArray &p_data, const Array &p_neighbors) const {
    Dictionary out;
    PackedVector3Array verts, norms;
    PackedColorArray cols;
    PackedInt32Array idx;

    if (p_data.size() < CS * HEIGHT * CS) {
        return out;
    }

    PackedByteArray nbs[4];
    for (int i = 0; i < 4 && i < p_neighbors.size(); i++) {
        nbs[i] = p_neighbors[i];
    }
    const uint8_t *d = p_data.ptr();

    auto block_at = [&](int x, int y, int z) -> int {
        if (y < 0) return 3;
        if (y >= HEIGHT) return 0;
        if (x >= 0 && x < CS && z >= 0 && z < CS) return d[(y * CS + z) * CS + x];
        int ni = x >= CS ? 0 : (x < 0 ? 1 : (z >= CS ? 2 : 3));
        const PackedByteArray &nb = nbs[ni];
        if (nb.size() < CS * HEIGHT * CS) return 3;
        int lx = (x + CS) % CS;
        int lz = (z + CS) % CS;
        return nb[(y * CS + lz) * CS + lx];
    };

    for (int y = 0; y < HEIGHT; y++) {
        for (int z = 0; z < CS; z++) {
            for (int x = 0; x < CS; x++) {
                int b = d[(y * CS + z) * CS + x];
                if (b == 0) continue;
                Color col = b < palette.size() ? palette[b] : Color(1, 1, 1);
                for (const Face &f : FACES) {
                    if (block_at(x + f.n[0], y + f.n[1], z + f.n[2]) != 0) continue;
                    int base = verts.size();
                    for (int k = 0; k < 4; k++) {
                        verts.push_back(Vector3(x + f.v[k][0], y + f.v[k][1], z + f.v[k][2]));
                        norms.push_back(Vector3(f.n[0], f.n[1], f.n[2]));
                        cols.push_back(Color(col.r * f.shade, col.g * f.shade, col.b * f.shade));
                    }
                    // Godot usa orden horario para las caras frontales
                    idx.push_back(base);
                    idx.push_back(base + 2);
                    idx.push_back(base + 1);
                    idx.push_back(base);
                    idx.push_back(base + 3);
                    idx.push_back(base + 2);
                }
            }
        }
    }

    out["vertices"] = verts;
    out["normals"] = norms;
    out["colors"] = cols;
    out["indices"] = idx;
    return out;
}
