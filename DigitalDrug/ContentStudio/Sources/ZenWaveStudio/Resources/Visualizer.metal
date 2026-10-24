#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct VisualizerUniforms {
    float time;
    float intensity;
    float activity;
    float aspect;
    float opacity;
    float level;
    float peak;
    float bass;
    float mids;
    float treble;
    float beatFrequency;
    float style;
    float presentation;
    float light;
    float motionAmount;
    float audioResponse;
    float palette;
};

vertex VertexOut zenWaveFullscreenVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };

    VertexOut output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.uv = positions[vertexID] * 0.5 + 0.5;
    return output;
}

// Stable cell hashes let the field move through depth without per-frame randomness.
float waveHash(float2 cell) {
    return fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
}

float3 deepParticleField(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float bass = clamp(u.bass, 0.0, 1.0) * u.activity;
    float angle = u.time * 0.018;
    float2 p = float2(point.x * cos(angle) - point.y * sin(angle),
                      point.x * sin(angle) + point.y * cos(angle));
    p /= 1.0 + bass * 0.06;
    float pixelWidth = max(fwidth(p.x), fwidth(p.y));
    float3 result = float3(0.008, 0.011, 0.027);
    result += float3(0.065, 0.028, 0.14) * exp(-length(p) * 4.5);
    for (int layer = 0; layer < 8; layer++) {
        float progress = fract(float(layer) / 8.0 - u.time * 0.026);
        float depth = 0.22 + progress * 3.7;
        float fade = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
        float2 position = p * depth * 7.0;
        float2 cell = floor(position);
        for (int row = -1; row <= 1; row++) {
            for (int column = -1; column <= 1; column++) {
                float2 tile = cell + float2(column, row);
                float2 seed = tile + float(layer) * 31.7;
                float h = waveHash(seed);
                float2 center = tile + float2(h, waveHash(seed + 17.1));
                float2 delta = (position - center) / (depth * 7.0);
                float distance = length(delta);
                float size = (0.0018 + 0.0028 / depth) * (0.65 + h * 0.65);
                float core = 1.0 - smoothstep(size * 0.3, size + pixelWidth, distance);
                float glow = exp(-distance * distance / (size * size * 8.0));
                float sparkle = exp(-abs(delta.x) / size * 4.0 - abs(delta.y) / size * 0.6)
                    + exp(-abs(delta.y) / size * 4.0 - abs(delta.x) / size * 0.6);
                float3 hue = mix(float3(0.20, 0.82, 0.94), float3(0.60, 0.30, 0.95), h);
                hue = mix(hue, float3(0.94, 0.78, 0.55), smoothstep(0.90, 1.0, h) * 0.65);
                float brightness = fade * (0.55 + h * 0.45) * (0.85 + drive * 0.55);
                result += hue * (core * 0.95 + glow * 0.20 + sparkle * 0.08) * brightness;
            }
        }
    }
    return result;
}

// A forward star flight: fixed angular lanes keep elongated trails continuous
// across the screen. Eight depth layers and three neighboring lanes bound GPU work.
float3 starDriftField(float2 point, constant VisualizerUniforms& u) {
    const float tau = 6.28318530718;
    const float lanes = 48.0;
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float2 p = point - float2(sin(u.time * 0.13), cos(u.time * 0.11)) * 0.007;
    float angularLane = floor((atan2(p.y, p.x) + tau) / tau * lanes);
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = float3(0.004, 0.007, 0.019);
    float radius = length(p);
    result += float3(0.025, 0.035, 0.09) * exp(-radius * 5.0);
    for (int layer = 0; layer < 8; layer++) {
        for (int neighbor = -1; neighbor <= 1; neighbor++) {
            float lane = fmod(angularLane + float(neighbor) + lanes, lanes);
            float2 seed = float2(lane, float(layer) * 19.7);
            float h = waveHash(seed);
            float angle = (lane + 0.15 + waveHash(seed + 8.2) * 0.70) / lanes * tau;
            float2 direction = float2(cos(angle), sin(angle));
            float progress = fract(float(layer) / 8.0 + h * 0.13 - u.time * 0.13);
            float depth = 0.12 + progress * 2.9;
            float worldRadius = 0.12 + waveHash(seed + 27.3) * 0.66;
            float near = 1.0 - smoothstep(0.10, 0.65, progress);
            float2 head = direction * worldRadius / depth;
            float2 tail = direction * worldRadius / (depth + 0.10 + near * 0.20);
            float2 segment = head - tail;
            float along = clamp(dot(p - tail, segment) / max(dot(segment, segment), 0.000001), 0.0, 1.0);
            // The soft bend and trailing haze make close stars stretch and melt.
            float bend = sin(along * 3.14159265) * sin(u.time * 0.7 + h * tau) * near * 0.003;
            float2 center = tail + segment * along + float2(-direction.y, direction.x) * bend;
            float distance = length(p - center);
            float width = (0.0007 + near * 0.0018) * (0.7 + h * 0.6);
            float core = 1.0 - smoothstep(width * 0.2, width + aa, distance);
            float glow = exp(-distance * distance / (width * width * 14.0 + aa * aa));
            float taper = 0.15 + pow(along, 0.7) * 0.85;
            float fade = smoothstep(0.0, 0.035, progress) * (1.0 - smoothstep(0.75, 1.0, progress));
            float3 hue = mix(float3(0.22, 0.72, 1.0), float3(0.65, 0.38, 1.0), h);
            hue = mix(hue, float3(0.85, 0.94, 1.0), along * 0.65);
            result += hue * (core * taper + glow * 0.32) * fade * (0.65 + h * 0.55) * (0.9 + drive * 0.25);
        }
    }
    return 1.0 - exp(-result * 1.15);
}

float3 geometricKaleidoscope(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float bass = clamp(u.bass, 0.0, 1.0) * u.activity;
    float mids = clamp(u.mids, 0.0, 1.0) * u.activity;
    float radius = length(point);
    float angle = atan2(point.y, point.x) + u.time * 0.045;
    float breath = 1.0 + 0.025 * sin(u.time * 0.42) + bass * 0.065;
    float3 result = float3(0.011, 0.009, 0.033);
    result += float3(0.08, 0.025, 0.16) * exp(-radius * 3.0);
    for (int ring = 0; ring < 16; ring++) {
        float index = float(ring);
        float base = 0.022 * pow(1.24, index) * breath;
        float fold = angle + sin(u.time * 0.16 + index * 0.20) * 0.055;
        float petals = cos(fold * 8.0);
        float contour = base * (1.0 + (0.19 + mids * 0.03) * petals
            + 0.035 * cos(fold * 16.0 + u.time * 0.12));
        float distance = abs(radius - contour);
        float aa = max(fwidth(radius), 0.00065);
        float core = 1.0 - smoothstep(0.00065, 0.00065 + aa, distance);
        float glow = exp(-distance * distance / (0.000016 + base * 0.000035));
        // Two fine inset contours provide depth and the feel of engraved petals.
        float detailDistance = min(abs(radius - contour * 0.94), abs(radius - contour * 1.045));
        float detail = (1.0 - smoothstep(0.0003, 0.0003 + aa, detailDistance)) * 0.25;
        float hue = 0.5 + 0.5 * sin(index * 0.62 + petals * 0.75 + u.time * 0.09);
        float3 pigment = mix(float3(0.08, 0.78, 0.88), float3(0.66, 0.22, 0.96), hue);
        float shade = 0.58 + 0.28 * (0.5 + 0.5 * cos(fold * 8.0 - index * 0.22));
        result += pigment * (core + detail + glow * 0.15) * shade * (0.85 + drive * 0.35);
    }
    return result;
}

// Smooth deterministic dust, sampled in three bounded octaves.
float nebulaNoise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(waveHash(cell), waveHash(cell + float2(1, 0)), f.x),
               mix(waveHash(cell + float2(0, 1)), waveHash(cell + float2(1, 1)), f.x), f.y);
}
float nebulaDust(float2 p) {
    float value = 0.0;
    float weight = 0.57;
    for (int octave = 0; octave < 3; octave++) {
        value += weight * nebulaNoise(p);
        p = float2(p.x * 1.6 - p.y * 1.2, p.x * 1.2 + p.y * 1.6) + 13.7;
        weight *= 0.5;
    }
    return value;
}

float3 nebulaFlightField(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float bass = clamp(u.bass, 0.0, 1.0) * u.activity;
    float3 result = float3(0.007, 0.009, 0.025);
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    p += float2(sin(u.time * 0.09), cos(u.time * 0.07)) * 0.025;
    for (int layer = 0; layer < 3; layer++) {
        float travel = fract(float(layer) / 3.0 - u.time * 0.045);
        float depth = 0.6 + travel * 3.0;
        float fade = smoothstep(0.0, 0.18, travel) * (1.0 - smoothstep(0.72, 1.0, travel));
        float2 q = p * depth * 2.6 + float2(float(layer) * 17.3, u.time * 0.026);
        q += float2(sin(q.y * 1.3), cos(q.x * 1.1)) * 0.35;
        float dust = nebulaDust(q);
        float cloud = smoothstep(0.33, 0.78, dust);
        float filament = exp(-abs(dust - 0.58) * 19.0) * cloud;
        float hue = 0.5 + 0.5 * sin(q.x * 0.65 + q.y * 0.45 + float(layer));
        float3 pigment = mix(float3(0.035, 0.38, 0.62), float3(0.40, 0.08, 0.68), hue);
        result += pigment * (cloud * 0.70 + filament * 0.35) * fade * (0.8 + bass * 0.25 + drive * 0.18);
    }
    // The established star lanes provide continuous forward flight through the dust.
    result += starDriftField(point, u) * 0.65;
    return 1.0 - exp(-result * 1.45);
}

float3 orbitalWaveField(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float bass = clamp(u.bass, 0.0, 1.0) * u.activity;
    float mids = clamp(u.mids, 0.0, 1.0) * u.activity;
    float scale = max(min(u.aspect, 1.0), 0.25);
    float2 p = point / scale;
    float radius = length(p);
    float sphereRadius = 0.24 + bass * 0.014;
    float aa = max(fwidth(p.x), fwidth(p.y));
    float sphere = 1.0 - smoothstep(sphereRadius - aa, sphereRadius + aa, radius);
    float3 result = float3(0.005, 0.008, 0.021);
    result += float3(0.035, 0.035, 0.15) * exp(-radius * radius * 5.5);
    float z = sqrt(max(0.0, 1.0 - radius * radius / (sphereRadius * sphereRadius)));
    float rim = pow(1.0 - z, 3.0) * sphere;
    float light = max(0.0, dot(float3(p / sphereRadius, z), normalize(float3(-0.5, -0.4, 0.7))));
    result = mix(result, float3(0.008, 0.014, 0.032) + float3(0.025, 0.06, 0.11) * light, sphere);
    result += mix(float3(0.02, 0.65, 0.80), float3(0.48, 0.14, 0.75), smoothstep(-0.2, 0.2, p.x)) * rim * 0.42;
    for (int family = 0; family < 3; family++) {
        float tilt = float(family) * 1.05 + sin(u.time * 0.10 + float(family)) * 0.16;
        float2 q = float2(p.x * cos(tilt) - p.y * sin(tilt), p.x * sin(tilt) + p.y * cos(tilt));
        for (int ribbon = 0; ribbon < 6; ribbon++) {
            float index = float(ribbon);
            float orbit = 0.34 + index * 0.017 + bass * 0.018;
            float angle = atan2(q.y / 0.34, q.x);
            float ripple = sin(angle * 3.0 - u.time * 0.55 + index * 0.32) * (0.006 + mids * 0.006);
            float distance = abs(length(float2(q.x, q.y / 0.34)) - orbit - ripple);
            float width = 0.0016 + drive * 0.0008;
            float core = 1.0 - smoothstep(width, width + aa * 2.0, distance);
            float glow = exp(-distance * distance / 0.00012);
            float front = smoothstep(-0.025, 0.025, q.y);
            float visibility = 1.0 - sphere * (1.0 - front);
            float hue = 0.5 + 0.5 * sin(angle + u.time * 0.12 + float(family) * 1.8 + index * 0.12);
            float3 pigment = mix(float3(0.025, 0.75, 0.94), float3(0.62, 0.16, 0.95), hue);
            result += pigment * (core * 0.52 + glow * 0.12) * visibility * (0.8 + drive * 0.25);
        }
    }
    return 1.0 - exp(-result * 1.15);
}

float constellationEdge(float2 p, float2 a, float2 b) {
    float2 segment = b - a;
    float along = clamp(dot(p - a, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
    return length(p - a - segment * along);
}
float2 constellationNode(float2 cell, float time) {
    float h = waveHash(cell);
    return cell + float2(0.18 + waveHash(cell + 7.3) * 0.64, 0.18 + h * 0.64)
        + float2(sin(time * 0.13 + h * 6.28), cos(time * 0.11 + h * 5.0)) * 0.10;
}
float3 liquidConstellationField(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float morph = smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(u.time * 0.23));
    float2 p = point / max(min(u.aspect, 1.0), 0.25) * 5.0;
    // Shape morphing must not gate translation. A bounded sinusoidal path keeps
    // scrolling through both completed shapes and eases continuously into reversal.
    float travelPhase = u.time * 0.115;
    float travelVelocity = cos(travelPhase);
    float travelDirection = travelVelocity / sqrt(travelVelocity * travelVelocity + 0.04);
    p.y += sin(travelPhase) * 1.35;
    p.x += sin(p.y * 0.8 - u.time * 0.22) * (0.11 + morph * 0.19);
    float2 cell = floor(p);
    float aa = max(fwidth(p.x), fwidth(p.y));
    float3 result = float3(0.006, 0.01, 0.027);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 tile = cell + float2(x, y);
            float h = waveHash(tile);
            float2 node = constellationNode(tile, u.time);
            float distance = length(p - node);
            float core = 1.0 - smoothstep(0.018, 0.03 + aa, distance);
            float glow = exp(-distance * distance / 0.008);
            float3 hue = mix(float3(0.08, 0.78, 0.95), float3(0.65, 0.24, 0.94), h);
            result += hue * (core + glow * 0.35) * (0.75 + drive * 0.30);
            for (int edge = 0; edge < 3; edge++) {
                float2 offset = edge == 0 ? float2(1, 0) : edge == 1 ? float2(0, 1) : float2(1, 1);
                float2 other = constellationNode(tile + offset, u.time);
                float link = constellationEdge(p, node, other);
                float gate = smoothstep(0.20, 0.65, waveHash(tile + offset * 3.1));
                result += hue * (1.0 - smoothstep(0.004, 0.004 + aa, link)) * (1.0 - morph) * gate * 0.30;
            }
            float2 tail = node + float2(sin(u.time * 0.22 + h * 6.28) * 0.045,
                (0.24 + drive * 0.08) * travelDirection);
            float stream = constellationEdge(p, node, tail);
            result += hue * exp(-stream * stream / 0.0018) * morph * 0.38;
        }
    }
    return 1.0 - exp(-result * 1.2);
}

float3 prismaticBloomField(float2 point, constant VisualizerUniforms& u) {
    float bass = clamp(u.bass, 0.0, 1.0) * u.activity;
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float radius = length(p);
    float angle = atan2(p.y, p.x) + u.time * 0.085;
    float breath = 1.0 + sin(u.time * 0.32) * 0.04
        + u.motionAmount * (sin(u.time * 0.46) * 0.12 + sin(u.time * 0.79 + 1.0) * 0.035)
        + bass * 0.09;
    float aa = max(fwidth(radius), 0.001);
    float3 result = float3(0.010, 0.009, 0.029) + float3(0.04, 0.025, 0.10) * exp(-radius * radius * 4.0);
    for (int ring = 0; ring < 10; ring++) {
        float index = float(ring);
        float fold = angle + index * 0.080
            + sin(u.time * 0.42 - index * 0.28) * 0.18 * u.motionAmount
            + sin(radius * 5.0 - u.time * 0.30) * 0.06;
        float opening = breath + sin(u.time * 0.70 - index * 0.55) * 0.065 * u.motionAmount;
        float contour = (0.04 + index * 0.034) * opening
            * (1.0 + 0.22 * cos(fold * 12.0) + 0.035 * cos(fold * 24.0));
        float outer = abs(radius - contour);
        float inner = abs(radius - contour * 0.80);
        float facet = smoothstep(contour * 0.79, contour * 0.85, radius)
            * (1.0 - smoothstep(contour * 0.98, contour * 1.02, radius));
        float edges = 1.0 - smoothstep(0.001, 0.001 + aa, min(outer, inner));
        float hue = 0.5 + 0.5 * sin(index * 0.60 + fold * 2.0 + u.time * 0.09);
        float3 pigment = mix(float3(0.03, 0.66, 0.86), float3(0.58, 0.18, 0.88), hue);
        float glint = pow(0.5 + 0.5 * cos(fold * 12.0 - index * 0.24 + u.time * 0.55), 12.0);
        float glow = exp(-outer * outer / 0.00008);
        result += pigment * (facet * 0.19 + edges * 0.45 + glow * 0.10) * (0.85 + drive * 0.30);
        result += float3(0.62, 0.83, 0.96) * glint * facet * 0.12;
    }
    return 1.0 - exp(-result * 1.3);
}

float3 auroraVeilField(float2 point, constant VisualizerUniforms& u) {
    float drive = clamp(u.level, 0.0, 1.0) * u.activity;
    float mids = clamp(u.mids, 0.0, 1.0) * u.activity;
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float3 result = float3(0.004, 0.009, 0.025);
    for (int layer = 0; layer < 6; layer++) {
        float index = float(layer);
        float bend = sin(p.y * 1.5 + u.time * 0.20 + index * 0.8) * 0.12
            + sin(p.y * 3.4 - u.time * 0.12 + index) * 0.035;
        float center = -0.42 + index * 0.17 + bend;
        float delta = p.x - center;
        float width = 0.035 + mids * 0.012;
        float fabric = exp(-delta * delta / (width * width * 5.0));
        float seam = exp(-delta * delta / (width * width * 0.30));
        float pleat = 0.68 + 0.32 * sin(delta * 90.0 + p.y * 2.0 + u.time * 0.13 + index);
        float height = 0.55 + 0.45 * sin(p.y * 1.1 - u.time * 0.09 + index * 0.7);
        float hue = 0.5 + 0.5 * sin(index * 0.9 + p.y * 0.6 + u.time * 0.045);
        float3 pigment = mix(float3(0.02, 0.68, 0.67), float3(0.48, 0.16, 0.86), hue);
        result += pigment * (fabric * pleat * 0.34 + seam * 0.09) * height * (0.85 + drive * 0.28);
    }
    return 1.0 - exp(-result * 1.45);
}

// Studio fields share a continuous, low-frequency current. Audio bends the current;
// it never resets phase or substitutes rapid flashes for motion.
float2 studioFlowPoint(float2 point, constant VisualizerUniforms& u) {
    float t = u.time;
    float amount = u.motionAmount;
    float scale = max(min(u.aspect, 1.0), 0.25);
    float breath = sin(t * 0.42) * 0.075 + sin(t * 0.19 + 1.2) * 0.035;
    float2 p = point / (1.0 + amount * (breath + u.bass * 0.10));
    float2 curl = float2(sin(p.y / scale * 2.8 - t * 0.24),
                         cos(p.x / scale * 2.4 + t * 0.21));
    p += curl * scale * amount * (0.035 + u.mids * 0.035);
    p += float2(sin(t * 0.13), cos(t * 0.17)) * scale * 0.025 * amount;
    return p;
}

float3 studioAtmosphere(float2 p, constant VisualizerUniforms& u) {
    float2 q = p / max(min(u.aspect, 1.0), 0.25);
    float cloud = nebulaDust(q * 2.2 + float2(u.time * 0.045, -u.time * 0.035));
    float halo = exp(-dot(q * float2(0.9, 0.65), q * float2(0.9, 0.65)) * 1.8);
    float hue = 0.5 + 0.5 * sin(q.x * 1.2 - q.y + u.time * 0.08);
    return float3(0.006, 0.012, 0.031) + mix(float3(0.015, 0.12, 0.15),
        float3(0.085, 0.025, 0.17), hue) * halo * (0.25 + cloud * 0.65 + u.bass * 0.18);
}

float3 studioSilkField(float2 point, constant VisualizerUniforms& u) {
    float scale = max(min(u.aspect, 1.0), 0.25);
    float2 p = point / scale;
    float t = u.time;
    float ebb = sin(t * 0.40) * 0.5 + sin(t * 0.17 + 1.1) * 0.25;
    float3 result = studioAtmosphere(point, u);
    float aa = max(fwidth(p.y), 0.0008);
    for (int family = 0; family < 3; family++) {
        float f = float(family);
        float phase = f * 2.1;
        float sweep = sin(p.x * 3.3 - t * 0.38 + phase);
        float fold = sin(p.x * 5.5 + t * 0.22 + phase) * 0.042 * u.motionAmount;
        float center = (f - 1.0) * 0.12 + sweep * (0.13 + u.motionAmount * 0.07 + u.mids * 0.11)
            + fold + ebb * 0.085 * u.motionAmount;
        float fan = (0.025 + 0.075 * (0.5 + 0.5 * sin(p.x * 3.0 - t * 0.27 + phase)))
            * (1.0 + u.bass * 0.6 + ebb * 0.18 * u.motionAmount);
        for (int ribbon = 0; ribbon < 16; ribbon++) {
            float lane = (float(ribbon) - 7.5) / 7.5;
            float curve = center + lane * fan + lane * lane * sin(p.x * 4.8 + t * 0.31 + phase) * 0.035;
            float distance = abs(p.y - curve);
            float core = 1.0 - smoothstep(0.0007, 0.0007 + aa, distance);
            float glow = exp(-distance * distance / (0.000075 + u.treble * 0.00004));
            float hue = 0.5 + 0.5 * sin(f * 1.8 + lane * 0.4 + p.x * 1.4 + t * 0.08);
            float3 color = mix(float3(0.03, 0.80, 0.84), float3(0.48, 0.19, 0.92), hue);
            float depth = 0.5 + 0.5 * (1.0 - abs(lane));
            result += color * (core * 0.58 + glow * 0.09) * depth * (0.75 + u.level * 0.25);
        }
    }
    return 1.0 - exp(-result * 1.1);
}

float3 tidalFlowField(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float t = u.time;
    float2 current = float2(t * 0.075, -t * 0.055);
    float2 q = p * 2.1 + current;
    float2 warp = float2(nebulaDust(q + float2(0.0, t * 0.035)),
                         nebulaDust(q + float2(4.8, -t * 0.04)));
    float density = nebulaDust(q + (warp - 0.5) * (2.4 + u.motionAmount * 1.3 + u.bass * 0.7));
    float contour = density * (12.0 + u.mids * 2.5) + p.y * 1.8 - t * 0.15;
    float tide = 0.5 + 0.5 * sin(contour * 6.2831853);
    float foam = pow(tide, 12.0) * (0.18 + u.treble * 0.16);
    float channel = smoothstep(0.28, 0.78, density);
    float hue = 0.5 + 0.5 * sin(density * 5.0 + p.x * 0.7 + t * 0.08);
    float3 pigment = mix(float3(0.02, 0.38, 0.45), float3(0.32, 0.08, 0.55), hue);
    float3 result = studioAtmosphere(point, u) + pigment * (0.18 + channel * 0.9) * (0.6 + tide * 0.4);
    result += mix(float3(0.08, 0.85, 0.79), float3(0.60, 0.47, 0.90), hue) * foam;
    return 1.0 - exp(-result * 1.45);
}

// The original palette is a passthrough. Other palettes remap only shader pixels,
// preserving the dark field, highlight detail, and independently composed white captions.
float3 studioColor(float3 color, constant VisualizerUniforms& u) {
    if (u.palette < 0.5) { return color; }
    float3 low, mid, high;
    if (u.palette < 1.5) {
        low = float3(0.345, 0.906, 0.886); mid = float3(0.918, 0.498, 0.773); high = float3(0.973, 0.851, 0.514);
    } else if (u.palette < 2.5) {
        low = float3(0.616, 0.220, 0.412); mid = float3(0.953, 0.616, 0.616); high = float3(1.0, 0.878, 0.651);
    } else if (u.palette < 3.5) {
        low = float3(0.620, 0.090, 0.290); mid = float3(0.980, 0.337, 0.200); high = float3(1.0, 0.812, 0.302);
    } else if (u.palette < 4.5) {
        low = float3(0.035, 0.326, 0.306); mid = float3(0.114, 0.788, 0.596); high = float3(0.757, 0.929, 0.529);
    } else if (u.palette < 5.5) {
        low = float3(0.082, 0.298, 0.620); mid = float3(0.329, 0.804, 0.922); high = float3(0.855, 0.973, 1.0);
    } else if (u.palette < 6.5) {
        low = float3(0.286, 0.141, 0.659); mid = float3(0.710, 0.212, 0.910); high = float3(0.984, 0.643, 0.922);
    } else if (u.palette < 7.5) {
        low = float3(0.333, 0.631, 1.0); mid = float3(0.949, 0.290, 0.675); high = float3(1.0, 0.671, 0.808);
    } else {
        low = float3(0.063, 0.678, 0.659); mid = float3(0.690, 0.337, 0.729); high = float3(1.0, 0.682, 0.404);
    }
    float brightness = max(color.r, max(color.g, color.b));
    float hue = clamp((color.b - color.g) / max(brightness, 0.001) * 1.6 - 0.18, 0.0, 1.0);
    float position = clamp(hue * 0.80 + brightness * 0.20, 0.0, 1.0);
    float3 pigment = position < 0.5 ? mix(low, mid, smoothstep(0.0, 0.5, position))
                                     : mix(mid, high, smoothstep(0.5, 1.0, position));
    float3 mapped = pigment / max(max(pigment.r, max(pigment.g, pigment.b)), 0.001) * brightness;
    float white = min(color.r, min(color.g, color.b)) / max(brightness, 0.001);
    return mix(mapped, float3(brightness), smoothstep(0.72, 1.0, white) * 0.42);
}

float3 portalPigment(float hue) {
    return mix(float3(0.03, 0.76, 0.85), float3(0.63, 0.14, 0.87), hue);
}

float3 prismaticWormhole(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float t = u.time;
    float3 result = studioAtmosphere(point, u) * 0.65;
    float aa = max(fwidth(length(p)), 0.001);
    for (int ring = 0; ring < 24; ring++) {
        float travel = fract(float(ring) / 24.0 + t * 0.065);
        float radius = 0.035 + pow(travel, 1.9) * 1.55;
        float depth = travel * travel;
        float2 bend = float2(sin(t * 0.15 + travel * 2.5), cos(t * 0.12 + travel * 2.2))
            * depth * 0.12 * u.motionAmount;
        float2 q = p - bend;
        float angle = atan2(q.y, q.x) + t * 0.13 + travel * 1.8;
        float petals = cos(angle * 12.0 + sin(t * 0.3 - travel * 3.0) * 0.5);
        float contour = radius * (1.0 + petals * (0.10 + u.mids * 0.04)
            + cos(angle * 24.0) * 0.018) * (1.0 + u.bass * 0.12);
        float distance = abs(length(q) - contour);
        float width = 0.0007 + depth * 0.003;
        float edge = 1.0 - smoothstep(width, width + aa, distance);
        float glow = exp(-distance * distance / (0.00002 + depth * 0.00035));
        float fade = smoothstep(0.0, 0.08, travel) * (1.0 - smoothstep(0.86, 1.0, travel));
        float hue = 0.5 + 0.5 * sin(travel * 7.0 + angle * 2.0 - t * 0.14);
        result += portalPigment(hue) * (edge * 0.65 + glow * 0.18) * fade * (0.65 + u.level * 0.4);
    }
    float hole = smoothstep(0.015, 0.065, length(p));
    return (1.0 - exp(-result * 1.3)) * hole;
}

float3 auroraWormhole(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float t = u.time;
    p -= float2(sin(t * 0.16), cos(t * 0.13)) * 0.035 * u.motionAmount;
    float r = length(p);
    float angle = atan2(p.y, p.x);
    float depth = 1.0 / (r + 0.13);
    float twist = angle + depth * 0.42 + t * 0.18 + sin(depth - t * 0.3) * 0.16 * u.motionAmount;
    float3 result = studioAtmosphere(point, u);
    for (int veil = 0; veil < 6; veil++) {
        float i = float(veil);
        float fold = 0.5 + 0.5 * cos(twist * 6.0 + i * 0.25 + sin(depth * 1.4 - t * 0.6 + i) * 0.30);
        float fabric = pow(fold, 9.0);
        float seam = pow(fold, 60.0);
        float tide = 0.6 + 0.4 * sin(depth * 2.5 - t * 1.1 + i * 0.8);
        float hue = 0.5 + 0.5 * sin(depth * 0.8 + i + t * 0.08);
        result += portalPigment(hue) * (fabric * 0.10 + seam * 0.16) * tide * (0.7 + u.mids * 0.4);
    }
    float rings = pow(0.5 + 0.5 * cos(depth * 8.0 - t * 2.4), 15.0);
    result += float3(0.12, 0.55, 0.68) * rings * 0.20 * (0.7 + u.bass * 0.5);
    return (1.0 - exp(-result * 1.5)) * smoothstep(0.025, 0.10, r);
}

float3 cosmicVortex(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float r = length(p);
    float t = u.time;
    float angle = atan2(p.y, p.x);
    float spiral = angle * 5.0 - log(r + 0.035) * (5.0 + u.bass * 0.6) - t * 0.65;
    float arms = pow(0.5 + 0.5 * cos(spiral + sin(r * 9.0 - t * 0.45) * 0.6 * u.motionAmount), 9.0);
    float dust = nebulaDust(p * 4.0 + float2(t * 0.08, -t * 0.06));
    float glow = exp(-r * 0.8) * smoothstep(0.025, 0.13, r);
    float hue = 0.5 + 0.5 * sin(log(r + 0.06) * 2.0 + angle * 2.0 + t * 0.12);
    float3 result = studioAtmosphere(point, u) + portalPigment(hue) * arms * glow * (0.15 + dust * 0.65 + u.mids * 0.25);
    result += starDriftField(point, u) * 0.35;
    float rim = exp(-pow((r - 0.085 - u.bass * 0.012) * 80.0, 2.0));
    result += float3(0.25, 0.68, 0.85) * rim * 0.38;
    return (1.0 - exp(-result * 1.55)) * smoothstep(0.035, 0.065, r);
}

float3 liquidPortal(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float t = u.time;
    float r = length(p);
    float angle = atan2(p.y, p.x);
    float depth = 1.0 / (r + 0.10);
    // Integer angular harmonics keep the cylindrical seam continuous.
    float ripple = sin(angle * 7.0 + t * 0.35 + depth * 0.3) * (0.2 + u.mids * 0.16)
        + cos(angle * 3.0 - t * 0.22) * 0.15 * u.motionAmount;
    float rings = 0.5 + 0.5 * sin(depth * 5.0 - t * 1.6 + ripple * 3.0);
    float caustic = pow(rings, 14.0);
    float sheen = pow(0.5 + 0.5 * cos(angle * 12.0 + depth * 2.0 - t * 0.4), 6.0);
    float hue = 0.5 + 0.5 * sin(depth * 0.75 + angle * 2.0 + t * 0.10);
    float3 result = studioAtmosphere(point, u) + portalPigment(hue)
        * (0.07 + rings * 0.16 + caustic * (0.30 + u.treble * 0.18) + sheen * caustic * 0.35);
    return (1.0 - exp(-result * 1.4)) * smoothstep(0.015, 0.09, r);
}

float3 crystalLotus(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float r = length(p), t = u.time;
    float angle = atan2(p.y, p.x);
    float aa = max(fwidth(r), 0.001);
    float3 result = studioAtmosphere(point, u);
    for (int layer = 0; layer < 14; layer++) {
        float i = float(layer);
        float rotation = angle + i * 0.18 + sin(t * 0.36 - i * 0.31) * 0.24 * u.motionAmount;
        float opening = 1.0 + sin(t * 0.52 - i * 0.42) * 0.13 * u.motionAmount + u.bass * 0.12;
        float petals = pow(0.5 + 0.5 * cos(rotation * 8.0), 0.60);
        float edge = (0.04 + i * 0.032) * opening * (0.63 + petals * 0.46);
        float distance = abs(r - edge);
        float facet = smoothstep(edge * 0.72, edge * 0.88, r) * (1.0 - smoothstep(edge * 0.96, edge * 1.02, r));
        float line = 1.0 - smoothstep(0.001, 0.001 + aa, distance);
        float hue = 0.5 + 0.5 * sin(i * 0.55 + rotation * 2.0 + t * 0.12);
        result += portalPigment(hue) * (line * 0.40 + facet * 0.17) * (0.7 + u.level * 0.30);
        result += float3(0.68, 0.80, 0.94) * pow(petals, 16.0) * facet * (0.10 + u.treble * 0.10);
    }
    return 1.0 - exp(-result * 1.35);
}

float3 radiantIris(float2 point, constant VisualizerUniforms& u) {
    float2 p = point / max(min(u.aspect, 1.0), 0.25);
    float r = length(p), t = u.time;
    float angle = atan2(p.y, p.x) + t * 0.10;
    float aa = max(fwidth(r), 0.001);
    float3 result = studioAtmosphere(point, u);
    float breathing = 1.0 + sin(t * 0.48) * 0.10 * u.motionAmount + u.bass * 0.10;
    for (int layer = 0; layer < 12; layer++) {
        float i = float(layer);
        float twist = angle + sin(t * 0.44 - i * 0.45) * 0.18 * u.motionAmount;
        float petal = cos(twist * 16.0 - i * 0.20);
        float contour = (0.055 + i * 0.032) * breathing * (1.0 + petal * 0.13);
        float distance = abs(r - contour);
        float edge = 1.0 - smoothstep(0.001, 0.001 + aa, distance);
        float glow = exp(-distance * distance / 0.00015);
        float hue = 0.5 + 0.5 * sin(i * 0.75 + twist * 2.0 + t * 0.15);
        result += portalPigment(hue) * (edge * 0.38 + glow * 0.13) * (0.70 + u.mids * 0.35);
        float ray = pow(0.5 + 0.5 * cos(twist * 32.0 + r * 15.0 - t * 0.5), 18.0);
        result += float3(0.58, 0.78, 0.95) * ray * glow * (0.08 + u.treble * 0.12);
    }
    return 1.0 - exp(-result * 1.30);
}

// STUDIO_SACRED_GEOMETRY
// STUDIO_RESONANCE

fragment half4 zenWaveVisualizerFragment(
    VertexOut input [[stage_in]],
    constant VisualizerUniforms& uniforms [[buffer(0)]]
) {
    if (uniforms.style > 33.5) {
        float2 p = (input.uv - 0.5) * float2(uniforms.aspect, 1.0) / max(min(uniforms.aspect, 1.0), 0.25);
        float3 field = uniforms.style < 34.5 ? resonanceOrb(p, uniforms) : resonanceTorus(p, uniforms);
        return half4(half3(studioColor(field, uniforms)), half(1.0));
    }
    if (uniforms.style > 25.5) {
        float2 p = (input.uv - 0.5) * float2(uniforms.aspect, 1.0);
        float3 field = studioAtmosphere(p, uniforms) * 0.55;
        return half4(half3(studioColor(field, uniforms)), half(1.0));
    }
    if (uniforms.style > 19.5) {
        // Keep sacred constructions rigid: no fluid domain warp is applied to their vertices.
        float2 p = (input.uv - 0.5) * float2(uniforms.aspect, 1.0)
            / max(min(uniforms.aspect, 1.0), 0.25);
        float3 field;
        if (uniforms.style < 20.5) { field = merkabaField(p, uniforms); }
        else if (uniforms.style < 21.5) { field = metatronField(p, uniforms); }
        else if (uniforms.style < 22.5) { field = circleLatticeField(p, uniforms, false); }
        else if (uniforms.style < 23.5) { field = circleLatticeField(p, uniforms, true); }
        else if (uniforms.style < 24.5) { field = vesicaField(p, uniforms); }
        else { field = octahedralField(p, uniforms); }
        return half4(half3(studioColor(field, uniforms)), half(1.0));
    }
    if (uniforms.style > 13.5) {
        float2 p = studioFlowPoint((input.uv - 0.5) * float2(uniforms.aspect, 1.0), uniforms);
        float3 field;
        if (uniforms.style < 14.5) { field = prismaticWormhole(p, uniforms); }
        else if (uniforms.style < 15.5) { field = auroraWormhole(p, uniforms); }
        else if (uniforms.style < 16.5) { field = cosmicVortex(p, uniforms); }
        else if (uniforms.style < 17.5) { field = liquidPortal(p, uniforms); }
        else if (uniforms.style < 18.5) { field = crystalLotus(p, uniforms); }
        else { field = radiantIris(p, uniforms); }
        return half4(half3(studioColor(field, uniforms)), half(1.0));
    }
    float2 original = (input.uv - 0.5) * float2(uniforms.aspect, 1.0);
    float2 point = studioFlowPoint(original, uniforms);
    if (uniforms.style > 11.5 && uniforms.style < 12.5) {
        return half4(half3(studioColor(tidalFlowField(point, uniforms), uniforms)), half(1.0));
    }
    if (uniforms.style > 2.5 && uniforms.style < 3.5) {
        return half4(half3(studioColor(studioSilkField(point, uniforms), uniforms)), half(1.0));
    }
    // Retain each field’s identity while adding a shared ebb and a luminous atmosphere.
    if (uniforms.style > 3.5 && uniforms.style < 11.5) {
        float3 field;
        if (uniforms.style < 4.5) { field = deepParticleField(point, uniforms); }
        else if (uniforms.style < 5.5) { field = geometricKaleidoscope(point, uniforms); }
        else if (uniforms.style < 6.5) { field = starDriftField(point, uniforms); }
        else if (uniforms.style < 7.5) { field = nebulaFlightField(point, uniforms); }
        else if (uniforms.style < 8.5) { field = orbitalWaveField(point, uniforms); }
        else if (uniforms.style < 9.5) { field = liquidConstellationField(point, uniforms); }
        else if (uniforms.style < 10.5) { field = prismaticBloomField(point, uniforms); }
        else { field = auroraVeilField(point, uniforms); }
        field += studioAtmosphere(point, uniforms) * 0.45;
        if (uniforms.light > 0.5) {
            float mask = clamp(max(field.r, max(field.g, field.b)) * 1.5, 0.0, 1.0);
            float3 ink = mix(float3(0.02, 0.30, 0.39), float3(0.34, 0.14, 0.56),
                clamp(field.b - field.g + 0.5, 0.0, 1.0));
            field = mix(float3(0.953, 0.933, 0.898), ink, mask);
        }
        return half4(half3(studioColor(field, uniforms)), half(1.0));
    }
    float liveEnergy = max(uniforms.level, uniforms.peak * 0.82);
    float normalizedBeat = clamp(uniforms.beatFrequency / 30.0, 0.0, 1.0);
    // Binaural beats are perceived at the difference frequency, but that rate
    // only offsets a slow twelve-second visual breath, never literal flashes.
    float binauralSwell = 0.5 + 0.5 * sin(uniforms.time * 0.52 + normalizedBeat * 0.5);
    float energy = mix(0.14, max(uniforms.intensity * 0.35, liveEnergy), uniforms.activity)
        * mix(0.82, 1.12, binauralSwell * uniforms.activity);
    // Keep the traces meditative: the audio changes their shape and brightness,
    // while their travel remains intentionally unhurried.
    float motion = uniforms.time * (uniforms.presentation < 0.5 ? 0.75 : 1.05);

    float waveA = sin(point.x * (10.0 + uniforms.bass * 8.0) - motion * 2.1) * (0.025 + energy * 0.24);
    float waveB = sin(point.x * (7.0 + uniforms.mids * 12.0) + motion * 1.4 + 1.2) * (0.018 + uniforms.mids * 0.19);
    float waveC = cos(point.x * (16.0 + uniforms.treble * 24.0) - motion * 1.1) * (0.012 + uniforms.treble * 0.15);
    float waveform = min(abs(point.y - waveA), min(abs(point.y - waveB), abs(point.y - waveC)));
    float waveGlow = smoothstep(0.082, 0.0, waveform);
    float waveCore = smoothstep(0.009, 0.0, waveform);

    float radius = length(point);
    float ringRadius = 0.20 + uniforms.bass * 0.19 + (binauralSwell - 0.5) * 0.035;
    float ring = smoothstep(0.026 + uniforms.peak * 0.025, 0.0, abs(radius - ringRadius));
    float halo = smoothstep(0.30 + energy * 0.36, 0.0, radius) * (0.18 + uniforms.bass * 0.44);
    float stars = smoothstep(0.90 - uniforms.treble * 0.12, 1.0, sin((point.x * 71.0 + point.y * 53.0 + motion) * 3.0)) * (0.06 + uniforms.treble * 0.34);

    float3 deepBlue = float3(0.04, 0.09, 0.26);
    float3 indigo = float3(0.29, 0.18, 0.72);
    float3 cyan = float3(0.24, 0.95, 1.0);
    float3 pink = float3(0.9, 0.34, 0.95);
    float3 violet = float3(0.48, 0.20, 1.0);
    float3 background = mix(deepBlue, indigo, input.uv.y * 0.72 + 0.08);
    float3 color = background;
    float visualMask = 0.0;

    if (uniforms.style < 0.5) {
        // Scope: layered, high-definition wave traces with frequency-specific motion.
        color += cyan * (waveGlow * (0.34 + uniforms.mids * 0.72) + waveCore * (0.76 + uniforms.peak));
        color += mix(cyan, pink, input.uv.x * 0.5 + uniforms.treble * 0.4) * (ring * (0.35 + uniforms.bass * 0.65) + halo * 0.42);
        color += cyan * stars * uniforms.activity * 0.65;
        visualMask = waveGlow * 0.48 + waveCore * 0.34 + ring * 0.12;
    } else if (uniforms.style < 1.5) {
        // Bloom: an audio-driven radial mandala whose petals open with the mid band.
        float angle = atan2(point.y, point.x);
        float petalCount = 8.0;
        float petals = 0.5 + 0.5 * cos(angle * petalCount + motion * 0.65);
        float bloomRadius = 0.13 + uniforms.bass * 0.13 + petals * (0.08 + uniforms.mids * 0.13);
        float bloomEdge = smoothstep(0.052, 0.0, abs(radius - bloomRadius));
        float innerBloom = smoothstep(bloomRadius, 0.0, radius) * (0.24 + uniforms.peak * 0.42);
        float outerBloom = smoothstep(0.032, 0.0, abs(radius - bloomRadius * 1.55)) * uniforms.treble;
        float radialSpark = smoothstep(0.92, 1.0, sin(angle * (18.0 + uniforms.treble * 20.0) - motion * 2.0)) * halo;
        color = mix(float3(0.03, 0.04, 0.18), indigo, 0.38 + innerBloom);
        color += mix(pink, cyan, petals) * bloomEdge * (0.62 + uniforms.peak);
        color += violet * innerBloom + cyan * outerBloom * 0.8 + pink * radialSpark * uniforms.activity;
        visualMask = bloomEdge * 0.58 + innerBloom * 0.36 + outerBloom * 0.22;
    } else if (uniforms.style < 2.5) {
        // Tunnel: concentric audio rings with a rotational, classic-visualizer feel.
        float angle = atan2(point.y, point.x);
        float warp = sin(angle * (5.0 + uniforms.mids * 5.0) + motion) * (0.014 + uniforms.mids * 0.035);
        float tunnelRadius = max(0.0, radius + warp);
        float bandPosition = abs(fract(tunnelRadius * (7.0 + uniforms.treble * 10.0) - motion * 0.24) - 0.5);
        float tunnelRings = smoothstep(0.13 + uniforms.peak * 0.08, 0.0, bandPosition);
        float spokes = smoothstep(0.93, 1.0, abs(sin(angle * 8.0 - motion * 0.72)));
        float centerPortal = smoothstep(0.24 + uniforms.bass * 0.10, 0.02, radius);
        float tunnelFade = smoothstep(0.82, 0.08, radius);
        color = mix(float3(0.015, 0.025, 0.12), violet, centerPortal * 0.62);
        color += mix(cyan, pink, input.uv.y + uniforms.treble * 0.25) * tunnelRings * tunnelFade * (0.42 + uniforms.level);
        color += cyan * spokes * tunnelRings * uniforms.treble * 0.52;
        color += pink * stars * uniforms.activity;
        visualMask = tunnelRings * tunnelFade * 0.58 + centerPortal * 0.28;
    } else {
        if (uniforms.presentation > 1.5) {
            // The brand mark stays upright: rounded triangular contours with
            // nested ribbons. Audio opens the strands without rotating the logo.
            float2 p = (input.uv - 0.5) * 2.0;
            p *= float2(max(uniforms.aspect, 1.0), max(1.0 / uniforms.aspect, 1.0));
            p.y += 0.05;
            float angle = atan2(p.y, p.x);
            float radial = length(p);
            float phase = uniforms.time * 0.48;
            // Measured sound opens and bends the ribbons; continuous phase
            // keeps amplitude changes from jumping the animation's position.
            float loudness = clamp(uniforms.level, 0.0, 1.0);
            float bassResponse = clamp(uniforms.bass, 0.0, 1.0) * uniforms.activity;
            float midResponse = clamp(uniforms.mids, 0.0, 1.0) * uniforms.activity;
            float highResponse = clamp(uniforms.treble, 0.0, 1.0) * uniforms.activity;
            float swell = loudness * uniforms.activity;
            float rocking = 0.085 * uniforms.motionAmount * sin(phase * 0.7);
            p = float2(p.x * cos(rocking) - p.y * sin(rocking),
                       p.x * sin(rocking) + p.y * cos(rocking));
            angle = atan2(p.y, p.x);
            // Smooth intersection of the three triangle half-planes rounds
            // the corners while keeping the sides and central opening legible.
            float3 planes = cos(float3(angle + M_PI_F * 0.5,
                angle - M_PI_F / 6.0, angle - M_PI_F * 5.0 / 6.0));
            float support = log(exp(planes.x * 12.0) + exp(planes.y * 12.0)
                + exp(planes.z * 12.0)) / 12.0;
            float triangleRadius = 0.34 / support;
            float breath = 1.0 + (0.055 * uniforms.motionAmount + swell * 0.040) * sin(phase)
                + swell * 0.035 + uniforms.peak * uniforms.activity * 0.012;
            float fold = sin(angle * 3.0 - phase) * (0.050 + bassResponse * 0.030 + swell * 0.020);
            float drift = (0.018 + midResponse * 0.017) * sin(angle * 2.0 + phase * 0.9);
            float outerFan = 0.17 + bassResponse * 0.035;
            float innerFan = 0.10 + midResponse * 0.025;
            float detail = highResponse * 0.012 * sin(angle * 5.0 - phase * 1.4);
            float outerDistance = 1.0;
            float innerDistance = 1.0;
            for (int strand = 0; strand < 16; strand++) {
                float lane = (float(strand) - 7.5) / 7.5;
                float outer = triangleRadius * breath * (1.0 + lane * outerFan)
                    + lane * fold + lane * lane * detail + drift;
                float inner = triangleRadius * breath * (0.55 + lane * innerFan)
                    - lane * fold * 0.55 - lane * lane * detail * 0.5 + drift * 0.5;
                outerDistance = min(outerDistance, abs(radial - outer));
                innerDistance = min(innerDistance, abs(radial - inner));
            }
            float distanceToRibbon = min(outerDistance, innerDistance);
            float antialias = max(fwidth(radial), 0.001);
            float core = 1.0 - smoothstep(0.0012, 0.0012 + antialias, distanceToRibbon);
            float glow = 1.0 - smoothstep(0.0, 0.018, distanceToRibbon);
            float hue = clamp(0.50 - p.y * 0.72 + p.x * 0.20, 0.0, 1.0);
            float3 ribbonColor = mix(float3(0.01, 0.88, 0.95), float3(0.64, 0.22, 0.96), hue);
            float3 base = mix(float3(0.031, 0.035, 0.043), float3(0.953, 0.933, 0.898), uniforms.light);
            float luminance = 0.86 + 0.10 * sin(angle * 2.0 + phase * 0.6)
                + swell * 0.24;
            float lightMask = clamp(core * 0.90 + glow * 0.14, 0.0, 1.0);
            float3 result = uniforms.light > 0.5
                ? mix(base, mix(float3(0.0, 0.36, 0.41), float3(0.39, 0.16, 0.62), hue), lightMask)
                : base + ribbonColor * (core + glow * 0.22) * luminance;
            return half4(half3(studioColor(result, uniforms)), half(1.0));
        }
        // Signature Waves: two sculptural families of fine cyan and violet
        // traces. Audio opens the ribbons and changes their light; the beat
        // difference only affects their slow travel, never literal flashes.
        float x = input.uv.x * 2.0 - 1.0;
        float y = input.uv.y * 2.0 - 1.0;
        float sculpture = step(1.5, uniforms.presentation);
        x += sculpture * y * 0.42 * sin(motion * 0.3 + y * 2.2);
        y *= mix(1.0, 0.68, sculpture);
        y += sculpture * 0.1 * sin(x * 3.5 + motion * 0.22);
        float slowFold = sin(x * 2.5 - motion * 0.42);
        float fineFold = sin(x * 4.9 + motion * 0.26 + 0.8);
        float cyanCenter = 0.10 + (0.18 + uniforms.mids * 0.11) * slowFold + 0.05 * fineFold;
        float violetCenter = -0.09 + (0.14 + uniforms.bass * 0.13)
            * sin(x * 2.7 + motion * 0.35 + 1.4) - 0.04 * fineFold;
        float cyanFan = 0.07 + (0.16 + uniforms.bass * 0.08)
            * (0.5 + 0.5 * sin(x * 3.4 - motion * 0.18));
        float violetFan = 0.06 + (0.14 + uniforms.mids * 0.07)
            * (0.5 + 0.5 * cos(x * 3.2 + motion * 0.18));
        float twist = sin(x * 6.0 + motion * 0.28) * 0.035;
        float cyanDistance = 1.0;
        float violetDistance = 1.0;

        for (int index = 0; index < 16; index++) {
            float lane = (float(index) - 7.5) / 7.5;
            float cyanTrace = cyanCenter + lane * cyanFan + lane * lane * twist;
            float violetTrace = violetCenter + lane * violetFan - lane * lane * twist;
            cyanDistance = min(cyanDistance, abs(y - cyanTrace));
            violetDistance = min(violetDistance, abs(y - violetTrace));
        }

        float cyanGlow = smoothstep(0.036, 0.0, cyanDistance);
        float cyanCore = smoothstep(0.004, 0.0, cyanDistance);
        float violetGlow = smoothstep(0.036, 0.0, violetDistance);
        float violetCore = smoothstep(0.004, 0.0, violetDistance);
        float edgeFade = smoothstep(-1.0, -0.86, x) * (1.0 - smoothstep(0.86, 1.0, x));
        float activeLight = mix(0.72, 0.94 + uniforms.peak * 0.32 + uniforms.treble * 0.18,
            uniforms.activity);
        float3 ink = mix(float3(0.031, 0.035, 0.043), float3(0.953, 0.933, 0.898), uniforms.light);
        float3 cyanLight = mix(float3(0.03, 0.88, 0.96), float3(0.12, 0.36, 1.0),
            0.44 + 0.28 * sin(x * 2.2));
        float3 violetLight = mix(float3(0.13, 0.39, 1.0), float3(0.65, 0.19, 0.95),
            0.56 + 0.24 * sin(x * 2.8 + 0.7));
        float3 ribbons = edgeFade * activeLight * (
            cyanLight * (cyanGlow * 0.34 + cyanCore * 1.10) +
            violetLight * (violetGlow * 0.34 + violetCore * 1.10)
        );
        float mask = clamp(max(cyanGlow, violetGlow) * edgeFade, 0.0, 1.0);
        color = uniforms.light > 0.5
            ? mix(ink, clamp(float3(0.0, 0.20, 0.28) + ribbons * float3(0.28, 0.12, 0.32), 0.0, 1.0), mask)
            : ink + ribbons;
        return half4(half3(studioColor(color, uniforms)), half(1.0));
    }

    if (uniforms.light > 0.5) {
        color = mix(float3(0.953, 0.933, 0.898), clamp(1.0 - color, 0.05, 0.65), clamp(visualMask, 0.0, 1.0));
    }
    float alpha = 1.0;
    return half4(half3(studioColor(color, uniforms)), half(alpha));
}
