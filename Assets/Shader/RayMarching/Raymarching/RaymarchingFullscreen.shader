Shader "Hidden/RaymarchingFullscreen"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

            v2f vert (appdata v)
            {
                v2f o;
                float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.vertex = pos;
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                o.ndc = pos.xy;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // ndc(-1~1) -> 0~1，用它在四角之间插值
                float2 t = i.ndc * 0.5 + 0.5;

                float3 bottom = lerp(_FrustumCorners[0].xyz, _FrustumCorners[1].xyz, t.x);
                float3 top    = lerp(_FrustumCorners[3].xyz, _FrustumCorners[2].xyz, t.x);
                float3 ray    = normalize(lerp(bottom, top, t.y));

                return float4(ray, 1); // 先直接输出射线方向，方便调试
            }
            ENDHLSL
        }
    }
}
