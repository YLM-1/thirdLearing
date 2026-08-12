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
            CBUFFER_END

            TEXTURE2D(_CloudTex);
            SAMPLER(sampler_CloudTex);

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
                        float cloudTopHeight=cloud0*_TopSurfaceScale+cloud1;
                        float cloudBottomHeight=cloud0*_BottomSurfaceScale+cloud2;

                        float f=(position.y-_CloudHeight)/_CloudThickness;

                        if(f>cloudBottomHeight&&f<cloudTopHeight)
                        {
                            float distanceToSurface = min(f-cloudBottomHeight,cloudTopHeight-f);
                            float localOpacity = saturate(distanceToSurface);

                            c+=localOpacity*stepOpacity;
                            if(c.a>0.99)
                               break;
                        }

                    }
                    return c;
                }
                else
                {
                    return 0;
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
