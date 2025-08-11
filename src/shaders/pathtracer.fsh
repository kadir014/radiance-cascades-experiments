#version 330

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_scene;
uniform sampler2D s_df;

#define RAY_COUNT 16
#define MAX_STEPS 256

const float PI = 3.14159265;
const float TAU = 2.0 * PI;
const float EPSILON = 0.0001;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

bool outOfBounds(vec2 uv) {
  return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

vec4 raymarch() {
    vec4 light = texture(s_scene, v_uv);

    if (light.a > 0.1) {
        return light;
    }
    
    float oneOverRayCount = 1.0 / float(RAY_COUNT);
    float tauOverRayCount = TAU * oneOverRayCount;
    
    // Different noise every pixel
    float noise = rand(v_uv);
    
    vec4 radiance = vec4(0.0);
    
    // Shoot rays in "rayCount" directions, equally spaced, with some randomness.
    for(int i = 0; i < RAY_COUNT; i++) {
        float angle = tauOverRayCount * (float(i) + noise);
        vec2 rayDirection = vec2(cos(angle), -sin(angle));

        vec2 sampleUv = v_uv;
        
        for (int s = 0; s < MAX_STEPS; s++) {
            // Go the direction we're traveling (with noise)
            // vec2 sampleUv = v_uv + rayDirectionUv * float(s);
        
            // if (sampleUv.x < 0.0 || sampleUv.x > 1.0 || sampleUv.y < 0.0 || sampleUv.y > 1.0) {
            //     break;
            // }
            
            // vec4 sampleLight = texture(s_scene, sampleUv);
            // if (sampleLight.a > 0.5) {
            //     radiance += sampleLight;
            //     break;
            // }

            // How far away is the nearest object?
            float dist = texture(s_df, sampleUv).r;
            
            // Go the direction we're traveling (with noise)
            sampleUv += rayDirection * dist;
            
            if (outOfBounds(sampleUv)) break;
            
            if (dist < EPSILON) {
                vec4 sampleColor = texture(s_scene, sampleUv);
                if (sampleColor.a > 0.1) {
                    radiance += sampleColor;
                }
                break;
            }
        }      
    }
    
    // Average radiance
    return radiance * oneOverRayCount;
}

void main() {
    f_color = vec4(raymarch().rgb, 1.0);
}