#ifndef _WHITTEDRAYTRACING_
#define _WHITTEDRAYTRACING_

float3 reflectFunction(float3 I,float3 N)
{
    return I-2*dot(N,I)*N;
}

////////////// chapter3_1 //////////////
float3 WhittedRayTracing(RayHit hit,inout Ray ray)
{
    ray.origin = hit.position + hit.normal*0.01f;
    ray.direction = reflectFunction(ray.direction,hit.normal);

    return 1;
}

#endif