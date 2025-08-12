/*
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments
*/

/*
    Display shader
    --------------
    HRD to LDR display shader.

    Applies exposure > tonemaps > corrects gamma
*/

#version 460

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_texture;
uniform float u_exposure;

#define GAMMA 0.45454545454545454545454545454545 // 1.0 / 2.2


/*
    ACES filmic tone mapping curve
    https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
*/
vec3 aces_filmic(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0, 1.0);
}


void main() {
    vec3 hdr_color = texture(s_texture, v_uv).rgb;

    hdr_color *= pow(sqrt(2.0), u_exposure);

    hdr_color = aces_filmic(hdr_color);

    hdr_color = pow(hdr_color, vec3(GAMMA));

    f_color = vec4(hdr_color, 1.0);
}