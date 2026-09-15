using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter5_3 : MonoBehaviour
{

    //RigidBody 决定了整体怎么动，
    // 而 Particle 则是将刚体的宏观运动分解到了微观的具体空间点上
   struct RigidBody
   {
       public Vector3 position;
       public Quaternion quaternion;  //Quaternion:四元数

       public Vector3 linearVelocity;   //描述刚体运动时横纵坐标（位移）的运动快慢（整体平均速度）
       public Vector3 angularVelocity;  //描述刚体在运动时角度随时间运动的快慢（旋转角速度）

       public int particleIndex;       //第0个粒子在全局数组里的下标
       public int particleCount;

       public RigidBody(Vector3 pos,int pIndex,int pCount)
        {
            position=pos;
            quaternion = Random.rotation;
            linearVelocity = angularVelocity = Vector3.zero;
            particleCount=pCount;
            particleIndex=pIndex;
        }
   };

   struct Particle
   {
      public Vector3 position;   //世界空间
      public Vector3 velocity;
      public Vector3 force;
      public Vector3 localPosition;  //局部坐标下相对于rigdBody的位移
      public Vector3 offsetPosition;  //世界空间下相对于rigdBody的位移
   };

   //初始化rigdBody,particles
   [SerializeField]private int rigidBodyCount = 1000;
   [SerializeField]private float rigidBodyRange = 20f;
   [SerializeField]private float edgeLength = 1f;      //立方体的边长
   [SerializeField]private int particlesPerEdge = 4;    //立方体每条变最多有几个粒子

   RigidBody[] rigidBodies;
   Particle[] particles;
   int particlesPerBody;

   //初始化ComputeBuffer
   ComputeBuffer rigidBodyBuffer;
   ComputeBuffer particleBuffer;
   ComputeBuffer argsBuffer;

   //初始化shader
   [SerializeField]private ComputeShader cs;
   [SerializeField]private Mesh cubeMesh;
   [SerializeField]private Material cubeMat;

   Bounds bounds;
   uint[] args = new uint[5] {0,0,0,0,0};

   int kernelUpdateParticle;
   int kernelComputeParticle;
   int kernelComputeRigidBody;
   int kernelComputeRigidBodyMovement;

    [SerializeField]private float springCoefficient=1f;
    [SerializeField]private float dampingCoefficient=0.1f;
    [SerializeField]private float tangentialCoefficient=1f;
    [SerializeField]private float gravityCofficient=1f;

    //debug
    [SerializeField] private bool isDebugParticle=false;
    [SerializeField] private Mesh debugParticleMesh;
    [SerializeField] private Material debugParticleMat;
    ComputeBuffer debugParticlesBuffer;
    uint[] debugArgs = new uint[5]{0,0,0,0,0};

    [SerializeField] private float linearForceScalar=1f;
    [SerializeField] private float angularForceScalar=1f;
    [SerializeField] private float cubeMass=10f;

    [SerializeField] private bool isDebugRigidBody = false;
    [SerializeField] private bool isDebugGrid = false;

    //绘制Grid相关
    [SerializeField] private bool isUseGrid=true;
    private Vector3 gridStartPos;
    int kernelPopulateGrid;
    int kernelClearGrid;
    int kernelComputeParticleInGrid;
    ComputeBuffer voxelGridBuffer;


   private void Start()
   {
       InitRigdBody();
       InitParticle();
       InitBuffer();
       InitMesh();
       InitGrid();
       InitShader();
       InitInstancing();
   }

   private void InitShader()
   {
       kernelUpdateParticle = cs.FindKernel("UpdateParticle");
       cs.SetBuffer(kernelUpdateParticle,"rigidBodyBuffer",rigidBodyBuffer);
       cs.SetBuffer(kernelUpdateParticle,"particleBuffer",particleBuffer);

       kernelComputeParticle = cs.FindKernel("ComputeParticle");
       cs.SetBuffer(kernelComputeParticle,"particleBuffer",particleBuffer);

       cs.SetInt("allParticleCount",particlesPerBody*rigidBodyCount);
       cs.SetFloat("particleDiameter",edgeLength/particlesPerEdge);
       //粒子计算时候力的各种系数
       cs.SetFloat("springCoefficient",springCoefficient);
       cs.SetFloat("dampingCoefficient",dampingCoefficient);
       cs.SetFloat("tangentialCoefficient",tangentialCoefficient);
       cs.SetFloat("gravityCofficient",gravityCofficient);

       kernelComputeRigidBody = cs.FindKernel("ComputeRigidBody");
       cs.SetBuffer(kernelComputeRigidBody,"rigidBodyBuffer",rigidBodyBuffer);
       cs.SetBuffer(kernelComputeRigidBody,"particleBuffer",particleBuffer);
       cs.SetFloat("linearForceScalar",linearForceScalar);
       cs.SetFloat("angularForceScalar",angularForceScalar);
       cs.SetFloat("cubeMass",cubeMass);

       kernelComputeRigidBodyMovement = cs.FindKernel("ComputeRigidBodyMovement");
       cs.SetBuffer(kernelComputeRigidBodyMovement,"rigidBodyBuffer",rigidBodyBuffer);

       //计算grid相关
       kernelPopulateGrid = cs.FindKernel("PopulateGrid");
       kernelClearGrid = cs.FindKernel("ClearGrid");
       kernelComputeParticleInGrid = cs.FindKernel("ComputeParticleInGrid");
       cs.SetBuffer(kernelPopulateGrid,"voxelGridBuffer",voxelGridBuffer);
       cs.SetBuffer(kernelPopulateGrid,"particleBuffer",particleBuffer);
       cs.SetBuffer(kernelClearGrid,"voxelGridBuffer",voxelGridBuffer);
       cs.SetBuffer(kernelComputeParticleInGrid,"particleBuffer",particleBuffer);
       cs.SetBuffer(kernelComputeParticleInGrid,"voxelGridBuffer",voxelGridBuffer);
       cs.SetVector("gridStartPos",gridStartPos);
       cs.SetFloat("gridSize",100/edgeLength*particlesPerEdge);
   }

   private void InitRigdBody()
   {
        int pIndex = 0;
        particlesPerBody = particlesPerEdge * particlesPerEdge *particlesPerEdge;

        rigidBodies = new RigidBody[rigidBodyCount];
        for(int i = 0;i<rigidBodyCount;i++)
        {
            Vector3 pos = Random.insideUnitSphere*rigidBodyRange + transform.position;
            rigidBodies[i] = new RigidBody(pos,pIndex,particlesPerBody);
            pIndex += particlesPerBody;
        }
   }

   private void InitParticle()
   {
        particles = new Particle[particlesPerBody * rigidBodyCount];

        float offset = edgeLength/particlesPerEdge/2*(particlesPerEdge-1);

        Vector3 startPos = new Vector3(-offset,-offset,-offset);
        float particleDiameter = edgeLength/particlesPerEdge;

        int index = 0;
        for(int x=0;x<particlesPerEdge;x++)
        {
            for(int y=0;y<particlesPerEdge;y++)
            {
                for(int z=0;z<particlesPerEdge;z++)
                {
                    Vector3 pos = startPos + new Vector3(x,y,z)*particleDiameter;
                    //为所有刚体（RigidBody）在同一相对位置上批量初始化粒子（Particle），并记录其相对局部坐标。
                    for(int i = 0;i<rigidBodyCount;i++)
                    {
                        RigidBody body = rigidBodies[i];

                        Particle particle = new Particle();
                        particle.localPosition = pos;
                        //绝对位置（数组索引） = 当前刚体的起始位置 + 粒子在刚体内部的相对编号
                        particles[body.particleIndex + index] = particle;
                    }

                    index++;
                }
            }
        }
   }

   private void InitBuffer()
   {
      int rigidBodySize = sizeof(float)*13+sizeof(int)*2;
      rigidBodyBuffer = new ComputeBuffer(rigidBodyCount,rigidBodySize);
      rigidBodyBuffer.SetData(rigidBodies);

      int particleBodySize = sizeof(float)*15;
      particleBuffer = new ComputeBuffer(rigidBodyCount*particlesPerBody,particleBodySize);
      particleBuffer.SetData(particles);

      //grid相关
      int gridSize = (int)(100/edgeLength*particlesPerEdge);
      voxelGridBuffer = new ComputeBuffer(gridSize*gridSize*gridSize,8*sizeof(int));
   }

    private void InitMesh()
    {
        bounds = new Bounds(Vector3.zero,Vector3.one*edgeLength);
        args[0] = (uint)cubeMesh.GetIndexCount(0);
        args[1] = (uint)rigidBodyCount;
        argsBuffer = new ComputeBuffer(1,5*sizeof(uint),ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        debugArgs[0] = debugParticleMesh.GetIndexCount(0);
        debugArgs[1] = (uint)(rigidBodyCount*particlesPerBody);
        debugParticlesBuffer = new ComputeBuffer(1,sizeof(uint)*5,ComputeBufferType.IndirectArguments);
        debugParticlesBuffer.SetData(debugArgs);
    }

    private void InitInstancing()
    {
        cubeMat.SetBuffer("rigidBodyBuffer",rigidBodyBuffer);
        cubeMat.SetFloat("edgeLength",edgeLength);

        debugParticleMat.SetBuffer("particleBuffer",particleBuffer);
        debugParticleMat.SetFloat("particleDiameter",edgeLength/particlesPerEdge);
    }

    private void Update()
    {
        cs.SetFloat("deltaTime",Time.deltaTime);

         cs.Dispatch(kernelUpdateParticle,Mathf.CeilToInt((float)rigidBodyCount/8),1,1);
        if(isUseGrid)
        {
            //grid相关参数
            int gridSize = (int)(100/edgeLength*particlesPerEdge);
            cs.Dispatch(kernelClearGrid,Mathf.CeilToInt((float)gridSize*gridSize*gridSize/1024),1,1);
            cs.Dispatch(kernelPopulateGrid,Mathf.CeilToInt((float)rigidBodyCount*particlesPerBody/1024),1,1);
            cs.Dispatch(kernelComputeParticleInGrid,Mathf.CeilToInt((float)rigidBodyCount*particlesPerBody/1024),1,1);
        }
        else
        {
            cs.Dispatch(kernelComputeParticle,Mathf.CeilToInt((float)rigidBodyCount*particlesPerBody/8),1,1);
        }
        cs.Dispatch(kernelComputeRigidBody,Mathf.CeilToInt((float)rigidBodyCount/8),1,1);
        cs.Dispatch(kernelComputeRigidBodyMovement,Mathf.CeilToInt((float)rigidBodyCount/8),1,1);

        if(isDebugParticle)
           Graphics.DrawMeshInstancedIndirect(debugParticleMesh,0,debugParticleMat,bounds,debugParticlesBuffer);
        else
           Graphics.DrawMeshInstancedIndirect(cubeMesh,0,cubeMat,bounds,argsBuffer);   

        
    }

    private void InitGrid()
    {
        float cellSize = edgeLength/particlesPerEdge;
        int gridSize = (int)(100/edgeLength*particlesPerEdge);
        //网格必须覆盖刚体生成范围：以transform.position为中心，半边长 = gridSize*cellSize/2
        gridStartPos = transform.position - Vector3.one*gridSize*cellSize*0.5f;
    }

    private void OnDestroy()
    {
        rigidBodyBuffer?.Release();
        particleBuffer?.Release();
        argsBuffer?.Release();
        debugParticlesBuffer?.Release();
        voxelGridBuffer?.Release();
    }

    //它的主要作用是在 Scene（场景）视图中绘制辅助线框、形状或图标，用于帮助开发者在编辑器里直观地调试和查看数据，
    // 而不会渲染到最终的游戏画面（Game 视图）中。
    //只要把这个方法写在继承自 MonoBehaviour 的脚本里，Unity 会在编辑器模式或运行模式下自动每帧调用它。
    private void OnDrawGizmos()
    {
        if(isDebugRigidBody)
        {
            if(rigidBodies!=null)
            {
                for(int i=0;i<rigidBodies.Length;i++)
                {
                    //绘制Cube
                    //都以当前刚体的位置和朝向作为临时原点与坐标轴
                    Gizmos.matrix = Matrix4x4.TRS(rigidBodies[i].position,rigidBodies[i].quaternion,Vector3.one);//S:缩放
                    Gizmos.color = Color.green;
                    Gizmos.DrawWireCube(Vector3.zero,Vector3.one*edgeLength);//绘制边框

                    //绘制Particles
                    Gizmos.color = Color.white;
                    for(int j=0;j<rigidBodies[i].particleCount;j++)
                    {
                        Vector3 particlePos = particles[rigidBodies[i].particleIndex+j].localPosition;
                        Gizmos.DrawWireSphere(particlePos,edgeLength/particlesPerEdge/2f);
                    }
                }
            }
        }
        if(isDebugGrid)
        {
            if(particleBuffer==null)
               return;
            Particle[] ps = new Particle[rigidBodyCount*particlesPerBody];
            particleBuffer.GetData(ps);//从GPU拿到CPU显存

            List<Vector3> list = new List<Vector3>();
            List<Vector3> list2 = new List<Vector3>();   

            Gizmos.matrix = Matrix4x4.identity;
            Gizmos.color = Color.grey;

            int count = (int)(100/edgeLength);
            for(int x = 0;x<count;x++)
            {
                for(int y=0;y<count;y++)
                {
                    for(int z=0;z<count;z++)
                    {
                        // 计算当前网格格子的世界坐标中心点
                        Vector3 pos = gridStartPos + new Vector3(x,y,z)*edgeLength;

                        // 2. 遍历所有粒子，检测是否有粒子落在这个格子内部
                        for(int p=0;p<particlesPerBody*rigidBodyCount;p++)
                        {
                            if(Vector3.Distance(ps[p].position,pos)<edgeLength/particlesPerEdge)
                            {
                                for (int xx = x - 1; xx <= x + 1; ++xx)
                                {
                                    for (int yy = y - 1; yy <= y + 1; ++yy)
                                    {
                                        for (int zz = z - 1; zz <= z + 1; ++zz)
                                        {
                                            list2.Add(gridStartPos + new Vector3(xx, yy, zz) * edgeLength);
                                        }
                                    }
                                }
                                list.Add(pos);
                                break;
                            }
                        }
                    }
                }
            }

            Gizmos.color = Color.blue;
            for(int i=0;i<list2.Count;i++)
            {
                Gizmos.DrawWireCube(list2[i],Vector3.one*edgeLength);
                if(i>27)
                  break;
            }

            Gizmos.color = Color.green;
            count *= particlesPerEdge;
            for (int i = 0; i < list.Count; ++i)
            {
                Vector3 gridLocation = (list[i] - gridStartPos) / (edgeLength / particlesPerEdge);
                int gridIndex = (int)(gridLocation.x + count * gridLocation.z + (count * count * gridLocation.y));
                break;
            }
        }
    }
}
