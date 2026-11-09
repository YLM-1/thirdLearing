Shader "Hidden/EdgeDetection"
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
                float2 uv[9] : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _EdgeColor;
            CBUFFER_END

            float4 _BlitTexture_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(v.vertexID);
                o.uv[0] = uv + _BlitTexture_TexelSize.xy*float2(-1,1);
                o.uv[1] = uv + _BlitTexture_TexelSize.xy*float2(0,1);
                o.uv[2] = uv + _BlitTexture_TexelSize.xy*float2(1,1);
                o.uv[3] = uv + _BlitTexture_TexelSize.xy*float2(-1,0);
                o.uv[4] = uv + _BlitTexture_TexelSize.xy*float2(0,0);
                o.uv[5] = uv + _BlitTexture_TexelSize.xy*float2(1,0);
                o.uv[6] = uv + _BlitTexture_TexelSize.xy*float2(-1,-1);
                o.uv[7] = uv + _BlitTexture_TexelSize.xy*float2(0,-1);
                o.uv[8] = uv + _BlitTexture_TexelSize.xy*float2(1,-1);
                return o;
            }

            float Grey(float3 color)
            {
                return dot(float3(0.2125,0.7154,0.0721),color);
            }

            //sobel边缘检测算子
            float Sobel(v2f i)
            {
                float GX = 0;
                float GY = 0;
                float gx[9] = {-1,0,1,
                               -2,0,2,
                               -1,0,1};
                float gy[9] = {-1 , -2 , -1,
                                0 ,  0 ,  0,
                                1 ,  2 ,  1};
                for(int j=0;j<9;j++)
                {
                    //我们现在只需要知道颜色明暗变化，不需要分别对 RGB 三个通道执行 Sobel。所以可以只用灰度
                    float grey = Grey(SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv[j]).rgb);
                    GX += grey*gx[j];
                    GY += grey*gy[j];
                }

                float sobel = saturate(1 - abs(GX) - abs(GY));//0->边缘，1->非边缘
                return sobel;
            }

            float4 frag (v2f i) : SV_Target
            {
                float edge = Sobel(i);
                float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv[4]);
                float3 color = lerp(_EdgeColor.rgb, baseColor.rgb, edge);
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}
