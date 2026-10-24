// Original procedural visual families: a quiet focal point, continuous flow, and room for type.
float3 resonanceOrb(float2 p, constant VisualizerUniforms& u) {
    float t = u.time, amount = u.motionAmount;
    float2 drift = float2(sin(t * 0.15), cos(t * 0.12)) * 0.013 * amount;
    float2 q = p - drift;
    float radius = 0.255 * (1.0 + sin(t * 0.48) * 0.055 * amount + u.bass * 0.09);
    float r = length(q), edge = abs(r - radius), aa = max(fwidth(r), 0.001);
    float3 result = studioAtmosphere(p * min(u.aspect, 1.0), u) * 0.42;
    float grid = max(pow(0.5 + 0.5 * cos(p.x * 58.0), 85.0), pow(0.5 + 0.5 * cos(p.y * 58.0), 85.0));
    result += float3(0.03, 0.045, 0.065) * grid * 0.28;
    result += portalPigment(0.5 + 0.3 * sin(t * 0.08)) * exp(-r * r / 0.11) * (0.25 + u.level * 0.16);
    if (r < radius + aa) {
        float2 xy = q / radius;
        float z = sqrt(max(0.0, 1.0 - dot(xy, xy)));
        float3 n = normalize(float3(xy, z));
        float diffuse = max(0.0, dot(n, normalize(float3(-0.45, 0.65, 1.0))));
        float silk = sin(xy.x * 5.0 + sin(xy.y * 4.0 + t * 0.22) * 1.5 - t * 0.28);
        float hue = 0.4 + silk * 0.15 + xy.y * 0.18;
        float3 pigment = portalPigment(hue);
        float specular = pow(max(0.0, dot(n, normalize(float3(-0.42, 0.55, 1.0)))), 20.0);
        float rim = pow(1.0 - z, 2.2);
        float coverage = 1.0 - smoothstep(radius - aa, radius + aa, r);
        result = mix(result, pigment * (0.24 + diffuse * 0.58 + silk * 0.04) + float3(0.85, 0.95, 1.0) * specular * 0.34 + pigment * rim * 0.38, coverage);
    }
    result += float3(0.55, 0.86, 0.96) * exp(-edge * edge / 0.000018) * 0.20;
    for (int ring = 0; ring < 4; ring++) {
        float i = float(ring), angle = atan2(q.y, q.x);
        float target = radius + 0.047 + i * 0.037 + sin(angle * 5.0 - t * 0.40 + i) * (0.0025 + u.mids * 0.004) * amount;
        float distance = abs(r - target);
        float arc = 0.28 + 0.72 * pow(0.5 + 0.5 * cos(angle - t * (0.18 + i * 0.035) + i * 1.9), 5.0);
        result += portalPigment(i / 4.0) * exp(-distance * distance / 0.000009) * arc * (0.13 + u.treble * 0.13);
    }
    for (int index = 0; index < 12; index++) {
        float i = float(index), a = i * 2.39996 + t * (0.085 + i * 0.002);
        float orbit = 0.335 + 0.035 * sin(i * 1.7 + t * 0.17);
        float2 center = drift + float2(cos(a), sin(a)) * orbit;
        float d = length(p - center), size = 0.007 + 0.003 * sin(i * 2.0);
        result += portalPigment(i / 12.0) * exp(-d * d / (size * size)) * (0.35 + u.level * 0.18);
    }
    return 1.0 - exp(-result * 1.38);
}

float3 resonanceRotate(float3 p, float t) {
    float a = 0.73 + sin(t * 0.13) * 0.19, b = t * 0.075;
    p = float3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a));
    return float3(p.x * cos(b) - p.y * sin(b), p.x * sin(b) + p.y * cos(b), p.z);
}
float resonanceTorusDistance(float3 p, float major, float minor) {
    return length(float2(length(p.xz) - major, p.y)) - minor;
}
float3 resonanceTorus(float2 p, constant VisualizerUniforms& u) {
    float t = u.time;
    float major = 0.265 * (1.0 + sin(t * 0.38) * 0.045 * u.motionAmount + u.bass * 0.06);
    float minor = 0.076 * (1.0 + u.level * 0.14);
    float3 result = studioAtmosphere(p * min(u.aspect, 1.0), u) * 0.48;
    result += portalPigment(0.5) * exp(-dot(p, p) * 9.0) * 0.10;
    if (length(p) > 0.46) { return 1.0 - exp(-result * 1.55); }
    float3 origin = resonanceRotate(float3(p, 1.0), t), direction = resonanceRotate(float3(0, 0, -1), t);
    float travel = 0.55, closest = 1.0;
    bool hit = false; float3 point;
    for (int step = 0; step < 56; step++) {
        point = origin + direction * travel;
        float distance = resonanceTorusDistance(point, major, minor);
        closest = min(closest, abs(distance));
        if (distance < 0.0012) { hit = true; break; }
        travel += max(distance * 0.88, 0.001);
        if (travel > 1.48) { break; }
    }
    float hue = 0.5 + 0.35 * sin(atan2(p.y, p.x) + t * 0.13);
    result += portalPigment(hue) * exp(-closest * 95.0) * (0.12 + u.treble * 0.10);
    if (hit) {
        float radial = max(length(point.xz), 0.0001);
        float3 normal = normalize(float3(point.x * (1.0 - major / radial), point.y, point.z * (1.0 - major / radial)));
        float longitude = atan2(point.z, point.x), latitude = atan2(point.y, radial - major);
        float meridians = pow(0.5 + 0.5 * cos(longitude * 48.0 + sin(latitude * 3.0 - t * 0.30) * 0.40 * u.motionAmount), 15.0);
        float parallels = pow(0.5 + 0.5 * cos(latitude * 24.0 - t * 0.60), 14.0);
        float stream = pow(0.5 + 0.5 * sin(latitude * 3.0 + longitude * 5.0 - t * 0.72), 6.0);
        float light = 0.24 + 0.76 * max(0.0, dot(normal, normalize(float3(-0.4, 0.8, 0.5))));
        float3 pigment = portalPigment(0.5 + 0.45 * sin(longitude * 0.8 + latitude * 0.5 + t * 0.1));
        result += pigment * (0.035 + meridians * 0.48 + parallels * 0.26 + stream * (0.13 + u.mids * 0.19)) * light;
        result += float3(0.60, 0.86, 0.98) * meridians * parallels * 0.40;
    }
    return 1.0 - exp(-result * 1.55);
}
