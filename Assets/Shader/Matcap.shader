Shader "Unlit/Matcap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MatCap("MatCap", 2D)="white"{}
        _CubeMap("CubeMap", Cube)=""{}
        _ReflectionStrength("ReflectionStrength",Range(0,1))=1
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
                float4 vertex : SV_POSITION;
                float3 normalWS:TEXCOORD1;
                float3 posWS:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                  float _ReflectionStrength;
            CBUFFER_END

            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);

            TEXTURECUBE(_CubeMap);
            SAMPLER(sampler_CubeMap);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv=v.uv;
                o.normalWS=TransformObjectToWorldNormal(v.normal);
                o.posWS=TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //反射
                float3 normalWS=normalize(i.normalWS);
                float3 viewDir=normalize(_WorldSpaceCameraPos.xyz-i.posWS);
                float3 reflectDir=reflect(-viewDir,normalWS);
                float3 viewReflect = normalize(mul((float3x3)UNITY_MATRIX_V, reflectDir));

                float3 normal2=viewReflect+float3(0,0,1);
                float m=sqrt(normal2.x*normal2.x+normal2.y*normal2.y+normal2.z*normal2.z);
                float2 uv2=float2(normal2.x/m,normal2.y/m)*0.5+0.5;

                //CubeMap
                float3 cubeMap=SAMPLE_TEXTURECUBE(_CubeMap,sampler_CubeMap,reflectDir);

                //MatCap
                float3 matCap=SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,uv2);

                //BaseColor
                float3 col=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);

                float3 finalColor=lerp(col.rgb,cubeMap,_ReflectionStrength);
                finalColor=finalColor*matCap;
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
