Shader "Unlit/Grass1.0"
{
    Properties
    {
        [Header(Shape)]
        _Height("Height", Float) = 1
        _Width("Width", Float) = 1
        _Forward("Forward", Float) = 1
        _Curve("Curve", Float)=2

        [Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (1,1,1,1)
        _Varation("Varation", Range(0,0.1)) = 0.02
        _VarationColor("Varation Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag

            #define PI 3.1415926
            #define _GRASS_SEGMENT 3

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float3 normal :TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float varation : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Height;
                float _Width;
                float _Forward;
                float _Curve;

                float4 _TopColor;
                float4 _BottomColor;
                float _Varation;
                float4 _VarationColor;
            CBUFFER_END    

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.uv = v.uv;
                return o;
            }

            //随机数的生成
            float Random(float3 pos)
            {
                return frac(sin(dot(pos,float3(12.9898,78.233,45.1643)))*43758.5453);
            }

            g2f VertexOutPut(float3 originPos,float3 pos,float3 normal,float2 uv,float3x3 mat)
            {
                g2f o;
                float3 p =mul(mat,pos);
                float3 position = originPos+p;
                o.pos = TransformObjectToHClip(position);
                o.posWS = TransformObjectToWorld(position);
                o.normal = TransformObjectToWorldNormal(mul(mat,normal));
                o.uv = uv;
                o.varation = Random(originPos);
                return o;
            }

            //旋转
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

            [maxvertexcount(_GRASS_SEGMENT*2+1)]
            void geo(triangle v2g IN[3],inout TriangleStream<g2f> triStream)
            {
                g2f o;
                float3 pos = IN[0].vertex.xyz;

                //构建TBN矩阵
                float3 normal = IN[0].normal;
                float4 tangent = IN[0].tangent;
                float3 binormal = cross(normal,tangent)*tangent.w;
                float3x3 TBN = transpose(float3x3(tangent.xyz,binormal,normal));

                float width = _Width;
                float height = _Height;
                float forward = _Forward;

                //随机方向
                float3x3 fracingRotationMat = _angleAxis3x3(Random(pos.xyz)*2*PI,float3(0,0,1));
                float3x3 facingMat=mul(TBN,fracingRotationMat);

                //随机弯曲
                float3x3 randomRotationMat = _angleAxis3x3(Random(pos.yzx)*0.5*PI,float3(1,0,0));
                float3x3 mat=mul(facingMat,randomRotationMat);

                for(int i=0;i<_GRASS_SEGMENT;i++)
                {
                    float t=i/(float)_GRASS_SEGMENT;
                    float w=(i==0)?width/1.5:width*(1-t);
                    float h=height*t;
                    float f=pow(forward,_Curve)*t;

                    float3x3 currentMat=(i==0)?facingMat:mat;
                    triStream.Append(VertexOutPut(pos,float3(-w,f,h),float3(0,-1,f),float2(0,t),currentMat));
                    triStream.Append(VertexOutPut(pos,float3(w,f,h),float3(0,-1,f),float2(1,t),currentMat));
                }
                triStream.Append(VertexOutPut(pos,float3(width,forward,height),float3(0,-1,forward),float2(0.5,1),mat));
            }

            float4 frag (g2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir=normalize(light.direction);
                float3 lightColor=light.color;
                float3 worldNormal=normalize(i.normal);
                float3 viewDir=normalize(_WorldSpaceCameraPos-i.posWS.xyz);

                //lambert
                float NdotL=saturate(dot(worldNormal,lightDir)+1.29);
                float4 col=lerp(_BottomColor,_TopColor,i.uv.y);

                //Specular
                float3 halfDir=normalize(lightDir+viewDir);
                float NdotH=saturate(dot(worldNormal,halfDir));
                float specular=pow(NdotH,5)*1.16;

                lightColor=(NdotL*lightColor+specular);

                float varation=step(i.varation,_Varation);
                col.rgb=lerp(col.rgb,_VarationColor.rgb,_VarationColor.a*varation)*lightColor;
            
                return col;
            }
            ENDHLSL
        }
    }
}
