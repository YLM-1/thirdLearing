Shader "Hidden/Glitch"
{
    Properties
    {
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
            float _Amplitude;
            float _Amount;
            CBUFFER_END

            float RandomNoise(float m,float n)
            {
                return frac(sin(dot(float2(12.9898, 78.233),float2(m,n)))* 43758.5453);
            }

            float4 frag (v2f i) : SV_Target
            {

                //1.RGB颜色分离故障（RGB Split Glitch）
                //float splitAmount = _SplitIntensity * RandomNoise(_Time.y,2);//会非常剧烈，没有顿挫感。
                float splitAmount = 0.5*sin(_Time.y*6)+0.5;
                splitAmount *= 0.5*sin(_Time.y*16)+0.5;
                splitAmount *= 0.5*sin(_Time.y*19)+0.5;
                splitAmount *= 0.5*sin(_Time.y*27)+0.5;
                splitAmount  = pow(splitAmount,_Amplitude);//pow算出了“什么时候该爆发故障（脉冲尖峰）”。
                splitAmount *= (0.05*_Amount);//给最终的错位偏移量做一个“整体缩放”，确保故障不会大到离谱，同时留出一个外部可以调节的强度开关（_Amount）。

                //颜色分离：
                float R = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv+float2(splitAmount,0)),r;
                float G = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv).g;
                float B = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv-float2(splitAmount,0)).b;
                float4 finalColor = float4(R,G,B,1);
                finalColor*=(1-splitAmount*0.5);
                return finalColor;

            }
            ENDHLSL
        }
    }
}
