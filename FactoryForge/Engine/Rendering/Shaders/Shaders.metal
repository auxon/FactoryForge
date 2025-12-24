#include <metal_stdlib>
using namespace metal;

// MARK: - Common Types

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

// MARK: - Tile Shaders

struct TileVertex {
    float2 position;
    float2 texCoord;
};

struct TileInstanceData {
    float2 position;
    float2 uvOrigin;
    float2 uvSize;
    float4 tint;
};

struct TileUniforms {
    float4x4 viewProjection;
};

vertex VertexOut tileVertexShader(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    constant TileUniforms& uniforms [[buffer(0)]],
    constant TileVertex* vertices [[buffer(1)]],
    constant TileInstanceData* instances [[buffer(2)]]
) {
    TileVertex vert = vertices[vertexId];
    TileInstanceData instance = instances[instanceId];
    
    float2 worldPos = vert.position + instance.position;
    
    VertexOut out;
    out.position = uniforms.viewProjection * float4(worldPos, 0.0, 1.0);
    out.texCoord = instance.uvOrigin + vert.texCoord * instance.uvSize;
    out.color = instance.tint;
    
    return out;
}

fragment float4 tileFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    float4 texColor = texture.sample(texSampler, in.texCoord);
    return texColor * in.color;
}

// MARK: - Sprite Shaders

struct SpriteVertex {
    float2 position;
    float2 texCoord;
};

struct SpriteInstanceData {
    float4x4 transform;
    float2 uvOrigin;
    float2 uvSize;
    float4 tint;
};

struct SpriteUniforms {
    float4x4 viewProjection;
};

vertex VertexOut spriteVertexShader(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    constant SpriteUniforms& uniforms [[buffer(0)]],
    constant SpriteVertex* vertices [[buffer(1)]],
    constant SpriteInstanceData* instances [[buffer(2)]]
) {
    SpriteVertex vert = vertices[vertexId];
    SpriteInstanceData instance = instances[instanceId];
    
    float4 localPos = float4(vert.position, 0.0, 1.0);
    float4 worldPos = instance.transform * localPos;
    
    VertexOut out;
    out.position = uniforms.viewProjection * worldPos;
    out.texCoord = instance.uvOrigin + vert.texCoord * instance.uvSize;
    out.color = instance.tint;
    
    return out;
}

fragment float4 spriteFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    float4 texColor = texture.sample(texSampler, in.texCoord);
    
    // Discard transparent pixels
    if (texColor.a < 0.01) {
        discard_fragment();
    }
    
    return texColor * in.color;
}

// MARK: - Particle Shaders

struct ParticleVertex {
    float2 position;
    float2 texCoord;
};

struct ParticleInstanceData {
    float2 position;
    float size;
    float rotation;
    float4 color;
};

struct ParticleUniforms {
    float4x4 viewProjection;
};

vertex VertexOut particleVertexShader(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    constant ParticleUniforms& uniforms [[buffer(0)]],
    constant ParticleVertex* vertices [[buffer(1)]],
    constant ParticleInstanceData* instances [[buffer(2)]]
) {
    ParticleVertex vert = vertices[vertexId];
    ParticleInstanceData instance = instances[instanceId];
    
    // Apply rotation
    float cosR = cos(instance.rotation);
    float sinR = sin(instance.rotation);
    float2 rotated = float2(
        vert.position.x * cosR - vert.position.y * sinR,
        vert.position.x * sinR + vert.position.y * cosR
    );
    
    // Apply scale and translation
    float2 worldPos = instance.position + rotated * instance.size;
    
    VertexOut out;
    out.position = uniforms.viewProjection * float4(worldPos, 0.0, 1.0);
    out.texCoord = vert.texCoord;
    out.color = instance.color;
    
    return out;
}

fragment float4 particleFragmentShader(
    VertexOut in [[stage_in]]
) {
    // Simple circular particle
    float2 center = in.texCoord - 0.5;
    float dist = length(center);
    float alpha = 1.0 - smoothstep(0.3, 0.5, dist);
    
    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - UI Shaders

struct UIVertex {
    float2 position;
    float2 texCoord;
    float4 color;
};

struct UIUniforms {
    float2 screenSize;
};

vertex VertexOut uiVertexShader(
    uint vertexId [[vertex_id]],
    constant UIUniforms& uniforms [[buffer(0)]],
    constant UIVertex* vertices [[buffer(1)]]
) {
    UIVertex vert = vertices[vertexId];
    
    // Convert from screen space to clip space
    float2 clipPos = (vert.position / uniforms.screenSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y; // Flip Y for screen coordinates
    
    VertexOut out;
    out.position = float4(clipPos, 0.0, 1.0);
    out.texCoord = vert.texCoord;
    out.color = vert.color;
    
    return out;
}

fragment float4 uiFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    float4 texColor = texture.sample(texSampler, in.texCoord);
    return texColor * in.color;
}

// MARK: - Pollution Overlay Shader (for visualizing pollution)

struct PollutionVertex {
    float2 position;
    float pollution;
};

vertex VertexOut pollutionVertexShader(
    uint vertexId [[vertex_id]],
    constant float4x4& viewProjection [[buffer(0)]],
    constant PollutionVertex* vertices [[buffer(1)]]
) {
    PollutionVertex vert = vertices[vertexId];
    
    VertexOut out;
    out.position = viewProjection * float4(vert.position, 0.0, 1.0);
    out.texCoord = float2(0.0, 0.0);
    out.color = float4(0.5, 0.2, 0.0, vert.pollution * 0.5);
    
    return out;
}

fragment float4 pollutionFragmentShader(
    VertexOut in [[stage_in]]
) {
    return in.color;
}

// MARK: - Power Line Shader

struct PowerLineVertex {
    float2 position;
    float2 texCoord;
};

vertex VertexOut powerLineVertexShader(
    uint vertexId [[vertex_id]],
    constant float4x4& viewProjection [[buffer(0)]],
    constant PowerLineVertex* vertices [[buffer(1)]],
    constant float& time [[buffer(2)]]
) {
    PowerLineVertex vert = vertices[vertexId];
    
    // Add slight wave animation
    float wave = sin(vert.texCoord.x * 10.0 + time * 3.0) * 0.02;
    float2 pos = vert.position + float2(0.0, wave);
    
    VertexOut out;
    out.position = viewProjection * float4(pos, 0.0, 1.0);
    out.texCoord = vert.texCoord;
    out.color = float4(0.3, 0.5, 1.0, 0.8);
    
    return out;
}

fragment float4 powerLineFragmentShader(
    VertexOut in [[stage_in]]
) {
    return in.color;
}

