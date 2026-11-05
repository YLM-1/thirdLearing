Shader "Hidden/RaymarchingFullscreen"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
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
                uint vertexID : SV_VertexID;//SV_VertexID 是 GPU 提供的系统语义，表示当前处理的顶点编号。
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;   // 屏幕 uv，后面采样深度/贴图用
                float2 ndc : TEXCOORD1;
            };

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_ReampMap);
            SAMPLER(sampler_ReampMap);

            v2f vert (appdata v)
            {
                v2f o;
                float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.vertex = pos;
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                o.ndc = pos.xy;
                return o;
            }

            float sdSphere(float3 p,float s)
            {
                return length(p) - s;
            }

            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }

            float sdBoxFrame(float3 p, float3 b, float e)
            {
                p = abs(p) - b;
                float3 q = abs(p + e) - e;
                return min(min(
                length(max(float3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
                length(max(float3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
                length(max(float3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
            }

            //并集:要"有一个在里面就行"→ 用 min（谁在里面就听谁的，取小的）
            float2 opU(float2 d1,float2 d2)
            {
                //return min(d1,d2);
                 return d1.x < d2.x ? d1 : d2;
            }

            //相减
            float2 opS(float2 d1,float2 d2)
            {
                //return max(-d1, d2);
                return -d1.x > d2.x ? float2(-d1.x, d1.y) : d2;
            }

            //交集:"两个都在里面"→ 用 max（谁在外面就听谁的，取大的）
            float2 opI(float2 d1,float2 d2)
            {
                //return max(d1, d2);
                return d1.x > d2.x ? d1 : d2;
            }

            float2 map(float3 pos)
            {
                float sphere0 = sdSphere(pos + float3(-0.5,0,0), 1);
                float sphere1 = sdSphere(pos + float3(0.5,0,0), 1);
                float2 opUSphere = opU(float2(sphere0, 0),float2(sphere1, 0.2));
                float2 opSSphere = opS(float2(sphere1, 0.2), float2(sphere0, 0));
                float2 opISphere = opI(float2(sphere0, 0), float2(sphere1, 0.2));

                float torus = sdTorus(pos, float2(2, 0.5));

                return opUSphere;
            }

            float3 calcNormal(float3 p)
            {
                float2 exp = float2(0.001,0.0);

                float3 n = float3(map(p+exp.xyy).x - map(p-exp.xyy).x,
                                  map(p+exp.yxy).x - map(p-exp.yxy).x,
                                  map(p+exp.yyx).x - map(p-exp.yyx).x);
                return normalize(n);
            }

            float4 Raymarching(float3 ro,float3 rd,float depth)
            {
                float4 c = 0;
                float t = 0;
                const int maxStep = 64;

                for(int i = 0;i<maxStep;i++)
                {
                     //与场景中的3D物体进行遮挡关系处理
                    if(t>=depth)
                    {
                        c = 0;
                        break;
                    }
                    float3 p = ro + rd*t;

                    //d是当前点 p 到最近表面的有符号距离
                    float2 d = map(p);
                    if(d.x<0.001)
                    {
                        c = 1;

                        //光照模型的计算
                        Light light = GetMainLight();
                        //lambert
                        float3 N = calcNormal(p);
                        float3 L = normalize(light.direction.xyz);
                        float NdotL = saturate(dot(N,L));

                        //specular
                        float3 V = normalize(_WorldSpaceCameraPos.xyz - p);
                        float3 H = normalize(V + L);
                        float NdotH = saturate(dot(N,H));
                        float specular = pow(NdotH,20);

                        float3 col = NdotL + specular;
                        float u = d.y;
                        float3 colorReamp = SAMPLE_TEXTURE2D(_ReampMap,sampler_ReampMap,float2(u,0)).rgb;

                        c.rgb = col*colorReamp;
                        break;
                    }
                    t += d.x;
                }

                return c;
            } 

            float4 frag (v2f i) : SV_Target
            {
                // ndc(-1~1) -> 0~1，用它在四角之间插值
                float2 t = i.ndc * 0.5 + 0.5;

                float3 bottom = lerp(_FrustumCorners[0].xyz, _FrustumCorners[1].xyz, t.x);
                float3 top    = lerp(_FrustumCorners[3].xyz, _FrustumCorners[2].xyz, t.x);
                float3 ray    = normalize(lerp(bottom, top, t.y));

                float3 ro = _WorldSpaceCameraPos.xyz;
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.uv).r;
                depth = LinearEyeDepth(depth,_ZBufferParams);

                //eye depth 是沿相机前方的距离，除以 cos 才是沿射线的距离
                float3 camForward = normalize(_FrustumCorners[0].xyz + _FrustumCorners[1].xyz +
                                              _FrustumCorners[2].xyz + _FrustumCorners[3].xyz);
                float sceneDistance = depth / max(dot(ray, camForward), 1e-4);

                float4 rayMarchingColor = Raymarching(ro,ray,sceneDistance);
                return rayMarchingColor;

                return float4(ray, 1); // 先直接输出射线方向，方便调试
            }
            ENDHLSL
        }
    }
}
