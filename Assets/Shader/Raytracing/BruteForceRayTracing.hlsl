#ifndef __BRUTEFORCERAYTRACING_
#define __BRUTEFORCERAYTRACING_


////////////// chapter2_1 //////////////
struct Plane
{
    float3 position;
    float3 normal;
    float3 size;
};

StructuredBuffer<Plane> planeBuffer;
int planeCount;

////////////// chapter2_2 //////////////
struct Sphere
{
    float3 center;
    float radius;
};
StructuredBuffer<Sphere> sphereBuffer;
const int sphereCount;

struct Cube
{
    float3 min;
    float3 max;
};
StructuredBuffer<Cube> cubeBuffer;
const  int cubeCount;

////////////// chapter2_2 //////////////
void IntersectPlane(Ray ray,Plane plane,inout RayHit hit)
{
    float t = dot(plane.normal,plane.position - ray.origin)/dot(plane.normal,ray.direction);
    if (t > 0 && t < hit.distance)
	{
		float3 min = plane.position - plane.size / 2;
        float3 max = plane.position + plane.size / 2;

		float3 p = ray.origin + t * ray.direction;
		if (p.x > min.x && p.x < max.x && p.y > min.y && p.y < max.y && p.z > min.z && p.z < max.z)
		{
			hit.distance = t;
            hit.position = p;
            hit.normal = plane.normal;
		}
    }
}

////////////// chapter2_2 //////////////
void IntersectSphere(Ray ray,Sphere sphere,inout RayHit hit)
{
    float3 dir = sphere.center - ray.origin;
    float dist = length(dir);

    //如果射线从球体内部发射，则不用求交
    if(dist < sphere.radius)
      return;
    float l = dot(dir,normalize(ray.direction));
    //如果射线方向不是朝向球体，则不需要求交
    if(l<0)
       return;
    float m = sqrt(dist*dist-l*l);
    //如果垂足距离大于半径则不需要求交
    if(m>sphere.radius)
       return;
    float q = sqrt(sphere.radius*sphere.radius - m*m);
    hit.distance = l-q;
    hit.position = ray.origin + hit.distance*ray.direction;
    hit.normal = normalize(hit.position - sphere.center); 
}

void IntersectCube(Ray ray,Cube cube,inout RayHit hit)
{
    float3 invDir = 1.0f / ray.direction;
    float3 tMin = (cube.min - ray.origin) * invDir;
    float3 tMax = (cube.max - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);

    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);

    if (tNear > tFar)
        return;

    float3 normal = float3(1, 0, 0);
    if (tNear == t1.y)
        normal = float3(0, 1, 0);
    else if (tNear == t1.z)
        normal = float3(0, 0, 1);

    normal *= sign(ray.origin - (cube.min + cube.max) * 0.5);

    hit.distance = tNear;
    hit.position = ray.origin + tNear * ray.direction;
    hit.normal = normal;
}

////////////// chapter2_1 //////////////
RayHit BruteForceRayTrace(Ray ray)
{
    RayHit hit = CreateRayHit();

    ////////////// chapter2_2 //////////////
    //处理射线和所有的plane交互
    for(int i=0;i<planeCount;i++)
    {
        Plane plane = planeBuffer[i];
        IntersectPlane(ray,plane,/*inout */hit);
    }

    for(int j = 0;j<sphereCount;j++)
    {
        Sphere sphere = sphereBuffer[j];
        IntersectSphere(ray,sphere,/*inout */hit);
    }

    for(int k = 0;k<cubeCount;k++)
    {
        Cube cube = cubeBuffer[k];
        IntersectCube(ray,cube,/*inout */hit);
    }

    return hit;
}

#endif