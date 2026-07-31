Shader "Unlit/SchlickFresnel"
{
    Properties
    {
        _RimTexture("Rim Texture",2D)="white"{}
        _RimPower("Rim Power",Range(0,10))=2
        _RimIntensity("Rim Intennsity",Range(0,5))=1
        _RimColor1("Rim Color1",Color)=(1,1,1,1)
        _RimColor2("Rim Color2",Color)=(1,1,1,1)
        _Bias("Bias",Range(0,5))=0.6
        _Eta("Eta",Range(0,5))=0.4
        _AngleMin("AngleMin",Range(0,360))=0
        _AngleMax("AngleMax",Range(0,360))=45
        _Inverse("Inverse",Range(-1,1))=1
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
            #define PI 3.14159265359

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float3 viewDir:TEXCOORD1;
                float3 worldNormal:TEXCOORD2;
                float3 viewNormal:TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
            float _RimIntensity;
            float _RimPower;
            float4 _RimColor1;
            float4 _RimColor2;
            float _Bias;
            float _Eta;
            float _AngleMin;
            float _AngleMax;
            float _Inverse;
            CBUFFER_END

            TEXTURE2D(_RimTexture);
            SAMPLER(sampler_RimTexture);

            v2f vert (appdata v)
            {
                v2f o;
                o.pos=TransformObjectToHClip(v.vertex);
                float3 worldPos=TransformObjectToWorld(v.vertex.xyz);
                o.viewDir=normalize(_WorldSpaceCameraPos.xyz-worldPos);
                o.uv=v.uv;
                o.worldNormal=TransformObjectToWorldNormal(v.normal);
                o.viewNormal=TransformWorldToViewDir(o.worldNormal);
                return o;
            }
            
            float3 BasicRimRim(float3 worldNormal,float3 viewDir)
            {
                float NdotV=saturate(dot(worldNormal,viewDir));
                float fresnel=(1-pow(NdotV,_RimPower))*_RimIntensity;
                float3 fresnelColor=fresnel*_RimColor1;
                return fresnelColor;
            }

            float Reamp(float2 range1,float2 range2,float value)
            {
                float t=value/(range1.y-range1.x);
                float b=range2.x+t*(range2.y-range2.x);
                return b;
            }

            float FuncBias(float bias,float t)
            {
                return pow(t,-log2(bias));
            }
            
            float FuncschlickFresnel(float bias,float eta,float intensity,float NdotV)
            {
                float a=Reamp(float2(0,1),float2(0,0.5),bias);
                float f0=Reamp(float2(0,1),float2(0,0.2),eta);//反射系数
                float fresnel=f0+(1-f0)*pow(1-NdotV,5);
                float schlickFresnel=FuncBias(a,fresnel)*intensity;
                return schlickFresnel;
            }

            float2 PolarCoordinate(float2 uv)
            {
                float radius=length(uv);
                float angle=atan2(uv.y,uv.x)/(PI);
                return float2(radius,angle);
            }

            float CustomLerp(float a,float b,float t)
            {
                //门控:[在a-b区间有效果]
                float gate=step(a, t) - step(b, t);
                //中点
                float mid=a+(b-a)/2;
                //上升部分
                float rise=smoothstep(a,mid,t);
                //下降部分
                float down=1-smoothstep(mid,b,t);
                // return (step(a, t) - step(b, t)) * (smoothstep(a, a + (b - a) / 2, t) * (1 - smoothstep(a + (b - a) / 2, b, t)));
                return gate*rise*down;
            }

            //计算fresnel的显示区域
            float3 SchlicFresnelSegment(float3 viewNormal,float bias,float eta,float intensity,float NdotV,float inverse)
            {
                float2 uv=float2(viewNormal.x*inverse,viewNormal.y);
                float2 p=PolarCoordinate(uv);

                float angleMin=Reamp(float2(0,360),float2(0,1),_AngleMin);
                float angleMax=Reamp(float2(0,360),float2(0,1),_AngleMax);
                float t=clamp(p.y,0,1);

                float v=CustomLerp(angleMin,angleMax,t);
                float3 fresnelColor=FuncschlickFresnel(_Bias,_Eta,_RimPower,NdotV);
                float3 fresnelSegment=fresnelColor*v*pow(p.x,2);
                return fresnelSegment;
            }

            float3 schlickFresnelSegmentColor(float3 viewNormal,float bias,float eta,float intensity,float NdotV,float inverse)
            {
                float3 color1=SchlicFresnelSegment(viewNormal,_Bias,_Eta,_RimPower,NdotV,inverse)*_RimColor1;
                float3 color2=SchlicFresnelSegment(viewNormal,_Bias,_Eta,_RimPower,NdotV,-inverse)*_RimColor2;
                return color1+color2;
            }
            
            float4 frag (v2f i) : SV_Target
            {
                float NdotV=saturate(dot(i.worldNormal,i.viewDir));
                // float3 fresnelColor=BasicRimRim(i.worldNormal,i.viewDir);     
                // float3 fresnelColor=FuncschlickFresnel(_Bias,_Eta,_RimPower,NdotV);     
                // float3 fresnel=SchlicFresnelSegment(i.viewNormal,_Bias,_Eta,_RimPower,NdotV);
                float3 fresnel=schlickFresnelSegmentColor(i.viewNormal,_Bias,_Eta,_RimPower,NdotV,_Inverse);
                return float4(fresnel,1);
            }
            ENDHLSL
        }
    }
}
