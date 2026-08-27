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

