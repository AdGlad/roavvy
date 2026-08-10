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

  // t is the share of flag B at this pixel.
  float t;
  if (uBlendMode < 0.5) {
    // Weighted cross-fade.
    t = 1.0 - clamp(uWeightA, 0.0, 1.0);
  } else if (uBlendMode < 1.5) {
    // Diagonal split, position set by the A/B weight.
    float d = (uv.x + uv.y) * 0.5;
    t = step(uWeightA, d);
  } else if (uBlendMode < 2.5) {
    // Torn noise-mask boundary.
    float n = valueNoise(uv * (3.0 + uRippleFreq) + uSeed * 17.0);
    t = step(uWeightA, n);
  } else {
    // Wavy split.
    float w = 0.5 + 0.5 * sin((uv.x + uv.y) * uRippleFreq * TAU + phase);
    t = step(uWeightA, w);
  }

  fragColor = mix(a, b, clamp(t, 0.0, 1.0));
}
