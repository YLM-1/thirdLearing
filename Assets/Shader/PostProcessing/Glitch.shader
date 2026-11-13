Shader "Hidden/Glitch"
{
    Properties
    {
        _Amplitude("Amplitude", Float) = 2
        _Amount("Amount", Float) = 1

        _BlockSize("Block Size", Float) = 10
        _Speed("Speed", Float) = 1
        _BlockSizeA_U("Block Size A U", Float) = 10
        _BlockSizeA_V("Block Size A V", Float) = 10
        _BlockSizeB_U("Block Size B U", Float) = 20
        _BlockSizeB_V("Block Size B V", Float) = 20
        _BlockPowerA("Block Power A", Float) = 2
        _BlockPowerB("Block Power B", Float) = 2
        _Offset("Offset", Float) = 0.1
        _SplitRGBIntensity("Split RGB Intensity", Float) = 0.1


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
        float _Amplitude;
        float _Amount;

        float _BlockSize;
        float _Speed;
        float _BlockSizeA_U;
        float _BlockSizeA_V;
        float _BlockSizeB_U;
        float _BlockSizeB_V;
        float _BlockPowerA;
        float _BlockPowerB;
        float _Offset;
        float _SplitRGBIntensity;

        float _TimeX;
        float _LineWidth;
        float _BlockAmount;
        float _LineOffset;
        float _Alpha;
        CBUFFER_END

        inline float RandomNoise(float2 seed)
        {
            return frac(sin(dot(seed * floor(_Time.y * _Speed), float2(17.13, 3.71))) * 43758.5453123);
        }

        inline float RandomNoise(float seed)
        {
            return RandomNoise(float2(seed, 1.0));
        }

        float4 RGBSplitfrag (v2f i) : SV_Target
        {
            //1.RGB颜色分离故障（RGB Split Glitch）
            float splitAmount = 0.5*sin(_Time.y*6)+0.5;
            splitAmount *= 0.5*sin(_Time.y*16)+0.5;
            splitAmount *= 0.5*sin(_Time.y*19)+0.5;
            splitAmount *= 0.5*sin(_Time.y*27)+0.5;
            splitAmount  = pow(splitAmount,_Amplitude);//pow算出了“什么时候该爆发故障（脉冲尖峰）”。
            splitAmount *= (0.05*_Amount);//给最终的错位偏移量做一个“整体缩放”

            //颜色分离：
            float R = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv+float2(splitAmount,0)).r;
            float G = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv).g;
            float B = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv-float2(splitAmount,0)).b;
            float4 finalColor = float4(R,G,B,1);
            finalColor*=(1-splitAmount*0.5);
            return finalColor;
        }

        float4 ImageBlockfrag(v2f i) : SV_Target
        {
            float blockA = RandomNoise(floor(i.uv*float2(_BlockSizeA_U,_BlockSizeA_V)));
            float blockB = RandomNoise(floor(i.uv*float2(_BlockSizeB_U,_BlockSizeB_V)));
            float blockNoiseA = pow(blockA,_BlockPowerA);
            float blockNoiseB = pow(blockB,_BlockPowerB);

            float splitRGBNoise = RandomNoise(7.1234);

            float offset = blockNoiseA*blockNoiseB*_Offset + splitRGBNoise*_SplitRGBIntensity;

            //颜色分离：
            float R = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv).r;
            float G = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv+offset).g;
            float B = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv-offset).b;
            return float4(R,G,B,1);
        }


        float trunc(float x,float num_levels)
        {
            return floor(x*num_levels)/num_levels;
        }
        float2 trunc(float2 x, float2 num_levels)
        {
            return floor(x * num_levels) / num_levels;
        }

        float randomNoise(float2 c)
        {
            return frac(sin(dot(c.xy, float2(12.9898, 78.233))) * 43758.5453);
        }

        float3 rgb2yuv(float3 rgb)
        {
            float3 yuv;
            yuv.x = dot(rgb, float3(0.299, 0.587, 0.114));
            yuv.y = dot(rgb, float3(-0.14713, -0.28886, 0.436));
            yuv.z = dot(rgb, float3(0.615, -0.51499, -0.10001));
            return yuv;
        }

        float3 yuv2rgb(float3 yuv)
        {
            float3 rgb;
            rgb.r = yuv.x + yuv.z * 1.13983;
            rgb.g = yuv.x + dot(float2(-0.39465, -0.58060), yuv.yz);
            rgb.b = yuv.x + yuv.y * 2.03211;
            return rgb;
        }

        float4 LineBlockfrag(v2f i): SV_Target
        {
            //1.生成随机强度梯度线条
            float lineID = trunc(i.uv.y,8);
            float timeID = trunc(_TimeX,4);
            float turcUV = randomNoise(float2(lineID,timeID));//让不同的条带拥有相同的时间节奏
            float uv_randomTrunc = 6.0 * trunc(_TimeX, 24.0 * turcUV);//让不同条带拥有不同的时间变化节奏

            //2.生成随机非均匀宽度线条
            float blockLineRandom = 0.5*randomNoise(trunc(i.uv.yy+uv_randomTrunc,float2(8*_LineWidth,8*_LineWidth)));
            blockLineRandom += 0.5*randomNoise(trunc(i.uv.yy+uv_randomTrunc,float2(7,7)));
            blockLineRandom = 2*blockLineRandom-1;
            //让低于_BlockAmount的值不进行偏移
            blockLineRandom = sign(blockLineRandom)*saturate((abs(blockLineRandom)-_BlockAmount)/0.4);
            //控制整体的偏移
            blockLineRandom = lerp(0,blockLineRandom,_LineOffset);

            //3.生成源色调的blockLine Glitch
            i.uv = saturate(i.uv + float2(0.1 * blockLineRandom, 0));
            float4 blockLineColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, abs(i.uv));
            
            //4.RGB转到YUV空间
            float3 blockLineColorYUV = rgb2yuv(blockLineColor);
            float uStrength = abs(blockLineRandom);
            float uMask = saturate(0.5 - blockLineRandom);
            float uFactor = 1.0 - 3.0 * uStrength * uMask;
            blockLineColorYUV.y /= uFactor;
            // V 分量处理
            float vMask = saturate(blockLineRandom - 0.5);
            float vOffset = 0.125 * blockLineRandom * vMask;
            blockLineColorYUV.z += vOffset;
            float3 blockLineColorRGB = yuv2rgb(blockLineColorYUV);

            //5.与源场景图进行混合
            float4 sceneColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.uv);
            return lerp(sceneColor, float4(blockLineColorRGB, blockLineColor.a), _Alpha);
            }
        ENDHLSL

        Pass
        {
            Name "RGBSplit"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment RGBSplitfrag
            ENDHLSL
        }

        Pass
        {
            Name "ImageBlock"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment ImageBlockfrag
            ENDHLSL
        }

        Pass
        {
            Name "LineBlock"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment LineBlockfrag
            ENDHLSL
        }
    }
}
