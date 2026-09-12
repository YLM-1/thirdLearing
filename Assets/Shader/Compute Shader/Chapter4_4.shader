Shader "Unlit/Chapter4_4"
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            struct Boid
            {
                float3 position;
                float3 direction;
            };
            StructuredBuffer<Boid> boidBuffer;

            float4x4 createMatrix(float3 pos, float3 dir, float3 up)
            {
                float3 zAxis = normalize(dir);
                float3 xAxis = normalize(cross(dir, up));
                float3 yAxis = up;
                return float4x4(
                    xAxis.x, yAxis.x, zAxis.x, pos.x,
                    xAxis.y, yAxis.y, zAxis.y, pos.y,
                    xAxis.z, yAxis.z, zAxis.z, pos.z,
                    0, 0, 0, 1
                    );
            }

            v2f vert (appdata v,uint instanceID : SV_InstanceID)
            {
                v2f o;
                //v.vertex.xyz += boidBuffer[instanceID].position;
                float4x4 mat = createMatrix(boidBuffer[instanceID].position, boidBuffer[instanceID].direction, float3(0, 1, 0));
                v.vertex.xyz = mul(mat, v.vertex);
                o.vertex = TransformObjectToHClip(v.vertex);

                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 normalWS = normalize(i.normalWS);

                //lambert
                float NdotL = dot(normalWS,lightDir);

                return NdotL;
            }
            ENDHLSL
        }
    }
}
