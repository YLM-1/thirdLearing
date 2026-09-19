Shader "Unlit/Chapter6_1_MipmapLevel"
{
    Properties
    {
        //Graphics.Blit(src, dst, mat, pass) 会把 src（也就是上一级 mip 的临时 RT preRenderTexture）自动绑定到材质的 _MainTex，
        //同时自动填充 _MainTex_TexelSize = (1/w, 1/h, w, h)。
        //所以 shader 里 TEXTURE2D(_MainTex) + SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) 拿到的就是上一级 mip 的深度图，_MainTex_TexelSize 也是它的尺寸。
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        HLSLINCLUDE
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = TransformObjectToHClip(v.vertex);
                return o;
            }

        ENDHLSL

        Pass
        {
            Tags { "RenderType"="Opaque" }
            LOD 100
            HLSLPROGRAM
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            // (1 / width, 1 / height, width, height)
            float4 _MainTex_TexelSize;
            CBUFFER_END

            inline float CalculatorMipmapDepth(float2 uv)
            {
                float4 depth;

                //该Texture为正方形x=y
                float offset = _MainTex_TexelSize.x/2;
                 // 采样周围4邻域的像素
                 // mipmap[i+1]的uv = mipmap[i]的 (uv), (u,v + 0.5/w), (u + 0.5/w, v), (u + 0.5w, v + 0.5w)
                depth.x = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv).r;
                depth.y = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + float2(0, offset)).r;
                depth.z = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv + float2(offset, 0)).r;
                depth.w = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv + float2(offset, offset)).r;
                
                #if defined(UNITY_REVERSED_Z)
                    return min(min(depth.x, depth.y), min(depth.z, depth.w));
                #else
                    return max(max(depth.x, depth.y), max(depth.z, depth.w));
                #endif
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth = CalculatorMipmapDepth(i.uv);
                return float4(depth,0,0,1);
            }
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 frag (v2f i) : SV_Target
            {
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture ,i.uv).r;
                return float4(depth, 0, 0, 1.0f);
            }
            ENDHLSL
        }
    }
}
