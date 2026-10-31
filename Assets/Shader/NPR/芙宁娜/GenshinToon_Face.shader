Shader "GenshinToon/Face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map",2D)="white"{}

        [Header(Shadow Option)]
        [Toggle(_USE_SDF_SHADOW)] _UseSDFShadow("Use SDF Shadow",Range(0,1))=2
        _SDF("SDF",2D)="white"{}
        _ShadowMask("Shadow Mask",2D)="white"{}
        _ShadowColor("Shadow Color",Color)=(1,0.87,0.87,1)//阴影颜色，默认肉色

        [Header(Head Direction)]
        [HideInInspector]_HeadForward("Head Forward",Vector)=(0,0,1,0)//面部前方
        [HideInInspector]_HeadRight("Head Right",Vector)=(1,0,0,0)//面部右方
        [HideInInspector]_HeadUp("Head Forward",Vector)=(0,1,0,0)//面部上方

        [Header(Face Blush)]
        _FaceBlushColor("Face Blush Color",Color)=(1,0,0,1)
        _FaceBlushStrength("Face Blush Strength",Range(0,1))=0
    }
    SubShader
    {
      Tags{
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
          }
      HLSLINCLUDE
      #pragma multi_compile _MAIN_LIGHT_SHADOWS // 主光源阴影
      #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
      #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

      #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
      #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
      #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
      #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
      #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化
      #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION // 反射探针盒投影

      #pragma shader_feature_local _USE_SDF_SHADOW

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


      CBUFFER_START(UnityPerMaterial)
      float3 _HeadForward;
      float3 _HeadRight;
      float3 _HeadUp;

      float4 _ShadowColor;

      float4 _FaceBlushColor;
      float _FaceBlushStrength;
      CBUFFER_END

      TEXTURE2D(_BaseMap);
      SAMPLER(sampler_BaseMap);

      TEXTURE2D(_SDF);
      SAMPLER(sampler_SDF);

      TEXTURE2D(_ShadowMask);
      SAMPLER(sampler_ShadowMask);

      struct appdata
      {
          float4 vertex:POSITION;
          float2 uv0:TEXCOORD0;
          float3 normal:NORMAL;
       };

       struct v2f
       {
           float4 pos:SV_POSITION;
           float2 uv0:TEXCOORD0;
           float3 worldNormal:TEXCOORD1;
        };

      ENDHLSL


        Pass
        {
          Name "UniversalForward"
          Tags{"LightMode"="UniversalForward"}

          HLSLPROGRAM
          #pragma vertex vert
          #pragma fragment frag

          v2f vert(appdata v)
          {
              v2f o;
              o.pos=TransformObjectToHClip(v.vertex.xyz);
              o.uv0=v.uv0;
              o.worldNormal=TransformObjectToWorldNormal(v.normal);
              return o; 
          }

          float4 frag(v2f i):SV_Target
          {
              Light light=GetMainLight();

              float3 N=normalize(i.worldNormal);
              float3 L=normalize(light.direction);
          
              float3 headUpDir=normalize(_HeadUp);
              float3 headForwardDir=normalize(_HeadForward);
              float3 headRightDir=normalize(_HeadRight);

              //采样贴图
              float4 baseMap=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0);
              float4 shadowMask=SAMPLE_TEXTURE2D(_ShadowMask,sampler_ShadowMask,i.uv0);

              //lambert
              float3 color=baseMap.rgb;
              float LdotN=dot(N,L);
              float half_lambert=LdotN*0.5+0.5;
              half_lambert*=half_lambert;

              //Face Shadow
              float3 LpU=dot(L,headUpDir)*headUpDir;   // 计算光源方向在面部上方的投影
              half3 LpHeadHorizon = normalize(L- LpU); //光照方向在头部水平面上的投影
              half value = acos(dot(LpHeadHorizon, headRightDir)) /PI; //计算光照方向与面部右方的夹角

              half exposeRight = step(value, 0.5); //判断光照是来自右侧还是左侧
              value*=2;
              half valueR = pow(1 - value , 3); //右侧阴影强度
              half valueL = pow(value - 1, 3); //左侧阴影强度
              half mixValue =lerp(valueL, valueR, exposeRight); //混合阴影强度

              //SDF 贴图不是阴影本身，而是一张记录了“脸部不同部位对光照角度的敏感度排序” 的查找表,即变黑需要的门槛，只有大于它才能变黑
              half sdfLeft = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, float2(1 - i.uv0.x, i.uv0.y)).r;
              half sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, i.uv0).r;
              half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); //采样SDF纹理
              

              half sdf = step(mixValue, mixSdf); //计算硬边界阴影
              //sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); //防止漏光，把“后脑勺”的光掐掉
              //sdf *= shadowMask.g; //使用G通道控制阴影强度
              sdf = lerp(sdf, 1, shadowMask.a); //使用A通道作为阴影遮罩,眼睛部位

              //Face Blush
              float blushStrength=baseMap.a*_FaceBlushStrength;//根据baseMap.a来计算腮红强度
              //finalColor
              #if _USE_SDF_SHADOW
                  float3 finalColor=lerp(_ShadowColor.rgb*baseMap.rgb,baseMap.rgb,sdf);
              #else
                  float3 finalColor=baseMap.rgb*half_lambert;
              #endif
              finalColor=lerp(finalColor,_FaceBlushColor.rgb*finalColor,blushStrength);
              return float4(finalColor,1.0);
              }
          ENDHLSL
        }
         Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode"="ShadowCaster"}
            ZWrite On//写入深度缓冲区
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma multi_compile_instancing // 启用GPU实例化编译
            #pragma multi_compile _ DOTS_INSTANCING_ON // 启用DOTS实例化编译
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影

            #pragma vertex vert
            #pragma fragment frag

            float3 _LightDirection;
            float3 _LightPosition;

            // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
            float4 GetShadowPositionHClip(appdata input)
            {
             float3 positionWS = TransformObjectToWorld(input.vertex.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
             float3 normalWS = TransformObjectToWorldNormal(input.normal); // 将本地空间法线转换为世界空间法线

             #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
             float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
             #else // 平行光
             float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
             #endif

             float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

             // 根据平台的Z缓冲区方向调整Z值
             #if UNITY_REVERSED_Z // 反转Z缓冲区
                 positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
             #else // 正向Z缓冲区
                 positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
             #endif

             return positionCS; // 返回裁剪空间顶点坐标
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos=GetShadowPositionHClip(v);
                o.uv0=v.uv0;
                o.worldNormal=TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                return 0;
            }

            ENDHLSL
         }
    }
}
