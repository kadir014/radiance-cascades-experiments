#version 330

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;
uniform float u_offset;
uniform vec2 u_invresolution;

void main() {
    vec2 uv = v_uv;
    vec4 nearestSeed = vec4(-2.0);
    float nearestDist = 999999.9;

    for (float y = -1.0; y <= 1.0; y += 1.0) {
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            vec2 sampleUV = uv + vec2(x, y) * u_offset * u_invresolution;

            if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) { continue; }

            vec4 sampleValue = texture(s_texture, sampleUV);
            vec2 sampleSeed = sampleValue.xy;

            if (sampleSeed.x != 0.0 || sampleSeed.y != 0.0) {
                vec2 diff = sampleSeed - uv;
                float dist = dot(diff, diff);
                if (dist < nearestDist) {
                    nearestDist = dist;
                    nearestSeed = sampleValue;
                }
            }
        }
    }

    f_color = nearestSeed;
}