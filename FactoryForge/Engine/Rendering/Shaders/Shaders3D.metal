#include <metal_stdlib>
using namespace metal;

// 3D Vertex structure
struct Vertex3D {
    float3 position;
    float3 normal;
    float2 texCoord;
    float4 color;
};

// Camera uniforms
struct CameraUniforms {
    float4x4 viewProjectionMatrix;
};

// Model uniforms
struct ModelUniforms {
    float4x4 modelMatrix;
};

// Vertex output
struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
    float4 color;
};

// Terrain vertex
struct TerrainVertex {
    float3 position;
    float3 normal;
    float2 texCoord;
};

// Terrain vertex output
struct TerrainVertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
    float4 color;
};

// 3D Model vertex shader
vertex VertexOut vertex_3d_model(
    device const Vertex3D* vertices [[buffer(0)]],
    constant CameraUniforms& cameraUniforms [[buffer(1)]],
    constant ModelUniforms& modelUniforms [[buffer(2)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;

    Vertex3D inVertex = vertices[vertexID];

    // Transform position to world space then to clip space
    float4 worldPosition = modelUniforms.modelMatrix * float4(inVertex.position, 1.0);
    out.position = cameraUniforms.viewProjectionMatrix * worldPosition;

    // Pass through attributes
    out.normal = inVertex.normal;
    out.texCoord = inVertex.texCoord;
    out.color = inVertex.color;

    return out;
}

// 3D Model fragment shader
fragment float4 fragment_3d_model(VertexOut in [[stage_in]]) {
    // Simple directional lighting
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diffuse = max(dot(normal, lightDir), 0.0);

    float3 lighting = float3(0.3) + float3(0.7) * diffuse;
    float3 finalColor = in.color.rgb * lighting;

    return float4(finalColor, in.color.a);
}

// Terrain vertex shader
vertex TerrainVertexOut vertex_terrain(
    device const TerrainVertex* vertices [[buffer(0)]],
    constant CameraUniforms& cameraUniforms [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    TerrainVertexOut out;

    TerrainVertex inVertex = vertices[vertexID];

    // Transform to clip space
    out.position = cameraUniforms.viewProjectionMatrix * float4(inVertex.position, 1.0);
    out.normal = inVertex.normal;
    out.texCoord = inVertex.texCoord;

    // Height-based coloring
    float height = inVertex.position.y;
    if (height < 0.0) {
        out.color = float4(0.0, 0.3, 0.8, 1.0); // Water
    } else if (height < 1.0) {
        out.color = float4(0.2, 0.8, 0.2, 1.0); // Grass
    } else if (height < 3.0) {
        out.color = float4(0.6, 0.4, 0.2, 1.0); // Hills
    } else {
        out.color = float4(0.5, 0.5, 0.5, 1.0); // Mountains
    }

    return out;
}

// Terrain fragment shader
fragment float4 fragment_terrain(TerrainVertexOut in [[stage_in]]) {
    // Simple lighting for terrain
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diffuse = max(dot(normal, lightDir), 0.0);

    float3 lighting = float3(0.4) + float3(0.6) * diffuse;
    float3 finalColor = in.color.rgb * lighting;

    return float4(finalColor, in.color.a);
}
