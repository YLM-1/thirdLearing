//Reflection
float _ReflectionIntensity;
float _ReflectionDistortion;
float _FresnelF0;
float _FresnelPower;

//Refraction
float _DepthLevel;
float _DepthPower;
float4 _ShallowColor;
float4 _DepthColor;
float _RefractionDistortion;

//SSS
float _SSSDistort;
float _SSSPower;
float _SSSIntensity;
float4 _SSSColor;

//Wave
float _WaveSpeed;
float _WaveDirection;
float _WaveNormalIntensity;

//Specular
float _SpecularPower;
float _SpecularIntensity;
float4 _WaterSpecularColor;

//Flow
float _FlowIntensity;
float _FlowSpeed;
float _NormalScale;
float _FlowNormalStrength;

//Foam
float4 _FoamColor;
float _FoamScope;
float _FoamPower;
float _FoamInterval;
float _FoamWidth;
float _FoamSpeed;
float _FoamIntensity;

TEXTURE2D(_ReflectionRT);
SAMPLER(sampler_ReflectionRT);

TEXTURE2D(_RefractionRT);
SAMPLER(sampler_RefractionRT);

TEXTURE2D(_WaveNormalMap);
SAMPLER(sampler_WaveNormalMap);
float4 _WaveNormalMap_ST;

TEXTURE2D(_FlowMap);
SAMPLER(sampler_FlowMap);
float4 _FlowMap_ST;

TEXTURE2D(_NormalTex);
SAMPLER(sampler_NormalTex);
float4 _NormalTex_ST;

//Gerstner
int _WaveCount;
float _WavelengthMax;
float _WavelengthMin;
float _WavesteepnessMax;
float _WavesteepnessMin;
float _RandomDirection;
float _GerstnerSpeed;
float4 _Direction;

//Gerstner结构体必须在函数之前声明
struct Gerstner
{
    float3 positionWS;
    float3 binormal;
    float3 tangent;
};

//给每个波一个稳定随机的值
float Random(int seed)
{
    return frac(sin(dot(float2(seed, 2), float2(12.9898, 78.233)))) * 2 - 1;
}

Gerstner GerstnerWave(float4 direction, float3 positionWS, int waveCount, float wavelengthMax, float wavelengthMin, float steepnessMax, float steepnessMin, float randomdirection)
{
    Gerstner gerstner;

    float3 P = 0;
    float3 B = 0;
    float3 T = 0;

    for (int i = 0; i < waveCount; i++)
    {
        float step = (float)i / (float)waveCount;

        float2 d = float2(Random(i), Random(2 * i));
        d = normalize(lerp(normalize(direction.xy), d, randomdirection));

        float wavelength = lerp(wavelengthMax, wavelengthMin, step);
        float steepness = lerp(steepnessMax, steepnessMin, step) / waveCount;

        float k = 2 * PI / wavelength;
        float g = 9.81f;
        float w = sqrt(g * k);
        float a = steepness / k;
        float2 wavevector = k * d;
        float value = dot(wavevector, positionWS.xz) - w * _Time.y * _GerstnerSpeed;

        P.x += d.x * a * cos(value);
        P.z += d.y * a * cos(value);
        P.y += a * sin(value);

        T.x += d.x * d.x * k * a * -sin(value);
        T.y += d.x * k * a * cos(value);
        T.z += d.x * d.y * k * a * -sin(value);

        B.x += d.x * d.y * k * a * -sin(value);
        B.y += d.y * k * a * cos(value);
        B.z += d.y * d.y * k * a * -sin(value);
    }

    gerstner.positionWS.x = positionWS.x + P.x;
    gerstner.positionWS.y = positionWS.y + P.y;
    gerstner.positionWS.z = positionWS.z + P.z;
    gerstner.tangent = float3(1 + T.x, T.y, T.z);
    gerstner.binormal = float3(B.x, B.y, 1 + B.z);

    return gerstner;
}

struct appdata
{
    float4 vertex:POSITION;
    float2 uv:TEXCOORD0;
    float3 normal:NORMAL;
    float4 tangent:TANGENT;
};

struct v2f
{
    float4 vertex:SV_POSITION;
    float2 uv:TEXCOORD0;
    float4 screenPos:TEXCOORD1;
    float3 worldNormal:TEXCOORD2;
    float3 tangent:TEXCOORD3;
    float3 binormal:TEXCOORD4;
    float3 worldPos:TEXCOORD5; 
};

v2f vert(appdata v)
{
    v2f o;
    o.uv=v.uv;

    //Gerstner波：世界空间顶点位移，同时得到切线/副切线
    float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
    Gerstner gerstner = GerstnerWave(_Direction, positionWS, _WaveCount, _WavelengthMax, _WavelengthMin,
        _WavesteepnessMax, _WavesteepnessMin, _RandomDirection);

    o.worldPos = gerstner.positionWS;
    o.vertex = TransformWorldToHClip(gerstner.positionWS);
    //ComputeScreenPos 需要裁剪空间坐标，否则 screenUV / screenPos.w 都是错的
    o.screenPos=ComputeScreenPos(o.vertex);

    //波面法线由切线/副切线叉乘得到，波面下的TBN让法线贴图跟着波走
    o.worldNormal = normalize(cross(gerstner.binormal,gerstner.tangent));
    o.tangent=normalize(gerstner.tangent);
    o.binormal=normalize(gerstner.binormal);
    return o;
}

float3 Normal_TS(float2 uv,float speed,float direction,Texture2D tex,SamplerState sampler_tex)
{
    float time = _Time.y*speed;
    float2 offset = time*float2(cos(direction),sin(direction));
    float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(tex,sampler_tex,uv+offset));
    return normal;
}

float3 FresnelSnhlick(float cosTheta, float3 F0)
{
    //Schlick: F0 + (1-F0)*(1-cos)^_FresnelPower
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, _FresnelPower);
}

float4 frag(v2f i):SV_TARGET
{
    float2 screenUV = i.screenPos.xy/i.screenPos.w;
    float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);

    Light light = GetMainLight(shadowCoord);
    float3 lightDir = normalize(light.direction);
    float3 lightColor = light.color;
    float shadowAtten = light.shadowAttenuation;
    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

    //构建TBN矩阵
    float3x3 TBN=float3x3(i.tangent,i.binormal,i.worldNormal);

    //Wave
    float2 waveUV = TRANSFORM_TEX(i.uv, _WaveNormalMap);
    float3 normalTS0 = Normal_TS(waveUV,_WaveSpeed,_WaveDirection,_WaveNormalMap,sampler_WaveNormalMap);
    float3 normalTS1 = Normal_TS(waveUV,_WaveSpeed,-_WaveDirection,_WaveNormalMap,sampler_WaveNormalMap);
    float3 normalTS = normalize(normalTS0+normalTS1);
    float3 normal_A = normalize(mul(normalTS,TBN))*_WaveNormalIntensity;

    //FlowMap：两张法线按人字形权重交替滚动
    #ifdef _USE_FLOWMAP
        float2 flowVector = SAMPLE_TEXTURE2D(_FlowMap,sampler_FlowMap,i.uv).rg;
        flowVector*=_FlowIntensity;
        float flowSpeed=_FlowSpeed*0.1;
        float progressA=frac(_Time.y*flowSpeed);
        float progressB=frac(_Time.y*flowSpeed+0.5);
        //你退我进，你进我退
        float weightDistortion1= 1 - abs(1-2*progressA); //1-2*progressA->[1,-1],abs->[1,0,1],1->[0,1,0],形成人字
        float weightDistortion2 = 1 - abs(1-2*progressB);

        float2 flowOffsetA = flowVector * progressA;
        float2 flowOffsetB = flowVector * progressB+0.5;

        float3 normal1 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, TRANSFORM_TEX(i.uv + flowOffsetA, _NormalTex)), _NormalScale).rgb;
        float3 normal2 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, TRANSFORM_TEX(i.uv + flowOffsetB, _NormalTex)), _NormalScale).rgb;
        float3 normal = normal1 * weightDistortion1 + normal2 * weightDistortion2;
        float3 normal_B=normalize(mul(normal,TBN));

        //FlowMap法线只叠加一部分，避免盖过波浪法线
        float3 normalWS=normalize(normal_A+normal_B*lerp(0,0.5,_FlowNormalStrength));
    #else
        float3 normalWS=normal_A;
    #endif

    //Reflection
    //反射相机是直接镜像 position/forward/up 再 LookAt 得到的，
    //镜像后的基是左手系，Unity 重建 right 时会取反，所以RT相对屏幕是左右镜像的，
    //这里采样时把X轴翻回来，保证反射和实际位置对齐
    float2 reflectOffset = normalWS.xz * _ReflectionDistortion;
    float2 reflectUV = float2(1.0 - screenUV.x, screenUV.y) + reflectOffset;
    float3 reflectColor = SAMPLE_TEXTURE2D(_ReflectionRT,sampler_ReflectionRT,reflectUV);
    //_ReflectionIntensity 不在这里乘，统一放到下面的菲涅尔权重里，避免反射被衰减两次

    //Refraction
       //深度获取:
    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV).r;
    float depthValue = LinearEyeDepth(depth, _ZBufferParams);
    float depthDiff = abs(depthValue - i.screenPos.w);
    float depthWeight = pow(saturate((depthValue - i.screenPos.w)*_DepthLevel), _DepthPower);
       //颜色变化:
    float3 baseColor = lerp(_ShallowColor,_DepthColor,depthWeight);
       //透射抓屏
    float2 refractOffset = normalWS.xz*_RefractionDistortion;
    float3 refractBase = SAMPLE_TEXTURE2D(_RefractionRT,sampler_RefractionRT,screenUV+refractOffset);
    float3 refractColor = lerp(refractBase,baseColor,depthWeight);

    //SSS
    float3 SSSHalf = light.direction + _SSSDistort*normalWS;
    float SSS = pow(saturate(dot(viewDir,-SSSHalf)),_SSSPower)*_SSSIntensity;
    float3 SSSColor = SSS*_SSSColor.rgb;

    //Blinn-Phong
    float3 halfDir = normalize(lightDir+viewDir);
    float NdotH = dot(normalWS,halfDir);
    float specular=pow(saturate(NdotH),_SpecularPower)*_SpecularIntensity;
    float3 specularColor = lightColor*specular*_WaterSpecularColor.rgb * shadowAtten;

    //Fresnel结合
    float NdotV = saturate(dot(normalWS,viewDir));
    float3 F = FresnelSnhlick(NdotV, _FresnelF0.xxx);
    //菲涅尔权重再乘 _ReflectionIntensity，作为反射最多能占的比例（0=纯折射，1=完全按菲涅尔）
    float3 reflectionWeight = saturate(F * _ReflectionIntensity);
    //反射和折射按菲涅尔混合
    float3 waterColor = lerp(refractColor, reflectColor, reflectionWeight);

    //高光和SSS是加色效果，不参与反射/折射混合，最后叠上去
    float3 finalColor = waterColor + specularColor + SSSColor;

    //Foam
    //depthDiff 是 view 空间下的深度差（世界单位），越小越靠岸
    //1.近岸遮罩：depthDiff 从 0 到 _FoamScope 时，泡沫从 1 衰减到 0
    float foamMask = pow(saturate(1.0 - depthDiff / max(_FoamScope, 1e-4)), _FoamPower);
    //2.泡沫条纹：相位直接用世界单位的 depthDiff（_FoamInterval = 每世界单位多少弧度）
    //   fwidth 做抗锯齿：屏幕上条纹过密时自动淡出，避免摩尔纹/闪烁
    float foamPhase = depthDiff * _FoamInterval + _Time.y * _FoamSpeed;
    float foamAA = saturate(1.0 - fwidth(foamPhase) * 2.0);
    float foamBand = _FoamWidth * sin(foamPhase) * 0.5 * foamAA + 0.5;
    //3.合成泡沫强度，_FoamIntensity 是总强度
    float foam = saturate(foamMask * foamBand) * _FoamIntensity;
    //4.混到最终颜色上
    finalColor = lerp(finalColor, _FoamColor.rgb, foam);

    return float4(finalColor,1);
}
