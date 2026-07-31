Shader "Unlit/CloudShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Repeat ("Repeat", Range(0,0.1))=0.1
        _SpeedX ("SpeedX", Float) = 0.1
        _SpeedY ("SpeedY", Float) = 0.1
        _CloudColor ("CloudColor", Color) = (1,1,1,1)
        _Alpha ("Alpha", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100

        Pass
        {
            ZTest Always
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            float _Repeat;
            float _SpeedX;
            float _SpeedY;
            float4 _CloudColor;
            float _Alpha;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                float3 worldPos = TransformObjectToWorld(v.vertex);
                o.ray = worldPos - _WorldSpaceCameraPos;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float rawDepth = SampleSceneDepth(i.uv);
                float linear01Depth = Linear01Depth(rawDepth, _ZBufferParams);
                float3 worldPos = _WorldSpaceCameraPos.xyz + i.ray * linear01Depth;

                float2 worldUV = worldPos.xz*_Repeat;
                float2 uv = worldUV+_Time.y*float2(_SpeedX,_SpeedY);

                float3 ambient = SampleSH(i.normalWS);

                float col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv).r*(1-linear01Depth);
                return float4(_CloudColor.rgb*ambient,col*_Alpha);
            }
            ENDHLSL
        }
    }
}
