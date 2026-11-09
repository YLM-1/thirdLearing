Shader "Hidden/Gaussian"
{
    Properties
    {
       _BlurSize("BlurSize",Float) = 1
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
            float2 uv[5] : TEXCOORD0;
            float4 vertex : SV_POSITION;
        };

        CBUFFER_START(UnityPerMaterial)
        float _BlurSize;
        float4 _BlitTexture_TexelSize;
        CBUFFER_END

        v2f vertVertical (appdata v)
        {
            v2f o;
            o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
            float2 uv = GetFullScreenTriangleTexCoord(v.vertexID);

            o.uv[0] = uv;
            o.uv[1] = uv + _BlitTexture_TexelSize.xy*float2(0,1)*_BlurSize;
            o.uv[2] = uv + _BlitTexture_TexelSize.xy*float2(0,2)*_BlurSize;
            o.uv[3] = uv + _BlitTexture_TexelSize.xy*float2(0,-1)*_BlurSize;
            o.uv[4] = uv + _BlitTexture_TexelSize.xy*float2(0,-2)*_BlurSize;
            return o;
        }


        v2f vertHorizontal (appdata v)
        {
            v2f o;
            o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
            float2 uv = GetFullScreenTriangleTexCoord(v.vertexID);

            o.uv[0] = uv;
            o.uv[1] = uv + _BlitTexture_TexelSize.xy*float2(1,0)*_BlurSize;
            o.uv[2] = uv + _BlitTexture_TexelSize.xy*float2(2,0)*_BlurSize;
            o.uv[3] = uv + _BlitTexture_TexelSize.xy*float2(-1,0)*_BlurSize;
            o.uv[4] = uv + _BlitTexture_TexelSize.xy*float2(-2,0)*_BlurSize;
            return o;
        }

        float4 frag (v2f i) : SV_Target
        {
            float4 finalColor = 1;

            float weight[3]={0.4025,0.2442,0.0545};//利用了对称性
            float3 sumColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv[0]).rgb*weight[0];
            for(int index=1;index<3;++index)
            {
                sumColor += SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv[index]).rgb*weight[index];
                sumColor += SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv[index+2]).rgb*weight[index];
            }
            finalColor.rgb = sumColor;
            return finalColor;
        }
        ENDHLSL

        Pass
        {
            Name "VerticalBlur"
            HLSLPROGRAM
            #pragma vertex vertVertical
            #pragma fragment frag
            ENDHLSL
        }

        Pass
        {
            Name "HorizontalBlur"
            HLSLPROGRAM
            #pragma vertex vertHorizontal
            #pragma fragment frag
            ENDHLSL
        }
    }
}
