Shader "Hidden/FinalBloom"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    float _Threshold;
    float _Intensity;
    float _Blur;
    float4 _Tint;

    // -----------------------------------------
    // 0: Extract bright pixels
    // -----------------------------------------

    float4 FragThreshold(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float4 col =
            SAMPLE_TEXTURE2D(
                _BlitTexture,
                sampler_LinearClamp,
                input.texcoord
            );

        float brightness = max(col.r, max(col.g, col.b));

        float contribution =
            max(brightness - _Threshold, 0.0)
            / max(brightness, 0.00001);

        return float4(col.rgb * contribution, 0);
    }


    // -----------------------------------------
    // 1: Vertical blur
    // -----------------------------------------

    float4 FragBlurVertical(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float2 uv = input.texcoord;

        float2 offset =
            float2(0, _BlitTexture_TexelSize.y * _Blur);

        float3 col = 0;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 4).rgb * 0.05;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 3).rgb * 0.09;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 2).rgb * 0.12;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset).rgb     * 0.15;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb              * 0.18;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset).rgb     * 0.15;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 2).rgb * 0.12;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 3).rgb * 0.09;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 4).rgb * 0.05;

        return float4(col, 0);
    }


    // -----------------------------------------
    // 2: Horizontal blur
    // -----------------------------------------

    float4 FragBlurHorizontal(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float2 uv = input.texcoord;

        float2 offset =
            float2(_BlitTexture_TexelSize.x * _Blur, 0);

        float3 col = 0;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 4).rgb * 0.05;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 3).rgb * 0.09;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset * 2).rgb * 0.12;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - offset).rgb     * 0.15;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb              * 0.18;

        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset).rgb     * 0.15;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 2).rgb * 0.12;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 3).rgb * 0.09;
        col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset * 4).rgb * 0.05;

        return float4(col, 0);
    }


    // -----------------------------------------
    // 3: Bloom contribution
    // -----------------------------------------

    float4 FragComposite(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float3 bloom =
            SAMPLE_TEXTURE2D(
                _BlitTexture,
                sampler_LinearClamp,
                input.texcoord
            ).rgb;

        return float4(bloom * _Tint.rgb * _Intensity, 0);
    }

    ENDHLSL


    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Cull Off
        ZWrite Off
        ZTest Always


        // PASS 0
        Pass
        {
            Name "Threshold"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragThreshold

            ENDHLSL
        }


        // PASS 1
        Pass
        {
            Name "Vertical Blur"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragBlurVertical

            ENDHLSL
        }


        // PASS 2
        Pass
        {
            Name "Horizontal Blur"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragBlurHorizontal

            ENDHLSL
        }


        // PASS 3
        Pass
        {
            Name "Composite"

            // Add bloom on top of existing screen
            Blend One One

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragComposite

            ENDHLSL
        }
    }
}