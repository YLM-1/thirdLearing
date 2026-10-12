using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using Unity.Mathematics;

public class MeshCollector : MonoBehaviour
{
   public Transform planeParent;
   public Transform sphereParent;
   public Transform cubeParent;

    ////////////// chapter2_2 //////////////
   struct Plane
   {
      public Vector3 position;
      public Vector3 normal;
      public Vector3 size;

      public Plane(Renderer r)
      {
           position = r.transform.position;
           normal = r.transform.up;
           //场景中的 Plane 用的是 Unity 内置 Plane 网格，它默认就是 10×10 大小，而 localScale 是 (1,1,1)。
           size = r.transform.localScale*10f;
            // position = r.bounds.center;
            // normal = r.transform.up;
            // size = r.bounds.size;
      }
   };
   private ComputeBuffer planeBuffer;

    ////////////// chapter2_3 //////////////
    struct Sphere
    {
        public Vector3 center;
        public float radius;
        public Sphere(Renderer r)
        {
            center = r.transform.position;
            radius = r.transform.localScale.x/2;
        }
    }
    private ComputeBuffer sphereBuffer;

    struct Cube
    {
        public Vector3 min;
        public Vector3 max;
        public Cube(Renderer r)
        {
            Vector3 pos = r.transform.position;
            Vector3 halfSize = r.transform.localScale/2;
            min = pos - halfSize;
            max = pos + halfSize;
        }
    }
    private ComputeBuffer cubeBuffer;

   public void Init(ComputeShader cs,int kernelHandle)
   {
       InitPlane(cs,kernelHandle);

       ////////////// chapter2_3 //////////////
       InitSphere(cs,kernelHandle);
       InitCube(cs,kernelHandle);
   }

   private void InitPlane(ComputeShader cs,int kernelHandle)
   {
       Plane[] planes = (from r in planeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Plane(r)).ToArray();
       planeBuffer = new ComputeBuffer(planes.Length,sizeof(float)*9);
       planeBuffer.SetData(planes);

       cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
       cs.SetInt("planeCount",planes.Length);
   }

   private void InitSphere(ComputeShader cs,int kernekHandle)
   {
       Sphere[] spheres = (from r in sphereParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Sphere(r)).ToArray();
       sphereBuffer = new ComputeBuffer(spheres.Length,sizeof(float)*4);
       sphereBuffer.SetData(spheres);

       cs.SetBuffer(kernekHandle,"sphereBuffer",sphereBuffer);
       cs.SetFloat("sphereCount",spheres.Length);
   }

    private void InitCube(ComputeShader cs,int kernekHandle)
   {
       Cube[] cubes = (from r in cubeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Cube(r)).ToArray();
       cubeBuffer = new ComputeBuffer(cubes.Length,sizeof(float)*6);
       cubeBuffer.SetData(cubes);

       cs.SetBuffer(kernekHandle,"cubeBuffer",cubeBuffer);
       cs.SetFloat("cubeCount",cubes.Length);
   }

   private void OnDestroy() 
   {
       planeBuffer?.Dispose(); 
   }
}
