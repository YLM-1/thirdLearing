Shader "Unlit/castShadow"
{
    Properties
    {
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
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 depth : TEXCOORD0;
            };

            float4x4 _MyCustomLightSpaceMatrix;

            float4 EncodeFloatRGBA(float val)
            {
                float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
                float kEncodeBit = 1.0 / 255.0;
                float4 enc = kEncodeMul * val;
                enc = frac(enc);
                enc -= enc.yzww * kEncodeBit;
                return enc;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float4 worldPos = mul(UNITY_MATRIX_M, v.vertex);
                o.pos = mul(_MyCustomLightSpaceMatrix,worldPos);
                o.depth = o.pos.zw;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth = i.depth.x / i.depth.y;

                #if defined(SHADER_TARGET_GLSL)
                    depth = depth * 0.5 + 0.5;
                #elif defined(UNITY_REVERSED_Z)
                    depth = 1.0 - depth;
                #endif
                
                float4 col=EncodeFloatRGBA(depth);
                return col;
            }
            ENDHLSL
        }
    }
}
