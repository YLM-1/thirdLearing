Shader "Unlit/Chapter6_1"
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
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normalWS:TEXCOORD1;
            };

            struct GrassClump
            {
                float3 position;
                float lean;
                float noise;
                float trample;
                float4 quaternion;
            };
            StructuredBuffer<GrassClump> clumpsBuffer;
            float grassScale;
            float leanMax;

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

            float4x4 createMatrix(float3 pos,float theta)
            {
                //绕z轴旋转
                float s = sin(theta);
                float c = cos(theta);
                float4x4 rotation = {
                         c, -s, 0, 0,
                         s,  c, 0, 0,
                         0,  0, 1, 0,
                         0,  0, 0, 1
                };
                float4x4 translation ={
                    grassScale,      0,        0,     pos.x,
                    0,          grassScale,    0,     pos.y,
                    0,               0,    grassScale,pos.z,
                    0,               0,        0,        1
                };
                return mul(translation,rotation);
            }

            float4x4 createMatrix(float3 pos,float4 quaternion)
            {
                //旋转
                float4x4 rotation = quaternionMatrix(quaternion);
                //位移+缩放
                float4x4 translation ={
                    grassScale,      0,        0,     pos.x,
                    0,          grassScale,    0,     pos.y,
                    0,               0,    grassScale,pos.z,
                    0,               0,        0,        1
                };
                return mul(translation,rotation);

            }

            v2f vert (appdata v,uint instanceID:SV_InstanceID)
            {
                v2f o;

                GrassClump clumps = clumpsBuffer[instanceID];
                float4x4 mat = createMatrix(clumps.position,clumps.lean*v.uv.y);
                float4x4 mat2 = createMatrix(clumps.position,clumps.quaternion);
                //v.vertex = mul(mat2,float4(v.vertex.xyz,1));

                v.vertex = lerp(mul(mat,float4(v.vertex.xyz,1)),mul(mat2,float4(v.vertex.xyz,1)),clumps.trample);
                // v.vertex = mul(mat,float4(v.vertex.xyz,1));
                o.vertex = TransformObjectToHClip(v.vertex);
                o.normalWS=TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 normalWS = normalize(i.normalWS);
                float NdotL = dot(lightDir,normalWS)*0.5+0.5;
                float3 col = NdotL*light.color.xyz;
                return float4(col,1);
            }
            ENDHLSL
        }
    }
}
