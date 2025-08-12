/*
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments
*/

/*
    JFA (Jump Flood Algorithm) Shader
    ---------------------------------
    TODO
*/

#version 460

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;
uniform float u_offset;
uniform vec2 u_invresolution;

#define MAX_VAL 999999.9


void main() {
    vec2 uv = v_uv;

    vec4 nearest_seed = vec4(-2.0);
    float nearest_dist = MAX_VAL;

    for (float y = -1.0; y <= 1.0; y += 1.0) {
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            vec2 sample_uv = uv + vec2(x, y) * u_offset * u_invresolution;

            // Out of bounds
            if (
                sample_uv.x < 0.0 ||
                sample_uv.x > 1.0 ||
                sample_uv.y < 0.0 ||
                sample_uv.y > 1.0
            ) {
                continue;
            }

            vec4 sample_tex = texture(s_texture, sample_uv);
            vec2 sample_seed = sample_tex.xy;

            if (sample_seed.x != 0.0 || sample_seed.y != 0.0) {
                vec2 diff = sample_seed - uv;
                float dist = dot(diff, diff);
                if (dist < nearest_dist) {
                    nearest_dist = dist;
                    nearest_seed = sample_tex;
                }
            }
        }
    }

    f_color = nearest_seed;
}