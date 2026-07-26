#define VS_SHADERMODEL vs_3_0
#define PS_SHADERMODEL ps_3_0

// Match this to the resolution of the render target you draw through the shader.
#define SCREEN_W 1280.0
#define SCREEN_H 720.0

float Time; // optional: seconds, for animated color scans. Leave 0 to disable.

Texture2D SpriteTexture;
sampler2D SpriteTextureSampler = sampler_state
{
    Texture = <SpriteTexture>;
};

float4x4 MatrixTransform;

struct PSInput
{
    float4 Position : POSITION;
    float4 Color    : COLOR0;
    float2 TexCoord : TEXCOORD0;
};
// x mod n for non-negative x, without fmod (GLSL-safe)
float modn(float x, float n) { return x - n * floor(x / n); }

float b2(float x, float y) { return 2.0 * x + 3.0 * y - 4.0 * x * y; } // 2x2 base

float bayer4v(float px, float py)
{
    float x0 = modn(px, 2.0);
    float y0 = modn(py, 2.0);
    float x1 = modn(floor(px * 0.5), 2.0);
    float y1 = modn(floor(py * 0.5), 2.0);
    return 4.0 * b2(x0, y0) + b2(x1, y1);            // 0..15
}

float bayer8v(float px, float py)
{
    float x0 = modn(px, 4.0);
    float y0 = modn(py, 4.0);
    float x1 = modn(floor(px * 0.25), 2.0);
    float y1 = modn(floor(py * 0.25), 2.0);
    return 4.0 * bayer4v(x0, y0) + b2(x1, y1);       // 0..63
}

float4 sampleColor(float2 screenUv, float2 warpedUv)
{
    // ---- tweakables ----
    const float ditherScreenScale = 12.0;
    const float spread4     = 0.0;
    const float spread8     = 0.0;
    const float maxColorsR  = 0.0;  // 0 = off, else number of palette steps
    const float maxColorsG  = 0.0;
    const float maxColorsB  = 0.0;
    const float4 colorScans = float4(.1, 0.2, 3.0, 1.0); // x,y amount | z freq | w speed
    const float vigSizeParam = 0.2;

    // int x4 = (int)(screenUv.x * SCREEN_W * ditherScreenScale) % 4;
    // int y4 = (int)(screenUv.y * SCREEN_H * ditherScreenScale) % 4;
    // float m4 = (Bayer4[y4 * 4 + x4] / 16.0) - 0.5;

    // int x8 = (int)(screenUv.x * SCREEN_W * ditherScreenScale) % 8;
    // int y8 = (int)(screenUv.y * SCREEN_H * ditherScreenScale) % 8;
    // float m8 = (Bayer8[y8 * 8 + x8] / 64.0) - 0.5;

    float px = floor(screenUv.x * SCREEN_W * ditherScreenScale);
    float py = floor(screenUv.y * SCREEN_H * ditherScreenScale);
    float m4 = (bayer4v(px, py) / 16.0) - 0.5;
    float m8 = (bayer8v(px, py) / 64.0) - 0.5;

    float4 col = tex2D(SpriteTextureSampler, warpedUv) + m4 * spread4 + m8 * spread8;

    col.r = maxColorsR <= 0.0 ? col.r : floor(col.r * (maxColorsR - 1.0) + 0.5) / (maxColorsR - 1.0);
    col.g = maxColorsG <= 0.0 ? col.g : floor(col.g * (maxColorsG - 1.0) + 0.5) / (maxColorsG - 1.0);
    col.b = maxColorsB <= 0.0 ? col.b : floor(col.b * (maxColorsB - 1.0) + 0.5) / (maxColorsB - 1.0);
    col.rgb = clamp(col.rgb, 0.0, 1.0);

    float t = Time * colorScans.w;
    float s = (sin(SCREEN_H * screenUv.y * colorScans.z + t) + 1.0) * colorScans.x + 1.0;
    float c = (cos(SCREEN_H * screenUv.y * colorScans.z + t) + 1.0) * colorScans.y + 1.0;
    col.g  *= s;
    col.rb *= c;

    float2 absUv = abs(warpedUv * 2.0 - 1.0);
    float2 invertAbsUv = 1.0 - absUv;
    float vigSize = lerp(0.0, 500.0, vigSizeParam);
    float2 v = float2(vigSize / SCREEN_W, vigSize / SCREEN_H);
    float2 vig = smoothstep(float2(0.0, 0.0), v, invertAbsUv);
    float vigMask = vig.x * vig.y;
    
    col = clamp(col * vigMask, 0.0, 1.0);
    col.a = 1.0;
    return col;
}

float4 MainPS(PSInput input) : COLOR
{
    const float curvature  = 6.0;   // screen bulge (lower = more warp)
    const float curvature2 = 0.05;  // extra edge distortion

    float2 p = input.TexCoord * 2.0 - 1.0;
    p += p * dot(p, p) * curvature2;

    float2 offset = p / curvature;
    float2 curvedSpace = p + p * offset * offset;
    float2 mappedUv = curvedSpace * 0.5 + 0.5;

    // black outside the curved screen
    if (mappedUv.x < 0.0 || mappedUv.x > 1.0 || mappedUv.y < 0.0 || mappedUv.y > 1.0)
        return float4(.3, .3, .3, 1);

    return sampleColor(input.TexCoord, mappedUv);
}

technique MainTechnique
{
    pass P0
    {
        PixelShader = compile PS_SHADERMODEL MainPS();
    }
};