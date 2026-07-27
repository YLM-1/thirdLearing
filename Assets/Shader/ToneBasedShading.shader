Shader "Unlit/ToneBasedShading"
{
    Properties
    {
        _ReampMap("Reamp Map",2D)="white"{}
        _OutLineWidth("OutLine Width",Range(0, 0.1))=0.1
        _SpecularPower("Specular Power",Range(1,100))=10
        _SpecularIntensity("Specular Intensity",Range(0, 2))=0.5
        _Color("Color",Color)=(1,1,1,1)

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        UsePass "Unlit/AntialiasedCelShading/Outline"

        Pass
        {
            Name "CelShading"
            Tags{"RenderType"="Opaque" "LightMode"="UniversalForward"}


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                float3 normal:TEXCOORD1;
                float3 pos:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                 float _SpecularPower;
                 float _SpecularIntensity;
                 float4 _Color;
            CBUFFER_END

            TEXTURE2D(_ReampMap);
            SAMPLER(sampler_ReampMap);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;  
                o.normal = TransformObjectToWorldNormal(v.normal);   
                o.pos=TransformObjectToWorld(v.vertex.xyz);    
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 worldNormal = normalize(i.normal);
                float3 viewDir = normalize(_WorldSpaceCameraPos-i.pos);
                float3 halfDir=normalize(lightDir+viewDir);

                //Diffuse
                float diff=dot(worldNormal,lightDir);
                diff=diff*0.5+0.5;
                float diffuse=SAMPLE_TEXTURE2D(_ReampMap,sampler_ReampMap,float2(diff,i.uv.y));

                //Specular
                float spec=max(0,dot(worldNormal,halfDir));
                spec=pow(spec,_SpecularPower)*_SpecularIntensity;

                float3 finalColor=diffuse*diff*_Color+spec;
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
