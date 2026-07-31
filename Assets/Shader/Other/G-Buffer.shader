Shader "Unlit/G-Buffer"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white"{}
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _SpecularPower ("Specular Power", Range(0, 100)) = 10
        _SpecularIntensity ("Specular Intensity", Range(0, 10)) = 1
        _Gloss("Gloss", Range(0, 1))=0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "UniversalMaterialType"="SimpleLit" }
        LOD 100

        Pass
        {
            Tags {"LightMode"="UniversalGBuffer"}
            ZWrite On

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers gles gles3 glcore
            #pragma multi_compile_fragment _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normalWS:TEXCOORD1;
                float3 posWS:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Diffuse;
                float4 _SpecularColor;
                float _SpecularPower;
                float _SpecularIntensity;
                float _Gloss;
                float4 _MainTex_ST;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            FragmentOutput frag (v2f i)
            {
                half3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Diffuse.rgb;

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo;
                surfaceData.occlusion = 1;
                surfaceData.specular = saturate(_SpecularColor.rgb * _SpecularIntensity);
                surfaceData.smoothness = _Gloss;
                surfaceData.emission = 0;
                surfaceData.alpha = 1;

                InputData inputData = (InputData)0;
                inputData.positionWS = i.posWS;
                inputData.positionCS = i.vertex;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.posWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(i.posWS);
                inputData.bakedGI = SampleSH(normalWS);
                inputData.shadowMask = half4(1, 1, 1, 1);

                half3 globalIllumination = inputData.bakedGI * surfaceData.albedo + surfaceData.emission;

                return SurfaceDataToGbuffer(
                    surfaceData,
                    inputData,
                    globalIllumination,
                    kLightingSimpleLit);

            }
            ENDHLSL
        }
        // 阴影Pass：延迟渲染也需要投射阴影
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    }
}
