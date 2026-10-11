Shader "Unlit/chapter6_4Pool"
{
    Properties
    {
        _PoolColor("Pool Color", Color) = (0, 0.5, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        LOD 100

        //用内置的_CameraOpaqueTexture来代替
        //GrabPass是内置渲染管线的
        // GrabPass
        // {
        //     //抓取屏幕画面，并把它存进一个名为 _RefractionRT 的纹理中
        //     "_RefractionRT"
        // }

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
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
                float3 normal : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float4 refCamPos : TEXCOORD3;//采样反射贴图
                float4 screenPos : TEXCOORD4;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _PoolColor;
            CBUFFER_END    

            float _MaxPoolDisplacement;
            float _PoolWidth;
            float _PoolHeight;
                
            float _ReflectionDistort;
            float _ReflectionStrength;
            float4x4 _ReflectionCamProjMatrix;
            float4 _ReflectionCamPos;

            float _RefractionDistort;
            float _DepthDensity;

            TEXTURE2D(_PressureRT);
            SAMPLER(sampler_PressureRT);

            TEXTURE2D(_VelocityRT);
            SAMPLER(sampler_VelocityRT);

            TEXTURE2D(_ReflectionRT);
            SAMPLER(sampler_ReflectionRT);

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                // o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);

                // 使用压力场贴图来扰动顶点，仅在Y轴上扰动
                float pressureBuffer = SAMPLE_TEXTURE2D_LOD(_PressureRT, sampler_PressureRT, v.uv, 0).r;
                float pressureValue = clamp(pressureBuffer,-_MaxPoolDisplacement*0.01f, _MaxPoolDisplacement);
                o.posWS.y += pressureValue; 

                o.vertex = TransformWorldToHClip(o.posWS);

                // 反射贴图采集：把世界坐标投影到反射相机的裁剪空间，frag里再除以w
                //变换目标:反射相机的裁剪空间
                o.refCamPos = mul(_ReflectionCamProjMatrix, float4(o.posWS,1));

                //变换目标：主相机的屏幕空间
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            float3 DiffuseDisney(float kd,float3 lightColor,float LdotH,float NdotL,float NdotV,float perceptualRoughness,float3 albedo)
            {
                float Fd90 = 0.5+2*LdotH*LdotH*perceptualRoughness;
                float lightScatter = 1+(Fd90-1)*pow(1-NdotL,5);
                float viewScatter = 1+(Fd90-1)*pow(1-NdotV,5);
                float3 disneyDiffuse = lightScatter*viewScatter*albedo;

                float3 result = kd * disneyDiffuse * lightColor*NdotL;
                return result;
            }

            //直接光镜面反射
            float3 DirectLightSpecular(float NdotH,float VdotH,float NdotV,float NdotL,float roughness,float metallic,float3 albedo,float3 lightColor,out float3 F)
            {
                //D项（GGX模型）:法线分布函数
                float D=D_GGX(NdotH,roughness);

                //F项（Schlick模型）:菲尼尔项
                float3 F0=lerp(kDielectricSpec.rgb,albedo,metallic);//反射系数,kDielectricSpec.rgb=float3(0.04,0.04,0.04)
                F=F_Schlick(F0,VdotH);
                // float3 F=F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);

                //G项（Smith模型）:几何遮蔽函数,V_SmithJointGGX 内部返回的是 G / (4·NdotL·NdotV)
                float G=V_SmithJointGGX(NdotL,NdotV,roughness);

                float3 result=D*F*G*NdotL*lightColor;
                return result;
            }

            //通过高度图重新生成法线
            float3 NormalmapFromHeightmap(float2 uv)
            {
                // 根据高度图中的像素与其周围像素的高度差，在切向空间构造S向量和T向量
                // 再由cross(S, T)得到法线向量

                float2 flow = SAMPLE_TEXTURE2D(_VelocityRT,sampler_VelocityRT,uv).rg;

                // 计算S方向，可以指定为u向
                float2 du = float2((1.0+flow.r)/_PoolWidth*0.5,0);
                // 即当前像素点u向左右邻域的像素
                float u1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - du).r;
                float u2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + du).r;
                // 计算T方向，可以指定为v向
                float2 dv = float2(0,(1.0+flow.y)/_PoolHeight*0.5);
                // 即当前像素点v向上下邻域的像素
                float v1 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv - dv).r;
                float v2 = SAMPLE_TEXTURE2D(_PressureRT, sampler_PressureRT, uv + dv).r;

                float3 normal = float3(u1-u2,1,v1-v2);
                normal = normalize(normal);
                return normal;
            }

            float3 ReflectionColor(v2f i, float3 normalWS)
            {
                //i.uv 是模型自己的纹理坐标，来自顶点数据，用来采样模型表面贴的贴图（比如木纹、砖墙）。
                //它描述的是「这个点在模型表面的哪个位置」，和相机、屏幕、反射没有任何关系。
                //所以要计算camUV，必须使用反射相机的投影矩阵和反射相机的位置来计算。
                float2 refCamUV = i.refCamPos.xy / i.refCamPos.w;
                refCamUV = refCamUV * 0.5 + 0.5;
                // 平台差异交给 _ProjectionParams.x，不要再额外硬编码翻转
                if (_ProjectionParams.x < 0)
                    refCamUV.y = 1 - refCamUV.y;
                // 用扰动后的水面法线偏移采样，让倒影随水波起伏（恢复水面扰动感）
                refCamUV += normalWS.xz * _ReflectionDistort;
                float3 reflectionColor = SAMPLE_TEXTURE2D(_ReflectionRT, sampler_ReflectionRT, refCamUV).rgb;
                return reflectionColor;
            }

            float3 RefractionColor(v2f i,float3 normalWS)
            {
                float2 refractUV = i.screenPos.xy/i.screenPos.w;
                float3 normalInCam = TransformWorldToViewNormal(normalWS);

                // 折射效果仅在水面之下，才会产生
                float2 uvOffset = normalInCam.xz * _RefractionDistort;

                //将uvOffset根据normal的变化做一个插值，仅当有压力场变化（normal有变化）的时候，uvOffset才有值
               uvOffset *= pow(saturate(1 - normalWS.y), 0.1);

                // 首先得到主摄像机空间下的深度值
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, refractUV+uvOffset).r;
                float backgroundDepth = LinearEyeDepth(depth, _ZBufferParams);//是将这个非线性的深度值转换成实际的相机空间直线距离（单位通常是米）。

                // 当前水面模型到主摄像机的深度值
                float surfaceDepth = i.screenPos.w;

                // 使用这两个值做比较，即可得到哪些部分是在水面之上，哪些是在水面之下
                float depthDifference = step(surfaceDepth , backgroundDepth);

                // 在水面之上的部分是不需要做uv偏移的
                uvOffset *= depthDifference;
                                                                                                                        
                float3 refractionColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractUV+uvOffset).rgb;
                return refractionColor;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 finalColor = 1;
                finalColor.rgb = _PoolColor.rgb;

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 lightColor = mainLight.color;
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 halfDir = normalize(lightDir + viewDir);

                // 法线信息来源于高度图，高度图来源于顶点的高度差，顶点的高度差来源于使用了压力场贴图
                // float3 normalWS = normalize(i.normal);
                float3 localnormalWS = NormalmapFromHeightmap(i.uv);
                float3 normalWS = TransformObjectToWorldNormal(localnormalWS);

                float LdotH = saturate(dot(lightDir , halfDir));
                float NdotL = saturate(dot(normalWS, lightDir));
                float NdotV = saturate(dot(normalWS, viewDir));
                float NdotH = saturate(dot(normalWS, halfDir));
                float VdotH = saturate(dot(viewDir, halfDir));
                
                float kd = 1;
                float smoothness = 0.8f;
                float perceptualRoughness = 1.0f - smoothness;
                float roughness = max(perceptualRoughness * perceptualRoughness, 0.002f);

                //直接光漫反射
                float3 disneyDiffuse = DiffuseDisney(kd,lightColor,LdotH, NdotL, NdotV, perceptualRoughness, _PoolColor.rgb);
                //直接光镜面反射
                float3 F;
                float3 directSpecular =DirectLightSpecular(NdotH,VdotH,NdotV,NdotL,roughness,0.001,_PoolColor.rgb,lightColor,F);
                //水体本身的直接光照（漫反射 + 镜面反射）
                float3 waterBase = disneyDiffuse + directSpecular;

                //折射效果（透过水看到的背景）
                float3 refractionColor = RefractionColor(i, normalWS);
                //反射效果（用扰动后的法线去偏移采样，倒影会随水波晃动）
                float3 reflectionColor = ReflectionColor(i, normalWS);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float backgroundDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float surfaceDepth = i.screenPos.w; // 当前水面像素的线性深度
                float waterThickness = max(backgroundDepth - surfaceDepth, 0.0);

                //折射+waterBase:
                finalColor.rgb = lerp(refractionColor, waterBase, saturate(waterThickness * _DepthDensity));

                //finalColor+反射：
                finalColor.rgb = lerp(finalColor.rgb, reflectionColor, _ReflectionStrength);

                return float4(finalColor.rgb,1);
                }
            ENDHLSL
        }
    }
}
