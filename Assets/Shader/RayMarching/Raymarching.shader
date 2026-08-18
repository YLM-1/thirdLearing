Shader "Unlit/Raymarching"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float4 ditherClipPos : TEXCOORD2;
            };

            float4 _VolumetricLightPos;
            float4 _VolumetricLightColor;
            float4 _VolumetricLightForward;
            float4x4 _MyCustomLightSpaceMatrix;
            float _MyCustomLightShadowBias;
            float _MyCustomShadowIntensity;

            TEXTURE2D(_MyCustomShadowMap);
            SAMPLER(sampler_MyCustomShadowMap);
            TEXTURE2D(_Dither);
            SAMPLER(sampler_Dither);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.ditherClipPos = mul(_MyCustomLightSpaceMatrix, float4(o.worldPos, 1));
                return o;
            }
            
            float DecodeFloatRGBA(float4 encodedDepth)
            {
                return dot(encodedDepth, float4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
            }
            
            float shadowCalculation(float4 posWS)
            {
                float4 shadowCoord = mul(_MyCustomLightSpaceMatrix,posWS);
                float2 uv = shadowCoord.xy/shadowCoord.w;
                uv = uv*0.5+0.5;

                if(_ProjectionParams.x<0)
                   uv.y = 1 - uv.y;
                   
                //从世界空间拿到深度信息
                float depth = shadowCoord.z/shadowCoord.w;
                #if defined(SHADER_TARGET_GLSL)
                    depth = depth*0.5 + 0.5;
                #elif defined(UNITY_REVERSED_Z)
                    depth = 1 - depth;
                #endif

                 float4 col = SAMPLE_TEXTURE2D(_MyCustomShadowMap,sampler_MyCustomShadowMap,uv);
                 float sampleDepth = DecodeFloatRGBA(col);
                 float shadow = sampleDepth + _MyCustomLightShadowBias < depth ? _MyCustomShadowIntensity : 1;

                 if (depth > 1 || depth < 0)
                    shadow = 1;
                 return shadow;
            }

            float3 Raymarching(float3 startPos, float3 viewDir, float2 ditherUV)
            {
                float viewDistance = length(startPos - _WorldSpaceCameraPos.xyz);

                //步进
                const int step=20;
                float oneStep=viewDistance/step;

                float ditherValue = SAMPLE_TEXTURE2D(_Dither, sampler_Dither, ditherUV).r;
                oneStep *= ditherValue;

                float3 finalLight = 0;

                for(int i=0;i<step;i++)
                {
                    //当前步进的位置
                    float3 samplePos = startPos + viewDir*oneStep*i;

                    //体积点到体积光源的方向向量
                    float3 sampleToLightDir = samplePos - _VolumetricLightPos.xyz;

                    //采样点到体积光源的距离
                    float sampleToLightDistance = length(sampleToLightDir) + 1;
                    float sampleToLightDistanceInv = 1.0/sampleToLightDistance;

                    //采样点的光强到，与距离的平方成反比
                    float sampleLightIntensity = sampleToLightDistanceInv*sampleToLightDistanceInv*_VolumetricLightPos.w;

                    //采样阴影贴图
                    float shadow = shadowCalculation(float4(samplePos,1));

                    float3 sampleToLightDirNorm = normalize(sampleToLightDir);
                    float ndotl = dot(sampleToLightDirNorm, _VolumetricLightForward.xyz);
                    float inLight = smoothstep(_VolumetricLightForward.w, 1, ndotl);

                    finalLight += _VolumetricLightColor.rgb * sampleLightIntensity * shadow * inLight;
                }
                return finalLight;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

                float3 volumetricLight = Raymarching(i.worldPos,viewDir,i.ditherClipPos.xy);

                float4 col = float4(volumetricLight,0.75);
                return col;
            }
            ENDHLSL
        }
    }
}
