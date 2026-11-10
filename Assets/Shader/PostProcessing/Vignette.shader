Shader "Hidden/Vignette"
{
    Properties
    {
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            CBUFFER_START(UnityPerMaterial)
            float4 _VignetteColor;
            float _VignettePower;
            float _VignetteIntensity;
            float _VignetteRadius;
            float _VignetteSoftness;
            CBUFFER_END

            float4 _BlitTexture_TexelSize;

            float4 frag (v2f i) : SV_Target
            {
                float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,i.uv);

                //圆形暗角
                // //宽高比矫正：让暗角是圆形而不是椭圆
                // float aspect = _BlitTexture_TexelSize.z / _BlitTexture_TexelSize.w;
                // float2 p = i.uv - 0.5;
                // if(aspect>1)
                // p.x *= aspect;
                // else
                // p.y/=aspect;
                // //归一化
                // float cornerDist = length(float2(0.5*aspect,0.5));//屏幕最右上角的坐标在矫正后是 (0.5 * aspect, 0.5)
                // float dist = length(p)/cornerDist;
                // float v = smoothstep(_VignetteRadius,_VignetteRadius + _VignetteSoftness,dist);
                // v = saturate(pow(v,_VignettePower)*_VignetteIntensity);
                // float3 color = lerp(baseColor.rgb,_VignetteColor.rgb,v);

                //矩形暗角
                float2 p = abs(i.uv - 0.5);
                float dist = max(p.x,p.y)*2;
                float v = smoothstep(_VignetteRadius,_VignetteRadius+_VignetteSoftness,dist);
                v = saturate(pow(v,_VignettePower)*_VignetteIntensity);
                float3 color = lerp(baseColor.rgb,_VignetteColor.rgb,v);
                return float4(color,baseColor.a);
            }
            ENDHLSL
        }
    }
}
