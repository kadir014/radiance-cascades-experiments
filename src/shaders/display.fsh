/*
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments
*/

/*
    Display shader
    --------------
    Just a basic screenquad display shader, nothing fancy ;)
*/

#version 460

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;


void main() {
    f_color = texture(s_texture, v_uv);
}