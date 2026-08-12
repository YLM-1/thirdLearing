Shader "Unlit/StylizedHighlights"
{
    Properties
    {
        [Header(Base Settings)]
        _ReampMap("Reamp Map", 2D) = "white" {}
        _Color("Color", Color) = (1, 1, 1, 1)
        _OutLineWidth("Outline Width", Range(0, 0.1)) = 0.01

        [Header((Specular Settings))]
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularPower("Specular Power", Range(0, 100)) = 10
        _SpecularIntensity("Specular Intensity", Range(0, 2)) = 0.5
        _SpecularSegments("Specular Segments", Range(0, 1)) = 0.5

        [Header(Translation)]
        _Tx("Tx", Range(-1, 1)) = 0
        _Ty("Ty", Range(-1, 1)) = 0

        [Header(Scale)]
        _Sx("Sx", Range(-1, 1)) = 0
        _Sy("Sy", Range(-1, 1)) = 0

        [Header(Rotation)]
        _Rx("Rx", Range(-180, 180)) = 0
        _Ry("Ry", Range(-180, 180)) = 0
        _Rz("Rz", Range(-180, 180)) = 0

        [Header(Split)]
        _SplitX("Split X", Range(0, 1)) = 0
        _SplitY("Split Y", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        UsePass "Unlit/AntialiasedCelShading/Outline"

        Pass
        {
            Name "CelShading"
            Tags { "LightMode" = "UniversalForward" } 
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #define Degree2Radian 0.01745329

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 posWS : TEXCOORD1;
                // 用来传递世界空间 TBN 的三个轴向给片元着色器
                float3 tbn0 : TEXCOORD3;
                float3 tbn1 : TEXCOORD4;
                float3 tbn2 : TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Tx;
            float _Ty;
            float _Sx;
            float _Sy;
            float _Rx;
            float _Ry;
            float _Rz;
            float _SplitX;
            float _SplitY;
            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularIntensity;
            float _SpecularSegments;
            float4 _Color;
            CBUFFER_END

            TEXTURE2D(_ReampMap);
            SAMPLER(sampler_ReampMap);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex.xyz);

                // 在世界空间直接拼装 TBN 基轴，将性能压力在顶点阶段化解
                float3 normalWS = TransformObjectToWorldNormal(v.normal);
                float3 tangentWS = TransformObjectToWorldDir(v.tangent.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * v.tangent.w;

                // 传递世界轴到片元
                o.tbn0 = tangentWS;
                o.tbn1 = bitangentWS;
                o.tbn2 = normalWS;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDirWS = normalize(light.direction);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - i.posWS);

                // 1. 行向量组装世界 TBN 矩阵：第一行为切线，第二行为副切线，第三行为法线
                float3x3 TBN = float3x3(i.tbn0, i.tbn1, i.tbn2);

                // 2. 【拨乱反正】：矩阵在左，向量在右（左乘），完美执行 World -> Tangent 投影！
                // 彻底丢弃 TransformWorldToObjectDir，每个像素白嫖两次中转消耗
                float3 tangentLightDir = normalize(mul(TBN, lightDirWS));
                float3 tangentViewDir  = normalize(mul(TBN, viewDirWS));
                float3 tangentHalfDir  = normalize(tangentLightDir + tangentViewDir);

                // Translation (平移)
                tangentHalfDir += float3(_Tx, _Ty, 0);
                tangentHalfDir = normalize(tangentHalfDir);

                // Scale (缩放)
                tangentHalfDir.x *= (1.0 - _Sx);
                tangentHalfDir.y *= (1.0 - _Sy);
                tangentHalfDir = normalize(tangentHalfDir);

                // Rotation (旋转)
                float rx = _Rx * Degree2Radian;
                float3x3 xRot = float3x3(1, 0, 0,
                                         0, cos(rx), sin(rx),
                                         0, -sin(rx), cos(rx));
                float ry = _Ry * Degree2Radian;                     
                float3x3 yRot = float3x3(cos(ry), 0, -sin(ry),
                                         0, 1, 0,
                                         sin(ry), 0, cos(ry));
                float rz = _Rz * Degree2Radian;                     
                float3x3 zRot = float3x3(cos(rz), sin(rz), 0,
                                         -sin(rz), cos(rz), 0,
                                         0, 0, 1);
                tangentHalfDir = mul(zRot, mul(yRot, mul(xRot, tangentHalfDir)));
                tangentHalfDir = normalize(tangentHalfDir);                   
                
                // Split (分裂)
                float signX = 1;
                if(tangentHalfDir.x < 0) 
                       signX = -1;
                       
                float signY = 1;
                if(tangentHalfDir.y < 0) 
                       signY = -1;
                        tangentHalfDir -= float3(_SplitX * signX, _SplitY * signY, 0);
                tangentHalfDir = normalize(tangentHalfDir);

                // 3.  Diffuse (漫反射)：此时 tangentLightDir.z 完美等于传统的 NdotL
                float diff = max(tangentLightDir.z * 0.5 + 0.5, 0);

                // 采样你的明暗梯度 Reamp 贴图
                float3 diffuseColor = SAMPLE_TEXTURE2D(_ReampMap, sampler_ReampMap, float2(diff, i.uv.y)).rgb;
                
                // 4.  Specular (高光)：等价于点积切空间标准法线 (0,0,1)，直接取 z 分量！
                float spec = pow(max(tangentHalfDir.z, 0), _SpecularPower) * _SpecularIntensity;

                // fwidth 动态抗锯齿过渡
                float f = fwidth(spec) * 2;
                spec = smoothstep(0, 1, smoothstep(_SpecularSegments - f, _SpecularSegments + f, spec));

                // 最终二次元颜色光影混合
                float3 finalColor = _Color.rgb * diffuseColor + spec * _SpecularColor.rgb;
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}