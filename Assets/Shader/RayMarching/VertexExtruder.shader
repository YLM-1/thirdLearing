Shader "Unlit/VertexExtruder"
{
    Properties
    {
        _ExtrusionFactor("ExtrusionFactor",Float)=1
        _FadePower("FadePower",Float)=1
        _FadeIntensity("FadeIntensity",Float)=1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float3 distance : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _WorldLightPos;
            float _ExtrusionFactor;
            float _FadePower;
            float _FadeIntensity;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;

                //转换到模型空间
                float3 lightPosOS = TransformWorldToObject(_WorldLightPos.xyz);
                float3 dirOS = normalize(lightPosOS - v.vertex.xyz);

                float dirValue = dot(dirOS,-v.normal);
                float controlValue = sign(dirValue)*0.5+0.5;

                float3 vpos = v.vertex.xyz - dirOS *_ExtrusionFactor*controlValue;
                o.vertex = TransformObjectToHClip(float4(vpos,1));

                o.distance = length(vpos);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float att =1/i.distance;
                att=pow(att,_FadePower)*_FadeIntensity;
                return att;
            }
            ENDHLSL
        }
    }
}
