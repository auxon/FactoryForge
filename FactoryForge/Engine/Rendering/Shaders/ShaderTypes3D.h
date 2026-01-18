#ifndef ShaderTypes3D_h
#define ShaderTypes3D_h

#include <simd/simd.h>

// 3D Vertex structure
typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoord;
    vector_float4 color;
} Vertex3D;

// Camera uniforms
typedef struct {
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewProjectionMatrix;
    vector_float3 cameraPosition;
} CameraUniforms;

// Model uniforms
typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
} ModelUniforms;

// Light structure
typedef struct {
    uint type;              // 0 = directional, 1 = point, 2 = spot, 3 = ambient
    vector_float3 position;
    vector_float3 direction;
    vector_float3 color;
    float intensity;
    float range;
    float spotAngle;
} Light;

// Light uniforms (support up to 4 lights)
typedef struct {
    uint lightCount;
    Light lights[4];
} LightUniforms;

// Terrain vertex structure
typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoord;
} TerrainVertex;

// Material properties
typedef struct {
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    float shininess;
    float metallic;
    float roughness;
} MaterialUniforms;

#endif /* ShaderTypes3D_h */