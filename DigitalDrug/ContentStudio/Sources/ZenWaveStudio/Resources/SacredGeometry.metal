// Inserted after the shared studio shader helpers. Geometry remains rigid; audio
// modulates global scale, depth lighting and a moving glint, not edge connectivity.
float2 sacredRotate(float2 p, float angle) {
    float c = cos(angle), s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}
float3 sacredRotate3D(float3 p, float time) {
    float y = time * 0.18 + 0.42;
    float x = 0.48 + sin(time * 0.13) * 0.32;
    float z = time * 0.065;
    p = float3(p.x * cos(y) + p.z * sin(y), p.y, -p.x * sin(y) + p.z * cos(y));
    p = float3(p.x, p.y * cos(x) - p.z * sin(x), p.y * sin(x) + p.z * cos(x));
    return float3(p.x * cos(z) - p.y * sin(z), p.x * sin(z) + p.y * cos(z), p.z);
}
float2 sacredProject(float3 p) { return p.xy * (1.8 / (1.8 - p.z)); }
float sacredBreath(constant VisualizerUniforms& u) {
    return 1.0 + sin(u.time * 0.44) * 0.035 * u.motionAmount + u.bass * 0.055;
}
float sacredLine(float distance, float width, float aa) {
    float core = 1.0 - smoothstep(width, width + aa, distance);
    float glow = exp(-distance * distance / max(width * width * 18.0, 0.000015));
    return core + glow * 0.18;
}
float3 sacredInk(float hue) {
    return mix(float3(0.06, 0.76, 0.85), float3(0.64, 0.26, 0.94), clamp(hue, 0.0, 1.0));
}
float3 sacredBackground(float2 p, constant VisualizerUniforms& u) {
    float r = length(p);
    float3 mist = float3(0.006, 0.008, 0.022)
        + float3(0.025, 0.018, 0.060) * exp(-r * r * 3.5);
    float angle = atan2(p.y, p.x);
    float halo = exp(-pow((r - 0.445) * 55.0, 2.0));
    return mist + sacredInk(0.5 + 0.5 * sin(angle * 2.0 - u.time * 0.12)) * halo * 0.07;
}
float sacredFace(float2 p, float2 a, float2 b, float2 c) {
    float d0 = (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x);
    float d1 = (p.x - b.x) * (c.y - b.y) - (p.y - b.y) * (c.x - b.x);
    float d2 = (p.x - c.x) * (a.y - c.y) - (p.y - c.y) * (a.x - c.x);
    return ((d0 >= 0.0 && d1 >= 0.0 && d2 >= 0.0)
         || (d0 <= 0.0 && d1 <= 0.0 && d2 <= 0.0)) ? 1.0 : 0.0;
}

float3 merkabaField(float2 p, constant VisualizerUniforms& u) {
    const float3 tetra[4] = {float3(1, 1, 1), float3(1, -1, -1),
                            float3(-1, 1, -1), float3(-1, -1, 1)};
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = sacredBackground(p, u);
    float breath = sacredBreath(u);
    for (int family = 0; family < 2; family++) {
        float sign = family == 0 ? 1.0 : -1.0;
        float3 vertices[4];
        float2 projected[4];
        for (int i = 0; i < 4; i++) {
            // The second tetrahedron is exactly the inversion of the first.
            // Both share one rigid rotation, preserving the interlocking star tetrahedron.
            vertices[i] = sacredRotate3D(tetra[i] * sign * 0.205 * breath, u.time);
            projected[i] = sacredProject(vertices[i]);
        }
        float3 pigment = sacredInk(family == 0 ? 0.10 : 0.90);
        for (int omitted = 0; omitted < 4; omitted++) {
            int ids[3]; int next = 0;
            for (int i = 0; i < 4; i++) { if (i != omitted) { ids[next++] = i; } }
            float3 normal = normalize(cross(vertices[ids[1]] - vertices[ids[0]], vertices[ids[2]] - vertices[ids[0]]));
            float light = 0.3 + 0.7 * abs(normal.z);
            result += pigment * sacredFace(p, projected[ids[0]], projected[ids[1]], projected[ids[2]]) * 0.025 * light;
        }
        for (int i = 0; i < 4; i++) {
            for (int j = i + 1; j < 4; j++) {
                float depth = (vertices[i].z + vertices[j].z) * 0.5;
                float edge = constellationEdge(p, projected[i], projected[j]);
                float front = 0.55 + (depth + 0.4) * 0.55;
                result += pigment * sacredLine(edge, 0.0015, aa) * front * (0.72 + u.level * 0.20);
                float along = 0.5 + 0.5 * sin(u.time * 0.65 + float(i * 3 + j));
                float glint = length(p - mix(projected[i], projected[j], along));
                result += float3(0.62, 0.88, 0.96) * exp(-glint * glint / 0.000055) * (0.10 + u.treble * 0.16);
            }
            float node = length(p - projected[i]);
            result += pigment * exp(-node * node / 0.000035) * 0.48;
        }
    }
    return 1.0 - exp(-result * 1.2);
}

float3 metatronField(float2 point, constant VisualizerUniforms& u) {
    float2 p = sacredRotate(point, u.time * 0.055) / sacredBreath(u);
    float aa = max(fwidth(p.x), fwidth(p.y));
    float2 centers[13];
    centers[0] = float2(0);
    for (int i = 0; i < 6; i++) {
        float angle = M_PI_F * 0.5 + float(i) * M_PI_F / 3.0;
        float2 direction = float2(cos(angle), sin(angle));
        centers[1 + i] = direction * 0.17;
        centers[7 + i] = direction * 0.34;
    }
    float3 result = sacredBackground(point, u);
    for (int i = 0; i < 13; i++) {
        float hue = 0.5 + 0.5 * sin(float(i) * 0.7 + u.time * 0.15);
        float circle = abs(length(p - centers[i]) - 0.085);
        result += sacredInk(hue) * sacredLine(circle, 0.0010, aa) * (0.68 + u.mids * 0.22);
        // All 13 centers are joined pairwise: 13*12/2 = 78 segments.
        for (int j = i + 1; j < 13; j++) {
            float edge = constellationEdge(p, centers[i], centers[j]);
            float glimmer = 0.75 + 0.25 * sin(u.time * 0.35 + float(i + j) * 0.4);
            result += sacredInk(0.5 + 0.5 * sin(float(i + j) * 0.37))
                * sacredLine(edge, 0.00045, aa * 0.75) * glimmer * (0.16 + u.treble * 0.04);
        }
        float node = length(p - centers[i]);
        result += float3(0.42, 0.78, 0.91) * exp(-node * node / 0.000025) * 0.30;
    }
    return 1.0 - exp(-result * 1.15);
}

float3 circleLatticeField(float2 point, constant VisualizerUniforms& u, bool seed) {
    float2 p = sacredRotate(point, u.time * (seed ? -0.070 : 0.045)) / sacredBreath(u);
    float radius = seed ? 0.19 : 0.128;
    int rings = seed ? 1 : 2;
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = sacredBackground(point, u);
    for (int q = -2; q <= 2; q++) {
        for (int r = -2; r <= 2; r++) {
            if (abs(q) > rings || abs(r) > rings || abs(q + r) > rings) { continue; }
            float2 center = float2(float(q) + float(r) * 0.5, float(r) * 0.8660254038) * radius;
            float distance = abs(length(p - center) - radius);
            float hue = 0.5 + 0.5 * sin(float(q - r) * 0.75 + u.time * 0.14);
            float light = 0.62 + 0.18 * sin(u.time * 0.45 - length(center) * 8.0) + u.mids * 0.20;
            result += sacredInk(hue) * sacredLine(distance, 0.0012, aa) * light;
        }
    }
    float boundary = abs(length(p) - radius * float(rings + 1));
    result += sacredInk(0.35) * sacredLine(boundary, 0.0007, aa) * 0.28;
    return 1.0 - exp(-result * 1.25);
}

float3 vesicaField(float2 point, constant VisualizerUniforms& u) {
    float2 p = sacredRotate(point, sin(u.time * 0.16) * 0.25 * u.motionAmount + u.time * 0.025)
        / sacredBreath(u);
    const float radius = 0.225;
    const float halfSpacing = radius * 0.5;
    float left = length(p - float2(-halfSpacing, 0));
    float right = length(p - float2(halfSpacing, 0));
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = sacredBackground(point, u);
    result += sacredInk(0.10) * sacredLine(abs(left - radius), 0.0015, aa) * (0.72 + u.level * 0.20);
    result += sacredInk(0.90) * sacredLine(abs(right - radius), 0.0015, aa) * (0.72 + u.level * 0.20);
    float lens = (1.0 - smoothstep(radius - aa, radius + aa, left))
        * (1.0 - smoothstep(radius - aa, radius + aa, right));
    float glow = 0.5 + 0.5 * cos(p.y * 12.0 - u.time * 0.45);
    result += sacredInk(0.5 + 0.5 * sin(u.time * 0.18)) * lens * (0.045 + glow * 0.05 + u.bass * 0.04);
    float2 top = float2(0, radius * 0.8660254038), bottom = -top;
    float2 a = float2(-halfSpacing, 0), b = -a;
    float diamond = min(min(constellationEdge(p, a, top), constellationEdge(p, top, b)),
                        min(constellationEdge(p, b, bottom), constellationEdge(p, bottom, a)));
    result += sacredInk(0.4) * sacredLine(diamond, 0.0005, aa) * 0.28;
    return 1.0 - exp(-result * 1.25);
}

float3 octahedralField(float2 p, constant VisualizerUniforms& u) {
    const float3 model[6] = {float3(1,0,0), float3(-1,0,0), float3(0,1,0),
                           float3(0,-1,0), float3(0,0,1), float3(0,0,-1)};
    float3 vertices[6]; float2 projected[6];
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = sacredBackground(p, u);
    float breath = sacredBreath(u);
    for (int i = 0; i < 6; i++) {
        vertices[i] = sacredRotate3D(model[i] * 0.33 * breath, u.time);
        projected[i] = sacredProject(vertices[i]);
    }
    for (int i = 0; i < 6; i++) {
        for (int j = i + 1; j < 6; j++) {
            if (abs(dot(model[i], model[j])) > 0.5) { continue; }
            float distance = constellationEdge(p, projected[i], projected[j]);
            float depth = (vertices[i].z + vertices[j].z) * 0.5;
            result += sacredInk(float(i + j) / 9.0) * sacredLine(distance, 0.0016, aa)
                * (0.75 + depth * 0.5 + u.level * 0.22);
        }
        float node = length(p - projected[i]);
        result += float3(0.44, 0.80, 0.95) * exp(-node * node / 0.00006) * (0.25 + u.treble * 0.25);
    }
    for (int ring = 0; ring < 2; ring++) {
        float2 q = sacredRotate(p, u.time * -0.10 + float(ring) * M_PI_F * 0.5);
        float ellipse = abs(length(q * float2(1.0, 2.6)) - 0.41 * breath) / 2.6;
        result += sacredInk(float(ring) * 0.8) * sacredLine(ellipse, 0.0007, aa) * 0.35;
    }
    return 1.0 - exp(-result * 1.25);
}
