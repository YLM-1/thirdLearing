Shader "Unlit/Grass"
{
    Properties
    {
        [Header(Grass)]
        _Height("Height",Range(0,0.5))=0.07
        _HeightRandom("Height Random",Range(0,0.5))=0.05

        _Width("Width",Range(0,0.1))=0.02
        _WidthRandom("Width Random",Range(0,0.1))=0.05

        _Forward("Forward",Range(0,1))=0.5
        _ForwardRandom("Forward Random",Range(0,0.5))=0.2
        _Curve("Curve",Range(0,5))=3

        _RotationRandom("Rotation Random",Range(0,1))=0.2
        _BlendingRandom("Blending Random",Range(0,1))=0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag

            #define _GRASS_SEGMENTS 3 //定义草叶垂直方向的细分段数
            #define PI 3.14159265

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct g2f
            {
                float4 pos:SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Height;
            float _Width;
            float _Forward;
            float _ForwardRandom;
            float _Curve;
            float _HeightRandom;
            float _WidthRandom;
            float _RotationRandom;
            float _BlendingRandom;
            CBUFFER_END

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.normal = v.normal;
                o.tangent = v.tangent;
                return o;
            }

            // angle: 弧度制的角度
            // axis: 旋转所绕的轴
            // 类似 c# Quaternion.AngleAxis
            float3x3 _angleAxis3x3(float angle, float3 axis)
	        {
		        float c, s;
		        sincos(angle, s, c);

		        float t = 1 - c;
		        float x = axis.x;
		        float y = axis.y;
		        float z = axis.z;

		        return float3x3(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c
               );
	        }

            float RandomValue(float3 pos)
            {
                return frac(sin(dot(pos,float3(12.9898,78.233,45.1643)))*43758.5453);
            }

            g2f VertexOutPut(float3 origPos,float3 pos,float3x3 mat)
            {
                g2f o;
                float3 p=mul(mat,pos);
                o.pos = TransformObjectToHClip(origPos+p);
                return o;
            }
            
            [maxvertexcount(_GRASS_SEGMENTS*2+1)]//单次执行最多会输出多少个顶点。
            void geo(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
            {
                g2f o;

                //每个顶点的位置绘制一个三角形
                float3 pos = IN[0].vertex;

                //定义每个草的模型的切线空间
                float3 normal = IN[0].normal;
                float4 tangent = IN[0].tangent;
                float3 binormal = cross(normal, tangent.xyz)*tangent.w;
                float3x3 TBN = float3x3(tangent.x, binormal.x, normal.x,
                                        tangent.y, binormal.y, normal.y,
                                        tangent.z, binormal.z, normal.z);

                //随机方向
                float3x3 fracingRotationMat = _angleAxis3x3(RandomValue(pos)*2*PI*_RotationRandom,float3(0,0,1));
                float3x3 facingMat = mul(TBN,fracingRotationMat);

                //随机弯曲
                float3x3 bendingRotationMat = _angleAxis3x3(RandomValue(pos.zxy)*0.5*PI*_BlendingRandom,float3(1,0,0));
                float3x3 mat = mul(facingMat,bendingRotationMat);

                //增加草模型的细分
                //计算高度和宽度
                float height = _Height + RandomValue(pos.yzx)*_HeightRandom;
                float width  = _Width  + RandomValue(pos.zxy)*_WidthRandom;
                float forward = _Forward + RandomValue(pos.xzy)*_ForwardRandom;

                for(int i=0;i<_GRASS_SEGMENTS;++i)
                {
                    float t=i/(float)_GRASS_SEGMENTS;
                    float h=height*t;
                    float w=i==0?width/1.5:width*(1-t);
                    float f=pow(t,_Curve)*forward;
                    float3x3 currentMat = (i == 0) ? facingMat : mat;
                    triStream.Append(VertexOutPut(pos,float3(w,f,h),currentMat));
                    triStream.Append(VertexOutPut(pos,float3(-w,f,h),currentMat));
                }
                triStream.Append(VertexOutPut(pos,float3(0,forward,height),mat));
            }

            float4 frag (g2f i) : SV_Target
            {
                return 1;
            }
            ENDHLSL
        }
    }
}
