Shader "Custom/chapter6_4BottomLit"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor]   _BaseColor("Color", Color) = (0.459, 0.341, 0.310, 1)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.2
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        // 调试模式：在材质面板切换，不用改代码
        [Enum(Normal,0,Pressure,1,PressureUV,2,MeshUV,3,Caustic,4,Pressure_MeshUV,5,PressureGradient,6)]
        _DebugMode("Debug Mode", Float) = 0
        _PressureDebugScale("Pressure Debug Scale", Float) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float _Smoothness;
                float _Metallic;
                float _DebugMode;
                float _PressureDebugScale;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // 焦散相关的全局参数（由 Chapter6_4SceneManager 设置）
            float _PoolWidth;
            float _PoolHeight;
            float _BottomDepth;
            float _CausticIntensity;

            // 压力场的世界 XZ 映射范围（和水面 shader 共用）
            float4 _WaterMinXZ;
            float4 _WaterSizeXZ;

            TEXTURE2D(_PressureRT);
            SAMPLER(sampler_PressureRT);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0; // 原始网格 UV
                float2 uvAlbedo    : TEXCOORD1; // 经过 Tiling/Offset 的 Albedo UV
                float3 positionWS  : TEXCOORD2;
                float3 normalWS    : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                float  fogCoord    : TEXCOORD5;
                half3  vertexLight : TEXCOORD6;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT = (Varyings)0;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   normalInputs   = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS  = positionInputs.positionCS;
                OUT.positionWS  = positionInputs.positionWS;
                OUT.normalWS    = normalInputs.normalWS;
                OUT.uv          = IN.uv;
                OUT.uvAlbedo    = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord = GetShadowCoord(positionInputs);
                OUT.fogCoord    = ComputeFogFactor(positionInputs.positionCS.z);
                OUT.vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);

                return OUT;
            }

            // 通过求1阶导数得到焦散的通道颜色，方法同Chapter6_4_Pool的NormalmapFromHeightmap
            float3 Derivative(float2 uv)
            {
                float2 du = float2(1 / _PoolWidth * 0.5, 0);
                float u1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - du).r;
                float u2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + du).r;

                float2 dv = float2(0, 1 / _PoolHeight * 0.5);
                float v1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - dv).r;
                float v2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + dv).r;

                float3 d = float3(u1 - u2, 1, v1 - v2);
                d = normalize(d);
                return d;
            }

            float3 CausticColor(float2 uv)
            {
                float3 derivative = Derivative(uv);

                //提取不同的通道
                float3 g = Derivative(uv + 20 * float2(1, 0) / _PoolWidth);
                float3 b = Derivative(uv + 20 * float2(0, 1) / _PoolHeight);

                float3 causticColor = float3(derivative.x, g.x, b.x);
                // 压力梯度很小，需要放大到可见范围再取正
                causticColor = saturate(causticColor * _CausticIntensity);
                causticColor = causticColor * float3(0.75, 0.75, 1.2);
                return causticColor;
            }

            float4 frag (Varyings IN) : SV_Target
            {
                // ===== 1. 压力场坐标：世界 XZ，和水面 shader 完全一致 =====
                float2 pressureUV = (IN.positionWS.xz - _WaterMinXZ.xy) / max(_WaterSizeXZ.xy, float2(1e-6, 1e-6));
                pressureUV = saturate(pressureUV);

                float pressureValue = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, pressureUV).r;

                // ===== 2. 调试可视化 =====
                int mode = (int)_DebugMode;

                if (mode == 1)
                    return float4(pressureValue.xxx * _PressureDebugScale, 1);

                if (mode == 2)
                    return float4(frac(pressureUV), 0, 1);

                if (mode == 3)
                    return float4(frac(IN.uv), 0, 1);

                if (mode == 4)
                    return float4(CausticColor(pressureUV), 1);

                if (mode == 5)
                {
                    float p = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, IN.uv).r;
                    return float4(p.xxx * _PressureDebugScale, 1);
                }

                if (mode == 6)
                {
                    float3 d = Derivative(pressureUV);
                    return float4(abs(d - float3(0, 1, 0)) * _PressureDebugScale, 1);
                }

                // ===== 3. 焦散 =====
                float3 causticColor = CausticColor(pressureUV) * 5 + CausticColor(pressureUV);

                // ===== 4. SurfaceData：池底石材的 PBR 参数 =====
                SurfaceData surfaceData = (SurfaceData)0;
                half3 baseMapColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uvAlbedo).rgb;
                surfaceData.albedo     = baseMapColor * _BaseColor.rgb;
                surfaceData.metallic   = _Metallic;
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS   = half3(0, 0, 1);
                surfaceData.occlusion  = 1.0;
                surfaceData.alpha      = 1.0;

                // ===== 5. InputData：像素的光照上下文 =====
                InputData inputData = (InputData)0;
                inputData.positionWS              = IN.positionWS;
                inputData.positionCS              = IN.positionCS;
                inputData.normalWS                = NormalizeNormalPerPixel(IN.normalWS);
                inputData.viewDirectionWS         = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                inputData.shadowCoord             = IN.shadowCoord;
                inputData.fogCoord                = IN.fogCoord;
                inputData.bakedGI                 = SampleSH(inputData.normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.vertexLighting = IN.vertexLight;
                #endif

                // ===== 6. 等价于内置管线的 fragForwardBaseInternal(i) =====
                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                // 在光照结果上叠加焦散
                color.rgb += causticColor;

                return color;
            }
            ENDHLSL
        }
    }
}
