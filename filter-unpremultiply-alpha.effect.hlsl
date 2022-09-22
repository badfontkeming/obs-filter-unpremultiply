// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture

// Size of the source picture
uniform int width;
uniform int height;


// General properties
uniform float dividepow = 2.0;

float3 decode_gamma(float3 color, float exponent, float shift)
{
    return pow(clamp(color, 0.0, 1.0), exponent - shift);
}

float3 encode_gamma(float3 color, float exponent)
{
    return pow(clamp(color, 0.0, 1.0), 1.0/exponent);
}

// Interpolation method and wrap mode for sampling a texture
SamplerState linear_clamp
{
    Filter    = Linear;     // Anisotropy / Point / Linear
    AddressU  = Clamp;      // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV  = Clamp;      // Wrap / Clamp / Mirror / Border / MirrorOnce
    //BorderColor = 00000000; // Used only with Border edges (optional)
};

struct VertData {
   float4 pos : POSITION;
   float2 uv  : TEXCOORD0;
};

// Vertex shader used to compute position of rendered pixels and pass UV
VertData vertex_shader_unpremultiply(VertData vertex)
{
    VertData pixel;
    pixel.pos = mul(float4(vertex.pos.xyz, 1.0), ViewProj);
    pixel.uv  = vertex.uv;
    return pixel;
}

// Pixel shader used to compute an RGBA color at a given pixel position
float4 pixel_shader_unpremultiply(VertData vertex) : TARGET
{
    float4 source_sample = image.Sample(linear_clamp, vertex.uv);
	//return float4(vertex.uv.x,vertex.uv.x,vertex.uv.x,vertex.uv.x);
	return float4(source_sample.rgb / pow(source_sample.a, dividepow), source_sample.a);
    //return float4(luminance.xxx, source_sample.a);
}

technique Draw
{
    pass
    {
        vertex_shader = vertex_shader_unpremultiply(vertex);
        pixel_shader  = pixel_shader_unpremultiply(vertex);
    }
}