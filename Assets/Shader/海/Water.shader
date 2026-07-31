Shader "Unlit/Water"
{
    Properties
    {
        [Header(BaseColor)]
        _ShallowColor ("Shallow Color", Color) = (0.44,0.95,0.36,1)
        _DepthColor ("Depth Color", Color) = (0.0,0.05,0.19,1)
        _DepthDensity ("Depth Density", Range(0,0.1)) = 0.01

        [Header(Refraction)]
        _RefractStrength ("Refract Strength", Range(0,1)) = 0.5

        [Header(Reflection)]
        _ReflectionTex("Reflection Texture", 2D) = "black"{}
        _ReflectionStrength("Reflection Strength", Range(0,1)) = 1
        _ReflectionDistortion("Reflection Distortion", Range(0,0.1)) = 0.02

        [Header(Wave)]
        _WaveNormalMap("Wave Normal Map", 2D)="bump"{}
        _FresnelPower("Fresnel Power", Range(0,20)) = 5
        _FresnelIntensity("Fresnel Intensity", Range(0,1)) = 0.5

        [Header(Edge Foam)]
        _EdgeFoamColor("Edge Foam Color", Color) = (1,1,1,1)
        _EdgeFoamDepth("Edge Foam Intensity", Range(0,1)) = 0.25

        [Header(Foam)]
        _FoamTexture("Foam Texture", 2D) = "black"{}
        _FoamNoiseScale("Foam Noise Scale", Range(0,10)) = 1
        _FoamScale("Foam Scale", Range(0,30)) = 1

        [Header(WaveMotion)]
        _WaveNormalSpeed("Wave Normal Speed", Range(0,0.1)) = 0.05
        _WaveNormalScale("Wave Normal Scale", Range(0,100)) = 1

        _Amplitude0("Amplitude0", Range(0,100)) =1
        _Wave0Length("Wave0 Length", Range(0,100)) = 1
        _Wave0Speed("Wave0 Speed", Range(0,10)) = 1
        _Wave0Direction("Wave0 Direction", Range(0,0.5))=0.25

        _Amplitude1("Amplitude1", Range(0,100)) =1
        _Wave1Length("Wave1 Length", Range(10,30)) = 1
        _Wave1Speed("Wave1 Speed", Range(0,10)) = 1
        _Wave1Direction("Wave1 Direction", Range(0,0.75))=0.5

        [Header(Sparkle)]
        _SparkleMap("Sparkle Texture", 2D) = "bump"{}
        _SparkleScale("Sparkle Scale", Float) = 75
        _SparkleSpeed("Sparkle Speed", Range(0,0.03)) = 0.025
        _SparkleColor("Sparkle Color", Color) = (1,1,1,1)
        _SparklePower("Sparkle Power", Float) = 3
        _SparkleAmplitude("Sparkle Amplitude", Float) = 0.5

        [Header(Specular)]
        _SpecularPower("Specular Power", Float) = 3
        _SpecularIntensity("Specular Intensity", Float) = 0.5

        [Header(SSS)]
        _SssColor("SSS Color", Color) = (1,1,1,1)
        _SssPower("SSS Power", Float) = 5
        _SssIntensity("SSS Intensity", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline"}
        LOD 100

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define PI 3.1415926535897932384626433832795

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent:TANGENT;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                float3 tangent:TEXCOORD2;
                float3 normal:TEXCOORD3;
                float3 binormal:TEXCOORD4;
                float3 posWS:TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _ShallowColor;
            float4 _DepthColor;
            float _DepthDensity;

            float _RefractStrength;

            float _ReflectionStrength;
            float _ReflectionDistortion;

            float _FresnelPower;
            float _FresnelIntensity;

            float4 _EdgeFoamColor;
            float _EdgeFoamDepth;

            float _Amplitude0;
            float _Wave0Length;
            float _Wave0Speed;
            float _Wave0Direction;

            float _WaveNormalSpeed;
            float _WaveNormalScale;

            float _Amplitude1;
            float _Wave1Length;
            float _Wave1Speed;
            float _Wave1Direction;

            float _SparkleScale;
            float _SparkleSpeed;
            float4 _SparkleColor;
            float _SparklePower;
            float _SparkleAmplitude;

            float _SpecularPower;
            float _SpecularIntensity;

            float4 _SssColor;
            float _SssPower;
            float _SssIntensity;

            float _FoamScale;
            float _FoamNoiseScale;
            CBUFFER_END

            TEXTURE2D(_WaveNormalMap);
            SAMPLER(sampler_WaveNormalMap);

            TEXTURE2D(_ReflectionTex);
            SAMPLER(sampler_ReflectionTex);

            TEXTURE2D(_SparkleMap);
            SAMPLER(sampler_SparkleMap);

            TEXTURE2D(_FoamTexture);
            SAMPLER(sampler_FoamTexture);

            float3 BaseColor(v2f i,float3 refractColor,float2 screenUV,out float waterDepth)
            {
                //采样场景深度
                float rawDepth=SampleSceneDepth(screenUV);
                float sceneDepth=LinearEyeDepth(rawDepth, _ZBufferParams);

                //计算水面深度
                float surfaceDepth=i.screenPos.w;

                //计算深度差
                waterDepth=abs(sceneDepth-surfaceDepth);

                float depthFactor=exp(-_DepthDensity*waterDepth);

                float3 baseColor=lerp(_DepthColor.rgb,refractColor,depthFactor);

                return baseColor;
            }

            float3 RefractColor(v2f i,out float2 screenUV,float3 normalTS)
            {
                screenUV=i.screenPos.xy/i.screenPos.w;
                float3 refract=SampleSceneColor(screenUV);//SampleSceneColor:用于采样摄像机渲染不透明的场景
                float3 refractColor=refract*_ShallowColor.rgb;
                return refractColor;
            }

            float3 PlanarReflectionColor(float2 screenUV,float3 normalTS)
            {
                float2 reflectionUV=screenUV+normalTS.xy*_ReflectionDistortion;
                reflectionUV=saturate(reflectionUV);
                return SAMPLE_TEXTURE2D(_ReflectionTex,sampler_ReflectionTex,reflectionUV).rgb;
            }

            float WaveMotion(float3 worldPos,float2 direction,float amplitude,float waveLength,float waveSpeed)
            {
                //y=a*sin(k*x+b)
                float a=amplitude;
                float k=2*PI/waveLength;
                float b=_Time.y*waveSpeed;
                float value=k*dot(worldPos.xz,direction)-b;
                worldPos.y=a*sin(value);

                return worldPos.y;
            }

            float WaveHeigh(float3 worldPos)
            {
                float2 direction0=float2(sin(_Wave0Direction),cos(_Wave0Direction));
                float h0=WaveMotion(worldPos,direction0,_Amplitude0,_Wave0Length,_Wave0Speed);

                float2 direction1=float2(sin(_Wave1Direction),cos(_Wave1Direction));
                float h1=WaveMotion(worldPos,direction1,_Amplitude1,_Wave1Length,_Wave1Speed);

                return h0+h1;
            }


            float2 Panner(float2 direction,float2 uv)
            { 
                return uv+normalize(direction)*_Time.y*_WaveNormalSpeed;
            }   

            float3 MotionWay(Texture2D tex,SamplerState samp,float2 uv,float4 scale,float type)
            {
                float2 uv0=Panner((float2(1,1)),uv*scale.x);
                float2 uv1=Panner(float2(-1,-1),(uv+float2(0.418,0.355))*scale.y);
                float2 uv2=Panner(float2(1,-1),(uv+float2(0.865,0.148))*scale.z);
                float2 uv3=Panner(float2(-1,1),(uv+float2(0.651,0.752))*scale.w);

                if(type==0)
                {
                     float3 normalTS0=UnpackNormal(SAMPLE_TEXTURE2D(tex,samp,uv0)).rgb;
                     float3 normalTS1=UnpackNormal(SAMPLE_TEXTURE2D(tex,samp,uv1)).rgb;
                     float3 normalTS2=UnpackNormal(SAMPLE_TEXTURE2D(tex,samp,uv2)).rgb;
                     float3 normalTS3=UnpackNormal(SAMPLE_TEXTURE2D(tex,samp,uv3)).rgb;

                     float3 normalTS=normalize(normalTS0+normalTS1+normalTS2+normalTS3);
                     return normalTS;
                }
                else
                {
                    float3 col=SAMPLE_TEXTURE2D(tex,samp,uv0).rgb;
                    float3 col1=SAMPLE_TEXTURE2D(tex,samp,uv1).rgb;
                    float3 col2=SAMPLE_TEXTURE2D(tex,samp,uv2).rgb;
                    float3 col3=SAMPLE_TEXTURE2D(tex,samp,uv3).rgb;
                    return (col+col1+col2+col3)/4;
                }
            }

            float3x3 TBN(float3 posWS)
            {
                float d=0.01;
                float h=WaveHeigh(posWS);
                float hx=WaveHeigh(posWS+float3(d,0,0));
                float hz=WaveHeigh(posWS+float3(0,0,d));

                float3 tangent=normalize(float3(d,hx-h,0));
                float3 binormal=normalize(float3(0,hz-h,d));
                float3 normal=normalize(cross(binormal,tangent));
                return float3x3(tangent,binormal,normal);

                // float3 tangent=float3(1,0,0);
                // float3 binormal=float3(0,0,1);
                // float3 normal=normalize(cross(binormal,tangent));
                return float3x3(tangent,binormal,normal);
            }

            float3 ReflectColor(v2f i,out float3 normalTS,out float3 reflectView,out float3 viewDirWS,out float fresnelMask)
            {
                //normalTS=UnpackNormal(SAMPLE_TEXTURE2D(_WaveNormalMap,sampler_WaveNormalMap,i.uv));
                normalTS=MotionWay(_WaveNormalMap,sampler_WaveNormalMap,i.uv*_WaveNormalScale,float4(1,1,1,1),0);//用uv来采集
                //float3x3 tbn=float3x3(i.tangent,i.binormal,i.normal);
                float3x3 tbn=TBN(i.posWS);
                float3 normalWS=normalize(mul(tbn,normalTS));

                //fresnel效果：
                viewDirWS=normalize(_WorldSpaceCameraPos-i.posWS);
                fresnelMask=pow(1-saturate(dot(normalWS,viewDirWS)),_FresnelPower)*_FresnelIntensity;

                //环境反射
                reflectView=reflect(-viewDirWS,normalWS);
                float4 Environment=SAMPLE_TEXTURECUBE(unity_SpecCube0,samplerunity_SpecCube0,reflectView);
                float3 skyColor=DecodeHDREnvironment(Environment,unity_SpecCube0_HDR);

                return skyColor;
            }

            float3 EdgeFoamColor(float waterDepth)
            {
                float3 foamColor=exp(-waterDepth*_EdgeFoamDepth)*_EdgeFoamColor.rgb;
                return foamColor;
            }

            float3 SparkleColor(v2f i)
            {
                float3 sparkle0=MotionWay(_SparkleMap,sampler_SparkleMap,i.uv*_SparkleScale,float4(1,2,3,4),0);
                float3 sparkle1=MotionWay(_SparkleMap,sampler_SparkleMap,i.uv*_SparkleScale,float4(4,3,2,1),0);
                float sparkleMask=dot(sparkle0,sparkle1)*(_SparkleAmplitude*sqrt(saturate(dot(sparkle0.x, sparkle1.x))));
                sparkleMask=pow(sparkleMask,_SparklePower);

                float3 sparkleColor=sparkleMask*_SparkleColor.rgb;

                return sparkleColor;
            }

            float3 SpecularColor(v2f i,float3 reflectView,float3 lightDir)
            {
                float mask=saturate(dot(lightDir,reflectView));//Phong模型
                mask=pow(mask,_SpecularPower)*_SpecularIntensity;
                return mask;
            }

            float3 SssColor(v2f i,float3 lightDir,float3 viewDirWS)
            {
                float mask=saturate(dot(lightDir,viewDirWS));
                mask=pow(mask,_SssPower)*_SssIntensity;
                float waveHeigh=max(0,WaveHeigh(i.posWS));
                float3 sssColor=mask*_SssColor.rgb*waveHeigh;
                return sssColor;
            }

            float3 FoamColor(v2f i,Texture2D foamTexture,SamplerState foamSample,float3 normalTS)
            {
                float2 uv=i.uv*_FoamScale+(_FoamNoiseScale*normalTS.xz);
                float3 foamColor=MotionWay(foamTexture,foamSample,i.uv*_FoamScale,float4(1,1,1,1),1);
                return foamColor;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.uv =v.uv;
                float3 worldPos=TransformObjectToWorld(v.vertex.xyz);
                worldPos.y+=WaveHeigh(worldPos);

                // // 计算 Wave0 的参数与斜率 (dy/dx0)
                // float2 dir0 = float2(sin(_Wave0Direction), cos(_Wave0Direction));
                // float k0 = 2.0 * PI / _Wave0Length;
                // float value0 = k0 * dot(worldPos.x, dir0) + _Time.y * _Wave0Speed;
                // float h0 = _Amplitude0 * sin(value0);
                // // 正弦波对位置求导：dy/d(pos) = a * k * cos(value) * dir
                // float slope0 = _Amplitude0 * k0 * cos(value0);

                // // 3. 计算 Wave1 的参数与斜率 (dy/dx1)
                // float2 dir1 = float2(sin(_Wave1Direction), cos(_Wave1Direction));
                // float k1 = 2.0 * PI / _Wave1Length;
                // float value1 = k1 * dot(worldPos.x, dir1) + _Time.y * _Wave1Speed;
                // float h1 = _Amplitude1 * sin(value1);
                // float slope1 = _Amplitude1 * k1 * cos(value1);

                // //顶点位置叠加波浪高度
                // worldPos.y+=h0+h1;
                worldPos.y+=WaveHeigh(worldPos);

                o.posWS=worldPos;
                o.vertex = TransformWorldToHClip(worldPos);
                o.screenPos = ComputeScreenPos(o.vertex);

                //叠加两层波浪在 X 和 Z 方向的切线斜率
                // float dhdx = slope0 * dir0.x + slope1 * dir1.x; // Y 随 X 的变化率
                // float dhdz = slope0 * dir0.y + slope1 * dir1.y; // Y 随 Z 的变化率

                // //构建TBN矩阵
                // o.binormal=normalize(float3(0,dhdz,1));
                // o.tangent=normalize(float3(1,dhdx,0));
                // o.normal=normalize(cross(o.binormal,o.tangent));

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 screenUV;
                float waterDepth;
                float3 reflectView;
                float3 viewDirWS;
                float3 normalTS;
                float fresnelMask;

                Light light=GetMainLight();
                float3 lightDir=normalize(light.direction);

                float3 reflectColor=ReflectColor(i,normalTS,reflectView,viewDirWS,fresnelMask);
                float3 refractColor=RefractColor(i,screenUV,normalTS);
                float3 baseColor=BaseColor(i,refractColor,screenUV,waterDepth);

                float3 edgeColor=EdgeFoamColor(waterDepth);

                float3 sparkleColor=SparkleColor(i);

                float3 specularColor=SpecularColor(i,reflectView,lightDir);

                float3 sssColor=SssColor(i,lightDir,viewDirWS);

                float3 foamColor=FoamColor(i,_FoamTexture,sampler_FoamTexture,normalTS);

                float3 planarReflectionColor=PlanarReflectionColor(screenUV,normalTS);
                reflectColor=lerp(reflectColor,planarReflectionColor,_ReflectionStrength);

                float3 finalColor=lerp(baseColor,reflectColor,saturate(fresnelMask));
                finalColor+=edgeColor+sparkleColor+specularColor+sssColor+foamColor;
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
