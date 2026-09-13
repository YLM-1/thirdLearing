using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter5_2 : MonoBehaviour
{

    //RigidBody 决定了整体怎么动，
    // 而 Particle 则是将刚体的宏观运动分解到了微观的具体空间点上
   struct RigidBody
   {
       public Vector3 position;
       public Quaternion quaternion;  //Quaternion:四元数

       public Vector3 linearVelocity;   //描述刚体运动时横纵坐标（位移）的运动快慢（整体平均速度）
       public Vector3 angularVelocity;  //描述刚体在运动时角度随时间运动的快慢（旋转角速度）

       public int particleIndex;       //组成刚体的粒子的index
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
      public Vector3 positoin;   //世界空间
      public Vector3 velocity;
      public Vector3 force;
      public Vector3 localPosition;  //局部坐标下相对于rigdBody的位移
      public Vector3 offsetPosition;  //世界空间下相对于rigdBody的位移
   };

   //初始化rigdBody,particles
   public int rigidBodyCount = 1000;
   public float rigidBodyRange = 20f;
   public float edgeLength = 1f;      //立方体的边长
   public int particlesPerEdge = 4;    //立方体每条变最多有几个粒子

   RigidBody[] rigidBodies;
   Particle[] particles;
   int particlesPerBody;

   //初始化ComputeBuffer
   ComputeBuffer rigidBodyBuffer;
   ComputeBuffer particleBuffer;
   ComputeBuffer argsBuffer;

   //初始化shader
   public ComputeShader cs;
   public Mesh cubeMesh;
   public Material cubeMat;

   Bounds bounds;
   uint[] args = new uint[5] {0,0,0,0,0};

   int kernelUpdateParticle;

   private void Start()
   {
       InitRigdBody();
       InitParticle();
       InitBuffer();
       InitShader();
   }

   private void InitShader()
   {
       kernelUpdateParticle = cs.FindKernel("UpdateParticle");
       cs.SetBuffer(kernelUpdateParticle,"rigidBodyBuffer",rigidBodyBuffer);
       cs.SetBuffer(kernelUpdateParticle,"particleBuffer",particleBuffer);
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
   }

   //它的主要作用是在 Scene（场景）视图中绘制辅助线框、形状或图标，用于帮助开发者在编辑器里直观地调试和查看数据，
   // 而不会渲染到最终的游戏画面（Game 视图）中。
   //只要把这个方法写在继承自 MonoBehaviour 的脚本里，Unity 会在编辑器模式或运行模式下自动每帧调用它。
    private void OnDrawGizmos()
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

    private void Update()
    {
        cs.Dispatch(kernelUpdateParticle,Mathf.CeilToInt((float)rigidBodyCount/8),1,1);
    }

    private void OnDestroy()
    {
        rigidBodyBuffer?.Release();
        particleBuffer?.Release();
        argsBuffer?.Release();
    }
}
