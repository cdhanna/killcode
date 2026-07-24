#define VS_SHADERMODEL vs_3_0
#define PS_SHADERMODEL ps_3_0

Texture2D SpriteTexture;
sampler2D SpriteTextureSampler = sampler_state
{
    Texture = <SpriteTexture>;
};

Texture2D PanelTexture;
sampler2D PanelTextureSampler = sampler_state
{
    Texture = <PanelTexture>;
};

float4x4 MatrixTransform;

struct PSInput
{
    float4 Position : POSITION;
    float4 Color    : COLOR0;
    float2 TexCoord : TEXCOORD0;
    float4 Extra : TEXCOORD1;
};

float4 MainPS(PSInput input) : COLOR
{
    float uvX1 = input.Extra.r;
    float uvY1 = input.Extra.g;
    float uvX2 = input.Extra.b;
    float uvY2 = input.Extra.w;

    float4 c = tex2D(SpriteTextureSampler, input.TexCoord) * input.Color;
    
    if (input.TexCoord.x < uvX1)
        discard;
    if (input.TexCoord.x > uvX2)
        discard;
    if (input.TexCoord.y < uvY1)
        discard;
    if (input.TexCoord.y > uvY2)
        discard;

    // float mask = (input.TexCoord.x > uvX1 && input.TexCoord.x < uvX2) ? 1.0 : 0.0;
    // c+= tex2D(PanelTextureSampler, input.TexCoord);
    // c.rgb = float3(1.0,1.0,1.0);
    // c.r = uvX2;
    // c.a = 1.0 ;
    // c.a *= mask;
    return float4(c.rgb, c.a);
}

technique MainTechnique
{
    pass P0
    {
        PixelShader  = compile PS_SHADERMODEL MainPS();
    }
};
