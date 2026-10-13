#ifndef _WHITTEDRAYTRACING_
#define _WHITTEDRAYTRACING_

////////////// chapter3_1 //////////////
float3 reflectFunction(float3 I,float3 N)
{
    return I-2*dot(N,I)*N;
}

////////////// chapter3_2 //////////////
float3 refractFunction(float3 I,float3 N,float eta)
{
    float cosi = clamp(dot(-I,N),-1,1);
    float c0 = cosi;
    float c1 = sqrt(1-eta*eta*(1-cosi*cosi));
    return eta*I+(eta*c0 - c1)*N;
}

////////////// chapter3_1 //////////////
float3 WhittedRayTracing(RayHit hit,inout Ray ray)
{
    ////////////////// chapter3_4 //////////////
    float3 shadow = 1;
    Ray shadowRay = CreateRay(hit.position + hit.normal*0.01f,-lightParameter.xyz);
    RayHit shadowHit =  BruteForceRayTrace(shadowRay);
    if(shadowHit.distance<1e20)
    {
        if(shadowHit.transparent<0)
           shadow = shadowParameter.rgb*shadowParameter.a;
        else
           shadow = 0.5f;   
    }
    if(hit.transparent < 0)
    {
        //反射
        ray.origin = hit.position + hit.normal*0.01f;
        ray.direction = reflectFunction(ray.direction,hit.normal);
        //ray.direction = reflect(ray.direction,hit.normal);
    }
    else
    {
        ////////////// chapter3_2 //////////////
        //折射
        float etai = 1;
        float etat = 1.1;
        bool fromOutSide = dot(ray.direction,hit.normal)<0;
        float3 N = fromOutSide?hit.normal:-hit.normal;
        //在这里使用减法（-）的原因，是由光线折射时“进入”与“离开”不同介质的几何方向决定的。
        //位置需求：折射光线要进入物体内部，其新起点必须位于物体里面。反之亦然
        //配合这里的减法，最终会变成向物体外部偏移，确保光线能够顺利穿出表面，不会因为浮点数精度误差被卡在物体内部造成死循环或黑斑。
        ray.origin = hit.position - N*0.01f;

        float eta = fromOutSide?etai/etat:etat/etai;
        ray.direction = refractFunction(ray.direction,N,eta);
        //ray.direction = refract(ray.direction,hit.normal,eta);
    }

    return hit.albedo*shadow;
}

#endif