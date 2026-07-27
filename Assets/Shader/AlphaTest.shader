Shader "Unlit/AlphaTest"
{
    Properties
    {
       _AlphaScale("Alpha Scale", Range(0,1))=0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest"}
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
            float _AlphaScale;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex=TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv=2*i.uv-1;
                float radius=length(uv);
                clip(radius-_AlphaScale);
                return radius;
            }
            ENDHLSL
        }
    }
}
