Shader "Unlit/Chapter5_2_debug"
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
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD1;
            };

            struct  Particle
            {
                float3 position;
                float3 velocity;
                float3 force;
                float3 localPosition;
                float3 offsetPosition;
            };

            StructuredBuffer<Particle> particleBuffer;
            float particleDiameter;

            float4x4 quaternionMatrix(float4 quat)
            {
                float4x4 m = float4x4(float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0));

                float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
                float x2 = x + x, y2 = y + y, z2 = z + z;
                float xx = x * x2, xy = x * y2, xz = x * z2;
                float yy = y * y2, yz = y * z2, zz = z * z2;
                float wx = w * x2, wy = w * y2, wz = w * z2;

                m[0][0] = 1.0 - (yy + zz);
                m[0][1] = xy - wz;
                m[0][2] = xz + wy;

                m[1][0] = xy + wz;
                m[1][1] = 1.0 - (xx + zz);
                m[1][2] = yz - wx;

                m[2][0] = xz - wy;
                m[2][1] = yz + wx;
                m[2][2] = 1.0 - (xx + yy);

                m[3][3] = 1.0;

                return m;
            }

            float4x4 CreatMatrix(float3 pos,float4 quat)
            {
                //通过四元数得到的旋转矩阵
                float4x4 rotation = quaternionMatrix(quat);
                float3 position = pos;
                //位移的矩阵
                float4x4 translation = 
                {
                    particleDiameter,     0,                 0,         position.x,
                    0,               particleDiameter,       0,         position.y,
                    0,                    0,          particleDiameter, position.z,
                    0,                    0,                 0,             1
                };
                return mul(translation,rotation);
            }

            v2f vert (appdata v , uint instanceID : SV_InstanceID)
            {
                v2f o;

                float3 position = particleBuffer[instanceID].position;
                float4 quaternion = float4(0,0,0,1);

                //构建当前rigidBody的旋转+位移矩阵
                float4x4 mat = CreatMatrix(position,quaternion);
                //最终点世界坐标 = (旋转矩阵 * v.vertex) + particleBuffer.position
                v.vertex.xyz = mul(mat,v.vertex).xyz;
                v.normal = mul(mat,float4(v.normal,0)).xyz;

                o.vertex = TransformObjectToHClip(v.vertex);

                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 normalWS = normalize(i.normalWS);
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float NdotL = dot(normalWS,lightDir);
                return NdotL;
            }
            ENDHLSL
        }
    }
}
