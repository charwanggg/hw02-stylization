Shader "Custom/URP/SimpleGradientSkybox"
{
     Properties
    {
        
       [Header(Primary)]
        _Exponent ("Gradient Exponent", Range(0.1, 8)) = 1 
        _TopColor ("Top Color", Color) = (0.2, 0.5, 1, 1)
        _DayColor ("Day Color", Color) = (1, 1, 1, 1)
        _DayColor2 ("Day Color 2", Color) = (1, 1, 1, 1)
        _NightColor ("Night Color", Color) = (0, 0, 0.8, 1)
        _NightColor2 ("Night Color 2", Color) = (1, 1, 1, 1)
        _SplitRotation ("Day/Night Divide Rotation", Range(0, 360)) = 0
        _Exposure ("Exposure", Range(0,5)) = 1

        [Header(Sun)]
        _SunDir ("Sun Direction", Vector) = (0,1,0,0)
        _SunColor ("Sun Color", Color) = (5,4,3,1)
        _MoonColor("Moon Color", Color) = (1,1,1,1)
        _SunSize ("Sun Size", Range(0.00001,0.1)) = 0.02
        _SunSoftness ("Sun Softness", Range(0.00001,0.1)) = 0.01
        _SunGlow("Sun Glow", Range(0, 0.1)) = 1
        _Stardust ("Stardust Color", Color) = (1,1,1,1)
        _Stardust2 ("Stardust Color2", Color) = (1,1,1,1)
    
    }
    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" "RenderPipeline"="UniversalPipeline" }
        //LOD 100
        // Cull Off
        // ZWrite Off
        // ZTest Always

        Pass
        {
            Name "Skybox"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature FUZZY
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 dirWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _TopColor;
                float4 _DayColor;float4 _DayColor2;
                float4 _NightColor; float4 _NightColor2;
                float _Exponent;
                float _SplitRotation;
                float _Exposure;

                float4 _SunDir; float4 _SunColor; float _SunSize; float _SunSoftness; float _SunGlow;
                float4 _MoonColor; float4 _Stardust; float4 _Stardust2;
            CBUFFER_END

            TEXTURE2D(_Stars);
            SAMPLER(sampler_Stars);
            TEXTURE2D(_BaseNoise);
            SAMPLER(sampler_BaseNoise);
            TEXTURE2D(_Distort);
            SAMPLER(sampler_Distort);
            TEXTURE2D(_SecNoise);
            SAMPLER(sampler_SecNoise);

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.dirWS = normalize(TransformObjectToWorldDir(IN.positionOS.xyz));
                return OUT;
            }

            float hash21(float2 p)
            {
                // cheap, deterministic hash
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            
            float noise2D(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                // Smoothstep curve for interpolation
                float2 u = f * f * (3.0 - 2.0 * f);

                float a = hash21(i + float2(0, 0));
                float b = hash21(i + float2(1, 0));
                float c = hash21(i + float2(0, 1));
                float d = hash21(i + float2(1, 1));

                // Bilinear interpolation
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            float fbm2D(float2 p, int octaves, float lacunarity, float gain)
            {
                float sum = 0.0;
                float amp = 0.5;
                float freq = 1.0;

                // Track amplitude sum so we can normalize to ~[0,1]
                float ampSum = 0.0;

                // Keep octaves small/constant if you can for performance (e.g. 5 or 6).
                [loop]
                for (int o = 0; o < octaves; o++)
                {
                    float n = noise2D(p * freq);
                    sum += n * amp;

                    ampSum += amp;
                    freq *= lacunarity;
                    amp *= gain;
                }

                return (ampSum > 0.0) ? (sum / ampSum) : 0.0;
            }

            float hash11(float x)
            {
                return frac(sin(x * 127.1) * 43758.5453123);
            }
            
            float noise1D(float x)
            {
                float i = floor(x);
                float f = frac(x);

                float a = hash11(i);
                float b = hash11(i + 1.0);

                float u = f * f * (3.0 - 2.0 * f); // smoothstep

                return lerp(a, b, u);
            }

            float fbm1D(float x)
            {
                float value = 0.0;
                float amplitude = 0.5;

                for (int i = 0; i < 8; i++)
                {
                    value += amplitude * noise1D(x);
                    x *= 2.0;      // frequency increase
                    amplitude *= 0.5; // amplitude decrease
                }

                return value;
            }

            float voronoiStar(float2 uv, float scale)
            {
                uv *= scale;

                float2 cell = floor(uv);
                float2 f = frac(uv);

                float minDist = 10.0;
                float brightness = 0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 offset = float2(x,y);

                        float2 rand = float2(
                            hash21(cell + offset),
                            hash21(cell + offset + 13.0)
                        );

                        float2 pos = offset + rand;

                        float dist = length(f - pos);

                        if (dist < minDist)
                        {
                            minDist = dist;
                            brightness = hash21(cell + offset + 99.0);
                        }
                    }
                }

                float star = smoothstep(0.02, 0.0, minDist);

                return star * brightness;
            }

            float hash12(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            float2 gradient(float2 p)
            {
                float angle = hash12(p) * 6.2831853;
                return float2(cos(angle), sin(angle));
            }

            float perlin2D(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                float2 g00 = gradient(i + float2(0,0));
                float2 g10 = gradient(i + float2(1,0));
                float2 g01 = gradient(i + float2(0,1));
                float2 g11 = gradient(i + float2(1,1));

                float n00 = dot(g00, f - float2(0,0));
                float n10 = dot(g10, f - float2(1,0));
                float n01 = dot(g01, f - float2(0,1));
                float n11 = dot(g11, f - float2(1,1));

                float2 u = f * f * (3.0 - 2.0 * f); // smoothstep

                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);

                return lerp(nx0, nx1, u.y);
            }


            float fbmPerlin(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;

                for (int i = 0; i < 3; i++)
                {
                    value += amplitude * perlin2D(p * frequency);

                    frequency *= 2.0;
                    amplitude *= 0.5;
                }

                return value * 0.5 + 0.5; // normalize to [0,1]
            }


            half4 frag (Varyings IN) : SV_TARGET
            {
                float3 worldDir = normalize(IN.dirWS);
                float t = saturate(IN.dirWS.y);
        
                //
                // Sky Split
                //
                t = pow(t, _Exponent);
                float3 skyCol;
                float splitAngle = radians(_SplitRotation);
                float2 splitDirection = float2(cos(splitAngle), sin(splitAngle));
                float splitCoordinate = dot(worldDir.xz, splitDirection);
                float border = 0;
                float thickness = 0.8;

                float3 nightCol = lerp(_NightColor2.rgb, _NightColor.rgb, saturate(t * 2.0));
                float3 dayCol =  lerp(_DayColor2.rgb, _DayColor.rgb, saturate(t * 1.0));

                bool isDaySide = splitCoordinate > border;

                if (splitCoordinate < border - thickness)
                { 
                    skyCol = nightCol;
                } 
                else if (splitCoordinate > border + thickness)
                {
                    skyCol = dayCol;
                } 
                else 
                {
                    float t1 = (splitCoordinate - border + thickness)/thickness/2;
                    t1 = pow(clamp(t1, 0.0, 1.0), 1.7);
                    skyCol = lerp(nightCol, dayCol, t1);
                }

                float3 col = lerp(skyCol, _TopColor.rgb, t);
                col *= _Exposure;

                //
                //Sun
                //

                float3 sunDir = normalize(_SunDir.xyz);
                float d = 1.0 - dot(worldDir, sunDir);
                float sun = smoothstep(_SunSize + _SunSoftness, _SunSize, d);
                float glow = 1.0 / max(d * d, 1e-6);
                glow *= _SunGlow;
                col += _SunColor.rgb * glow;

                //
                // Stars
                //

                float2 skyUV;
                skyUV.x = atan2(worldDir.z, worldDir.x) / (2.0 * PI) + 0.5;
                skyUV.y = asin(clamp(worldDir.y, -1.0, 1.0)) / PI + 0.5;
                
                float2 starxz = skyUV * 30.0;
                float stars1 = voronoiStar(starxz, 10.0);
                float stars2 = voronoiStar(starxz, 1.5) * 1.5;
                float stars3 = voronoiStar(starxz, 40.0) * 3.0;
                float stars4 = voronoiStar(starxz, 80.0) * 3.0;
                
                float stars = stars1 + stars2 + stars3 + stars4;
                float2 p = worldDir.yz * 4.0;

                float2 warp = float2(
                    fbmPerlin(p + _Time.y * 0.1),
                    fbmPerlin(p + 7.3 + _Time.y * 0.1)
                );

                float twinkle = noise1D(_Time.y * 2.0 + skyUV.x * 100.0); stars *= lerp(0.8, 1.5, twinkle);
                stars *= lerp(0.8, 1.5, twinkle);

                //
                //Stardust
                //

                float stardust = fbmPerlin(p + warp);
                stardust = smoothstep(0.47, 0.8, stardust);

                float3 stardustColor = stardust;

                float fade = smoothstep(0.0, 0.3, stardust);
                stardustColor *= lerp(_Stardust2, _Stardust, fade);;

                float threshold = 0.24;
                if (worldDir.y < threshold) {
                    stars *= saturate(worldDir.y);
                    float t = worldDir.y / threshold;
                    stardustColor *= smoothstep(0, 1.0, t);
                }

                //
                //Clouds
                //

                float clouds = fbmPerlin(worldDir.zy * 2);
                clouds = smoothstep(0.48, 0.8, clouds);

                float3 cloudColor = (1.0, 1.0, 1.0) * 0.8;

                float fadeClouds = smoothstep(0.0, 0.3, clouds);

                cloudColor *= lerp(0, 1, fadeClouds);;

                threshold = 0.24;
                if (worldDir.y < threshold) {
                    float t = worldDir.y / threshold;
                    cloudColor *= smoothstep(0, 1.0, t);
                }

                if (isDaySide) {
                    if (splitCoordinate < 1.0) {
                        float t = splitCoordinate / 1.0;
                        cloudColor *= smoothstep(0, 1.0, t);
                    }
                    col += cloudColor;
                } else {
                    if (splitCoordinate > -1.0) {
                        float t = -splitCoordinate / 1.0;
                        stardustColor *= smoothstep(0, 1.0, t);
                        stars *= smoothstep(0, 1.0, t);
                    }
                    col += stardustColor;
                    col += stars * float3(1,1,1) * (stardust + 0.06) * 3.0;;
                }    
                
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
