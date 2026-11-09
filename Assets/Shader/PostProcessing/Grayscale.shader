
Shader "Hidden/Grayscale"
{
    Properties
    {
        _Intensity("Intensity", Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

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
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID) * _BlitScaleBias.xy + _BlitScaleBias.zw;
                return o;
            }

            CBUFFER_START(UnityPerMaterial)
            float _Intensity;
            CBUFFER_END

            float4 frag(v2f i) : SV_Target
            {
                // 1. 获取摄像机原本渲染出来的颜色
                float4 color = SAMPLE_TEXTURE2D_X( _BlitTexture,sampler_LinearClamp,i.uv);

                // 2. 将 RGB 转换成灰度值
                float gray = dot(color.rgb,float3(0.299, 0.587, 0.114));

                // 3. 根据强度混合原始颜色和灰度颜色
                color.rgb = lerp(color.rgb,gray.xxx,saturate(_Intensity));

                return color;
            }

            ENDHLSL
        }
    }
}
