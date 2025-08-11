#version 330

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;

void main() {
    vec2 uv = v_uv;

    vec2 nearestSeed = texture(s_texture, uv).xy;
    // Clamp by the size of our texture (1.0 in uv space).
    float dist = clamp(distance(uv, nearestSeed), 0.0, 1.0);

    // Normalize and visualize the distance
    f_color = vec4(vec3(dist), 1.0);
}