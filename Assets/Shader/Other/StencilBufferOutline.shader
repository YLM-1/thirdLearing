Shader "Unlit/StencilBufferOutline"
{
    Properties
    {
        _Color("Color", Color)=(1,1,1,1)
        _Edge("Edge", Range(0,1))=0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Name "CelShading"
            Tags { "LightMode" = "UniversalForward" }

            Stencil
            {
                Ref 1
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normalOS:NORMAL; 
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normalWS:TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 normal = normalize(i.normalWS);
                float3 lightDir =normalize(light.direction);
                float lambert=dot(normal,lightDir)*0.5+0.5;
                return lambert;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags{"LightMode"="SRPDefaultUnlit"}
            Cull Front

            Stencil
            {
                Ref 1
                Comp NotEqual
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normalOS:NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Edge;
            float4 _Color;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                float3 posWS = TransformObjectToWorld(v.vertex.xyz);
                float3 posVS = TransformWorldToView(posWS);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                float3 normalVS = TransformWorldToViewDir(normalWS);
                normalVS.z = -0.5;
                posVS += normalVS * _Edge;
                o.vertex = mul(GetViewToHClipMatrix(), float4(posVS, 1.0));
                return o;
            }

            float4 frag () : SV_Target
            {
                return _Color;
            }
            ENDHLSL

        }
    }
}