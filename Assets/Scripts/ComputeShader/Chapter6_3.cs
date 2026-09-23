using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;
using UnityEngine.Rendering;
using Unity.Mathematics;

public class Chapter6_3 : MonoBehaviour
{
   [SerializeField] private ComputeShader cs;

   //Step1:Advanced Mesh API
   //驱动mesh的顶点来之前布料的模拟
   Mesh originalMesh;
   Mesh newMesh;
   GraphicsBuffer originalIndexBuffer;//三角形顶点索引
   GraphicsBuffer originalVertexBuffer;//初始静止坐标、初始法线、初始 UV
   GraphicsBuffer vertexBuffer;//最新动态坐标、最新法线、最新切线

   int kernelComputeMeshTest;
   int triangleCount;

   struct MeshVertex
   {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 tangent;
        public Vector2 uv;
   }

   //Step2:编写大概框架
   [Range(0f,0.1f)]
   [SerializeField] private float timeStep=0.005f;
   private float nexFrameTime = 0f;
   struct Particle
   {
        public Vector3 position;
        public Vector3 predictPosition;
        public Vector3 velocity;
        public Vector3 normal;
        public float mass;
        public int constraintsType;//用来记录该粒子是否和碰撞体有轴约束0:Distance距离约束,1:pin固定位置约束,2:Collosion碰撞约束
   }
   private ComputeBuffer particleBuffer;
   private int particleCount;
   private int kernelInitParticle;
   private int kernelComputeParticle;
   private int kernelComputeMesh;

   //Step3；处理外力
   [SerializeField] private Vector3 gravity = new Vector3(0,1,0);//重力
   [SerializeField] private Vector3 wind = new Vector3(1,3,4);//风力
   [SerializeField] private float density = 1;//粒子密度，用来计算mass
   [Range(0,0.2f)]
   [SerializeField] private float dampingForec=0.1f; //阻力
   private int kernelComputeExternalForce;

   //Step4:碰撞约束
   //球体的碰撞体
   public SphereCollider[] sphereColliders;
    struct SphereColliderDesc
    {
        public Vector3 center;  //世界坐标系下
        public float radius;

        public SphereColliderDesc(SphereCollider sc)
        {
            center = sc.transform.position + sc.center;
            radius = sc.transform.localScale.x * sc.radius;
        }
    };
    private SphereColliderDesc[] sphereColliderDescs;
    private ComputeBuffer sphereColliderBuffer;
    private int sphereColliderCount;

    //立方体的碰撞体
    public BoxCollider[] boxColliders;
    struct BoxColliderDesc
    {
        public Vector3 min;
        //xyz代表轴在世界空间下的朝向，w代表length
        public Vector4 ax;
        public Vector4 ay;
        public Vector4 az;

        public BoxColliderDesc(BoxCollider bc)
        {
            Matrix4x4 mat = bc.transform.localToWorldMatrix;
            Vector3 size = bc.size;

            //xyz为Normalized方向，w为长度
            Vector3 dx = mat.MultiplyVector(new Vector3(size.x,0,0));//MultiplyVecto：只缩放和旋转
            Vector3 dy = mat.MultiplyVector(new Vector3(0,size.y,0));
            Vector3 dz = mat.MultiplyVector(new Vector3(0,0,size.z));

            min = mat.MultiplyPoint(bc.center - size/2);
            ax = new Vector4(dx.normalized.x,dx.normalized.x,dx.normalized.x,dx.magnitude);
            ay = new Vector4(dy.normalized.x,dy.normalized.y,dz.normalized.z,dy.magnitude);
            az = new Vector4(dz.normalized.x,dz.normalized.y,dz.normalized.z,dz.magnitude);
       }
    }
    private BoxColliderDesc[] boxColliderDescs;
    private ComputeBuffer boxColliderBuffer;
    private int boxColliderCount;

    //使用这个数据来记录碰撞本身的信息
    struct CollisionInfo
    {
        public Vector3 constrainPosition;
        public Vector3 velocity;
        public Vector3 normal;
    }
    private ComputeBuffer collisionInfoBuffer;
    
    int kernelInitCollisionConstraints;
    int kernelComputeCollisionConstraints;

    private void Start()
    {
        UpdateParameters();
        //Step1:交接Advanced Mesh API
        GenerateMesh();

        //step2:初始化质点相关
        InitParticles();
        //将布料粒子和Mesh创建驱动
        InitComputeMesh();
        //计算外力
        InitExternalForce();
        //初始化碰撞约束
        InitCollisionConstrain();
        //定义布料的粒子的粒子结构
        InitComputeParticles();
    }

    private void Update()
    {
        //Step1:交接Advanced Mesh API
        cs.SetFloat("time",Time.time);
        // DispatchThreads(kernelComputeMeshTest, triangleCount);

        //Step2:编写大概框架
        IterateParticles();
    }

    //Step1:交接Advanced Mesh API
    private Mesh CreateMesh(Mesh original)
    {
        //拿到所有三角面
        int[] originalTriangles = original.triangles;
        //拿到所有顶点
        Vector3[] originalPosition = original.vertices;
        //拿到所有法线
        Vector3[] originalNormals = original.normals;
        Vector3[] originalTangents = (from t in original.tangents select new Vector3(t.x, t.y, t.z)).ToArray();
        Vector2[] originalUVs = original.uv;

        Mesh mesh = new Mesh();

        //Byte Address uffer,读写时，把buffer里的内容（byte）做偏移，可用于寻址
        //对应hlsl的ByyeAddressBuffer,RWByteAddressBuffer
        mesh.indexBufferTarget |= GraphicsBuffer.Target.Raw; 
        mesh.vertexBufferTarget |= GraphicsBuffer.Target.Raw;

        //VertexAttributeDescriptor 是 Unity 在 2019.3 引入的底层 API，用来向 GPU 精准描述“每一个顶点的数据排版格式”。
        //Vertex position : float32 *3,VertexAttributeFormat.Float32他有4个字节所以是32Byte
        VertexAttributeDescriptor pDesc = new VertexAttributeDescriptor(VertexAttribute.Position,VertexAttributeFormat.Float32,3);
        VertexAttributeDescriptor nDesc = new VertexAttributeDescriptor(VertexAttribute.Normal,VertexAttributeFormat.Float32,3);
        VertexAttributeDescriptor tDesc = new VertexAttributeDescriptor(VertexAttribute.Tangent,VertexAttributeFormat.Float32,3);
        VertexAttributeDescriptor uvDesc = new VertexAttributeDescriptor(VertexAttribute.TexCoord0,VertexAttributeFormat.Float32,2);

        //按刚才定义的规格（pDesc、nDesc...），在 GPU 显存里开辟出一整块空间，正好能装下 original.vertexCount 个顶点。”
        //SetVertexBufferParams：只是划定区域、建立内存框架（此时里面全是垃圾废数据或空白）。   
        mesh.SetVertexBufferParams(original.vertexCount,pDesc,nDesc,tDesc,uvDesc);

        // 参数 1：索引数据的总长度（例如 1000 个三角形，这里就是 3000）
        // 参数 2：每个索引序号的数据格式（用 32 位无符号整数 int 存储）
        //UInt16（默认 16 位/2字节）：最多只能支持到 65,535 个顶点（超过就会报错/网格破裂）。
        //UInt32（32 位/4字节）：支持几十亿个顶点（高精度大网格/复杂布料必备）。
        mesh.SetIndexBufferParams(originalTriangles.Length,IndexFormat.UInt32);

        //“告诉 MeshRenderer:请拿着刚才塞进显存的这N个三角形索引，配上第 0 号材质球，准备把画面画出来！”
        //参数 1：这里传 0 代表我们要把这段三角形组合交给第 0 个材质球来渲染。
        //参数 2：SubMesh 的范围描述（从索引 0 开始，一共取 Length 个）
        //默认情况下，每次修改 SubMesh，Unity 会在 CPU 端遍历所有顶点去重新算一遍这个网格的长宽高（AABB 包围盒）,通过加上 DontRecalculateBounds 标志，直接禁止 Unity 自动计算！
        mesh.SetSubMesh(0,new SubMeshDescriptor(0,originalTriangles.Length),MeshUpdateFlags.DontRecalculateBounds);

        //开始传递顶点索引
        mesh.SetIndexBufferData(originalTriangles,0,0,originalTriangles.Length);

        //开始传递顶点缓存
        MeshVertex[] vertices = new MeshVertex[original.vertexCount];
        for(var i = 0;i<original.vertexCount;++i)
        {
            vertices[i].position = originalPosition[i];
            vertices[i].normal = originalNormals[i];
            vertices[i].uv = originalUVs[i];
            vertices[i].tangent = originalTangents[i];
        }
        mesh.SetVertexBufferData(vertices,0,0,original.vertexCount);
        mesh.bounds = original.bounds;

        return mesh;
    }

    private void GenerateMesh()
    {
        MeshFilter mf = GetComponent<MeshFilter>();

        originalMesh = CreateMesh(mf.sharedMesh);

        //三角面的个数
        //triangles.Length = 网格的三角形总个数 * 3
        triangleCount = originalMesh.triangles.Length/3;
        newMesh = CreateMesh(mf.sharedMesh);

        mf.mesh = newMesh;

        //初始化buffer
        originalIndexBuffer = originalMesh.GetIndexBuffer();
        originalVertexBuffer = originalMesh.GetVertexBuffer(0);
        vertexBuffer = newMesh.GetVertexBuffer(0);

        kernelComputeMeshTest=cs.FindKernel("ComputeMeshTest");

        //传递数据
        cs.SetBuffer(kernelComputeMeshTest,"originalIndexBuffer",originalIndexBuffer);
        cs.SetBuffer(kernelComputeMeshTest,"originalVertexBuffer",originalVertexBuffer);
        cs.SetBuffer(kernelComputeMeshTest,"vertexBuffer",vertexBuffer);
    }

    private void DispatchThreads(int kernel,int count)
    {
        cs.GetKernelThreadGroupSizes(kernel,out uint threadGroupSizeX,out _,out _);
        int groups = Mathf.CeilToInt((float)count/threadGroupSizeX);
        cs.Dispatch(kernel,groups,1,1);
    }

    //Step2:编写大致框架
    private void InitParticles()
    {
        particleCount = originalMesh.vertexCount;

        kernelInitParticle = cs.FindKernel("InitParticle");
        particleBuffer = new ComputeBuffer(particleCount,sizeof(float)*13+sizeof(int));

        cs.SetBuffer(kernelInitParticle,"originalVertexBuffer",originalVertexBuffer);
        cs.SetBuffer(kernelInitParticle,"originalIndexBuffer",originalIndexBuffer);
        cs.SetBuffer(kernelInitParticle,"particleBuffer",particleBuffer);
        cs.SetInt("particleCount",particleCount);
        cs.SetInt("triangleCount",triangleCount);
        cs.SetMatrix("localToWorldMatrix",transform.localToWorldMatrix);

        //开启的线程组数是根据三角面计算而来的，而不是顶点个数
        DispatchThreads(kernelInitParticle,triangleCount);
    }

    private void InitComputeMesh()
    {
        kernelComputeMesh=cs.FindKernel("ComputeMesh");
        cs.SetBuffer(kernelComputeMesh,"particleBuffer",particleBuffer);
        cs.SetBuffer(kernelComputeMesh,"originalVertexBuffer",originalVertexBuffer);
        cs.SetBuffer(kernelComputeMesh,"originalIndexBuffer",originalIndexBuffer);
        cs.SetBuffer(kernelComputeMesh,"vertexBuffer",vertexBuffer);

        cs.SetMatrix("worldToLocalMatrix",transform.worldToLocalMatrix);
    }

    private void InitComputeParticles()
    {
        kernelComputeParticle = cs.FindKernel("ComputeParticle");
        cs.SetBuffer(kernelComputeParticle,"particleBuffer",particleBuffer);
    }
    //布料算法需要在一个稳定的帧率下进行计算
    //Update() 的调用频率取决于图像渲染的帧率（FPS）。如果场景复杂导致掉帧，或者设备性能波动，Update() 每次调用的时间间隔（即 Time.deltaTime）就会发生剧烈变化。
    private void IterateParticles()
    {
        //1. 累加渲染时间到池子里
        nexFrameTime += Time.deltaTime;
        //计算当前能切出几个固定的 timeStep
        int cnt = Mathf.FloorToInt(nexFrameTime/timeStep);

        //3. 执行固定步长的物理解算
        for(int i=0;i<cnt;i++)
        {
            cs.SetFloat("deltaTime",timeStep);

            //开始布料解算
            DispatchThreads(kernelComputeExternalForce,particleCount);
            //使用粒子来解算，迭代次数是粒子的数量，即模型的顶点数
            DispatchThreads(kernelComputeParticle,particleCount);
            //在计算碰撞约束相关
            DispatchThreads(kernelComputeCollisionConstraints,particleCount);
            //结束布料解算
            //粒子解算完之后，迭代次数是三角形的数量
            DispatchThreads(kernelComputeMesh,triangleCount);
        }
        //后续池子里面剩的时间
        nexFrameTime%=timeStep;
    }

    //Step3:ExternalForce
    private void InitExternalForce()
    {
        kernelComputeExternalForce = cs.FindKernel("ComputeExternalForce");
        cs.SetBuffer(kernelComputeExternalForce,"particleBuffer",particleBuffer);
    }

    //Step4 :计算碰撞约束
    private void InitCollisionConstrain()
    {
        kernelInitCollisionConstraints = cs.FindKernel("InitCollisionConstraints");
        kernelComputeCollisionConstraints = cs.FindKernel("ComputeCollisionConstraints");
    

        //每个粒子碰撞信息初始化
        cs.SetBuffer(kernelInitCollisionConstraints,"particleBuffer",particleBuffer);
        collisionInfoBuffer = new ComputeBuffer(particleCount,sizeof(float)*9);
        cs.SetBuffer(kernelInitCollisionConstraints,"collisionInfoBuffer",collisionInfoBuffer);

        DispatchThreads(kernelInitCollisionConstraints,particleCount);

        //碰撞体初始化
        //通过场景中的碰撞体来初始化自定义的碰撞体结构体
        sphereColliderCount = sphereColliders.Length;
        sphereColliderDescs = new SphereColliderDesc[sphereColliderCount];
        if(sphereColliderCount>0)
        {
            for(int i=0;i<sphereColliderCount;i++)
                sphereColliderDescs[i] = new SphereColliderDesc(sphereColliders[i]);
            sphereColliderBuffer = new ComputeBuffer(sphereColliderCount,sizeof(float)*4);   
            sphereColliderBuffer.SetData(sphereColliderDescs);
        }
        else
          sphereColliderBuffer = new ComputeBuffer(1,sizeof(float)*4);  

        boxColliderCount = boxColliders.Length;
        boxColliderDescs = new BoxColliderDesc[boxColliderCount];
        if(boxColliderCount>0)
        {
            for(int i = 0;i<boxColliderCount;i++)
                boxColliderDescs[i] = new BoxColliderDesc(boxColliders[i]);
            boxColliderBuffer = new ComputeBuffer(boxColliderCount,sizeof(float)*15);
            boxColliderBuffer.SetData(boxColliderDescs);    
        }  
        else
          boxColliderBuffer = new ComputeBuffer(1,sizeof(float)*15);

        cs.SetBuffer(kernelComputeCollisionConstraints,"particleBuffer",particleBuffer);
        cs.SetBuffer(kernelComputeCollisionConstraints,"collisionInfoBuffer",collisionInfoBuffer);
        cs.SetBuffer(kernelComputeCollisionConstraints,"sphereColliderBuffer",sphereColliderBuffer);
        cs.SetBuffer(kernelComputeCollisionConstraints,"boxColliderBuffer",boxColliderBuffer);

        cs.SetInt("sphereColliderCount",sphereColliderCount);
        cs.SetInt("boxColliderCount",boxColliderCount);
    }

    private void UpdateParameters()
    {
        cs.SetVector("gravity",gravity);
        cs.SetVector("wind",wind);
        cs.SetFloat("density",density);
        cs.SetFloat("dampingForec",dampingForec);
    }

    private void OnValidate()
    {
        //只有面板上的数值发生变化的时候，或者start的时候，才会调用
        UpdateParameters();
    }

    private void OnDestroy()
    {
        originalIndexBuffer?.Dispose();
        originalVertexBuffer?.Dispose();
        vertexBuffer?.Dispose();
        particleBuffer?.Dispose();
    }
}