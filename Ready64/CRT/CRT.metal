// Copyright (c) 2013-2021 Filippo Scognamiglio (cool-retro-term)
// Copyright (c) 2026 Brandon Thompson (Ready64 Metal adaptation)
//
// Adapted from cool-retro-term terminal_static / terminal_dynamic / burn_in shaders.
// Bloom approximates Qt FastBlur (downsample + wide separable Gaussian + transparent border).
// GPL-3.0-or-later — see LICENSE and NOTICE.

#include <metal_stdlib>
using namespace metal;

struct CRTUniforms {
    float time;
    float screenCurvature;
    float rgbShift;
    float bloom;
    float staticNoise;
    float jitter;
    float2 jitterDisplacement;
    float glowingLine;
    float flickering;
    float horizontalSync;
    float horizontalSyncStrength;
    float burnIn;
    float burnInLastUpdate;
    float burnInTime;
    float ambientLight;
    float frameShininess;
    float frameSize;
    float2 virtualResolution;
    float2 noiseScale;
    float contrast;
    float saturation;
};

struct BurnInUniforms {
    float burnInLastUpdate;
    float burnInTime;
    float prevLastUpdate;
};

struct BlurUniforms {
    float2 texelSize;   // 1/width, 1/height of the sampled texture
    float2 direction;   // (1,0) horizontal or (0,1) vertical
    float radius;       // FastBlur-style radius in bloom-buffer texels
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut crt_vertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    float2 uvs[3] = { float2(0.0, 1.0), float2(2.0, 1.0), float2(0.0, -1.0) };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

float min2(float2 v) { return min(v.x, v.y); }
float max2(float2 v) { return max(v.x, v.y); }
float rand2(float2 v) {
    return fract(sin(dot(v, float2(12.9898, 78.233))) * 43758.5453);
}
float rgb2grey(float3 v) { return dot(v, float3(0.21, 0.72, 0.04)); }

float2 distortCoordinates(float2 coords, float screenCurvature, float frameSize) {
    float2 paddedCoords = coords * (float2(1.0) + frameSize * 2.0) - frameSize;
    float2 cc = (paddedCoords - float2(0.5));
    float dist = dot(cc, cc) * screenCurvature;
    return (paddedCoords + cc * (1.0 + dist) * dist);
}

float randomPass(float2 coords, float2 virtualResolution, float time) {
    return fract(smoothstep(-120.0, 0.0, coords.y - (virtualResolution.y + 120.0) * fract(time * 0.15)));
}

/// Transparent-border sample (Qt FastBlur `transparentBorder: true`).
float4 sampleBorder(texture2d<float> tex, sampler s, float2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
        return float4(0.0);
    }
    return tex.sample(s, uv);
}

// Prepare bloom input: keep RGB, put luminance in alpha so soft edges fade like phosphor.
fragment float4 bloom_prepare_fragment(VertexOut in [[stage_in]],
                                       texture2d<float> source [[texture(0)]],
                                       sampler sourceSampler [[sampler(0)]]) {
    float4 c = source.sample(sourceSampler, in.uv);
    float lum = rgb2grey(c.rgb);
    // Bias toward bright glyphs so the screen fill doesn't wash into a huge halo.
    float alpha = saturate(smoothstep(0.05, 0.45, lum));
    return float4(c.rgb * alpha, alpha);
}

// Wide separable Gaussian — radius matches cool-retro-term FastBlur
// (`lint(16, 64, bloomQuality)` at bloomQuality resolution).
fragment float4 bloom_blur_fragment(VertexOut in [[stage_in]],
                                    constant BlurUniforms &u [[buffer(0)]],
                                    texture2d<float> source [[texture(0)]],
                                    sampler sourceSampler [[sampler(0)]]) {
    float2 uv = in.uv;
    float radius = max(u.radius, 1.0);

    // 17-tap Gaussian; step scales so kernel spans ~radius texels (soft long falloff).
    constexpr float weights[9] = {
        0.2010, 0.1760, 0.1210, 0.0650, 0.0270,
        0.0085, 0.0020, 0.0004, 0.0001
    };

    float4 sum = sampleBorder(source, sourceSampler, uv) * weights[0];
    // Kernel spans a bit past the glyph for a readable halo.
    float2 stepVec = u.direction * u.texelSize * (radius / 10.0);

    for (int i = 1; i < 9; ++i) {
        float2 offset = stepVec * float(i);
        sum += sampleBorder(source, sourceSampler, uv + offset) * weights[i];
        sum += sampleBorder(source, sourceSampler, uv - offset) * weights[i];
    }
    return sum;
}

// burn_in.frag
fragment float4 burn_in_fragment(VertexOut in [[stage_in]],
                                 constant BurnInUniforms &u [[buffer(0)]],
                                 texture2d<float> txt_source [[texture(0)]],
                                 texture2d<float> burnInSource [[texture(1)]],
                                 sampler sourceSampler [[sampler(0)]]) {
    float2 coords = in.uv;
    float3 txtColor = txt_source.sample(sourceSampler, coords).rgb;
    float4 accColor = burnInSource.sample(sourceSampler, coords);

    float prevMask = accColor.a;
    float blurDecay = clamp((u.burnInLastUpdate - u.prevLastUpdate) * u.burnInTime, 0.0, 1.0);
    blurDecay = max(0.0, blurDecay - prevMask);
    float3 color = max(accColor.rgb - float3(blurDecay), txtColor);
    float currMask = step(rgb2grey(color), rgb2grey(txtColor));
    return float4(color, currMask);
}

fragment float4 crt_fragment(VertexOut in [[stage_in]],
                             constant CRTUniforms &u [[buffer(0)]],
                             texture2d<float> source [[texture(0)]],
                             texture2d<float> noiseSource [[texture(1)]],
                             texture2d<float> burnInSource [[texture(2)]],
                             texture2d<float> bloomSource [[texture(3)]],
                             sampler sourceSampler [[sampler(0)]],
                             sampler noiseSampler [[sampler(1)]]) {
    float2 uv = in.uv;

    float2 noiseCoords = float2(fract(u.time / 2.048), fract(u.time / 1048.576));
    float4 initialNoiseTexel = noiseSource.sample(noiseSampler, noiseCoords);
    float vBrightness = 1.0 + (initialNoiseTexel.g - 0.5) * u.flickering;
    float randval = u.horizontalSyncStrength - initialNoiseTexel.r;
    float vDistortionScale = step(0.0, randval) * randval * u.horizontalSyncStrength * u.horizontalSync;
    float vDistortionFreq = mix(4.0, 40.0, initialNoiseTexel.g) * step(0.0, u.horizontalSync);

    float2 curvatureCoords = distortCoordinates(uv, u.screenCurvature, u.frameSize);
    float shownDraw = max2(step(float2(0.0), curvatureCoords) - step(float2(1.0), curvatureCoords));
    float isScreen = min2(step(float2(0.0), curvatureCoords) - step(float2(1.0), curvatureCoords));
    float isReflection = shownDraw - isScreen;
    float2 staticCoords = curvatureCoords * (-1.0 + 2.0 * step(float2(0.0), curvatureCoords)
                                             - 2.0 * step(float2(1.0), curvatureCoords));

    if (shownDraw < 0.5) {
        float3 ambient = float3(u.ambientLight);
        return float4(ambient, 1.0);
    }

    float2 coords = uv;
    float dst = sin((coords.y + u.time) * vDistortionFreq);
    coords.x += dst * vDistortionScale;

    float2 noiseUV = u.noiseScale * coords + float2(fract(u.time / 0.051), fract(u.time / 0.237));
    float4 noiseTexel = noiseSource.sample(noiseSampler, noiseUV);

    float2 txt_coords = coords + (noiseTexel.ba - float2(0.5)) * u.jitterDisplacement * u.jitter;
    if (u.screenCurvature > 0.0001) {
        txt_coords = staticCoords + (noiseTexel.ba - float2(0.5)) * u.jitterDisplacement * u.jitter;
    }

    float distance = length(float2(0.5) - uv);
    float color = 0.0001;
    color += noiseTexel.a * u.staticNoise * (1.0 - distance * 1.3);
    color += randomPass(coords * u.virtualResolution, u.virtualResolution, u.time) * u.glowingLine;

    float3 txt_color = source.sample(sourceSampler, txt_coords).rgb;

    if (u.rgbShift > 0.00001) {
        float2 displacement = float2(u.rgbShift, 0.0);
        float3 rightColor = source.sample(sourceSampler, txt_coords + displacement).rgb;
        float3 leftColor = source.sample(sourceSampler, txt_coords - displacement).rgb;
        txt_color.r = leftColor.r * 0.10 + rightColor.r * 0.30 + txt_color.r * 0.60;
        txt_color.g = leftColor.g * 0.20 + rightColor.g * 0.20 + txt_color.g * 0.60;
        txt_color.b = leftColor.b * 0.30 + rightColor.b * 0.10 + txt_color.b * 0.60;
    }

    float bloomScale = 1.0 + max(u.bloom, 0.0);
    txt_color *= bloomScale;

    if (u.burnIn > 0.0001) {
        float4 txt_blur = burnInSource.sample(sourceSampler, staticCoords);
        float blurDecay = clamp((u.time - u.burnInLastUpdate) * u.burnInTime, 0.0, 1.0);
        float3 burnInColor = 0.65 * (txt_blur.rgb - float3(blurDecay)) * (1.0 - txt_blur.a);
        txt_color = max(txt_color, burnInColor);
    }

    txt_color += float3(color);

    float3 finalColor = txt_color * shownDraw;

    // terminal_static.frag bloom path — sample pre-blurred bloomSource
    float4 bloomFullColor = bloomSource.sample(sourceSampler, txt_coords);
    float3 bloomColor = bloomFullColor.rgb;
    float bloomAlpha = bloomFullColor.a;

    if (u.bloom > 0.0001) {
        float3 bloomOnScreen = bloomColor * isScreen;
        finalColor += clamp(bloomOnScreen * u.bloom * bloomAlpha, 0.0, 0.5);
        finalColor /= bloomScale;
    }

    if (u.frameShininess > 0.0001) {
        float3 reflectionColor = mix(bloomColor * bloomAlpha * 2.0, finalColor, u.frameShininess * 0.5);
        finalColor = mix(finalColor, reflectionColor, isReflection);
    }

    finalColor += float3(u.ambientLight) * (0.15 + 0.35 * bloomAlpha) * (1.0 - isScreen * 0.5);

    float brightness = mix(1.0, vBrightness, step(0.0, u.flickering));
    finalColor *= brightness;

    // Contrast — cool-retro-term uses contrast to separate fg/bg; as a post-process
    // we expand around mid-grey. 0 = bypass; default 0.80 ≈ gentle punch.
    if (u.contrast > 0.0001) {
        float contrastFactor = 0.7 + u.contrast * 0.3; // matches CRT mix weight range
        // Map that weight into an image-contrast multiplier around 1…1.6
        float factor = mix(1.0, 1.6, saturate((contrastFactor - 0.7) / 0.3));
        finalColor = saturate((finalColor - 0.5) * factor + 0.5);
    }

    // Saturation — cool-retro-term `saturationColor` pulls phosphor toward white;
    // for captured RGBA we boost chroma around luminance. 0 = bypass.
    if (u.saturation > 0.0001) {
        float grey = rgb2grey(finalColor);
        // 1.0 = original; up to 1.0 + saturation (default 0.25 → 1.25× chroma)
        finalColor = saturate(mix(float3(grey), finalColor, 1.0 + u.saturation));
    }

    float grain = rand2(uv + fract(u.time)) - 0.5;
    finalColor = clamp(finalColor + float3(grain * 0.025), 0.0, 1.0);

    return float4(finalColor, 1.0);
}
