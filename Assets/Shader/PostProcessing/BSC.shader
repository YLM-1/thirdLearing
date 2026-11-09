Shader "BSC"
{
    Properties
    {
        _Color("Color",Color) = (1,1,1,1)
        _Intensity("Intensity", Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "ColorBlitPass"
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex Vert
            #pragma fragment frag

           struct appdata
            {
                float2 uv:TEXCOORD0;
                uint vertexID:SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float _Intensity;
            CBUFFER_END

            half4 frag (v2f i) : SV_Target
            {
                float4 baseColor = SAMPLE_TEXTURE2D_X( _BlitTexture,sampler_LinearClamp,i.uv);

                // 乘法染色：保留原画面的明暗和背景，只改变颜色倾向
                float3 tinted = baseColor.rgb * _Color.rgb;
                float3 result = lerp(baseColor.rgb, tinted, saturate(_Intensity));

                return _Color*_Intensity;
            }
            ENDHLSL
        }
    }
}
