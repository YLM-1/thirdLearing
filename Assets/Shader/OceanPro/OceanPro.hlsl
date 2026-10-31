//Reflection
float _ReflectionIntensity;
float _ReflectionDistortion;
float _FresnelF0;
float _FresnelPower;
//粗糙度：用 mip 级别来近似"反射的模糊程度"
float _ReflectionRoughness;
float _ReflectionRoughnessDist;
float _ReflectionRoughnessMax;

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
float _FoamContrast;
float _FoamCoverage;
float4 _FoamFlow;
float _FoamScope;
float _FoamPower;
float _FoamInterval;
float _FoamSpeed;
float _FoamIntensity;
float _FoamCrestHeight;
float _FoamCrestScale;
float _FoamCrestIntensity;

TEXTURE2D(_ReflectionRT);
SAMPLER(sampler_ReflectionRT);

//TEXTURE2D(_RefractionRT);
//SAMPLER(sampler_RefractionRT);

TEXTURE2D(_WaveNormalMap);
SAMPLER(sampler_WaveNormalMap);
float4 _WaveNormalMap_ST;

TEXTURE2D(_FlowMap);
SAMPLER(sampler_FlowMap);
float4 _FlowMap_ST;

TEXTURE2D(_NormalTex);
SAMPLER(sampler_NormalTex);
float4 _NormalTex_ST;

TEXTURE2D(_FoamTex);
SAMPLER(sampler_FoamTex);
float4 _FoamTex_ST;

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
    float3 foamData:TEXCOORD6;   //xy = 位移前的世界 XZ（泡沫 UV 用）, z = 波高（浪尖白沫用）
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
    //泡沫用：xy=位移前的世界XZ（纹理不会随波浪游动）, z=波高（浪尖白沫）
    o.foamData = float3(positionWS.xz, gerstner.positionWS.y - positionWS.y);
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

float3 FresnelSchlick(float cosTheta, float3 F0)
{
    //Schlick: F0 + (1-F0)*(1-cos)^_FresnelPower
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, _FresnelPower);
}

float4 frag(v2f i):SV_TARGET
{
    //数据准备
    float2 screenUV = i.screenPos.xy/i.screenPos.w;
    float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);

    Light light = GetMainLight(shadowCoord);
    float3 lightDir = normalize(light.direction);
    float3 lightColor = light.color;
    float shadowAtten = light.shadowAttenuation;
    //到相机的距离给粗糙度用，顺便复用给 viewDir，省一次 length
    float3 toCam = _WorldSpaceCameraPos.xyz - i.worldPos;
    float distToCam = length(toCam);
    float3 viewDir = toCam / max(distToCam, 1e-5);

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

    //NdotV 提前算：菲涅尔和反射粗糙度都要用（用扰动后的法线，所以反射强度/模糊会跟着波浪变化）
    float NdotV = saturate(dot(normalWS,viewDir));

    //Reflection
    //扰动方向用视图空间（投影到屏幕平面）：否则相机绕 Y 一转，水面的扰动方向会跟着一起转
    //注意：视图空间 +y 朝上，screenPos 的 v 也是朝上，所以这里不用取负
    float2 distortVS = TransformWorldToViewDir(normalWS).xy;
    float2 reflectOffset = distortVS * _ReflectionDistortion;
    float2 reflectUV = screenUV + reflectOffset;
    reflectUV.x = 1.0 - reflectUV.x;   //左右翻转要放在扰动之后

    //粗糙度 -> mip 级别：近处用 _ReflectionRoughness，越远越接近全模糊（远处的水面细节被平均掉）
    float roughByDist = saturate(distToCam / max(_ReflectionRoughnessDist, 1e-4));
    float reflectionRoughness = max(_ReflectionRoughness, roughByDist);
    //掠射角下你能同时看到一大片波面，所以既更反光也更糊：给 LOD 再补一点角度项
    reflectionRoughness = saturate(reflectionRoughness + (1.0 - NdotV) * 0.35);
    float reflectionLOD = reflectionRoughness * _ReflectionRoughnessMax;
    float3 reflectColor = SAMPLE_TEXTURE2D_LOD(_ReflectionRT,sampler_ReflectionRT,reflectUV,reflectionLOD).rgb;

    //Refraction
    //深度获取:
    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV).r;//非线性的0-1
    float depthValue = LinearEyeDepth(depth, _ZBufferParams);//真实的距离
    float depthDiff = abs(depthValue - i.screenPos.w);
    float depthWeight = pow(saturate((depthValue - i.screenPos.w)*_DepthLevel), _DepthPower);
    //颜色变化:
    float3 baseColor = lerp(_ShallowColor,_DepthColor,depthWeight);
    //透射抓屏（扰动方向复用上面算好的视图空间方向）
    float2 refractOffset = distortVS * _RefractionDistortion;
    //float3 refractBase = SAMPLE_TEXTURE2D(_RefractionRT,sampler_RefractionRT,screenUV+refractOffset);
    //直接采样 URP 每帧生成的不透明场景拷贝（不含水面，2x 降采样，天然柔和）
    float3 refractBase = SampleSceneColor(screenUV+refractOffset);
    float3 refractColor = lerp(refractBase,baseColor,depthWeight);

    //SSS（背光透光）
    float3 SSSHalf = -normalize(light.direction + _SSSDistort*normalWS);
    float SSS = pow(saturate(dot(viewDir,SSSHalf)),_SSSPower)*_SSSIntensity;
    float3 SSSColor = lightColor * SSS * _SSSColor.rgb * shadowAtten;

    //Blinn-Phong
    float3 halfDir = normalize(lightDir+viewDir);
    float NdotH = saturate(dot(normalWS,halfDir));
    float NdotL = saturate(dot(normalWS, lightDir));
    //高光随距离变软：近处保留碎金，远处波面细节被平均掉，顺便压掉 specular aliasing,
    //典型的“距离 LOD”思路套在高光指数上。
    const float specSoftDist = 300.0;
    float specPower = lerp(_SpecularPower, 8.0, saturate(distToCam / specSoftDist));
    //Blinn-Phong 归一化 (p+8)/(8π)：让 _SpecularPower 只改形状、不改总能量
    float specNorm = (specPower + 8.0) / (8.0 * PI);
    //乘 NdotL：太阳转到水面背后时不应该还有高光
    float specular = specNorm * pow(NdotH, specPower) * _SpecularIntensity * NdotL;
    float3 specularColor = lightColor*specular*_WaterSpecularColor.rgb * shadowAtten;

    //Fresnel结合
    float3 F = FresnelSchlick(NdotV, _FresnelF0);
    float3 reflectionWeight = saturate(F * _ReflectionIntensity);
    //反射和折射按菲涅尔混合
    float3 waterColor = lerp(refractColor, reflectColor, reflectionWeight);

    //高光和SSS是加色效果，不参与反射/折射混合，最后叠上去
    float3 finalColor = waterColor + specularColor + SSSColor;

    //Foam
    float foamMask = pow(saturate(1.0 - depthDiff / max(_FoamScope, 0.0001)), _FoamPower);
    float2 foamUV = TRANSFORM_TEX(i.foamData.xy, _FoamTex) + _Time.y * _FoamFlow.xy;
    float foamNoise = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, foamUV).r;
    //Contrast 把纹理的细纹压出来，Coverage 补一点底色（否则只剩几根线）
    float foamShape = saturate(foamNoise * _FoamContrast + _FoamCoverage);

    //近岸"往岸上推"的呼吸
    float foamPhase = depthDiff * _FoamInterval + _Time.y * _FoamSpeed;
    float foamPulse = lerp(0.6, 1.0, (sin(foamPhase) * 0.5 + 0.5));

    //4.浪尖白沫：波高超过 _FoamCrestHeight 就出沫，和近岸遮罩取 max
    float crest = saturate((i.foamData.z - _FoamCrestHeight) * _FoamCrestScale);
    float foamAmount = max(foamMask * foamPulse, crest * _FoamCrestIntensity);

    float foam = saturate(foamAmount * foamShape * _FoamIntensity);
    //泡沫也要吃光照和阴影
    float3 foamLit = _FoamColor.rgb * (0.35 + lightColor * NdotL * shadowAtten);
    finalColor = lerp(finalColor, foamLit, foam);

    return float4(finalColor,1);
}
