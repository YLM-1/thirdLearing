Shader "GenshinToon/Body"
{
    Properties
    {
        // _Bright("Bright",Range(0,2))=0
        [Header(Textures)]
        _BaseMap("Base Map",2D)="white"{}
        _LightMap("Light Map",2D)="white"{}
        [Toggle(_USE_LIGHTMAP_AO)] _UseLightMapAO("Use LightMap AO",Range(0,1))=1

        [Header(Ramp Shadow)]
        _RampTex("Ramp Map",2D)="white"{}
        [Toggle(_USE_RAMP_SHADOW)] _UseRampShadow("Use RampMap Shadow",Range(0,1))=1
        _ShadowColor("Shadow Color",Color)=(1,1,1,1)
        //ILM.a 的5个枚举值(0.0/0.3/0.5/0.7/1.0)分别对应Ramp贴图的第几行(1~5)
        //行号与枚举值不是同序的，需要按模型单独配置。这套默认值对应芙宁娜的Ramp：
        //1=亮色/常亮 2=饰品 3=主布料 4=皮肤 5=纯白(不受光)
        _RampMapRow0("Ramp Row [ILM.a=0.0]",Range(1,5))=1
        _RampMapRow1("Ramp Row [ILM.a=0.3]",Range(1,5))=2
        _RampMapRow2("Ramp Row [ILM.a=0.5]",Range(1,5))=3
        _RampMapRow3("Ramp Row [ILM.a=0.7]",Range(1,5))=5
        _RampMapRow4("Ramp Row [ILM.a=1.0]",Range(1,5))=4

        [Header(Ramp Shading)]
        _RampSmoothMin("Ramp U Smooth Min",Range(0,1))=0.2
        _RampSmoothMax("Ramp U Smooth Max",Range(0,1))=0.4
        _ShadowLerpMin("Shadow/Light Min",Range(0,1))=0.423
        _ShadowLerpMax("Shadow/Light Max",Range(0,1))=0.45

        [Header(Lighting Option)]
        [Toggle] _AutoDayNight("Auto Day/Night (Sun Direction)",Float)=1
        _DayorNight("Manual Day(1)/Night(0)",Range(0,1))=1

        [Header(Spec Option)]
        _SpecPower("Spec Power",Float)=1
        _SpecScale("Spec Scale",Float)=1

        [Header(Metallic Option)]
        [Toggle(_USE_METALLIC)] _UseMetallic("Use Metallic",Range(0,1))=1
        _MetallicMatcap("Metallic Matcap",2D)="white"{}
        _MetallicMatmapBrightness("Metallic Matmap Brightness",Float)=1
        _MetallicColor("Metallic Color",Color)=(1,1,1,1)

        [Header(Fresnel Options)]
        [Toggle(_USE_FRESNEL)] _UseFresnel ("Use Fresnel", Range(0, 1)) = 1
        _FresnelColor ("Fresnel Color", Color) = (1, 1, 1, 1)
        _FresnelPower ("Fresnel Power", Range(0,10)) = 1.5
        _FresnelScale ("Fresnel Scaler", Range(0,1)) = 0.02

        [Header(Emission Option)]
        [Toggle(_USE_Emission)] _UseEmission("Use Emission",Range(0,1))=1
        _Flicker("flicker",Float)=1
        _EmissionScale("Emission Scale",Float)=1

        [Header(Outline Option)]
        [Toggle(_USE_OUTLINE)] _UseOutLine("Use OutLine",Range(0,1))=1
        _OutLineWidth("Out Line Width",Float)=1
        _OutLineColor("Out Line Color",Color)=(0,0,0,1)
    }
    SubShader
    {
      Tags{
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
          }

      HLSLINCLUDE
      #pragma multi_compile _MAIN_LIGHT_SHADOWS 
      #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
      #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

      #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
      #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
      #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
      #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
      #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化

      #pragma shader_feature_local _USE_LIGHTMAP_AO//AO开关
      #pragma shader_feature_local _USE_RAMP_SHADOW//色阶阴影开关
      #pragma shader_feature_local _USE_FRESNEL//菲涅尔开关
      #pragma shader_feature_local _USE_METALLIC//金属度和非金属高光强度控制
      #pragma shader_feature_local _USE_Emission//自发光开关
      #pragma shader_feature_local _USE_OUTLINE//描边

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


      CBUFFER_START(UnityPerMaterial)
      float4 _ShadowColor;
      float _RampMapRow0;
      float _RampMapRow1;
      float _RampMapRow2;
      float _RampMapRow3;
      float _RampMapRow4;
      float _RampSmoothMin;
      float _RampSmoothMax;
      float _ShadowLerpMin;
      float _ShadowLerpMax;
      float _AutoDayNight;
      float _DayorNight;
      float4 _FresnelColor;
      float _FresnelPower;
      float _FresnelScale;
      float _MetallicMatmapBrightness;
      float4 _MetallicColor;
      float _SpecPower;
      float _SpecScale;
      float _Flicker;
      float _EmissionScale;
      float _OutLineWidth;
      float4 _OutLineColor;
      //float _Bright;
      CBUFFER_END

      TEXTURE2D(_BaseMap);
      SAMPLER(sampler_BaseMap);

      TEXTURE2D(_LightMap);
      SAMPLER(sampler_LightMap);

      TEXTURE2D(_RampTex);
      SAMPLER(sampler_RampTex);

      TEXTURE2D(_MetallicMatcap);
      SAMPLER(sampler_MetallicMatcap);

      struct Universalappdata
      {
          float4 vertex:POSITION;
          float2 uv0:TEXCOORD0;
          float2 uv1:TEXCOORD1;
          float3 normal:NORMAL;
          float4 color:COLOR;
       };

       struct Universalv2f
       {
           float4 pos:SV_POSITION;
           float2 uv0:TEXCOORD0;
           float3 worldNormal:TEXCOORD1;
           float4 color:TEXCOORD2;
           float3 worldPos:TEXCOORD3;
           float3 viewNormal:TEXCOORD4;
        };
           
        float4 frag(Universalv2f i):SV_Target
        {
              Light light=GetMainLight();
              float4 vertexColor=i.color;

              float3 N=normalize(i.worldNormal);
              float3 L=normalize(light.direction);
              float3 V=normalize(_WorldSpaceCameraPos-i.worldPos);
              float3 H=normalize(L+V);

              float4 baseMap=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0);

              //R:高光枚举/金属遮罩  G:光影(0=常暗 0.5=受光 1=常亮)  B:高光细节  A:Ramp枚举
              float4 lightMap=SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,i.uv0);

              //============ 官方 Ramp 采样 ============
              //半兰伯特：官方写法是先clamp再平方，范围[0.25,1]
              float lambert=max(0.0,dot(N,L));
              float halfLambert=pow(lambert*0.5+0.5,2.0);

              //亮暗过渡：官方默认 0.423 ~ 0.450（越大阴影越大）
              float lambertStep=smoothstep(_ShadowLerpMin,_ShadowLerpMax,halfLambert);

              //A通道枚举(0.0/0.3/0.5/0.7/1.0) -> Ramp行号
              //与官方一致：用相邻枚举的中点做step，由大到小逐级插值
              float rampRow;
              //所以“行号”永远只按上半区从上往下数
              rampRow=lerp(_RampMapRow4,_RampMapRow3,step(lightMap.a,0.85));
              rampRow=lerp(rampRow,_RampMapRow2,step(lightMap.a,0.60));
              rampRow=lerp(rampRow,_RampMapRow1,step(lightMap.a,0.40));
              rampRow=lerp(rampRow,_RampMapRow0,step(lightMap.a,0.15));

              //行号1~5 -> V坐标（Unity的UV原点在左下）
              //白天=上半5行，夜晚=下半5行（官方：夜晚=白天+0.5）
              float dayV=1.05-rampRow*0.1;
              float nightV=0.55-rampRow*0.1;

              //U坐标：官方用smoothstep + clamp(0.003, 0.997)，防止采到贴图边界外和相邻行
              float rampClampMin=0.003;
              float rampClampMax=0.997;
              float rampGrayU=clamp(smoothstep(_RampSmoothMin,_RampSmoothMax,halfLambert),rampClampMin,rampClampMax);
              float rampDarkU=rampClampMin;

              //白天/夜晚：默认跟随太阳方向，也可以手动锁定
              float isDay=lerp(_DayorNight,saturate((L.y+1.0)*0.5),_AutoDayNight);

              //Ramp必须关Mipmap；这里再用LOD0保证色阶不会被mip糊掉
              //灰阶阴影 / 亮暗过渡
              float3 rampGrayColor=lerp(
                  SAMPLE_TEXTURE2D_LOD(_RampTex,sampler_RampTex,float2(rampGrayU,nightV),0).rgb,
                  SAMPLE_TEXTURE2D_LOD(_RampTex,sampler_RampTex,float2(rampGrayU,dayV),0).rgb,isDay);
              //暗部阴影 / 固定阴影
              float3 rampDarkColor=lerp(
                  SAMPLE_TEXTURE2D_LOD(_RampTex,sampler_RampTex,float2(rampDarkU,nightV),0).rgb,
                  SAMPLE_TEXTURE2D_LOD(_RampTex,sampler_RampTex,float2(rampDarkU,dayV),0).rgb,isDay);

              //============ 官方三段阴影混合 ============
              float3 grayShadowColor=baseMap.rgb*rampGrayColor*_ShadowColor.rgb;
              float3 darkShadowColor=baseMap.rgb*rampDarkColor*_ShadowColor.rgb;

              float3 diffuse=lerp(grayShadowColor,baseMap.rgb,lambertStep);
              #if _USE_LIGHTMAP_AO
                  //G=0 黑色阴影(常暗) / G=0.5 灰色阴影(受光) / G=1 常亮
                  diffuse=lerp(darkShadowColor,diffuse,saturate(lightMap.g*2.0));
                  diffuse=lerp(diffuse,baseMap.rgb,saturate(lightMap.g-0.5)*2.0);
              #endif

              #if _USE_RAMP_SHADOW
                  float3 finalLightColor=diffuse;
              #else
                  float3 finalLightColor=baseMap.rgb*(halfLambert*0.8+0.2);
              #endif

              //Specular
              float NdotH=saturate(dot(N,H));
              float spec=pow(NdotH,_SpecPower)*_SpecScale;
              spec*=lightMap.r;
              spec*=lightMap.b;
              float3 specColor=spec*baseMap.rgb;//元神高光部分是固有色，所以要乘BaseColor
              float specMask=lambertStep; //只有亮面才有高光
              specColor= specColor*specMask;
    
              // Metallic
              float metallicMask=0;
              float3 matmapColor=0;
              #if _USE_METALLIC
              {
                  metallicMask=1-step(lightMap.r,0.9);//遮罩区分1金属，0非金属
                  float2 matmapUV=i.viewNormal.xy*0.5+0.5;
                  matmapColor=SAMPLE_TEXTURE2D(_MetallicMatcap,sampler_MetallicMatcap,matmapUV).rgb;
                  matmapColor=lerp(_MetallicColor.rgb,baseMap.rgb,matmapColor);//游戏里的金属的边缘会反射一个类似环境色的颜色
                  matmapColor=lerp(float3(0,0,0),matmapColor,metallicMask);
              }
              #endif
             
              //Fresnel
              float3 fresnelColor=0;
              #if _USE_FRESNEL
                  float fresnel=1-saturate(dot(N,V));
                  fresnel=pow(fresnel,_FresnelPower);
                  fresnel=step(0.5,fresnel)*_FresnelScale;
                  fresnelColor=fresnel*_FresnelColor.rgb*baseMap.rgb;
              #endif

              float3 EmissionColor=0;
              #if _USE_Emission
              //Emission
              //diffuse的a通道存放的是自发光遮罩(也有可能是透明遮罩)
              float emissMask=smoothstep(0,1,baseMap.a);//baseMap.a有噪点
              float emission=(sin(_Time.w*_Flicker)*0.5+0.5)*_EmissionScale;
              EmissionColor=emission*baseMap.rgb*emissMask;
              #endif

             //float3 fianlColor=specColor+matmapColor;
             float3 fianlColor=finalLightColor*step(lightMap.r, 0.9)+matmapColor+fresnelColor+EmissionColor+specColor;
              // float3 fianlColor=matmapColor+fresnelColor+specColor;
              return float4(fianlColor,1);

        }

      ENDHLSL


        Pass
        {
          Name "UniversalForward"
          Tags{"LightMode"="UniversalForward" }
          Cull Back

          HLSLPROGRAM
          #pragma vertex vert
          #pragma fragment frag

          Universalv2f vert(Universalappdata v)
          {
              Universalv2f o;
              o.pos=TransformObjectToHClip(v.vertex.xyz);
              o.worldPos=TransformObjectToWorld(v.vertex.xyz);
              o.uv0=v.uv0;
              o.worldNormal=TransformObjectToWorldNormal(v.normal);
              float3 viewNormal = mul((float3x3)GetWorldToViewMatrix(), o.worldNormal);
              o.viewNormal=normalize(viewNormal);
              o.color=v.color;
              return o; 
          }

          ENDHLSL
        }
        Pass
        {
          Name "UniversalBack"
          Tags{"LightMode"="SRPDefaultUnlit" }
          Cull Front

          HLSLPROGRAM
          #pragma vertex vert
          #pragma fragment frag

          Universalv2f vert(Universalappdata v)
          {
              Universalv2f o;
              o.pos=TransformObjectToHClip(v.vertex.xyz);
              o.worldPos=TransformObjectToWorld(v.vertex.xyz);
              o.uv0=v.uv1;
              o.worldNormal=TransformObjectToWorldNormal(v.normal);
              float3 viewNormal = mul((float3x3)GetWorldToViewMatrix(), o.worldNormal);
              o.viewNormal=normalize(viewNormal);
              o.color=v.color;
              return o; 
          }
          ENDHLSL
        }

        Pass
        {
          Name "OutLine"
          Tags{"LightMode"="SRPDefaultUnlit" }
          Cull Front // 剔除正面，只渲染背面，从而把外扩后的壳露在外面

          HLSLPROGRAM
          #pragma vertex vert
          #pragma fragment frag

          struct Outlinedata
          {
              float4 vertex:POSITION;
              float2 uv:TEXCOORD0;
              float3 normal:NORMAL;
              float4 color:COLOR;
          };

          struct OutlineV2f
          {
              float4 posCS:SV_POSITION;
              float2 uv:TEXCOORD0;
          };

          OutlineV2f vert(Outlinedata v)
          {
            OutlineV2f o;
            o.uv = v.uv;

            // 1. 将顶点和法线转到世界空间
            float3 posWS = TransformObjectToWorld(v.vertex.xyz);
            float3 normalWS = TransformObjectToWorldNormal(v.normal);

            // 2. 转换到观察空间 (View Space)
            float3 posVS = TransformWorldToView(posWS);
            float3 normalVS = TransformWorldToViewDir(normalWS);
            normalVS.z=-0.5;

            // 3. 法线外扩核心
            posVS.xy += normalVS.xy * _OutLineWidth * 0.01*v.color.a;

            // 4. 将外扩后的观察空间坐标，通过投影矩阵转换到裁剪空间，并赋值给输出的变量
            o.posCS = mul(GetViewToHClipMatrix(), float4(posVS, 1.0));
            return o;
          }

          float4 frag(OutlineV2f i) : SV_Target
          {
              return _OutLineColor;
          }
           ENDHLSL
         }

        //UsePass "Hidden/ShowVertexColor/OutLine"

    

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode"="ShadowCaster"}
            ZWrite On
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

            struct appdata
            {
                float4 vertex:POSITION;
                float3 normal:NORMAL;
             };

             struct v2f
             {
                 float4 pos:SV_POSITION;
              };

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
