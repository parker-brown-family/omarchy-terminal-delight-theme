#version 320 es
// Terminal Delight — the MONITOR pass: curved glass for the whole desktop.
//
// v2 ports the terminal's own display stack, dial for dial, from
// terminal-delight (app/src/crt.rs + gpui_wgpu/src/crt_pass.wgsl): px-true
// scanlines, the sweeping tracking band with its thin white core, occasional
// stepped flicker bursts, the glass glare hotspot + diagonal streak, centre
// phosphor bloom, vignette — and a monitor-OSD colour grade (brightness /
// contrast / saturation / gamma) applied last, the way the terminal grades
// its own tube.
//
// Hyprland pairs screen shaders with a GLES3 vertex shader, so the version
// directive is required and the dialect is in/out/texture(), not varying.
// The clock is OPT-IN: see ANIMATED in the config block — Hyprland treats any
// screen shader that declares `uniform float time` as animated and switches
// damage tracking off for it (full-screen redraws every frame), so the still
// glass deliberately declares no clock at all.

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// ---- MONITOR CONFIG ----------------------------------------------------
// One knob per line, 1:1 with a terminal-delight dial (named in the comment).
// `td-monitor` rewrites this block and re-applies the shader; hand edits are
// equally welcome — this block IS the config surface.
#define ANIMATED 0              // 1 = the tracking band / flicker / jiggle actually move.
                                // Costs what Hyprland's warning says it costs: a time
                                // uniform forces damage tracking off, i.e. the whole
                                // screen redraws every frame. 0 = still glass — no clock,
                                // no warning, the three motion knobs freeze invisibly.
                                // td-monitor raises this when you turn a motion knob and
                                // drops it when all three are zero.
const float CURV       = 0.00;  // whole-desktop barrel — the per-window warp carries the curve
const float ABERR      = 0.55;  // chromatic split at the rim
const float SCAN       = 0.22;  // scanline depth              (TD scanline_opacity)
const float SCAN_STEP  = 4.0;   // px between scanlines        (TD scanline_step; 0 = legacy sin lines)
const float LINES      = 480.0; // legacy sin line pairs, used only when SCAN_STEP = 0
const float GLOW       = 0.40;  // 4-tap bloom
const float BLOOM      = 0.35;  // centre phosphor wash        (TD bloom)
const float VIGN       = 0.32;  // corner falloff              (TD vignette)
const float SPECULAR   = 0.50;  // upper-left room-light catch on the glass
const float TRACKING   = 0.60;  // rolling band strength       (TD tracking)
const float TRACK_PERIOD = 16.0;// seconds between sweeps      (TD tracking_period)
const float TRACK_SWEEP  = 7.0; // seconds one sweep takes     (TD tracking_sweep)
const float BAND_H     = 160.0; // band height in px           (crt.rs BAND_H)
const float FLICKER    = 0.35;  // stepped burst depth         (TD flicker)
const float GLARE      = 0.42;  // glare hotspot + streak      (TD screen_glare)
const float JIGGLE     = 0.00;  // rare 1–2px vertical hop     (TD jiggle; earn it before desktop-wide)
const float BRIGHTNESS = 0.00;  // -1..1                       (TD grade brightness)
const float CONTRAST   = 0.00;  // -1..1                       (TD grade contrast)
const float SATURATION = 1.00;  // 0..2                        (TD grade colour)
const float GAMMA      = 1.00;  // 0.5..2                      (TD grade gamma)
const vec3  PHOSPHOR   = vec3(0.133, 0.773, 0.369); // #22C55E — build-variants retints per variant
const vec3  GLARE_TINT = vec3(0.72, 1.00, 0.78);    // crt_pass.wgsl glare_color
// ---- END CONFIG --------------------------------------------------------

// The clock exists only when asked for. Declaring `uniform float time` — even
// unused — is what trips Hyprland's animated-shader path (the warning keys off
// the declaration, not the use), so the still glass compiles a const instead
// and every time-driven expression below folds away.
#if ANIMATED
uniform float time;
#else
const float time = 0.0;
#endif

const float K1 = CURV * 0.14;
const float K2 = CURV * 0.06;

vec2 warp(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return 0.5 + c * (1.0 + K1 * r2 + K2 * r2 * r2);
}

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// Occasional stepped flicker: a 0.45 s burst of five brightness steps —
// 0.86 / 1.06 / 0.90 / 1.03 / 0.95, the terminal's exact ladder — landing at
// a hashed moment inside every 13 s window. Like crt.rs it scales the
// scanlines and the vignette, not the picture: the tube breathes, the text
// doesn't strobe.
float flicker_mul(float t) {
    if (FLICKER < 0.001) return 1.0;
    float win = floor(t / 13.0);
    float start = win * 13.0 + 2.0 + hash(win) * 8.0;
    if (t < start || t > start + 0.45) return 1.0;
    int ph = int((t - start) / 0.09);
    float s = ph == 0 ? 0.86 : ph == 1 ? 1.06 : ph == 2 ? 0.90 : ph == 3 ? 1.03 : 0.95;
    return 1.0 + (s - 1.0) * FLICKER;
}

// The rolling tracking band: BAND_H px tall, a triangle profile peaking at
// its centre, phosphor-tinted with a thin white core, sweeping top→bottom
// over TRACK_SWEEP seconds then resting out the period — crt.rs's numbers,
// as a continuous profile instead of painted rows.
vec3 tracking_add(float py, float screen_h, float t, inout float darken) {
    if (TRACKING < 0.001) return vec3(0.0);
    float tc = mod(t, TRACK_PERIOD);
    if (tc > TRACK_SWEEP) return vec3(0.0);
    float p = tc / TRACK_SWEEP;
    float center = -BAND_H + p * (screen_h + BAND_H * 2.0);
    float d = 1.0 - clamp(abs(py - center) / (BAND_H * 0.5), 0.0, 1.0);
    if (d <= 0.0) return vec3(0.0);
    darken += 0.05 * TRACKING * d;
    vec3 add = PHOSPHOR * (d * d * 0.05 * TRACKING);
    if (d > 0.92) add += vec3(0.018 * TRACKING);
    return add;
}

// The glass glare: an exponential hotspot up-left plus a diagonal streak —
// crt_pass.wgsl's formula verbatim, over screen-local UV.
vec3 glare_add(vec2 uv) {
    if (GLARE < 0.001) return vec3(0.0);
    vec2 go = (uv - vec2(0.18, 0.10)) / vec2(0.34, 0.18);
    float hotspot = exp(-dot(go, go) * 2.2);
    float band = (1.0 - smoothstep(0.0, 0.10, abs(uv.y + uv.x * 0.22 - 0.17)))
               * (1.0 - smoothstep(0.0, 0.72, uv.x))
               * (1.0 - smoothstep(0.0, 0.42, uv.y));
    float amount = clamp((hotspot * 0.58 + band * 0.34) * GLARE, 0.0, 1.0);
    return GLARE_TINT * amount;
}

void main() {
    vec2  res = vec2(textureSize(tex, 0));
    float t   = time;
    float fl  = flicker_mul(t);

    vec2 uv0 = v_texcoord;
    // jiggle: a two-frame vertical hop at a hashed moment inside every 10 s
    // window. Off by default — a whole desktop hopping needs to be asked for.
    if (JIGGLE > 0.001) {
        float jw = floor(t / 10.0);
        float js = jw * 10.0 + 4.0 + hash(jw + 7.0) * 6.0;
        if (t > js && t < js + 0.09) {
            uv0.y += (hash(jw + 3.0) - 0.5) * 4.0 * JIGGLE / res.y;
        }
    }
    vec2 uv = warp(uv0);

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

    // scanlines: px-true — a 1px dark line then a 1px phosphor-tinted line
    // per SCAN_STEP, following the curve because uv is already warped. The
    // sin pattern survives as the SCAN_STEP=0 fallback for the old look.
    float scanA = SCAN * fl;
    if (scanA > 0.001) {
        if (SCAN_STEP > 0.5) {
            float row = mod(uv.y * res.y, SCAN_STEP);
            if (row < 1.0) {
                col = mix(col, vec3(0.0), scanA);
            } else if (row < 2.0) {
                col = mix(col, PHOSPHOR, scanA * 0.22);
            }
        } else {
            col *= 1.0 - scanA * 0.18 * (0.5 + 0.5 * sin(uv.y * LINES * 6.2831853));
        }
    }

    // cheap bloom: 4 taps
    vec3  bl = vec3(0.0);
    float o  = 0.0013;
    bl += texture(tex, uv + vec2(o, 0.0)).rgb;
    bl += texture(tex, uv - vec2(o, 0.0)).rgb;
    bl += texture(tex, uv + vec2(0.0, o)).rgb;
    bl += texture(tex, uv - vec2(0.0, o)).rgb;
    col += GLOW * 0.18 * bl * 0.25;

    // centre phosphor wash: nothing above 5%, ramping to full at 42% and
    // holding below — the tube's brightest belt, in the theme's own hue.
    if (BLOOM > 0.001) {
        col = mix(col, PHOSPHOR, 0.05 * BLOOM * smoothstep(0.05, 0.42, uv.y));
    }

    // the rolling tracking band, plus its band-local scanline pressure
    float darken = 0.0;
    col += tracking_add(uv.y * res.y, res.y, t, darken);
    col *= 1.0 - darken * 0.5;

    col += glare_add(uv);

    // upper-left specular: the room's light source catching the glass
    if (SPECULAR > 0.001) {
        vec2 so = (uv - vec2(0.05, 0.04)) / vec2(0.13, 0.10);
        col += vec3(0.05 * SPECULAR) * exp(-dot(so, so)) * fl;
    }

    // vignette breathes with the flicker, like the terminal's glass
    col *= 1.0 - VIGN * fl * 1.72 * r2;
    col *= edge;

    // the grade goes LAST — it is the monitor's front panel, turned after
    // everything the tube itself does
    col = pow(max(col, vec3(0.0)), vec3(1.0 / GAMMA));
    col = (col - 0.5) * (1.0 + CONTRAST) + 0.5 + BRIGHTNESS * 0.35;
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, SATURATION);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
