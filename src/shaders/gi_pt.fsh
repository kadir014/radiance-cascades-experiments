/*
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments
*/

/*
    Global Illumination - Pathtracing
    ---------------------------------
    Naive GI approach where we shoot number of rays at each pixel and raymarch
    through the scene (which we just generated a distance field for with JFA)
    and gather radience information.
*/

#version 460

in vec2 v_uv;
out vec4 f_color;

uniform sampler2D s_color_scene;
uniform sampler2D s_emissive_scene;
uniform sampler2D s_df;
uniform sampler2D s_inv_df;
uniform sampler2D s_bluenoise;
uniform vec2 u_resolution;
uniform uint u_ray_count;
uniform uint u_noise_method;
uniform vec2 u_mouse;

/*  \/  SETTINGS  \/  */

#define RAY_COUNT u_ray_count
#define MAX_DEPTH 2
#define MAX_STEPS 64

/*  /\  SETTINGS /\  */

#define PI 3.141592653589793238462643383279
#define TAU 6.283185307179586476925286766559
#define EPSILON 0.0005
#define BLUENOISE_SIZE 1024


struct Ray {
    vec2 origin;
    vec2 direction;
};

struct Material {
    vec3 color;
    float emissive;
};

struct HitInfo {
    bool hit;
    vec2 uv;
    vec2 normal;
    Material material;
};


/*
    Wang hash

    From https://www.shadertoy.com/view/ttVGDV
*/
uint wang_hash(uint a) {
    a = (a ^ 61u) ^ (a >> 16);
    a *= 9u;
    a = a ^ (a >> 4);
    a *= 0x27d4eb2du;
    a = a ^ (a >> 15);
    return a;
}

/*
    Mulberry32 PRNG
    Returns a float in range 0 and 1.

    From https://gist.github.com/tommyettinger/46a874533244883189143505d203312c
*/
uint prng_state;
float prng() {
    prng_state += 0x6D2B79F5u;
    uint z = (prng_state ^ (prng_state >> 15)) * (1u | prng_state);
    z ^= z + (z ^ (z >> 7)) * (61u | z);
    return float((z ^ (z >> 14))) / 4294967296.0;
}

vec2 bluenoise_seed;
vec4 bluenoise() {
    vec4 bluenoise_sample = texture(s_bluenoise, (bluenoise_seed * u_resolution) / vec2(BLUENOISE_SIZE, BLUENOISE_SIZE));
    return fract(bluenoise_sample);
}

vec2 sample_semicircle(vec2 n, float t) {
    t *= TAU;
    vec2 s = vec2(cos(t), sin(t));
    return s * sign(dot(s, n));
}

/*
    Scatter the ray from the surface depending on the material.
    (Only diffuse scattering right now.)
*/
Ray scatter(Ray ray, HitInfo hitinfo) {
    vec2 new_pos = hitinfo.uv + hitinfo.normal * (EPSILON * 1.0);

    vec2 diffuse_ray_dir = vec2(0.0);

    if (u_noise_method == 0) {
        diffuse_ray_dir = sample_semicircle(hitinfo.normal, 0.0);
    }
    else if (u_noise_method == 1) {
        diffuse_ray_dir = sample_semicircle(hitinfo.normal, prng());
    }
    else if (u_noise_method == 2) {
        //bluenoise_seed=new_pos;
        //diffuse_ray_dir = sample_semicircle(hitinfo.normal, bluenoise().r);
        diffuse_ray_dir = sample_semicircle(hitinfo.normal, prng());
    }

    vec2 new_dir = normalize(diffuse_ray_dir);

    return Ray(new_pos, new_dir);
}

/*
    Sample nearby distance field and approximate normal.
*/
vec2 get_normal(vec2 uv) {
    // Step size in UV space for one pixel
    // TOOD: Can this be optimized?
    vec2 e = 1.0 / vec2(textureSize(s_df, 0));

    vec2 grad = vec2(
        texture(s_df, uv + vec2(e.x, 0.0)).r -
        texture(s_df, uv - vec2(e.x, 0.0)).r,
        texture(s_df, uv + vec2(0.0, e.y)).r -
        texture(s_df, uv - vec2(0.0, e.y)).r
    );

    grad = normalize(grad);

    // Fix degenerate normal
    if (abs(grad.x) <= EPSILON && abs(grad.y) <= EPSILON) {
        grad = vec2(0.0, 1.0);
    }

    return grad;
}

/*
    Raymarch through the scene and gather hit information.
*/
HitInfo raymarch(Ray ray) {
    HitInfo empty = HitInfo(false, vec2(0.0), vec2(0.0), Material(vec3(0.0), 0.0));

    vec2 uv = ray.origin;

    float traveled = 0.0;

    for (int s = 0; s < MAX_STEPS; s++) {
        // Sample the nearest jump from distance field
        float dist = texture(s_df, uv).r;

        traveled += dist;
        uv += ray.direction * dist;
        
        // Out of UV bounds
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            break;
        }
        
        if (traveled > EPSILON && dist < EPSILON) {
            vec4 color_sample = texture(s_color_scene, uv);
            vec4 emissive_sample = texture(s_emissive_scene, uv);

            return HitInfo(
                true,
                uv,
                get_normal(uv),
                Material(
                    color_sample.rgb,
                    emissive_sample.a
                )
            );
        }
    }

    return empty;
}

/*
    Raymarch, except use the inverted distance field.
    This is used to getting the ray origin out of solids.
*/
vec2 raymarch_out(Ray ray) {
    vec2 uv = ray.origin;
    float traveled = 0.0;

    for (int s = 0; s < MAX_STEPS; s++) {
        float dist = texture(s_inv_df, uv).r;

        traveled += dist;
        uv += ray.direction * dist;
        
        // Out of UV bounds
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            break;
        }
        
        if (traveled > EPSILON && dist < EPSILON) {
            break;
        }
    }

    return uv;
}

/*
    Pathtrace!
*/
vec3 pathtrace() {
    vec2 screen_uv = v_uv * u_resolution;

    vec4 color_sample = texture(s_color_scene, v_uv);
    vec4 emissive_sample = texture(s_emissive_scene, v_uv);

    // Exit early if the current pixel is emissive
    if (emissive_sample.a > 0.0) {
        return color_sample.rgb;
    }

    float inv_ray_n = 1.0 / float(RAY_COUNT);
    float tau_over_ray_n = TAU * inv_ray_n;

    prng_state = wang_hash(
        uint(screen_uv.x) * 73856093u ^
        uint(screen_uv.y) * 19349663u
    );

    vec3 final_radiance = vec3(0.0);

    for (int i = 0; i < RAY_COUNT; i++) {
        vec3 radiance = vec3(0.0); // Final ray color
        vec3 radiance_delta = vec3(1.0); // Accumulated multiplier

        float noise = 0.0;

        if (u_noise_method == 1) {
            noise = prng();
        }
        else if (u_noise_method == 2) {
            bluenoise_seed = v_uv;
            noise = bluenoise().r;
        }

        float angle = tau_over_ray_n * (float(i) + noise);

        Ray ray = Ray(
            v_uv,
            vec2(cos(angle), -sin(angle))
        );

        // Inside solid
        if (color_sample.a > 0.0 || emissive_sample.a > 0.0) {
            vec2 out_uv = raymarch_out(ray);
            ray.origin = out_uv;

            radiance_delta *= color_sample.rgb;
            radiance += radiance_delta * emissive_sample.a;
        }

        for (int bounce = 0; bounce < MAX_DEPTH; bounce++) {
            HitInfo hitinfo = raymarch(ray);

            // TODO: sun?
            if (!hitinfo.hit) {
                break;
            }

            ray = scatter(ray, hitinfo);

            radiance_delta *= hitinfo.material.color;
            radiance += radiance_delta * hitinfo.material.emissive;
        }

        final_radiance += radiance;
    }

    return final_radiance * inv_ray_n;
}


void main() {
    vec3 color = pathtrace();
    f_color = vec4(color, 1.0);
}