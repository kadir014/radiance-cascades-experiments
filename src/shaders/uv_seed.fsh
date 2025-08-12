/*
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments
*/

/*
    UV seed shader
    --------------
    Spits out UV colors of the non-alpha pixels.
*/

#version 460

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;


void main() {
    vec2 uv = v_uv;
    float alpha = texture(s_texture, uv).a;
    if (alpha == 0.0) {
        f_color = vec4(0.0, 0.0, 0.0, 1.0);
    }
    else {
        f_color = vec4(v_uv, 0.0, 1.0);
    }
}