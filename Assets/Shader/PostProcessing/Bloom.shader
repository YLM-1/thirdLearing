Shader "Hidden/Bloom"
{
    Properties
    {
        _GreyThreshold("Grey Threshold", Range(0, 1)) = 0.1
        _BloomIntensity("Bloom Intensity", Range(0, 5)) = 1
        _BlurSize("Blur Size", Range(0.1, 10)) = 1
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

        TEXTURE2D(_BloomTex);

        float _GreyThreshold;
        float _BloomIntensity;

        float4 fragBrightness (v2f i) : SV_Target
        {
            float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv);
            float grey = dot(baseColor.rgb, float3(0.2125, 0.7154, 0.0721));
            float brightness = saturate(grey - _GreyThreshold);
            return float4(baseColor.rgb * brightness, baseColor.a);
        }

        float4 fragBloom (v2f i) : SV_Target
        {
            float4 original = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv);
            float4 bloom = SAMPLE_TEXTURE2D(_BloomTex, sampler_LinearClamp, i.uv);
            return float4(original.rgb + bloom.rgb * _BloomIntensity, original.a);
        }
        ENDHLSL

        UsePass "Hidden/Gaussian/VerticalBlur"
        UsePass "Hidden/Gaussian/HorizontalBlur"

        Pass
        {
            Name "Brightness"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBrightness
            ENDHLSL
        }

        Pass
        {
            Name "Composite"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBloom
            ENDHLSL
        }
    }
}
