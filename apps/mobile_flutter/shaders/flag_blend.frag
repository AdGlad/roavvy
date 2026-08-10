#version 460 core
#include <flutter/runtime_effect.glsl>

// Cross-platform GPU flag-blend + ripple shader (Impeller: Metal on iOS,
// Vulkan/GLES on Android). Merges two flag textures into one graphic with an
// optional ripple/displacement warp. Deterministic: identical uniforms → an
// identical result, so preview == print (see design_engine/docs/rendering-
// technology.md).

precision highp float;

// Uniform order matters — it maps to setFloat() indices in Dart:
//   0,1 uSize · 2 uWeightA · 3 uBlendMode · 4 uRippleAmp · 5 uRippleFreq · 6 uSeed
uniform vec2 uSize;       // target resolution in px
uniform float uWeightA;   // 0..1 share of flag A
uniform float uBlendMode; // 0 mix · 1 diagonal · 2 noiseMask · 3 wavy
uniform float uRippleAmp; // ripple amplitude, normalised (0 = none)
uniform float uRippleFreq;// ripple / mask frequency
uniform float uSeed;      // 0..1 deterministic seed

uniform sampler2D uFlagA; // setImageSampler(0)
uniform sampler2D uFlagB; // setImageSampler(1)

out vec4 fragColor;

const float TAU = 6.28318530718;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Smoothed value noise for the noise-mask blend.
float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float phase = uSeed * TAU;

  // Ripple / displacement warp on the sampling coordinates.
  vec2 disp = vec2(
    sin(uv.y * uRippleFreq * TAU + phase),
    cos(uv.x * uRippleFreq * TAU + phase)
  ) * uRippleAmp;
  vec2 suv = clamp(uv + disp, 0.0, 1.0);

  vec4 a = texture(uFlagA, suv);
  vec4 b = texture(uFlagB, suv);

  // t is the share of flag B at this pixel. uBlendMode selects the pattern.
  float t;
  if (uBlendMode < 0.5) {
    // 0 mix — weighted cross-fade.
    t = 1.0 - clamp(uWeightA, 0.0, 1.0);
  } else if (uBlendMode < 1.5) {
    // 1 diagonal split.
    t = step(uWeightA, (uv.x + uv.y) * 0.5);
  } else if (uBlendMode < 2.5) {
    // 2 torn noise-mask boundary.
    float n = valueNoise(uv * (3.0 + uRippleFreq) + uSeed * 17.0);
    t = step(uWeightA, n);
  } else if (uBlendMode < 3.5) {
    // 3 wavy split.
    float w = 0.5 + 0.5 * sin((uv.x + uv.y) * uRippleFreq * TAU + phase);
    t = step(uWeightA, w);
  } else if (uBlendMode < 4.5) {
    // 4 vertical split (left A / right B).
    t = step(uWeightA, uv.x);
  } else if (uBlendMode < 5.5) {
    // 5 horizontal split (top A / bottom B).
    t = step(uWeightA, uv.y);
  } else if (uBlendMode < 6.5) {
    // 6 stripes — alternating horizontal bands.
    float bands = max(2.0, floor(uRippleFreq * 2.0));
    t = mod(floor(uv.y * bands), 2.0);
  } else if (uBlendMode < 7.5) {
    // 7 checkerboard.
    float n = max(2.0, floor(uRippleFreq + 1.0));
    t = mod(floor(uv.x * n) + floor(uv.y * n), 2.0);
  } else {
    // 8 radial — flag A in a centre disc, flag B around it.
    float d = distance(uv, vec2(0.5)) * 1.6;
    t = step(0.35 + uWeightA * 0.4, d);
  }

  fragColor = mix(a, b, clamp(t, 0.0, 1.0));
}
