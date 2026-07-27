Shader "Unlit/PBR"
{
    Properties
    {
        _MainTex("Texture", 2D)="white"{}
        _Tint("Tint",Color)=(1,1,1,1)
        [Gamma]_Metallic("Metallic",Range(0,1))=0
        _Smoothness("Smoothness(Metallic.a)",Range(0,1))=0.6
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="UniversalForward"}
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define PI 3.14159265359

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"   //DecodeHDR
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal:TEXCOORD1;
                float3 worldPos:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _Tint;
            float _Metallic;
            float _Smoothness;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float3 FresnelLerp(float3 F0, float3 grazingTerm, float NdotV)
            {
              float x = pow(1.0 - NdotV, 5.0);
              return lerp(F0, grazingTerm, x);
            }

            float3 DiffuseDisney(float LdotH,float NdotL,float NdotV,float perceptualRoughness,float3 albedo)
            {
                float Fd90 = 0.5+2*LdotH*LdotH*perceptualRoughness;
                float lightScatter = 1+(Fd90-1)*pow(1-NdotL,5);
                float viewScatter = 1+(Fd90-1)*pow(1-NdotV,5);
                float3 disneyDiffuse = lightScatter*viewScatter*albedo/PI;
                return disneyDiffuse;
            }

            //直接光漫反射
            float3 DirectLightDiffuse(float kd,float3 albedo,float3 lightColor,float perceptualRoughness,float NdotV,float NdotL,float LdotH)
            {
                // Disney模型
                //kd 是漫反射的权重系数，用来控制"漫反射部分在最终光照中占多少比例"，核心作用是配合金属度实现能量守恒
                float3 disneyDiffuse = DiffuseDisney(LdotH, NdotL, NdotV, perceptualRoughness, albedo);
                float3 result = kd * disneyDiffuse *NdotL* lightColor;
                return result;
            }

            //间接光漫反射
            float3 IndirectLightDiffuse(float kd,float3 albedo,float3 worldNormal)
            {
                float3 ambient=SampleSH(worldNormal);
                float3 result=kd*ambient*albedo;
                return result;
            }

            //直接光镜面反射
            float3 DirectLightSpecular(float NdotH,float VdotH,float NdotV,float NdotL,float roughness,float metallic,float3 albedo,float3 lightColor)
            {
                //D项（GGX模型）:法线分布函数
                float D=D_GGX(NdotH,roughness);

                //F项（Schlick模型）:菲尼尔项
                float3 F0=lerp(kDielectricSpec.rgb,albedo,metallic);//反射系数,kDielectricSpec.rgb=float3(0.04,0.04,0.04)
                float3 F=F_Schlick(F0,VdotH);
                // float3 F=F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);

                //G项（Smith模型）:几何遮蔽函数,V_SmithJointGGX 内部返回的是 G / (4·NdotL·NdotV)
                float G=V_SmithJointGGX(NdotL,NdotV,roughness);

                float3 result=D*F*G*NdotL*lightColor*PI;
                return result;
            }

            //间接光镜面反射
            float3 IndirectLightSpecular(float kd,float perceptualRoughness,float roughness,float NdotV,float3 worldNormal,float3 viewDir,float3 albedo,float metallic)
            {
                //使用粗糙度来采样CubeMap
                //Unity的粗糙度和采样的mipMap不是线性的要转换
                //*6是为了映射层级，从0-1映射到0-6层级
                float mip_roughness=perceptualRoughness*(1.7-0.7*perceptualRoughness)*6;

                float3 reflectDir=reflect(-viewDir,worldNormal);
                float4 rgbm=SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,reflectDir,mip_roughness);
                float3 specular=DecodeHDREnvironment(rgbm,unity_SpecCube0_HDR);
                // return specular;

                //使用SufaceReduction来拟合间接光照在粗糙物体上过亮的问题
                //unity使用拟合函数来查找
                float surfaceReduction=1.0/(roughness*roughness+1);
                float oneMinusReflectivity=kd;

                //unity 考虑掠射镜面反射 
                float grazingTerm=saturate(_Smoothness+(1-oneMinusReflectivity));
                float3 F0=lerp(0.04,albedo,metallic);//反射系数
                float3 fresnelTerm= FresnelLerp(F0,grazingTerm,NdotV);

                float3 result=specular*surfaceReduction*fresnelTerm;
                return result;
            }


            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv =v.uv;
                o.normal=TransformObjectToWorldNormal(v.normal);
                o.worldPos=TransformObjectToWorld(v.vertex);
                return o;
            }     

            float4 frag (v2f i) : SV_Target
            {
                //参数准备
                Light light=GetMainLight();
                float attenuation=light.distanceAttenuation*light.shadowAttenuation;
                float3 lightColor=light.color*attenuation;
                float3 lightDir=normalize(light.direction);
                
                float3 worldNormal=normalize(i.normal);
                float3 viewDir=normalize(_WorldSpaceCameraPos.xyz-i.worldPos);
                float3 halfDir=normalize(lightDir+viewDir);

                float NdotV=saturate(dot(worldNormal,viewDir));
                float NdotL=saturate(dot(worldNormal,lightDir));
                float LdotH=saturate(dot(halfDir,lightDir));
                float VdotH=saturate(dot(viewDir,halfDir));
                float NdotH=saturate(dot(worldNormal,halfDir));

                float perceptualRoughness=1-_Smoothness;
                float roughness=perceptualRoughness*perceptualRoughness;
                roughness=max(roughness,0.002);//避免除0

                float kd=1.0 - lerp(0.04, 1.0, _Metallic);//简化版（1-Metallic）认为绝缘体材的kd为1，金属材质的kd为0太绝对了;
                float3 albedo=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)*_Tint.rgb;

                float3 directLightColor=DirectLightDiffuse(kd,albedo,lightColor,perceptualRoughness,NdotV,NdotL,LdotH)+DirectLightSpecular(NdotH,VdotH,NdotV,NdotL,roughness,_Metallic,albedo,lightColor);
                float3 indirectLiightColor=IndirectLightDiffuse(kd,albedo,worldNormal)+IndirectLightSpecular(kd,perceptualRoughness,roughness,NdotV,worldNormal,viewDir,albedo,_Metallic);
              
                //float3 finalColor=DirectLightSpecular(NdotH,VdotH,NdotV,NdotL,roughness,_Metallic,albedo,lightColor);
                float3 finalColor=directLightColor+indirectLiightColor;
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
