Shader "Unlit/Chapter4_3_instance"
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //第一步：shader增加变体可以支持instance
            #pragma multi_compile_instancing

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;

                // 第二步：instanceID 加入顶点着色器的输入结构
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD0;

                 // 第三步：instanceID 加入顶点着色器的输出结构
                 UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            v2f vert (appdata v)
            {
                v2f o;

                // 第四步：instanceID在顶点着色器的相关设置
                UNITY_SETUP_INSTANCE_ID(v);
                // 第五步：传递数据到片元着色器
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {

                // 第四步：instanceID在片元着色器的相关设置
                UNITY_SETUP_INSTANCE_ID(i);
                
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 normalWS = normalize(i.normalWS);

                //lambert
                float NdotL = dot(normalWS,lightDir);

                return NdotL;
            }
            ENDHLSL
        }
    }
}
