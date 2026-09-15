Shader "Unlit/Grass"
{
    Properties
    {
        [Header(Grass)]
        _Height("Height",Range(0,0.5))=0.07
        _HeightRandom("Height Random",Range(0,0.5))=0.05

        _Width("Width",Range(0,0.1))=0.02
        _WidthRandom("Width Random",Range(0,0.1))=0.05

        _Forward("Forward",Range(0,1))=0.5
        _ForwardRandom("Forward Random",Range(0,0.5))=0.2
        _Curve("Curve",Range(0,5))=3

        _RotationRandom("Rotation Random",Range(0,1))=0.2
        _BlendingRandom("Blending Random",Range(0,1))=0.2

        [Header(Shading)]
        _TopColor("Top Color",Color)=(1,1,1,1)
        _BottomColor("Bottom Color",Color)=(1,1,1,1)
        _ColorVaration("Color Variation",Color)=(1,1,1,1)
        _Varation("Variation",Range(0,0.05))=0.02
        _Translucent("Translucent",Range(0,2))=0.5

        _SpecularPower("Specular Power",Range(0,20))=5
        _SpecularIntensity("Specular Intensity",Range(0,10))=1

        _ShadowStrength("Shadow Strength",Range(0,1))=0.5

        [Header(Wind)]
        _WindTexture("Wind Texture",2D) = "white" {}
        _WindSpeed("Wind Speed",Range(0,1))=0.1
        _WindStrength("Wind Strength",Range(0,1))=1

        [Header(Interaction)]
        _Radius("Radius",Float)=1
    }

    HLSLINCLUDE
    #pragma target 4.0
    
    #define _GRASS_SEGMENTS 3 //定义草叶垂直方向的细分段数
    #define PI 3.14159265

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
    };

    struct v2g
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
    };

    struct g2f
    {
        float4 pos:SV_POSITION;
        float3 worldNormal : NORMAL;
        float2 uv : TEXCOORD0;
        float3 posWS : TEXCOORD1;
        float varation : TEXCOORD2;
        float4 shadowCoord: TEXCOORD3;
    };

    CBUFFER_START(UnityPerMaterial)
    float _Height;
    float _Width;
    float _Forward;
    float _ForwardRandom;
    float _Curve;
    float _HeightRandom;
    float _WidthRandom;
    float _RotationRandom;
    float _BlendingRandom;

    float4 _TopColor;
    float4 _BottomColor;
    float4 _ColorVaration;
    float _Varation;
    float _Translucent;
    float _SpecularPower;
    float _SpecularIntensity;
    float _ShadowStrength;

    float _WindSpeed;
    float _WindStrength;

    float _Radius;
    CBUFFER_END

    TEXTURE2D(_WindTexture);
    SAMPLER(sampler_WindTexture);

    float3 _LightDirection;
    float3 _LightPosition;
    float4 _Position;

    v2g vert (appdata v)
    {
        v2g o;
        o.vertex = v.vertex;
        o.uv = v.uv;
        o.normal = v.normal;
        o.tangent = v.tangent;
        return o;
    }

    // angle: 弧度制的角度
    // axis: 旋转所绕的轴
    // 类似 c# Quaternion.AngleAxis
    float3x3 _angleAxis3x3(float angle, float3 axis)
    {
        float c, s;
        sincos(angle, s, c);

        float t = 1 - c;
        float x = axis.x;
        float y = axis.y;
        float z = axis.z;

        return float3x3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c
        );
    }

    float RandomValue(float3 pos)
    {
        return frac(sin(dot(pos,float3(12.9898,78.233,45.1643)))*43758.5453);
    }

    g2f VertexOutPut(float3 origPos,float3 pos,float3 normal,float2 uv,float3x3 mat)
    {
        g2f o;
        float3 p=mul(mat,pos);
        float3 objectPos = origPos + p;
        o.pos = TransformObjectToHClip(objectPos);
        o.worldNormal = TransformObjectToWorldNormal(mul(mat,normal));
        o.posWS = TransformObjectToWorld(objectPos);
        o.uv = uv;
        o.varation = RandomValue(origPos);

        //计算阴影坐标
        o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
        return o;
    }

    g2f ShadowVertexOutPut(float3 origPos,float3 pos,float3 normal,float2 uv,float3x3 mat)
    {
        g2f o;
        float3 objectPos = origPos + mul(mat,pos);
        float3 positionWS = TransformObjectToWorld(objectPos);
        float3 normalWS = TransformObjectToWorldNormal(mul(mat,normal));

        #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
            float3 lightDirectionWS = normalize(_LightPosition - positionWS);
        #else
            float3 lightDirectionWS = _LightDirection;
        #endif

        o.pos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
        #if UNITY_REVERSED_Z
            o.pos.z = min(o.pos.z, UNITY_NEAR_CLIP_VALUE);
        #else
            o.pos.z = max(o.pos.z, UNITY_NEAR_CLIP_VALUE);
        #endif
        o.worldNormal = normalWS;
        o.posWS = positionWS;
        o.uv = uv;
        o.varation = RandomValue(origPos);
        o.shadowCoord = 0;
        return o;
    }
    
    [maxvertexcount(_GRASS_SEGMENTS*2+1)]//单次执行最多会输出多少个顶点。
    void geo(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
    {
        g2f o;

        //每个顶点的位置绘制一个三角形
        float3 pos = IN[0].vertex;

        //定义每个草的模型的切线空间
        float3 normal = IN[0].normal;
        float4 tangent = IN[0].tangent;
        float3 binormal = cross(normal, tangent.xyz)*tangent.w;
        float3x3 TBN = transpose(float3x3(tangent.xyz, binormal, normal));

        //随机方向
        float3x3 fracingRotationMat = _angleAxis3x3(RandomValue(pos)*2*PI*_RotationRandom,float3(0,0,1));//在切线空间旋转，此时它的法线方向是z轴
        float3x3 facingMat = mul(TBN,fracingRotationMat);//在切线空间旋转然后再转换到模型空间，所以是先乘以旋转矩阵再TBN
                                                         //重新创建了这个变换矩阵(线性代数中矩阵的乘是从右往左来乘的)

        //随机弯曲
        float3x3 bendingRotationMat = _angleAxis3x3(RandomValue(pos.zxy)*0.5*PI*_BlendingRandom,float3(1,0,0));
        float3x3 mat = mul(facingMat,bendingRotationMat);

        //添加动画
        float2 windUV = pos.xz+_Time.x*_WindSpeed;
        float2 windSample = SAMPLE_TEXTURE2D_LOD(_WindTexture,sampler_WindTexture,windUV,0).rg*_WindStrength;
        float3 wind = normalize(float3(windSample.x,windSample.y,0));
        float3x3 windRotationMat = _angleAxis3x3(windSample.x*PI,wind);
        mat = mul(mat,windRotationMat);

        //增加草模型的细分
        //计算高度和宽度
        float height = _Height + RandomValue(pos.yzx)*_HeightRandom;
        float width  = _Width  + RandomValue(pos.zxy)*_WidthRandom;
        float forward = _Forward + RandomValue(pos.xzy)*_ForwardRandom;

        //交互
        float3 worldPos = TransformObjectToWorld(pos).xyz;
        float dis = distance(_Position.xyz,worldPos);
        float radius = 1-saturate(dis/_Radius);
        height = height-radius;
        forward = forward-radius*2;

        for(int i=0;i<_GRASS_SEGMENTS;++i)
        {
            float t=i/(float)_GRASS_SEGMENTS;
            float h=height*t;
            float w=i==0?width/1.5:width*(1-t);
            float f=pow(t,_Curve)*forward;

            float3x3 currentMat = (i == 0) ? facingMat : mat;

            //在这里，我修改了坐标轴x轴：宽度 ,y轴：向前弯曲 ,z轴：草的高度
            triStream.Append(VertexOutPut(pos,float3(w,f,h), float3(0,-1,f),float2(0,t),currentMat));
            triStream.Append(VertexOutPut(pos,float3(-w,f,h), float3(0,-1,f),float2(1,t),currentMat));
        }
        triStream.Append(VertexOutPut(pos,float3(0,forward,height),float3(0,-1,forward),float2(0.5,1),mat));
    }

    [maxvertexcount(_GRASS_SEGMENTS*2+1)]
    void shadowGeo(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
    {
        float3 pos = IN[0].vertex;
        float3 normal = IN[0].normal;
        float4 tangent = IN[0].tangent;
        float3 binormal = cross(normal, tangent.xyz) * tangent.w;
        float3x3 TBN = transpose(float3x3(tangent.xyz, binormal, normal));

        float3x3 facingRotationMat = _angleAxis3x3(RandomValue(pos) * 2 * PI * _RotationRandom, float3(0, 0, 1));
        float3x3 facingMat = mul(TBN, facingRotationMat);
        float3x3 bendingRotationMat = _angleAxis3x3(RandomValue(pos.zxy) * 0.5 * PI * _BlendingRandom, float3(1, 0, 0));
        float3x3 mat = mul(facingMat, bendingRotationMat);

        float height = _Height + RandomValue(pos.yzx) * _HeightRandom;
        float width = _Width + RandomValue(pos.zxy) * _WidthRandom;
        float forward = _Forward + RandomValue(pos.xzy) * _ForwardRandom;

        for (int i = 0; i < _GRASS_SEGMENTS; ++i)
        {
            float t = i / (float)_GRASS_SEGMENTS;
            float h = height * t;
            float w = i == 0 ? width / 1.5 : width * (1 - t);
            float f = pow(t, _Curve) * forward;
            float3x3 currentMat = i == 0 ? facingMat : mat;

            triStream.Append(ShadowVertexOutPut(pos, float3(w, f, h), float3(0, -1, t), float2(0, t), currentMat));
            triStream.Append(ShadowVertexOutPut(pos, float3(-w, f, h), float3(0, -1, t), float2(1, t), currentMat));
        }
        triStream.Append(ShadowVertexOutPut(pos, float3(0, forward, height), float3(0, -1, 1), float2(0.5, 1), mat));
    }
    ENDHLSL
    SubShader
    {
        Name "Grass"
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            float4 frag (g2f i) : SV_Target
            {
                //获取光照和阴影
                Light light = GetMainLight(i.shadowCoord);
                float3 lightColor = light.color;
                float3 lightDir = normalize(light.direction);
                float shadowAttenuation = light.shadowAttenuation;
                shadowAttenuation = lerp(1,shadowAttenuation,_ShadowStrength);

                //lambert
                float NdotL = saturate(dot(i.worldNormal,lightDir)+_Translucent);
                float4 col=lerp(_BottomColor,_TopColor,i.uv.y);

                //specular
                float3 viewDir = normalize(_WorldSpaceCameraPos-i.posWS.xyz);
                float3 halfDir = normalize(lightDir+viewDir);
                float NdotH = saturate(dot(i.worldNormal,halfDir));
                float specular = pow(NdotH,_SpecularPower)*_SpecularIntensity;

                lightColor = (NdotL*lightColor+specular)*shadowAttenuation;

                col = col*float4(lightColor,1);
                //杂色
                col=lerp(col,_ColorVaration*float4(lightColor,1),step(i.varation,_Varation));

                return col;
            }  
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            Cull Off
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry shadowGeo
            #pragma fragment Shadowfrag
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float4 Shadowfrag(g2f i):SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
