Shader "Unlit/PostEffect_Pixelate"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white"
        _Colums("Colums", Float) = 1
        _Rows("Rows", Float) = 1
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Colums;
            float _Rows;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv=i.uv;
                uv=float2(round(uv.x*_Colums)/_Colums,round(uv.y*_Rows)/_Rows);
                float3 col=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv);
                return float4(col,1);
            }
            ENDHLSL
        }
    }
}
