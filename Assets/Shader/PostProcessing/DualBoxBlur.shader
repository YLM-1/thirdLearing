Shader "Hidden/DualBoxBlur"
{
    Properties
    {
        _DualBoxBlurSize("Blur Size", Range(0.1, 3)) = 0.4
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        struct appdata
        {
            uint vertexID : SV_VertexID;
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

        float4 _BlitTexture_TexelSize;
        float _DualBoxBlurSize;

        // 降采样：4 个对角线采样
        float4 Downfrag(v2f i) : SV_Target
        {
            float2 halfTexel = _BlitTexture_TexelSize.xy * 0.5 * _DualBoxBlurSize;

            float4 sumColor = 0;
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(halfTexel.x, halfTexel.y));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(-halfTexel.x, halfTexel.y));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(-halfTexel.x, -halfTexel.y));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(halfTexel.x, -halfTexel.y));

            return sumColor * 0.25;
        }

        // 升采样：4 个对角线 *2 + 4 个十字方向 *1
        float4 Upfrag(v2f i) : SV_Target
        {
            float2 halfTexel = _BlitTexture_TexelSize.xy * 0.5 * _DualBoxBlurSize;

            float4 sumColor = 0;

            // 对角线
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(halfTexel.x, halfTexel.y)) * 2;
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(-halfTexel.x, halfTexel.y)) * 2;
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(-halfTexel.x, -halfTexel.y)) * 2;
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(halfTexel.x, -halfTexel.y)) * 2;

            // 十字方向
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(0, halfTexel.y));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(-halfTexel.x, 0));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(0, -halfTexel.y));
            sumColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv + float2(halfTexel.x, 0));

            return sumColor / 12.0;
        }
        ENDHLSL

        Pass
        {
            Name "Downsample"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment Downfrag
            ENDHLSL
        }

        Pass
        {
            Name "Upsample"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment Upfrag
            ENDHLSL
        }
    }
}
