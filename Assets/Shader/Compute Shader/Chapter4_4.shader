Shader "Unlit/Chapter4_4"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BoidScale ("Boid Scale", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);
        float4 _BaseMap_ST;

        float _BoidScale;          // 模型整体缩放（模型本身多大就画多大）
        float4x4 _BoidRotationFix; // 模型朝向修正（默认单位矩阵）

        struct Boid
        {
            float3 position;
            float3 direction;
        };
        StructuredBuffer<Boid> boidBuffer;

        float3 SafeNormalize(float3 v, float3 fallback)
        {
            float lenSq = dot(v, v);
            return lenSq > 1e-8f ? v * rsqrt(lenSq) : fallback;
        }

        // 由 Boid 的世界坐标 + 朝向构造 object -> world 矩阵（右手正交基 + 统一缩放）
        float4x4 BuildBoidMatrix(float3 pos, float3 dir)
        {
            float3 zAxis = SafeNormalize(dir, float3(0, 0, 1));

            // x = cross(up, z)，保证右手系（写成 cross(z, up) 会导致模型镜像）
            float3 xAxis = cross(float3(0, 1, 0), zAxis);

            // 鱼正上/正下游时 up 与 z 平行，cross 退化，换一个参考轴
            if (dot(xAxis, xAxis) < 1e-6f)
                xAxis = cross(float3(0, 0, 1), zAxis);

            xAxis = normalize(xAxis);

            // y 由 z、x 叉乘得到，保证与 z 正交（直接用 up 会让基变斜、模型被剪切）
            float3 yAxis = cross(zAxis, xAxis);

            // 统一缩放：模型顶点有多大就画多大，所以缩放必须乘进基向量
            float s = max(_BoidScale, 0.0001f);
            xAxis *= s;
            yAxis *= s;
            zAxis *= s;

            return float4x4(
                xAxis.x, yAxis.x, zAxis.x, pos.x,
                xAxis.y, yAxis.y, zAxis.y, pos.y,
                xAxis.z, yAxis.z, zAxis.z, pos.z,
                0, 0, 0, 1
            );
        }

        // 模型空间顶点 -> Boid 世界空间（先做朝向修正，再乘 Boid 矩阵）
        float3 BoidVertexToWorld(float3 posOS, float4x4 mat)
        {
            float3 p = mul((float3x3)_BoidRotationFix, posOS);
            return mul(mat, float4(p, 1.0)).xyz;
        }

        // 模型空间法线 -> 世界空间（正交基 + 统一缩放，归一化后即正确）
        float3 BoidNormalToWorld(float3 normalOS, float4x4 mat)
        {
            float3 n = mul((float3x3)_BoidRotationFix, normalOS);
            return normalize(mul((float3x3)mat, n));
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.5      
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float2 uv       : TEXCOORD1;
            };

            v2f vert (appdata v, uint instanceID : SV_InstanceID)
            {
                v2f o;

                float4x4 mat = BuildBoidMatrix(
                    boidBuffer[instanceID].position,
                    boidBuffer[instanceID].direction);

                o.vertex   = TransformWorldToHClip(BoidVertexToWorld(v.vertex.xyz, mat));
                o.normalWS = BoidNormalToWorld(v.normal, mat);
                o.uv       = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 normalWS = normalize(i.normalWS);

                float NdotL = saturate(dot(normalWS, lightDir));

                float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                return float4(albedo.rgb * NdotL, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // 方向光/点光、聚光灯的 Normal Bias 公式不同
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryings ShadowPassVertex(ShadowAttributes input, uint instanceID : SV_InstanceID)
            {
                ShadowVaryings output;

                float4x4 mat = BuildBoidMatrix(
                    boidBuffer[instanceID].position,
                    boidBuffer[instanceID].direction);

                float3 positionWS = BoidVertexToWorld(input.positionOS.xyz, mat);
                float3 normalWS   = BoidNormalToWorld(input.normalOS, mat);

                //当光源是点光源或聚光灯（punctual light）时启用。
                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                //ApplyShadowBias：沿法线+光方向微调，防自阴影瑕疵
                float4 positionCS = TransformWorldToHClip(
                    ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                
                //深度钳制：保证 z 落在 [近平面, 远平面] 合法范围内
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                output.positionCS = positionCS;
                return output;
            }

            half4 ShadowPassFragment(ShadowVaryings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            //DepthOnlyPass 在 URP 14 的 UniversalRenderer 里，执行时机在所有不透明物体之前：
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On// // 必须写深度，这个 Pass 唯一的目的
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            struct DepthAttributes
            {
                float4 positionOS : POSITION;
            };

            struct DepthVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            DepthVaryings DepthOnlyVertex(DepthAttributes input, uint instanceID : SV_InstanceID)
            {
                DepthVaryings output;

                float4x4 mat = BuildBoidMatrix(
                    boidBuffer[instanceID].position,
                    boidBuffer[instanceID].direction);

                output.positionCS = TransformWorldToHClip(
                    BoidVertexToWorld(input.positionOS.xyz, mat));
                return output;
            }

            half4 DepthOnlyFragment(DepthVaryings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
