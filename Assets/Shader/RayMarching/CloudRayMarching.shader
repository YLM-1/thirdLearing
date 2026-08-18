Shader "Hidden/CloudRayMarching"
{
    Properties
    {
        [Header(Shape)]
        _CloudTex ("CloudTex", 2D) = "white"{}
        _CloudScale("CloudScale", Vector) = (20000,20000,20000,20000)
        _CloudOpacity("Cloud Opacity", Range(0,0.1))=0.01

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
        _NearCloudColorAmount("Far Cloud Color Amount", Range(0,1))=0.5

        [Header(Ground)]
        _GroundColor("Ground Color", Color) = (1,1,1,1)
        _GroundColorAmount("Ground Color Amount", Range(0,0.1))=0.01

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
            CBUFFER_END

            TEXTURE2D(_CloudTex);
            SAMPLER(sampler_CloudTex);

            TEXTURE2D(_GradientTex);
            SAMPLER(sampler_GradientTex);

            float4 raymarching(float3 ro,float3 rd)
            {
                if(rd.y>=0)
                {
                    rd = rd/rd.y;
                    float4 c = 0;//颜色
                    float maxStep=64;
                    float3 position = ro + rd * (_CloudHeight-ro.y);
                    float3 t=rd*_CloudThickness/maxStep;
                    float stepOpacity=_CloudOpacity;
                    stepOpacity=1-1/(_CloudOpacity*length(t)+1);

                    //和天空颜色的混合
                    float farCloudColorAmount=1-1/(_FarCloudColorAmount*length(rd)+1);
                    c=float4(_CloudColor.rgb*farCloudColorAmount,farCloudColorAmount);
                    
                    for(int i=0;i<maxStep;i++)
                    {
                        position+=t;

                        float2 uv0 = (position.xz+_CloudSpeed*_Time.y)/_CloudScale.xy;
                        float cloud0 = SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, uv0).r*stepOpacity;

                        float2 uv1=(position.xz+_CloudSpeed*_Time.y)/_CloudScale.zw;
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
                            float localOpacity = saturate(distanceToSurface)/_CloudSoftness;

                            //添加渐变
                            float cloudToHeightSmooth=1-cloud0*_TopSurfaceScale;
                            float cloudDarkness=1-saturate(cloudToHeightSmooth-f);
                            float4 gradientColor=SAMPLE_TEXTURE2D(_GradientTex, sampler_GradientTex, float2(cloudDarkness,0));

                            c += (1 - c.a) * stepOpacity * localOpacity * gradientColor;

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
