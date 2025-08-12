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

uniform sampler2D s_scene;
uniform sampler2D s_df;

/* *** SETTINGS *** */

#define RAY_COUNT 32
#define MAX_DEPTH 1
#define MAX_STEPS 512

/* *** SETTINGS *** */

#define PI 3.141592653589793238462643383279
#define TAU 6.283185307179586476925286766559
#define EPSILON 0.0001


struct Ray {
    vec2 origin;
    vec2 direction;
};

struct HitInfo {
    bool hit;
    vec2 uv;
    vec2 normal;
    vec4 emissive;
};


float rand(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453);
}

bool out_of_bounds(vec2 uv) {
  return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

uint wang_hash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16);
    seed *= 9u;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15);
    return seed;
}

float prng(inout uint prng_state) {
    prng_state += 0x6D2B79F5u;
    uint z = (prng_state ^ (prng_state >> 15)) * (1u | prng_state);
    z ^= z + (z ^ (z >> 7)) * (61u | z);
    return float((z ^ (z >> 14))) / 4294967296.0;
}

vec2 random_in_unit_circle(inout uint prng_state) {
    float angle = prng(prng_state) * TAU;
    float radius = sqrt(prng(prng_state)); // sqrt to correct density
    float x = radius * cos(angle);
    float y = radius * sin(angle);
    return vec2(x, y);
}

/*
    Bounces and scattering doesn't work right now...
*/
Ray scatter(Ray ray, HitInfo hitinfo, inout uint prng_state) {
    vec2 new_pos = hitinfo.uv + hitinfo.normal * EPSILON;

    vec2 diffuse_ray_dir = normalize(hitinfo.normal + random_in_unit_circle(prng_state));
    //vec2 diffuse_ray_dir = reflect(ray.direction, hitinfo.normal);

    vec2 new_dir = diffuse_ray_dir;

    // specular = (prng(prng_state) < hitinfo.material.specular_percentage) ? 1.0 : 0.0;

    // vec3 diffuse_ray_dir = normalize(hitinfo.normal + random_in_unit_sphere(prng_state));
    // vec3 specular_ray_dir = reflect(ray.dir, hitinfo.normal);
    // specular_ray_dir = normalize(mix(specular_ray_dir, diffuse_ray_dir, hitinfo.material.roughness * hitinfo.material.roughness));

    // vec3 new_dir = mix(diffuse_ray_dir, specular_ray_dir, specular);

    return Ray(new_pos, new_dir);
}

/*
    Sample nearby distance field and approximate normal.
*/
vec2 get_normal(vec2 uv) {
    // Step size in UV space for one pixel
    vec2 eps = 1.0 / vec2(textureSize(s_df, 0));

    float dx = texture(s_df, uv + vec2(eps.x, 0.0)).r
             - texture(s_df, uv - vec2(eps.x, 0.0)).r;
    float dy = texture(s_df, uv + vec2(0.0, eps.y)).r
             - texture(s_df, uv - vec2(0.0, eps.y)).r;

    return normalize(vec2(dx, dy));
}

/*
    Raymarch through the scene and gather hit information.
*/
HitInfo raymarch(Ray ray) {
    HitInfo empty = HitInfo(false, vec2(0.0), vec2(0.0), vec4(0.0));

    vec2 uv = ray.origin;

    for (int s = 0; s < MAX_STEPS; s++) {
        // How far away is the nearest object?
        float dist = texture(s_df, uv).r;
        
        // Go the direction we're traveling
        uv += ray.direction * dist;
        
        if (out_of_bounds(uv)) {
            return empty;
        }
        
        if (dist < EPSILON) {
            vec4 tex = texture(s_scene, uv);
            return HitInfo(
                true,
                uv,
                get_normal(uv),
                tex
            );
        }
    }

    return empty;
}

/*
    Pathtrace and gather radiance information.
*/
vec4 pathtrace() {
    vec4 tex = texture(s_scene, v_uv);

    // TODO: transparency, refractions
    if (tex.a > 0.1) {
        return tex;
    }

    float inv_ray_n = 1.0 / float(RAY_COUNT);
    float tau_over_ray_n = TAU * inv_ray_n;

    vec4 radiance = vec4(0.0); // Final ray color
    vec4 radiance_delta = vec4(1.0); // Accumulated ray color

    float noise = rand(v_uv);

    for (int i = 0; i < RAY_COUNT; i++) {
        float angle = tau_over_ray_n * (float(i) + noise);

        Ray ray = Ray(
            v_uv,
            vec2(cos(angle), -sin(angle))
        );

        uint prng_state = wang_hash(uint(v_uv.x * 1280.0) * 73856093u ^ uint(v_uv.y * 720.0) * 19349663u ^ uint(i) * 83492791u);

        for (int bounce = 0; bounce < MAX_DEPTH; bounce++) {
            HitInfo hitinfo = raymarch(ray);

            // TODO: sun?
            if (!hitinfo.hit) {
                radiance += vec4(0.0);
                break;
            }

            //ray = scatter(ray, hitinfo, prng_state);

            radiance += hitinfo.emissive * radiance_delta;
            radiance_delta *= vec4(1.0); // TODO
        }
    }

    return radiance * inv_ray_n;
}


void main() {
    vec4 color = pathtrace();
    f_color = vec4(color.rgb, 1.0);
}