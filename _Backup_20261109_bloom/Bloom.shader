Shader "Hidden/Bloom"
{
    Properties
    {
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

        float _GreyThreshold;

        float4 fragBrightness (v2f i) : SV_Target
        {
            float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv);
            float grey = dot(baseColor.rgb,float3(0.2125,0.7154,0.0721));
            float brightness = saturate(grey - _GreyThreshold);
            return brightness;
        }

        float4 fragBloom(v2f i) : SV_Target
        {
            return 1;
        }
        ENDHLSL

        UsePass "Hidden/Gaussian/VerticalBlur"
        UsePass "Hidden/Gaussian/HorizontalBlur"

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBrightness
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBloom
            ENDHLSL
        }
    }
}
