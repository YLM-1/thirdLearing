Shader "Unlit/Ifelse"
{
    Properties
    {
        _ReampNumber("Reamp Number", Range(1,10)) = 3
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos:TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            float _ReampNumber;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex=TransformObjectToHClip(v.vertex.xyz);
                o.uv=v.uv;
                o.worldPos=TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float RampColor(float x)
            {
                return floor(x*_ReampNumber)/(_ReampNumber-1);
            }

            float Equal(float x,float y)
            {
                return 1-abs(sign(x-y));
            }

            float NotEqual(float x,float y)
            {
                return abs(sign(x-y));
            }

            //大于
            float Greater(float x,float y)
            {
                return max(sign(x-y),0);
            }

            //小于
            float Less(float x,float y)
            {
                return max(sign(y-x),0);
            }

            //大于等于:不小于
            float GreaterEqual(float x,float y)
            {
                return 1-Less(x,y);
            }

            //小于等于：不大于
            float LessEqual(float x,float y)
            {
                return 1-Greater(x,y);
            }

            //逻辑与
            float Add(float x,float y)
            {
                return Greater(x*y,0);
            }
            
            //逻辑或
            float Or(float x,float y)
            {
                return min(x+y,1);
            }

            float3 Branch(float3 falseValue,float3 trueValue,float condition)
            {
                return lerp(falseValue,trueValue,condition);
            }

            float3 StripColor(float y)
            {
                y=frac(y);
                float3 col=0;
                // if(Add(GreaterEqual(y,0),LessEqual(y,0.5)))
                //     col=float3(1,0,0);
                // else
                //     col=float3(0,1,0);

                col=Branch(float3(0,1,0),float3(1,0,0),Add(GreaterEqual(y,0),LessEqual(y,0.5)));
                return col;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 col=StripColor(i.worldPos.y);
                return float4(col,1);
            }
            ENDHLSL
        }
    }
}
