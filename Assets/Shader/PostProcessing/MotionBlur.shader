Shader "Hidden/MotionBlur"
{
    Properties
    {
        _MotionAmount("Motion Amount", Range(0,1)) = 0.3
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

        CBUFFER_START(UnityPerMaterial)
        float _MotionAmount;
        CBUFFER_END

        float4 fragBlurAmount (v2f i) : SV_Target
        {
            float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv);
            baseColor.a = 1-_MotionAmount;
            return baseColor;
        }

        float4 frag(v2f i) : SV_Target
        {
            float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv);
            return baseColor;
        }
        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha//将当前帧的画面与 copiedColor 中保存的历史画面按比例融合。
            ColorMask RGB
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlurAmount
            ENDHLSL
        }

        Pass
        {
            ColorMask A
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}
