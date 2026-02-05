#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 position;
    float2 uv; // 纹理坐标
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// 顶点着色器：处理位置
vertex VertexOut lh_vertexShader(uint vertexID [[vertex_id]],
                                 constant float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    float4 data = vertices[vertexID];

    // x, y 是坐标
    out.position = float4(data.x, data.y, 0.0, 1.0);
    // z, w 是纹理UV (只取左半边)
    out.uv = float2(data.z, data.w);

    return out;
}

fragment float4 lh_fragmentShader(VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    // 1. 【改】让 Color 去读右半边 (in.uv + 0.5)
    float2 colorUV = in.uv + float2(0.5, 0.0);
    float4 color = texture.sample(s, colorUV);

    // 2. 【改】让 Alpha 去读左半边 (直接用 in.uv)
    float2 alphaUV = in.uv;
    float alpha = texture.sample(s, alphaUV).r;

    return float4(color.rgb, alpha);
}