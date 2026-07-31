Shader "Unlit/Forward"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Diffuse("Diffuse", Color) = (1,1,1,1)
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _Gloss("Gloss", Range(0,1)) = 0.41
        _SpecularPower("Specular Power",Range(1,100)) = 10
        _SpecularIntensity("Specular Intensity",Range(0,10)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100

        Pass
        {
            //将旧版ForwardBase和ForwardAdd合并成一个
            Tags {"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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
                float4 _MainTex_ST;
                float4 _Diffuse;
                float4 _SpecularColor;
                float _Gloss;
                float _SpecularPower;
                float _SpecularIntensity;
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

            float4 frag (v2f i) : SV_Target
            {
                half3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.posWS);
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Diffuse.rgb;
                half4 specular = half4(saturate(_SpecularColor.rgb * _SpecularIntensity), 1);

                Light mainLight = GetMainLight();
                half3 attenuatedMainColor = mainLight.color * mainLight.distanceAttenuation;
                half3 color = SampleSH(normalWS) * albedo;
                color += LightingLambert(attenuatedMainColor, mainLight.direction, normalWS) * albedo;
                half specularPower = exp2(10.0 * _Gloss + 1.0);
                color += LightingSpecular(attenuatedMainColor, mainLight.direction, normalWS, viewDirectionWS, specular, specularPower);

                #if defined(_ADDITIONAL_LIGHTS)
                uint pixelLightsCount = GetAdditionalLightsCount();
                for (uint j = 0; j < pixelLightsCount; ++j)
                {
                    Light additionalLight = GetAdditionalLight(j, i.posWS, half4(1, 1, 1, 1));
                    half3 attenuatedLightColor = additionalLight.color * additionalLight.distanceAttenuation;
                    color += LightingLambert(attenuatedLightColor, additionalLight.direction, normalWS) * albedo;
                    color += LightingSpecular(attenuatedLightColor, additionalLight.direction, normalWS, viewDirectionWS, specular, specularPower);
                }
                #endif

                return half4(color, 1);
            }
            ENDHLSL
        }

    }
}
