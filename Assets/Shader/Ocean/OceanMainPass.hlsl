//Wave
float _WaveSpeed;
float _WaveDirection;

// Gerstner parameters; existing wave variables remain for normal-map animation.
float _GerstnerWaveCount;
float _GerstnerRandomDirection;
float _GerstnerWavelengthMax;
float _GerstnerWavelengthMin;
float _GerstnerSteepnessMax;
float _GerstnerSteepnessMin;
float _GerstnerSpeed;
float4 _GerstnerDirection;

//BaseColor
float _DepthFactor;
float4 _DepthColor;
float4 _ShallowColor;

//Reflection
float _Distortion;

//Refraction
float _RefractionDistortion;

//Specular
float _SpecularPower;
float _SpecularIntensity;

//Combine
float _CombineFactor;
float _FresnelInfluence;

TEXTURE2D(_ReflectionTex);
SAMPLER(sampler_ReflectionTex);

TEXTURE2D(_WaveNormalMap);
SAMPLER(sampler_WaveNormalMap);
float4 _WaveNormalMap_ST;


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

struct GerstnerResult { float3 position; float3 tangent; float3 binormal; };

float GerstnerRandom(uint seed)
{
    return frac(sin((float)seed*12.9898)*43758.5453)*2.0-1.0;
}

GerstnerResult GerstnerWave(float3 positionWS)
{
    GerstnerResult result;
    float3 displacement=0;
    float3 tangent=float3(1,0,0);
    float3 binormal=float3(0,0,1);
    float2 baseDirection=normalize(_GerstnerDirection.xy);
    baseDirection=dot(_GerstnerDirection.xy,_GerstnerDirection.xy)>0.0001 ? baseDirection : float2(1,0);
    int waveCount=(int)clamp(_GerstnerWaveCount,1,32);
    for(int index=0;index<waveCount;index++)
    {
        float step=(float)index/(float)waveCount;
        float2 randomDirection=normalize(float2(GerstnerRandom((uint)index),GerstnerRandom((uint)(index*2+1))));
        float2 direction=normalize(lerp(baseDirection,randomDirection,_GerstnerRandomDirection));
        float wavelength=max(0.01,lerp(_GerstnerWavelengthMax,_GerstnerWavelengthMin,step));
        float steepness=lerp(_GerstnerSteepnessMax,_GerstnerSteepnessMin,step)/(float)waveCount;
        float k=2.0*PI/wavelength;
        float amplitude=steepness/k;
        float phase=dot(direction*k,positionWS.xz)-sqrt(9.81*k)*_Time.y*_GerstnerSpeed;
        float sine=sin(phase); float cosine=cos(phase);
        displacement.xz+=direction*amplitude*cosine; displacement.y+=amplitude*sine;
        tangent+=float3(-direction.x*direction.x*k*amplitude*sine,direction.x*k*amplitude*cosine,-direction.x*direction.y*k*amplitude*sine);
        binormal+=float3(-direction.x*direction.y*k*amplitude*sine,direction.y*k*amplitude*cosine,-direction.y*direction.y*k*amplitude*sine);
    }
    result.position=positionWS+displacement; result.tangent=tangent; result.binormal=binormal;
    return result;
}

v2f vert(appdata v)
{
    v2f o;
    o.uv=v.uv;
    float3 worldPos=TransformObjectToWorld(v.vertex.xyz);
    GerstnerResult gerstner=GerstnerWave(worldPos);
    worldPos=gerstner.position;
    o.vertex=TransformWorldToHClip(worldPos);
    o.worldPos=worldPos;
    o.screenPos=ComputeScreenPos(o.vertex);

    o.tangent=normalize(gerstner.tangent);
    o.binormal=normalize(gerstner.binormal);
    o.worldNormal=normalize(cross(o.binormal,o.tangent));
    return o;
}

float3 Normal_TS(float2 uv,Texture2D tex,SamplerState sampler_tex,float speed,float direction)
{
    float time=_Time.y*speed;
    float2 offset=time*float2(sin(direction),cos(direction));
    float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(tex, sampler_tex, uv+offset));
    return normalTS;
}

float3 FresnelSnhlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5);
}

float4 frag(v2f i):SV_TARGET
{
    float2 screenUV=i.screenPos.xy/i.screenPos.w;

    Light light=GetMainLight();
    float3 lightDir=normalize(light.direction);
    float3 viewDirWS=normalize(_WorldSpaceCameraPos-i.worldPos);

    //构建TBN矩阵
    float3x3 TBN=float3x3(i.tangent,i.binormal,i.worldNormal);

    //Wave
    float2 waveUV = TRANSFORM_TEX(i.uv, _WaveNormalMap);
    float3 normalTS0 = Normal_TS(waveUV,_WaveNormalMap,sampler_WaveNormalMap,_WaveSpeed,_WaveDirection);
    float3 normalTS1 = Normal_TS(waveUV,_WaveNormalMap,sampler_WaveNormalMap,-_WaveSpeed,-_WaveDirection);
    float3 normalTS  = normalize(normalTS0+normalTS1);
    float3 normalWS = normalize(mul(normalTS,TBN));

    //水体折射
    float rawDepth=SampleSceneDepth(screenUV);
    float sceneDepth=LinearEyeDepth(rawDepth, _ZBufferParams);
    float surfaceDepth=i.screenPos.w;
    float waterDepth=abs(sceneDepth-surfaceDepth);
    float depthFactor=exp(-_DepthFactor*waterDepth);

    float2 refractOffset=normalWS.xz*_RefractionDistortion;
    float3 refract=SampleSceneColor(screenUV+refractOffset);//SampleSceneColor:用于采样摄像机渲染不透明的场景
    float3 refractColor=refract*_ShallowColor.rgb;

    refractColor=lerp(_DepthColor.rgb,refractColor,depthFactor);

    //水体反射：反射相机渲染的是屏幕空间画面，不能用模型 UV 采样。
    float2 reflectOffset=normalWS.xz*_Distortion;
    float3 reflectColor=SAMPLE_TEXTURE2D(_ReflectionTex,sampler_ReflectionTex,screenUV+reflectOffset).rgb;
    reflectColor=lerp(reflectColor,_DepthColor.rgb,_CombineFactor);

    //BPhong
    float3 halfDir=normalize(viewDirWS+lightDir);
    float NdotH=saturate(dot(normalWS,halfDir));
    float specular=pow(1-NdotH,_SpecularPower)*_SpecularIntensity;
    
    //结合reflect和refraact
    float NdotV=saturate(dot(normalWS,viewDirWS));
    float3 F = FresnelSnhlick(NdotV, float3(0.02,0.02,0.02));
    float3 reflectionWeight=lerp(_CombineFactor,F,_FresnelInfluence);
    float3 finalColor=lerp(refractColor,reflectColor,reflectionWeight);

    finalColor+=specular*light.color.rgb;
    return float4(depthFactor.xxx,1.0);
}
