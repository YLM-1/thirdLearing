Shader "Unlit/chapter6_4Bottom"
{
    Properties
    {
        _PoolColor("PoolColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _PoolColor;
            CBUFFER_END

            float4x4 _LightCamProjMatrix;
            float _PoolWidth;
            float _PoolHeight;
            float _BottomDepth;
            float _CausticIntensity;

            TEXTURE2D(_TestMap);
            SAMPLER(sampler_TestMap);

            TEXTURE2D(_PressureRT);
            SAMPLER(sampler_PressureRT);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos:TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            // 通过求1阶导数得到焦散的通道颜色，方法同Chapter6_4_Pool的NormalmapFromHeightmap
            float3 Derivative(float2 uv)
            {
                // 根据高度图中的像素与其周围像素的高度差，在切向空间构造S向量和T向量
                // 再由cross(S, T)得到法线向量

                // 计算S方向，可以指定为u向
                float2 du = float2(1 / _PoolWidth * 0.5, 0);
                // 即当前像素点u向左右邻域的像素
                float u1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - du).r;
                float u2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + du).r;
                // 计算T方向，可以指定为v向
                float2 dv = float2(0, 1 / _PoolHeight * 0.5);
                // 即当前像素点v向上下邻域的像素
                float v1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - dv).r;
                float v2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + dv).r;

                float3 d = float3(u1 - u2, 1, v1 - v2);
                d = normalize(d);
                return d;
            }

            float3 CausticColor(float2 uv)
            {
                float3 derivative = Derivative(uv);
                
                //提取不同的通道
                float3 g = Derivative(uv+20*float2(1,0)/_PoolWidth);
                float3 b = Derivative(uv+20*float2(0,1)/_PoolHeight);

                float3 causticColor = float3(derivative.x,g.x,b.x);
                // 压力梯度很小，需要放大到可见范围再取正
                causticColor = saturate(causticColor * _CausticIntensity);
                causticColor = causticColor * float3(0.75, 0.75, 1.2);
                return causticColor;
            }

            float4 frag (v2f i) : SV_Target
            {
                float pressureValueY = SAMPLE_TEXTURE2D(_PressureRT,sampler_PressureRT,i.uv);
                i.worldPos.y += _BottomDepth * pressureValueY; 
                float4 lightCamPos = mul(_LightCamProjMatrix,float4(i.worldPos,1));
                float2 lightCamUV = lightCamPos.xy/lightCamPos.w*0.5+0.5;

                float3 causticColor=0;

                // float3 test = SAMPLE_TEXTURE2D(_TestMap,sampler_TestMap,lightCamUV*5);

                //水底的焦散
                float3 causticColor0 = CausticColor(lightCamUV);

                //水面四周的焦散
                float3 causticColor1 = CausticColor(lightCamUV);

                // 原始的材质的颜色
                float4 fragBaseColor = _PoolColor; 
                fragBaseColor.rgb+=causticColor0*5+causticColor1;
                return fragBaseColor;
            }
            ENDHLSL
        }
    }
}
