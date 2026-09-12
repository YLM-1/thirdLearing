Shader "Unlit/Chapter4_2"
{
    Properties
    {
        _BaseMap("BaseMap",2D)="white"{}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv:TEXCOORD0;
            };

            struct Vertex
            {
                float3 position;
                float2 uv;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            //只用从CPU接受传递来的就行
            StructuredBuffer<Vertex> vertexBuffer;

            v2f vert (uint vertexID:SV_VertexID, uint instanceID:SV_InstanceID)
            {
                v2f o;

                //此时的粒子Position是在worldSpace下
                int index = instanceID*6+vertexID;
                float4 vertex = float4(vertexBuffer[index].position,1);

                o.vertex = TransformWorldToHClip(vertex);
                o.uv = vertexBuffer[index].uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
            }
            ENDHLSL
        }
    }
}
