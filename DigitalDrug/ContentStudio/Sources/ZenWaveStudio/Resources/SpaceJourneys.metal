// Original ZenWave space scenes. Shared math also generates the GLSL MilkDrop presets.
// Finite layers and antialiased contours keep these usable on the Intel renderer.
float spaceHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float3 spaceTint(float phase) {
    return 0.50 + 0.45 * cos(float3(0.2, 2.1, 4.2) + phase * 6.2831853);
}
float spaceLine(float phase, float width) {
    float distance = abs(sin(phase));
    return 1.0 - smoothstep(width, width + max(fwidth(phase) * 0.75, 0.012), distance);
}
float3 spaceStars(float2 p, float t, float energy) {
    float3 stars = float3(0.0);
    for (int layer = 0; layer < 5; layer++) {
        float travel = fract(float(layer) / 5.0 - t * 0.032);
        float depth = 0.18 + travel * 3.6;
        float2 q = p * depth * 12.0;
        float2 cell = floor(q);
        float seed = spaceHash(cell + float(layer) * 19.3);
        float2 spot = 0.18 + 0.64 * float2(seed, spaceHash(cell + 17.4 + float(layer) * 19.3));
        float2 delta = (fract(q) - spot) / (depth * 12.0);
        float size = 0.0010 + 0.0012 / depth;
        float aa = max(fwidth(p.x), fwidth(p.y));
        float star = exp(-dot(delta, delta) / (size * size + aa * aa));
        float fade = smoothstep(0.0, 0.12, travel) * (1.0 - smoothstep(0.80, 1.0, travel));
        stars += mix(float3(0.45, 0.80, 1.0), float3(1.0, 0.68, 0.45), spaceHash(cell + 101.7)) * star * fade * smoothstep(0.94, 0.98, seed) * (0.55 + energy * 0.65);
    }
    return stars;
}
float3 spaceJourney(float2 point, float t, float energy, float bass, float treble, float motion, int kind) {
    // Camera drift is continuous, with no hard direction reversal or phase reset.
    float2 p = point - float2(sin(t * 0.11), cos(t * 0.09)) * (0.018 + energy * 0.012) * motion;
    float r = max(length(p), 0.008);
    float angle = atan2(p.y, p.x);
    float depth = -log(r + 0.018);
    float3 color = float3(0.003, 0.006, 0.018);
    float3 stars = spaceStars(p, t, energy);
    float core = smoothstep(0.055, 0.13, r);
    if (kind == 0) {
        // Lensed accretion disc, orbiting filaments and a dark central aperture.
        float twist = angle + depth * 1.9 + t * 0.085 * (0.3 + motion * 0.7);
        float stream = pow(0.5 + 0.5 * sin(twist * 7.0 + sin(depth * 4.0 - t * 0.23)), 12.0);
        float rings = spaceLine(depth * 17.0 + t * 0.65, 0.045);
        float haloRadius = 0.112 + bass * 0.009;
        float halo = exp(-pow((r - haloRadius) / 0.012, 2.0));
        float disc = exp(-pow((length(float2(p.x, p.y * 3.2)) - 0.22) / 0.027, 2.0));
        color += spaceTint(depth * 0.12 + t * 0.012) * (rings * 0.18 + stream * 0.40) * core * exp(-r * 0.8);
        color += float3(0.48, 0.78, 1.0) * halo * (0.65 + energy * 0.35);
        color += float3(1.0, 0.52, 0.19) * disc * (0.20 + stream * 0.20) * core;
        color += stars * (0.35 + r * 0.4);
        color *= smoothstep(0.066, 0.092, r);
    } else if (kind == 1) {
        // Broad aurora curtains weave along a bent tunnel, rather than hard rings.
        for (int ribbon = 0; ribbon < 5; ribbon++) {
            float lane = float(ribbon);
            float bend = angle * 3.0 + depth * 3.5 - t * 0.34 + lane * 1.24;
            float curtain = pow(0.5 + 0.5 * sin(bend + sin(depth * 2.0 + t * 0.15 + lane) * 0.7 * motion), 18.0);
            float flow = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(depth * 9.0 + t * 0.8 + lane), 3.0);
            color += spaceTint(lane * 0.19 + depth * 0.045 + t * 0.006) * curtain * flow * 0.36 * core;
        }
        color += float3(0.08, 0.37, 0.42) * exp(-r * 2.3) * core * 0.18;
        color += stars * 0.65;
    } else if (kind == 2) {
        // Perspective hexagonal gates and a slowly twisting angular light grid.
        float a = angle + t * 0.035 + sin(depth * 1.7 - t * 0.12) * 0.06 * motion;
        float sector = 1.04719755;
        float folded = fract(a / sector + 0.5) * sector - sector * 0.5;
        float polygonRadius = r * cos(folded);
        float corridor = -log(max(polygonRadius, 0.012));
        float gates = spaceLine(corridor * 15.0 + t * 0.72, 0.045);
        float ribs = spaceLine(a * 6.0, 0.023);
        float glow = pow(0.5 + 0.5 * cos(corridor * 30.0 + t * 1.44), 18.0);
        float3 pigment = spaceTint(corridor * 0.11 + t * 0.008);
        color += pigment * (gates * 0.70 + ribs * 0.16 + glow * 0.10) * core;
        color += float3(0.55, 0.87, 1.0) * gates * ribs * (0.35 + treble * 0.3) * core;
        color += stars * 0.45;
    } else {
        // Open space: layered clouds with forward star flight, no enclosing tube.
        float haze = 0.0;
        float2 q = p;
        for (int octave = 0; octave < 4; octave++) {
            float scale = float(octave) + 1.0;
            q = float2(q.x * 0.82 - q.y * 0.57, q.x * 0.57 + q.y * 0.82);
            float cloud = sin(q.x * (4.0 + scale * 3.0) + t * 0.07 * scale)
                * sin(q.y * (3.0 + scale * 2.0) - t * 0.05 * scale + sin(q.x * 4.0));
            haze += cloud / (scale * 2.2);
        }
        float cloud = pow(clamp(haze * 0.80 + 0.45, 0.0, 1.0), 2.0);
        color += mix(float3(0.13, 0.08, 0.40), float3(0.06, 0.42, 0.50), 0.5 + haze * 0.5) * cloud * (1.80 + energy * 0.40);
        color += float3(0.49, 0.12, 0.38) * cloud * exp(-abs(p.y - sin(p.x * 2.0 + t * 0.045) * 0.19) * 5.0) * 0.80;
        color += stars * 1.20;
    }
    color *= 0.85 + energy * 0.25;
    return 1.0 - exp(-color * 1.8);
}
