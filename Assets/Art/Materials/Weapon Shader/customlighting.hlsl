#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif

void GetMainLight_float(
    float3 WorldPos,
    out float3 Direction,
    out float3 Color,
    out float DistanceAtten,
    out float ShadowAtten)
{
#if SHADERGRAPH_PREVIEW

    Direction = float3(0.5, 0.5, 0);
    Color = 1;
    DistanceAtten = 1;
    ShadowAtten = 1;

#else

    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
        float4 clipPos = TransformWorldToHClip(WorldPos);
        float4 shadowCoord = ComputeScreenPos(clipPos);
    #else
        float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
    #endif

    Light mainLight = GetMainLight(shadowCoord);

    Direction = mainLight.direction;
    Color = mainLight.color;
    DistanceAtten = mainLight.distanceAttenuation;
    ShadowAtten = mainLight.shadowAttenuation;

#endif
}

// void MainLight_half(float3 WorldPos, out half3 Direction, out half3 Color, out half DistanceAtten, out half ShadowAtten)
// {
// #if SHADERGRAPH_PREVIEW
//     Direction = half3(0.5, 0.5, 0);
//     Color = 1;
//     DistanceAtten = 1;
//     ShadowAtten = 1;
// #else
// #if SHADOWS_SCREEN
//     half4 clipPos = TransformWorldToHClip(WorldPos);
//     half4 shadowCoord = ComputeScreenPos(clipPos);
// #else
//     half4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
// #endif
//     Light mainLight = GetMainLight(shadowCoord);
//     Direction = mainLight.direction;
//     Color = mainLight.color;
//     DistanceAtten = mainLight.distanceAttenuation;
//     ShadowAtten = mainLight.shadowAttenuation;
// #endif
// }

void DirectSpecular_float(float3 Specular, float Smoothness, float3 Direction, float3 Color, float3 WorldNormal, float3 WorldView, out float3 Out)
{
#if SHADERGRAPH_PREVIEW
    Out = 0;
#else
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    Out = LightingSpecular(Color, Direction, WorldNormal, WorldView, float4(Specular, 0), Smoothness);
#endif
}

void DirectSpecular_half(half3 Specular, half Smoothness, half3 Direction, half3 Color, half3 WorldNormal, half3 WorldView, out half3 Out)
{
#if SHADERGRAPH_PREVIEW
    Out = 0;
#else
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    Out = LightingSpecular(Color, Direction, WorldNormal, WorldView,half4(Specular, 0), Smoothness);
#endif
}

// Connect world-space Position and Normal nodes and use Out in the fragment graph.
// Out is the sum of DistanceAtten * ShadowAtten * saturate(N dot L).
// Light color/intensity and toon thresholds are deliberately left to the graph.
void AdditionalLightsStylized_float(float3 WorldPosition, float3 WorldNormal, out float Out)
{
    Out = 0.0;

#ifndef SHADERGRAPH_PREVIEW
    #if defined(_ADDITIONAL_LIGHTS) || USE_CLUSTER_LIGHT_LOOP
        WorldNormal = SafeNormalize(WorldNormal);

        // LIGHT_LOOP_BEGIN needs these fields when using Forward+.
        InputData inputData = (InputData)0;
        inputData.positionWS = WorldPosition;
        float4 screenPosition = ComputeScreenPos(TransformWorldToHClip(WorldPosition));
        inputData.normalizedScreenSpaceUV = screenPosition.xy / screenPosition.w;

        // The three-argument overload evaluates additional-light shadows.
        // A white shadow mask keeps this function limited to realtime shadows.
        half4 shadowMask = half4(1.0, 1.0, 1.0, 1.0);

        #if USE_CLUSTER_LIGHT_LOOP
            [loop] for (uint lightIndex = 0u; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
            {
                CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
                Light light = GetAdditionalLight(lightIndex, WorldPosition, shadowMask);
                #if defined(_LIGHT_LAYERS)
                    if (!IsMatchingLightLayer(light.layerMask, GetMeshRenderingLayer())) continue;
                #endif
                Out += light.distanceAttenuation * light.shadowAttenuation
                    * saturate(dot(WorldNormal, light.direction));
            }
        #endif

        uint pixelLightCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, WorldPosition, shadowMask);
            #if defined(_LIGHT_LAYERS)
                if (!IsMatchingLightLayer(light.layerMask, GetMeshRenderingLayer())) continue;
            #endif
            Out += light.distanceAttenuation * light.shadowAttenuation
                * saturate(dot(WorldNormal, light.direction));
        LIGHT_LOOP_END
    #endif
#endif
}

void AdditionalLightsStylized_half(float3 WorldPosition, half3 WorldNormal, out half Out)
{
    float result;
    AdditionalLightsStylized_float(WorldPosition, (float3)WorldNormal, result);
    Out = (half)result;
}

void AdditionalLights_float(float3 SpecColor, float Smoothness, float3 WorldPosition, 
    float3 WorldNormal, float3 WorldView, out float3 Diffuse, out float3 Specular)
{
    float3 diffuseColor = 0;
    float3 specularColor = 0;

#ifndef SHADERGRAPH_PREVIEW
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, float4(SpecColor, 0), Smoothness);
    }
#endif

    Diffuse = diffuseColor;
    Specular = specularColor;
}

void AdditionalLights_half(half3 SpecColor, half Smoothness, half3 WorldPosition, half3 WorldNormal, half3 WorldView, out half3 Diffuse, out half3 Specular)
{
    half3 diffuseColor = 0;
    half3 specularColor = 0;

#ifndef SHADERGRAPH_PREVIEW
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, half4(SpecColor, 0), Smoothness);
    }
#endif

    Diffuse = diffuseColor;
    Specular = specularColor;
}

#endif
