Shader "Unlit/AlphaBlending"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _AlphaScale("Alpha Scale", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        // Pass 1: 只写深度，不输出颜色
        // Pass
        // {
        //     ZWrite On
        //     ColorMask 0

        //     HLSLPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag

        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        //     struct appdata
        //     {
        //         float4 vertex : POSITION;
        //     };

        //     struct v2f
        //     {
        //         float4 vertex : SV_POSITION;
        //     };

        //     v2f vert(appdata v)
        //     {
        //         v2f o;
        //         o.vertex = TransformObjectToHClip(v.vertex.xyz);
        //         return o;
        //     }

        //     float4 frag(v2f i) : SV_Target
        //     {
        //         return 1;
        //     }
        //     ENDHLSL
        // }

        // Pass 2: 混合渲染（默认 ZTest LEqual，不需要额外指定）
        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            float _AlphaScale;
            float4 _Color;
            CBUFFER_END

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 worldNormal = normalize(i.normalWS);

                float3 diffuse = max(round(frac(i.uv.x * 5)), round(frac(i.uv.y * 5))) * _Color.rgb;
                float3 col = light.color * max(0, dot(worldNormal, lightDir)) * diffuse;
                return float4(col, _AlphaScale);
            }
            ENDHLSL
        }
    }
}
