Shader "Hidden/CloudRayMarching"
{
    Properties
    {
        [Header(Shape)]
        _CloudTex ("CloudTex", 2D) = "white"{}
        _CloudScale("CloudScale", Vector) = (20000,20000,20000,20000)
        _CloudOpacity("Cloud Opacity", Range(0,0.1))=0.01

        [Header(Shape Detail)]
        _ShapeScale("Shape Scale", Float) = 6
        _Coverage("Coverage", Range(0,1)) = 0.48
        _CoverageSoftness("Coverage Softness", Range(0.001,1)) = 0.12
        _DetailAmount("Detail Amount", Range(0,1)) = 0.5

        [Header(Height)]
        _CloudHeight("Cloud Height", Float)=1000
        _CloudThickness("Cloud Thickness", Float)=600
        _TopSurfaceScale("Top Surface Scale", Float) = 2.5
        _BottomSurfaceScale("Bottom Surface Scale", Float) = 0.6

        [Header(Animation)]
        _CloudSpeed("Cloud Speed", Float) = 100

        [Header(Color)]
        _SkyColor("Sky Color", Color) = (1,1,1,1)
        _CloudColor("Cloud Color", Color) = (1,1,1,1)
        _FarCloudColorAmount("Far Cloud Color Amount", Range(0,1))=0.5
        _NearCloudColorAmount("Near Cloud Color Amount", Range(0,1))=0.5

        [Header(Ground)]
        _GroundColor("Ground Color", Color) = (1,1,1,1)
        _GroundColorAmount("Ground Color Amount", Range(0,0.1))=0.01

        [Header(Distance)]
        _MaxStepLength("Max Step Length", Float) = 40
        _DistanceFalloff("Distance Falloff", Float) = 0.00002

        [Header(Gradient)]
        _CloudEdgeScale("Cloud Edge Scale", Range(0,1)) = 0.5
        _CloudSoftness("Cloud Softness", Range(0,1))=0.5
        _GradientTex("GradientTex", 2D)="white"{}
    }
    SubShader
    {
        Cull Off ZWrite Off 
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.ray = v.vertex.xyz;

                return o;
            }

            CBUFFER_START(UnityPerMaterial)
            float4 _CloudScale;
            float _CloudOpacity;
            float _CloudHeight;
            float _CloudThickness;
            float _TopSurfaceScale;
            float _BottomSurfaceScale;
            float _CloudSpeed;
            float4 _SkyColor;
            float4 _CloudColor;
            float _FarCloudColorAmount;
            float _NearCloudColorAmount;
            float4 _GroundColor;
            float _CloudEdgeScale;
            float _GroundColorAmount;
            float _CloudSoftness;
            float _ShapeScale;
            float _Coverage;
            float _CoverageSoftness;
            float _DetailAmount;
            float _MaxStepLength;
            float _DistanceFalloff;
            CBUFFER_END

            TEXTURE2D(_CloudTex);
            SAMPLER(sampler_CloudTex);

            TEXTURE2D(_GradientTex);
            SAMPLER(sampler_GradientTex);

            float4 raymarching(float3 ro,float3 rd)
            {
                if(rd.y>0.001)
                {
                    rd = rd/rd.y;
                    float4 c = 0;//颜色
                    float maxStep=64;
                    float3 position = ro + rd * (_CloudHeight-ro.y);
                    float3 t=rd*_CloudThickness/maxStep;
                    //限制单步长度：掠射角下 length(t)远处几步就糊满
                    float stepLength=min(length(t),_MaxStepLength);
                    float stepOpacity=(_CloudOpacity * stepLength)/ (1 + _CloudOpacity * stepLength);

                    //和天空颜色的混合
                    float farCloudColorAmount=1-1/(_FarCloudColorAmount*length(rd)+1);
                    c=float4(_CloudColor.rgb*farCloudColorAmount,farCloudColorAmount);
                    
                    for(int i=0;i<maxStep;i++)
                    {
                        position+=t;

                        float2 uv0 = saturate((position.xz+_CloudSpeed*_Time.y)/_CloudScale.xy);
                        float detail = SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, uv0).r;

                        //大尺度形状：同一张噪声放大 _ShapeScale 倍，形成成片的云和晴空
                        float2 shapeUV = (position.xz+_CloudSpeed*_Time.y)/(_CloudScale.xy*max(_ShapeScale,0.001));
                        float shape = SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, shapeUV).r;

                        //细节只做轻微扰动，避免破坏覆盖率
                        float density = shape + shape*(detail-0.5)*_DetailAmount;
                  
                        //覆盖率：低于阈值的区域直接是晴空
                        float cloud0 = smoothstep(_Coverage,_Coverage+max(_CoverageSoftness,1e-4),density);

                        float2 uv1=saturate((position.xz+_CloudSpeed*_Time.y)/_CloudScale.zw);
                        float2 uv2=uv1;
                        uv2.y+=0.5;

                        float cloud1=SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, uv1).r;
                        float cloud2=SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, uv2).r;

                        //控制云层的顶部和底部
                        float cloudTopHeight=cloud0*_TopSurfaceScale+cloud1*_CloudEdgeScale;
                        float cloudBottomHeight=cloud0*_BottomSurfaceScale+cloud2*_CloudEdgeScale;

                        float f=(position.y-_CloudHeight)/_CloudThickness;

                        if(f>cloudBottomHeight&&f<cloudTopHeight)
                        {
                            float distanceToSurface = min(f-cloudBottomHeight,cloudTopHeight-f);
                            float localOpacity = saturate(distanceToSurface/_CloudSoftness);

                            //添加渐变：云底=0(暗) → 云顶=1(亮)
                            float localThickness=max(cloudTopHeight-cloudBottomHeight,0.001);
                            float height01=saturate((f-cloudBottomHeight)/localThickness);
                            float4 gradientColor=SAMPLE_TEXTURE2D(_GradientTex, sampler_GradientTex, float2(height01,0));

                            //距离衰减：远处的云淡进天空色，不再越远越密
                            float distanceToCamera=length(position-ro);
                            float distanceFade=exp(-distanceToCamera*_DistanceFalloff);

                            c += (1 - c.a) * stepOpacity * localOpacity * distanceFade * gradientColor;

                            if(c.a>0.99)
                               break;
                        }

                    }

                    //最终云层和天空的混合
                    float nearCloudColorAmount=1-1/(_NearCloudColorAmount*length(rd)+1);
                    float4 totalSkyColor=lerp(_SkyColor,_CloudColor,nearCloudColorAmount);
                    c+=(1-c.a)*totalSkyColor;
                    return c;
                }
                else
                {
                    rd=rd/rd.y;
                    float groundColorAmount=1-1/(_GroundColorAmount*length(rd)+1);
                    float4 groundColor=lerp(_GroundColor,_SkyColor,groundColorAmount);
                    return groundColor;
                }
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 ro = _WorldSpaceCameraPos.xyz;
                float3 rd = normalize(i.ray);
                float4 rayMarchingColor=raymarching(ro,rd);
                return rayMarchingColor;
            }
            ENDHLSL
        }
    }
}
