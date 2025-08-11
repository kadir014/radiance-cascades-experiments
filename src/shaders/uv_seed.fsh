#version 330

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;

void main() {
    vec2 uv = v_uv;
    float alpha = texture(s_texture, uv).a;
    f_color = vec4(v_uv * alpha, 0.0, 1.0);
}