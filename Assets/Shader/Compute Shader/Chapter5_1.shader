Shader "Unlit/Chapter5_1"
{
    Properties
    {
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
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : TEXCOORD0;
            };

            struct Ball
            {
                float3 position;
                float3 velocity;
                float4 color;
            };
            StructuredBuffer<Ball> ballBuffer;

            v2f vert (appdata v,uint instanceID:SV_InstanceID)
            {
                v2f o;
                v.vertex.xyz += ballBuffer[instanceID].position;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.color = ballBuffer[instanceID].color;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return i.color;
            }
            ENDHLSL
        }
    }
}
