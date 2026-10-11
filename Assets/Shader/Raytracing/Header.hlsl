#ifndef _HEADER_
#define _HEADER_

////////////// chapter2_1 //////////////
#define _MAX_BOUNCE 6

////////////// chapter2_1 //////////////
struct Ray
{
    float3 origin;
    float3 direction;
};

struct RayHit
{
    float3 position;
    float3 distance;
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
    return CreateRay(0,0);
}

RayHit CreateRayHit()
{
    RayHit rayHit;
    rayHit.position = 0;
    rayHit.distance = 1;
    rayHit.normal = 0;
    return rayHit;
}

#endif