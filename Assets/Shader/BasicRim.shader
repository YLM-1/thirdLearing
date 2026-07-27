Shader "Unlit/BasicRim"
{
    Properties
    {
        _RimTexture("Rim Texture",2D)="white"{}
        _RimPower("Rim Power",Range(0,10))=2
        _RimIntensity("Rim Intennsity",Range(0,5))=1
        _RimColor("Rim Color",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 viewDir:TEXCOORD1;
                float3 worldNormal:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            float _RimIntensity;
            float _RimPower;
            float4 _RimColor;
            CBUFFER_END

            TEXTURE2D(_RimTexture);
            SAMPLER(sampler_RimTexture);

            v2f vert (appdata v)
            {
                v2f o;
                o.pos=TransformObjectToHClip(v.vertex);
                float3 worldPos=TransformObjectToWorld(v.vertex.xyz);
                o.viewDir=normalize(_WorldSpaceCameraPos.xyz-worldPos);
                o.uv=v.uv;
                o.worldNormal=TransformObjectToWorldNormal(v.normal);
                return o;
            }
            
            float3 FuncFresnel(float3 worldNormal,float3 viewDir)
            {
                float NdotV=saturate(dot(worldNormal,viewDir));
                float fresnel=(1-pow(NdotV,_RimPower))*_RimIntensity;
                float3 fresnelColor=fresnel*_RimColor;
                return fresnelColor;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 fresnelColor=FuncFresnel(i.worldNormal,i.viewDir);     
                float2 rimUV=float2(i.worldNormal.x*0.5+0.5,i.uv.y);

                float3 rimMap=SAMPLE_TEXTURE2D(_RimTexture,sampler_RimTexture,rimUV);
                float3 finalColor=rimMap*fresnelColor;


                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
