using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using Unity.Mathematics;
using System;

public class MeshCollector : MonoBehaviour
{
   public Transform planeParent;
   public Transform sphereParent;
   public Transform cubeParent;

   //////////////// chapter3_3 //////////////
   interface Primitive
   {
      public void Init(Renderer r)
      {
        
      }
      
      //接口允许定义 static 方法。既然是静态方法，它就必须带有完整的实现逻辑，因为它不属于某一个具体的对象实例，而是直接挂在 Primitive 接口名之下的工具方法。
      public static void InitMaterial(Renderer r,
        out Vector3 albedo,
        out float metallic,
        out float smoothness,
        out float transparent,
        out Vector3 emissionColor)
      {
        Material mat = r.sharedMaterial;
        
        albedo = new Vector3(mat.color.linear.r,mat.color.linear.g,mat.color.linear.b);
        metallic = Mathf.Max(0.01f,mat.GetFloat("_Metallic"));
        smoothness = Math.Max(0.01f,mat.GetFloat("_Glossiness"));

        transparent = -1;
        emissionColor = Vector3.zero;
        //Surface = 0 为Opaque,Surface = 1，为Transparent
        if((int)mat.GetFloat("_Surface")==1)
           transparent = mat.color.a;
        if(mat.IsKeywordEnabled("_EMISSION"))
        {
            Color color = mat.GetColor("_EmissionColor");
            emissionColor = new Vector3(color.r,color.g,color.b);
        }   
      }
   }

    ////////////// chapter2_2 //////////////
   Camera cam;
   struct Plane : Primitive
   {
      public Vector3 position;
      public Vector3 normal;
      public Vector3 size;
      //////////////// chapter3_3 //////////////
      public Vector3 albedo;
      public float metallic;
      public float smoothness;
      public float transparent;
      public Vector3 emissionColor;

      //Renderer 是 Unity 中所有“可渲染组件”的基类。它本身不能直接挂在物体上用，而是通过它的子类来工作。
      public void Init(Renderer r)
      {
           position = r.transform.position;
           normal = r.transform.up;
           //场景中的 Plane 用的是 Unity 内置 Plane 网格，它默认就是 10×10 大小，而 localScale 是 (1,1,1)。
           size = r.transform.localScale*10f;

           //////////////// chapter3_3 //////////////
           //调用方式：通过接口类型调用，不能通过实现类调用
           Primitive.InitMaterial(r,out albedo,out metallic,out smoothness,out transparent,out emissionColor);
      }
   };
   private ComputeBuffer planeBuffer;

    ////////////// chapter2_3 //////////////
    struct Sphere : Primitive
    {
        public Vector3 center;
        public float radius;
        //////////////// chapter3_3 //////////////
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;
        // public Sphere(Renderer r)
        // {
        //     center = r.transform.position;
        //     radius = r.transform.localScale.x/2;

        //     //////////////// chapter3_3 //////////////
        //     Primitive.InitMaterial(r,out albedo,out metallic,out smoothness,out transparent,out emissionColor);
        // }
        public void Init(Renderer r)
        {
            center = r.transform.position;
            radius = r.transform.localScale.x/2;

            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r,out albedo,out metallic,out smoothness,out transparent,out emissionColor);
        }
    }
    private ComputeBuffer sphereBuffer;

    struct Cube : Primitive
    {
        public Vector3 min;
        public Vector3 max;
        //////////////// chapter3_3 //////////////
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;
        public void Init(Renderer r)
        {
            Vector3 pos = r.transform.position;
            Vector3 halfSize = r.transform.localScale/2;
            min = pos - halfSize;
            max = pos + halfSize;

            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r,out albedo,out metallic,out smoothness,out transparent,out emissionColor);
        }
    }
    private ComputeBuffer cubeBuffer;

   public void Init(ComputeShader cs,int kernelHandle)
   {
       ////////////// chapter2_3 //////////////
       cam = Camera.main;

        //    InitPlane(cs,kernelHandle);

        //    ////////////// chapter2_3 //////////////
        //    InitSphere(cs,kernelHandle);
        //    InitCube(cs,kernelHandle);
        ////////////// chapter3_3 //////////////
       InitPrimitive<Plane>(cs,kernelHandle,18,"planeBuffer","planeCount",planeParent,ref planeBuffer);
       InitPrimitive<Sphere>(cs,kernelHandle,13,"sphereBuffer","sphereCount",sphereParent,ref sphereBuffer);
       InitPrimitive<Cube>(cs,kernelHandle,15,"cubeBuffer","cubeCount",cubeParent,ref cubeBuffer);
   }

//    private void InitPlane(ComputeShader cs,int kernelHandle)
//    {
//        Plane[] planes = (from r in planeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Plane(r)).ToArray();
//        planeBuffer = new ComputeBuffer(planes.Length,sizeof(float)*18);
//        planeBuffer.SetData(planes);

//        cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
//        cs.SetInt("planeCount",planes.Length);
//    }

//    private void InitSphere(ComputeShader cs,int kernekHandle)
//    {
//        //进行z轴深度排序

//        ////这是 LINQ 查询表达式写法,直接通过一行 LINQ 快速筛选并提取出所有的 Sphere，不计算距离，也不进行排序。
//        //Sphere[] spheres = (from r in sphereParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Sphere(r)).ToArray();
//        Dictionary<Renderer,float> di = new Dictionary<Renderer, float>();
//        foreach(Renderer r in sphereParent.GetComponentsInChildren<Renderer>(false))
//        {
//           if(!r.gameObject.activeInHierarchy)
//               continue;

//           float dist = Vector3.Distance(r.transform.position,cam.transform.position);  
//           di.TryAdd(r,dist);  
//        }
//        //根据距离的远近，由远及近排序，在computeShader中，远物体先画
//        //近处物体后画，则完成z排序，绘制得到正确答案
//        //o => o.Value：这里的 o 代表字典里的每一项,ToDictionary：把这个排好序的列表重新打包恢复成一个标准的字典（Dictionary）。
//        di = di.OrderByDescending(o => o.Value).ToDictionary(o=>o.Key,p=>p.Value);

//        Renderer[] rs = di.Keys.ToArray();
//        Sphere[] spheres = new Sphere[di.Keys.Count];
//        for(int i = 0; i<rs.Length;i++)
//           spheres[i] = new Sphere(rs[i]);

//        sphereBuffer = new ComputeBuffer(spheres.Length,sizeof(float)*13);
//        sphereBuffer.SetData(spheres);

//        cs.SetBuffer(kernekHandle,"sphereBuffer",sphereBuffer);
//        cs.SetFloat("sphereCount",spheres.Length);
//    }

//     private void InitCube(ComputeShader cs,int kernekHandle)
//    {
//        //进行z轴排序
//        //Cube[] cubes = (from r in cubeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Cube(r)).ToArray();

//        Dictionary<Renderer,float> di = new Dictionary<Renderer, float>();
//        foreach(Renderer r in cubeParent.GetComponentsInChildren<Renderer>(false))
//        {
//            if(!r.gameObject.activeInHierarchy)
//               continue;
//            float dist = Vector3.Distance(r.transform.position,cam.transform.position);
//            di.TryAdd(r,dist);   
//        }
//        di = di.OrderByDescending(o => o.Value).ToDictionary(o=>o.Key,p=>p.Value);
//        Renderer[] rs = di.Keys.ToArray();
//        Cube[] cubes = new Cube[rs.Length];
//        for(int i = 0;i<rs.Length;i++)
//            cubes[i] = new Cube(rs[i]);
       
//        if(cubes.Length>0)
//        {
//             cubeBuffer = new ComputeBuffer(cubes.Length,sizeof(float)*15);
//        }
//        else
//        {
//             cubeBuffer = new ComputeBuffer(1,sizeof(float)*15);   
//        }
//        cubeBuffer.SetData(cubes);

//        cs.SetBuffer(kernekHandle,"cubeBuffer",cubeBuffer);
//        cs.SetFloat("cubeCount",cubes.Length);
//    }

   //////////////// chapter3_3 //////////////
   private void InitPrimitive<T>(ComputeShader cs,
                                 int kernelHandle,
                                 int size,
                                 string bufferName,
                                 string bufferCountName,
                                 Transform parent,
                                 ref ComputeBuffer buffer) where T :Primitive,new()
   {
       Dictionary<Renderer,float> di = new Dictionary<Renderer, float>();
       foreach(Renderer r in parent.GetComponentsInChildren<Renderer>(false))
       {
           if(!r.gameObject.activeInHierarchy)
              continue;
           float dist = Vector3.Distance(r.transform.position,cam.transform.position);
           di.TryAdd(r,dist);   
       }
       di = di.OrderByDescending(o => o.Value).ToDictionary(o=>o.Key,p=>p.Value);
       Renderer[] rs = di.Keys.ToArray();
       T[] primitives = new T[rs.Length];
       for(int i = 0;i<rs.Length;i++)
       {
           //primitives[i] = new T(rs[i]);你的泛型约束不允许这样做，在开头new()这是无参构造函数，T 目前没有定义接收 Renderer 参数的构造函数。
            primitives[i] = new T();
            primitives[i].Init(rs[i]);
       }

       if(parent == null||primitives.Length ==0)
          primitives = new T[1]{new T()};

        buffer = new ComputeBuffer(primitives.Length,sizeof(float)*size);
        buffer.SetData(primitives);

        cs.SetBuffer(kernelHandle,bufferName,buffer);
        cs.SetInt(bufferCountName,primitives.Length); 
   }

   private void OnDestroy() 
   {
       planeBuffer?.Dispose(); 
       sphereBuffer?.Dispose();
       cubeBuffer?.Dispose();
   }
}
