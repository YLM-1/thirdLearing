#ifndef _SHADE_
#define _SHADE_

#include "WhittedRayTracing.hlsl"

////////////// chapter3_1 //////////////
//TextureCube：专门用于存储 6 个方形纹理组合而成的立方体贴图，常用于天空盒、环境光照或反射贴图。
TextureCube<float4> skyBoxCube;
SamplerState sampler_LinearClamp;

////////////// chapter2_1 //////////////
float3 Shade(RayHit hit,inout Ray ray)
{
    if(hit.distance<1e20)
    {
        ray.energy *= WhittedRayTracing(hit,/*inout */ray);

        //return 0只是代表物体表面没有自身发光
        return 0;
    }
    else
    {
        ray.energy = 0;

        //如果射线和场景没有交互，则采样skyBoxoxCube
        float3 dir = ray.direction;
        float3 skyBoxColor = skyBoxCube.SampleLevel(sampler_LinearClamp,dir,0).rgb;
        return skyBoxColor;
    }
}

#endif