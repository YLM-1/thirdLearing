Shader "Unlit/AntialiasedCelShading"
{
    Properties
    {
        _OutLineWidth("Outline Width", Range(0, 0.1)) = 0.01
        _Color("Color", Color)=(1,1,1,1)
        _SpecularPower("Specular Power", Range(0, 100)) = 10
        _SpecularIntensity("Specular Intensity", Range(0, 2)) = 1
        _SpecularSegment("Specular Segment", Range(0,1))=0.5
        _DiffuseSegment("Diffuse Segment", Vector)=(0.1,0.3,0.6,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        // --- 1. 正常渲染身体的 Pass (挪到前面，让 URP 作为主 pass 渲染) ---
        Pass
        {
            Name "CelShading"
            Tags { "LightMode"="UniversalForward" } // 核心：告诉 URP 这是前向渲染的主体

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS:TEXCOORD0;
                float3 posWS:TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _DiffuseSegment;
                float _SpecularPower;
                float _SpecularIntensity;
                float _SpecularSegment;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                o.posWS=TransformObjectToWorld(v.vertex.xyz);
                o.normalWS=TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light=GetMainLight();
                float3 lightDir=normalize(light.direction);
                float3 normalWS=normalize(i.normalWS);

                float3 viewDir=normalize(_WorldSpaceCameraPos.xyz-i.posWS.xyz);
                float3 H=normalize(lightDir+viewDir);

                //half_lambert
                float NdotL=dot(normalWS,lightDir)*0.5+0.5;

                float _f=fwidth(NdotL)*0.5; //fwidth()当前这个像素，和它周围的像素相比，变化得有多剧烈

                if(NdotL<_DiffuseSegment.x+_f)
                     NdotL=lerp(_DiffuseSegment.x,_DiffuseSegment.y,smoothstep(_DiffuseSegment.x-_f,_DiffuseSegment.x+_f,NdotL));
                else if(NdotL<_DiffuseSegment.y+_f)
                     NdotL=lerp(_DiffuseSegment.y,_DiffuseSegment.z,smoothstep(_DiffuseSegment.y-_f,_DiffuseSegment.y+_f,NdotL));
                else if(NdotL<_DiffuseSegment.z+_f)
                     NdotL=lerp(_DiffuseSegment.z,_DiffuseSegment.w,smoothstep(_DiffuseSegment.z-_f,_DiffuseSegment.z+_f,NdotL));
                else 
                     NdotL=_DiffuseSegment.w;

               //Specular
               float NdotH=saturate(dot(normalWS,H));
               float spec=pow(NdotH,_SpecularPower)*_SpecularIntensity;

               _f=fwidth(spec)*2;
               if(spec<_SpecularSegment+_f)
                   spec=lerp(0,1,smoothstep(_SpecularSegment-_f,_SpecularSegment+_f,spec));
               else
                   spec=1;
               float4 finalColor=_Color*NdotL+spec;
               return finalColor; 
            }
            ENDHLSL
        }

        // --- 2. 描边 Pass ---
        Pass
        {
            Name "Outline"
            Cull Front
            Tags { "LightMode"="SRPDefaultUnlit" } // 核心：利用未标记物体的默认光照通道渲染描边

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float _OutLineWidth;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                //Object Space
                // float3 posOS = v.vertex.xyz + v.normal * _OutLineWidth;
                // o.positionCS = TransformObjectToHClip(posOS);

                //View Space
                // float3 posWS=TransformObjectToWorld(v.vertex.xyz);
                // float3 posVS=TransformWorldToView(posWS);
                
                // float3 normalWS=TransformObjectToWorldNormal(v.normal);
                // float3 normalVS=TransformWorldToViewDir(normalWS);
                // normalVS.z=-0.5; // 强行让法线朝向摄像机方向偏移，防止侧面或刁钻角度时描边断裂

                // posVS+=normalVS*_OutLineWidth;
                // o.positionCS = mul(GetViewToHClipMatrix(), float4(posVS, 1.0));

                //Clip Space
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                float3 normalWS=TransformObjectToWorldNormal(v.normal);
                float3 normalCS=mul((float3x3)GetWorldToHClipMatrix(), normalWS);

                float2 offset=normalize(normalCS.xy);
                o.positionCS.xy+=offset*_OutLineWidth*o.positionCS.w;
                return o;
            }

            float4 frag () : SV_Target
            {
                return float4(0, 0, 0, 1); // 描边是纯黑色
            }
            ENDHLSL
        }
    }
}