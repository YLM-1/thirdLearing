Shader "Hidden/CloudRaymarchingFullscreen"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {

            Tags{"Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // 世界空间四角：0=左下, 1=右下, 2=右上, 3=左上
            // 已经是世界空间了，所以不用再乘 cameraToWorld
            float4x4 _FrustumCorners;

            struct appdata
            {
                uint vertexID : SV_VertexID;
            };
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CloudMap);
            SAMPLER(sampler_CloudMap);

            TEXTURE2D(_GradientTex);
            SAMPLER(sampler_GradientTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _CloudScale;
            float _CloudOpacity;
            float _CloudHeight;
            float _CloudThickness;
            float _TopSurfaceScale;
            float _BottomSurfaceScale;
            float4 _CloudSpeed;
            float4 _SkyColor;
            float4 _CloudColor;
            float _FarCloudColorAmount;
            float _NearCloudColorAmount;
            float4 _GroundColor;
            float _FarGroundColorAmount;
            float _CloudSoftness;
            float _CloudEdgeScale;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.vertex = pos;
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            float4 Raymarching(float3 ro,float3 rd)
            {
                if(rd.y>0.001)
                {
                    rd = rd/rd.y;
                    float4 c = 0;
                    const int maxStep = 32;
                    float3 position = ro + rd*(_CloudHeight - ro.y);
                    float3 t = rd/maxStep*_CloudThickness;
                    float stepOpacity = 1 - 1/(length(t)*_CloudOpacity+1);

                    //天空颜色混合
                    float farCloudColorAmount = 1-1/(length(rd)*_FarCloudColorAmount+1);
                    c = float4(_CloudColor.rgb*farCloudColorAmount,farCloudColorAmount);

                    for(int i = 0;i<maxStep;i++)
                    {
                        position += t;

                        float2 uv0 = (position.xz + _CloudSpeed.xy*_Time.y)/max(_CloudScale.xy,0.001);
                        float cloud0 = SAMPLE_TEXTURE2D(_CloudMap,sampler_CloudMap,uv0).r;

                        float2 uv1 = (position.xz+_CloudSpeed.zw*_Time.y)/max(_CloudScale.zw,0.001);
                        float cloud1 = SAMPLE_TEXTURE2D(_CloudMap,sampler_CloudMap,uv1).r;

                        float f = (position.y - _CloudHeight)/_CloudThickness;

                        float cloudTopHeight = saturate(cloud0*_TopSurfaceScale + cloud1*_CloudEdgeScale);
                        float cloudBottomHeight = saturate(cloud0*_BottomSurfaceScale + cloud1*_CloudEdgeScale);

                        if(f>cloudBottomHeight&&f<cloudTopHeight)
                        {
                            float distanceToSurface = min(cloudTopHeight - f,f - cloudBottomHeight);
                            float localOpacity = saturate(distanceToSurface/_CloudSoftness);

                            float cloudTopHeightSmooth = 1 - cloud0 * _TopSurfaceScale;
                            float cloudDarkness = 1 - saturate(cloudTopHeightSmooth - f);
                            float4 gradientColor = SAMPLE_TEXTURE2D(_GradientTex,sampler_GradientTex,float2(cloudDarkness,0));
                            c +=(1-c.a)*localOpacity*stepOpacity*gradientColor;
                        }

                        if(c.a>0.99)
                          break;
                    }
                    //天空云的混合
                    float nearCloudColorAmount = 1 - (1 / (_NearCloudColorAmount * length(rd) + 1));
                    float4 totalSkyColor = lerp(_SkyColor, _CloudColor, nearCloudColorAmount);
                    c += (1-c.a)*totalSkyColor;
                    return c;
                }
                else
                {
                    rd = rd/rd.y;
                    float farGroundAmount = 1 - 1/(length(rd)*_FarGroundColorAmount+1);
                    float4 groundColor = lerp(_GroundColor,_CloudColor,farGroundAmount);
                    return groundColor;
                }
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 t = i.uv;
                float3 bottom = lerp(_FrustumCorners[0].xyz, _FrustumCorners[1].xyz, t.x);
                float3 top    = lerp(_FrustumCorners[3].xyz, _FrustumCorners[2].xyz, t.x);
                float3 ray = normalize(lerp(bottom, top, t.y));

                float3 ro = _WorldSpaceCameraPos.xyz;

                float4 rayMarchingColor = Raymarching(ro,ray);

                return rayMarchingColor;
            }
            ENDHLSL
        }
    }
}
