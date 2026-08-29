#version 300 es

#define ALLOW_INCLUDES
#extension GL_ARB_shading_language_include : enable
#extension GL_OES_EGL_image_external_essl3 : require

precision                  highp float;
in vec2                    v_texcoord;
uniform samplerExternalOES tex;
uniform float              alpha;

uniform float              radius;
uniform float              roundingPower;
uniform vec2               topLeft;
uniform vec2               fullSize;
#include "rounding.glsl"

uniform int  discardOpaque;
uniform int  discardAlpha;
uniform int  discardAlphaValue;

uniform int  applyTint;
uniform vec3 tint;

layout(location = 0) out vec4 fragColor;

// terminal-delight: per-tile glass glare — the terminal's own hotspot +
// streak formula (crt_pass), in window-local UV, so every tile catches the
// room light the way a TD pane does. TD's own windows are radius-0 and skip
// all of this — they draw their own glass.
const float TD_GLARE      = 0.42;
const vec3  TD_GLARE_TINT = vec3(0.72, 1.00, 0.78);

void main() {

    // terminal-delight per-window curved glass (runtime-gated: windows have radius > 0)
    vec2  td_uv   = v_texcoord;
    float td_edge = 1.0;
    if (radius > 0.0) {
        vec2  td_c  = v_texcoord - 0.5;
        float td_r2 = dot(td_c, td_c);
        td_uv       = 0.5 + td_c * (1.0 + 0.14 * td_r2 + 0.06 * td_r2 * td_r2);
        vec2 td_e   = min(td_uv, 1.0 - td_uv);
        td_edge     = smoothstep(0.0, 0.004, min(td_e.x, td_e.y));
        td_uv       = clamp(td_uv, 0.0, 1.0);
    }

    vec4 pixColor = texture(tex, td_uv);
    pixColor *= td_edge; // transparent bezel outside the tube

    if (radius > 0.0 && TD_GLARE > 0.0) {
        vec2  g_o   = (v_texcoord - vec2(0.18, 0.10)) / vec2(0.34, 0.18);
        float g_hot = exp(-dot(g_o, g_o) * 2.2);
        float g_bnd = (1.0 - smoothstep(0.0, 0.10, abs(v_texcoord.y + v_texcoord.x * 0.22 - 0.17)))
                    * (1.0 - smoothstep(0.0, 0.72, v_texcoord.x))
                    * (1.0 - smoothstep(0.0, 0.42, v_texcoord.y));
        float g_amt = clamp((g_hot * 0.58 + g_bnd * 0.34) * TD_GLARE, 0.0, 1.0) * td_edge;
        pixColor.rgb += TD_GLARE_TINT * g_amt * pixColor.a;
    }

    if (discardOpaque == 1 && pixColor[3] * alpha == 1.0)
        discard;

    if (applyTint == 1) {
        pixColor[0] = pixColor[0] * tint[0];
        pixColor[1] = pixColor[1] * tint[1];
        pixColor[2] = pixColor[2] * tint[2];
    }

    if (radius > 0.0)
        pixColor = rounding(pixColor, radius, roundingPower, topLeft, fullSize);

    fragColor = pixColor * alpha;
}

