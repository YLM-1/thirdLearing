Shader "Unlit/Cull"
{
    Properties
    {
        _Color0("Color0", Color)=(1,1,1,1)
        _Color1("Color1", Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off

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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _Color0;
            float4 _Color1;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.normal=TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i,float facing:VFACE) : SV_Target
            {
                float3 col=lerp(_Color0.rgb,_Color1.rgb,facing>0);

                col=lerp(i.normal,float3(0,0,1),facing>0);
                return float4(col,1);
            }
            ENDHLSL
        }
    }
}
