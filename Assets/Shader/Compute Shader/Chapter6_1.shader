Shader "Unlit/Chapter6_1"
{
    Properties
    {
        _BaseMap("Base Map",2D)="white"{}
    }
    SubShader
    {
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
        ENDHLSL

        Tags{"RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        // ================= Pass 1: 主光照与阴影接收 Pass =================
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode"="UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            //URP阴影相关Keyword
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

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
                float4 shadowCoord : TEXCOORD2;//用于存储阴影采样坐标
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            v2f vert (appdata v,uint instanceID:SV_InstanceID)
            {
                v2f o;

                GrassClump clumps = clumpsBuffer[instanceID];
                float4x4 mat = createMatrix(clumps.position,clumps.lean*v.uv.y);
                float4x4 mat2 = createMatrix(clumps.position,clumps.quaternion);
                //v.vertex = mul(mat2,float4(v.vertex.xyz,1));

                v.vertex = lerp(mul(mat,float4(v.vertex.xyz,1)),mul(mat2,float4(v.vertex.xyz,1)),clumps.trample);
                float4 posWS = v.vertex;
                // v.vertex = mul(mat,float4(v.vertex.xyz,1));
                o.vertex = TransformWorldToHClip(v.vertex);
                o.normalWS=TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;

                //计算阴影采样坐标
                o.shadowCoord = TransformWorldToShadowCoord(posWS.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight(i.shadowCoord);

                float3 lightDir = normalize(light.direction);
                float3 normalWS = normalize(i.normalWS);

                //half_lambert
                float NdotL = dot(lightDir,normalWS)*0.5+0.5;

                float3 baseColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv).xyz;

                //乘以light.shadowAttenuation实时接收阴影
                float3 radiance = light.color.xyz*light.shadowAttenuation*NdotL;
                float3 col = radiance*baseColor;
                return float4(col,1);
            }
            ENDHLSL
        }

        // ================= Pass 2: 阴影投射 Pass (让草能在地面或其他物体上产生阴影) =================
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode"="ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            float3 _LightDirection;

            v2f vertShadow(appdata v,uint instanceID : SV_InstanceID)
            {
                v2f o;

                GrassClump clumps = clumpsBuffer[instanceID];
                float4x4 mat = createMatrix(clumps.position, clumps.lean * v.uv.y);
                float4x4 mat2 = createMatrix(clumps.position, clumps.quaternion);

                float4 posWS = lerp(mul(mat, float4(v.vertex.xyz, 1.0)), mul(mat2, float4(v.vertex.xyz, 1.0)), clumps.trample);
                float3 normalWS = TransformObjectToWorldNormal(v.normal);

                // 应用 URP Shadow Bias (避免 Shadow Acne 自阴影瑕疵)
                //渲染 ShadowMap 时记录的深度是 shadow。
                //在计算受光时，渲染像素算出的深度也是 pixel。
                //由于浮点数精度误差，很容易出现 pixel >shadow，导致像素错把自己判定为“在阴影里”（Shadow Acne）。
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(posWS.xyz, normalWS, _LightDirection));

                #if UNITY_REVERSED_Z
                //OpenGL
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                //DX
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                o.vertex = positionCS;
                return o;
            }

            float4 fragShadow(v2f i):SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
