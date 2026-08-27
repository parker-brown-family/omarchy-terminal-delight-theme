#version 320 es
// Terminal Delight — curved glass for the whole desktop.
//
// Ported from the tuned WebGL2 pass in
//   web-warp-lab/approaches/03-webgl-canvas-terminal.html
// Barrel polynomial  f = 1 + k1·r² + k2·r⁴  with k1/k2 = CURV·(0.14, 0.06) —
// the same pair asserted in app/src/warp.rs:189.
//
// Hyprland pairs screen shaders with a GLES3 vertex shader, so the version
// directive is required and the dialect is in/out/texture(), not varying.

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float CURV  = 0.00;   // FLAT: per-window warp (surface.frag/ext.frag) carries the curve now.
                            // Raise toward 1.0 to bow the whole desktop as one big tube again.
const float ABERR = 0.55;   // chromatic split at the rim
const float SCAN  = 0.35;   // scanline depth
const float LINES = 480.0;  // CRT line pairs — resolution-independent
const float GLOW  = 0.40;   // 4-tap bloom
const float VIGN  = 0.32;   // corner falloff

const float K1 = CURV * 0.14;
const float K2 = CURV * 0.06;

vec2 warp(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return 0.5 + c * (1.0 + K1 * r2 + K2 * r2 * r2);
}

void main() {
    vec2 uv0 = v_texcoord;
    vec2 uv  = warp(uv0);

    // outside the tube -> bezel interior, with a soft edge
    vec2  e    = min(uv, 1.0 - uv);
    float edge = smoothstep(0.0, 0.003, min(e.x, e.y));
    if (edge <= 0.0) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }

    float r2 = dot(uv - 0.5, uv - 0.5);

    // chromatic aberration: sample R/B at slightly different warps near the rim
    float a  = ABERR * 0.004 * r2;
    float cr = texture(tex, warp(uv0 + vec2(a, 0.0))).r;
    float cg = texture(tex, uv).g;
    float cb = texture(tex, warp(uv0 - vec2(a, 0.0))).b;
    vec3  col = vec3(cr, cg, cb);

    // scanlines follow the curve, because uv is already warped
    col *= 1.0 - SCAN * 0.18 * (0.5 + 0.5 * sin(uv.y * LINES * 6.2831853));

    // cheap bloom: 4 taps
    vec3  bl = vec3(0.0);
    float o  = 0.0013;
    bl += texture(tex, uv + vec2(o, 0.0)).rgb;
    bl += texture(tex, uv - vec2(o, 0.0)).rgb;
    bl += texture(tex, uv + vec2(0.0, o)).rgb;
    bl += texture(tex, uv - vec2(0.0, o)).rgb;
    col += GLOW * 0.18 * bl * 0.25;

    // vignette + rim falloff + edge AA
    col *= 1.0 - VIGN * 1.72 * r2;
    col *= edge;

    fragColor = vec4(col, 1.0);
}
