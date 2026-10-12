#ifndef _HEADER_
#define _HEADER_

////////////// chapter2_1 //////////////
#define _MAX_BOUNCE 6

////////////// chapter2_2 //////////////
float4x4 camera2World;
float4x4 cameraInverseProjection;

////////////// chapter2_1 //////////////
struct Ray
{
    float3 origin;
    float3 direction;
};

struct RayHit
{
    float3 position;
    float distance;
    float3 normal;
};

////////////// chapter2_1 //////////////
Ray CreateRay(float3 origin,float3 direction)
{
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    return ray;
}

Ray CreateCameraRay(float2 uv)
{
    float3 origin = mul(camera2World,float4(0,0,0,1)).xyz;
    //
    float3 direction = mul(cameraInverseProjection,float4(uv,0,1)).xyz; 
    //
    direction = mul(camera2World,float4(direction,0)).xyz;

    return CreateRay(origin,direction);
}

RayHit CreateRayHit()
{
    RayHit rayHit;
    rayHit.position = 0;
    rayHit.distance = 1e20;
    rayHit.normal = 0;
    return rayHit;
}

#endif