Shader "Unlit/Wobble"
{
    Properties
    {
        _WobbleX("Wobble X",Range(-45,45))=0
        _WobbleZ("Wobble Z",Range(-45,45))=0
        [Header(Liquid)]
        _FillAmount("Fill Amount",Range(0,1))=0
        _LiquidColor("Liquid Color",Color)=(1,1,1,1)
        _LiquidTopColor("Liquid Top",Color)=(1,1,1,1)
        _LiquidFoamColor("Liquid Foam",Color)=(1,1,1,1)
        _LiquidFoamHeight("Liquid Foam Height",Range(0,1))=0.5
        [Header(Rim)]
        _LiquidRimPower("Liquid Rim Power",Range(0,100))=10
        _LiquidRimIntensity("Liquid Rim Intensity",Range(0,100))=10
        [Header(Specular)]
        _SpecularPower("Specular Power",Range(0,100))=10
        _SpecularIntensity("Specular Intensity",Range(0,100))=10

        [Header(Bottle)]
        _BottleThickness("Bottle Thickness",Range(0,0.1))=0.05
        _BottleColor("Bottle Color",Color)=(1,1,1,1)
        [Header(Bottle Rim)]
        _BottleRimPower("Bottle Rim Power",Range(0,100))=10
        _BottleRimIntensity("Bottle Rim Intensity",Range(0,100))=10
        [Header(Bottle Specular)]
        _BottleSpecularPower("Bottle Specular Power",Range(0,100))=10
        _BottleSpecularIntensity("Bottle Specular Intensity",Range(0,100))=10


    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100
        Cull Off
        AlphaToMask On

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        float Rim(float3 normal,float3 viewDir,float rimPower,float rimIntensity)
        {
            float NdotV=1-saturate(dot(normal,viewDir));
            float rim=pow(NdotV,rimPower)*rimIntensity;
            return rim;
        }

        float Specular(float3 normal,float3 viewDir,float3 lightDir,float specularPower,float specularIntensity)
        {
            float3 H=normalize(lightDir+viewDir);
            float NdotH=saturate(dot(normal,H));
            float specular=pow(NdotH,specularPower)*specularIntensity;
            return specular;
        }
        ENDHLSL

        //渲染水体
        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            Name "Water"
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
    
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float fill:TEXCOORD1;
                float3 normalWS:TEXCOORD2;
                float3 worldPos:TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
            float _WobbleX;
            float _WobbleZ;
            float _FillAmount;
            float4 _LiquidColor;
            float4 _LiquidTopColor;
            float4 _LiquidFoamColor;
            float _LiquidFoamHeight;
            float _LiquidRimPower;
            float _LiquidRimIntensity;
            float _SpecularPower;
            float _SpecularIntensity;
            CBUFFER_END

            float2 RotateAroundAxis(float2 vertex,float degree)
            {
                float sina,cosa;
                float radian=degree*PI/180;
                sincos(radian,sina,cosa);
                float2x2 m=float2x2(cosa,sina,-sina,cosa);
                return mul(m,vertex);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);

                //对模型空间内顶点做旋转变换
                v.vertex.yz=RotateAroundAxis(v.vertex.yz,_WobbleX);
                v.vertex.xy=RotateAroundAxis(v.vertex.xy,_WobbleZ);
                o.uv = v.uv;
                float3 objectOrigin = UNITY_MATRIX_M._m03_m13_m23;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                //相减得到相对物体的世界位置
                float3 posWS = o.worldPos - objectOrigin;
                o.fill = posWS.y;

                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i,float facing:VFACE) : SV_Target
            {
                Light light = GetMainLight();
                float3 lightDir=normalize(light.direction);

                //1.液体
                float liquidPart=step(i.fill,_FillAmount);
                float3 liquidColor=liquidPart*_LiquidColor.rgb;

                //2.液体和平面交界处
                float foamPart=liquidPart-step(i.fill,_FillAmount-_LiquidFoamHeight);
                float3 liquidFoamColor=_LiquidFoamColor.rgb*foamPart;

                //Rim
                float3 viewDir=normalize(_WorldSpaceCameraPos-i.worldPos);
                float3 worldNormal=normalize(i.normalWS);
                float3 rim=Rim(worldNormal,viewDir,_LiquidRimPower,_LiquidRimIntensity)*_LiquidColor.rgb;

                //Specular
                worldNormal=lerp(worldNormal,-worldNormal,facing<0);
                float3 spec=Specular(worldNormal,viewDir,lightDir,_SpecularPower,_SpecularIntensity)*_LiquidColor.rgb;
                // spec=step(0.9,spec);

                //3.液体平面
                float4 finalColor=1;
                finalColor.rgb=liquidColor+liquidFoamColor+rim;
                finalColor.rgb=lerp(finalColor.rgb,_LiquidTopColor.rgb,facing<0)+spec;
                finalColor.a=liquidPart;
                return finalColor;
            }
            ENDHLSL
        }

        //渲染容器
       //渲染容器
Pass
{
    Tags { "LightMode"="SRPDefaultUnlit" "Queue"="Transparent" "RenderType"="Transparent" }
    
    Name "Bottle"
    Blend SrcAlpha OneMinusSrcAlpha
    ZWrite Off
    
    HLSLPROGRAM
    #pragma vertex vert
    #pragma fragment frag

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 normalWS : TEXCOORD1;   // 片元需要世界空间法线
        float3 worldPos : TEXCOORD2;   // 片元需要世界空间位置
    };

    CBUFFER_START(UnityPerMaterial)
    float _BottleThickness;
    float4 _BottleColor;
    float _BottleRimPower;
    float _BottleRimIntensity;
    float _BottleSpecularPower;
    float _BottleSpecularIntensity;
    CBUFFER_END

    v2f vert (appdata v)
    {
        v2f o;
        
        // ============ 第1步：变换到世界空间 ============
        float3 posWS = TransformObjectToWorld(v.vertex.xyz);
        float3 normalWS = TransformObjectToWorldNormal(v.normal);
        
        // ============ 第2步：变换到视图空间 ============
        float3 posVS = TransformWorldToView(posWS);
        float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, normalWS));
        // 注意：法线不能用 TransformWorldToViewDir，要用正规的法线变换矩阵
        
        // ============ 第3步：在视图空间偏移 ============
        posVS = posVS + normalVS * _BottleThickness;
        
        // ============ 第4步：变换到裁剪空间 ============
        // 视图空间 → 裁剪空间：使用投影矩阵
        o.vertex = mul(GetViewToHClipMatrix(), float4(posVS, 1.0));
        
        o.uv = v.uv;
        
        // ============ 第5步：传递片元需要的数据（世界空间） ============
        // 注意：posWS 是偏移前的，需要重新计算偏移后的世界坐标
        // 方法：从偏移后的视图空间反推世界空间
        float4 viewToWorld = mul(UNITY_MATRIX_I_V, float4(posVS, 1.0));
        o.worldPos = viewToWorld.xyz;
        o.normalWS = normalWS;  // 法线在世界空间不变（如果物体没有非均匀缩放）
        
        return o;
    }

    float4 frag (v2f i, float facing : VFACE) : SV_Target
    {
        Light light = GetMainLight();
        float3 lightDir = normalize(light.direction);
        
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
        float3 normal = normalize(i.normalWS);
        normal = lerp(normal, -normal, facing < 0);
        
        // Rim 边缘光
        float3 rim = Rim(normal, viewDir, _BottleRimPower, _BottleRimIntensity) * _BottleColor.rgb;
        
        // Specular 高光
        float3 spec = Specular(normal, viewDir, lightDir, _BottleSpecularPower, _BottleSpecularIntensity) * _BottleColor.rgb;
        
        float4 finalColor = 1;
        finalColor.rgb = _BottleColor.rgb + rim + spec;
        finalColor.a = _BottleColor.a;
        
        return finalColor;
    }
    ENDHLSL
}
    }
}
