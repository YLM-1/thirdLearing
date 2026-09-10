Shader "Unlit/Chapter4_1"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Blend One One

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // struct appdata
            // {
            //     float4 vertex : POSITION;
            //     float2 uv : TEXCOORD0;
            // };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
            };

            struct Particle
            {
                float3 position;
                float3 velocity;
                float lifetime;
                float3 color;
            };
            //只用从CPU接受传递来的就行
            StructuredBuffer<Particle> particleBuffer;

            v2f vert (uint instanceID:SV_InstanceID)
            {
                v2f o;

                //此时的粒子Position是在worldSpace下
                float4 vertex = float4(particleBuffer[instanceID].position,1);

                o.vertex = TransformWorldToHClip(vertex);
                o.color = float4(particleBuffer[instanceID].color,1);
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
