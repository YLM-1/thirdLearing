Shader "Unlit/PostEffect_OneBit"
{
    Properties
    {
       _BlitTexture("_Blit Texture", 2D) = "white" {}
       _OneBit("OneBit",2D)="white"{}
       _BG("BG",Color)=(0.5,0.5,0.5,1)
       _FG("FG",Color)=(1,1,1,1)
       _Tilling("Tilling",float)=1
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

            CBUFFER_START(UnityPerMaterial)
            float _Tilling;
            float4 _BG;
            float4 _FG;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            TEXTURE2D(_OneBit);
            SAMPLER(sampler_OneBit);

            v2f vert (appdata v)
            {
                v2f o;
                o.uv=v.uv;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col=SAMPLE_TEXTURE2D(_BlitTexture,sampler_BlitTexture,i.uv);
                float grey=dot(col.rgb,float3(0.299, 0.587, 0.114));

                float oneBit=SAMPLE_TEXTURE2D(_OneBit,sampler_OneBit,i.uv*_Tilling).r;
                
                float ramp=step(oneBit,grey);
                float3 finalColor = lerp(_BG.rgb, _FG.rgb, ramp);

                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
