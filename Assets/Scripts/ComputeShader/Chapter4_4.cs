using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class Chapter4_4 : MonoBehaviour
{
    [SerializeField] private ComputeShader cs;
    public struct Boid
    {
        public Vector3 position;
        public Vector3 direction;

        public Boid(Vector3 pos,Vector3 dir)
        {
            position=pos;
            direction = dir;
        }
    };

    [SerializeField] private float boidSpeed = 150f;
    [SerializeField] private float neighbourDistance = 20f;
    [SerializeField] private int boidCount = 1000;
    [SerializeField] private float spawnRadius = 100f;
    [SerializeField] private GameObject boidPrefab;
    [SerializeField] private Transform target;

    [SerializeField] private float alignmentWeight = 1;
    [SerializeField] private float cohesionWeight = 1;
    [SerializeField] private float separationWeight = 1;


    int kernelHandle;
    int groupSizeX;
    int numOfBoids;

    Boid[] boids;//数据载体
    GameObject[] boidGOs;//显示载体

    private ComputeBuffer boidBuffer;

    //使用initMesh的相关参数
    Mesh boidMesh;
    Bounds bounds;
    [SerializeField] private Material boidmat;
    private ComputeBuffer argsBuffer;

    private void Start()
    {
        InitShader();
        InitMesh();
    }

    private void InitMesh()
    {
        //.sharedMesh只获取对原始网格资源的引用（Reference），不会在内存中创建任何新的 Mesh 副本。
        //.mesh隐式地在内存中克隆（Duplicate）出一份全新的 Mesh 实例
        boidMesh = boidPrefab.GetComponent<MeshFilter>().sharedMesh;
        bounds = new Bounds(Vector3.zero,Vector3.one*1000);

        argsBuffer = new ComputeBuffer(1,5*sizeof(uint),ComputeBufferType.IndirectArguments);
        uint[] args = new uint[5] {0,0,0,0,0};
        args[0] = (uint)boidMesh.GetIndexCount(0); //0: 单个 Mesh 的索引数量 (Index Count),“单个 Mesh 的索引数量 (Index Count)” 简单来说，就是显卡绘制这一个模型时，需要读取的“顶点序号总个数”。
        args[1] = (uint)numOfBoids;                //1: 准备绘制的物体总数量 (Instance Count)
        argsBuffer.SetData(args);
    }

    private void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out _,out _);
        groupSizeX = Mathf.CeilToInt((float)boidCount/(float)x);
        // 虽然逻辑上只生成 boidCount 个 boid，
        // 但 Buffer 必须按 numOfBoids 来分配。
        // 因为 GPU 是按「线程组个数 × 每组线程数」来启动线程的，
        // 实际启动的线程数会是 boidCount 向上取整到线程组整数倍后的结果，
        // 多出来的线程也要能安全访问 Buffer，否则会越界。
        numOfBoids = groupSizeX*(int)x; 

        boids = new Boid[numOfBoids];
        boidGOs = new GameObject[numOfBoids];

        for(int i=0;i<numOfBoids;i++)
        {
            Vector3 pos = transform.position + Random.insideUnitSphere*spawnRadius;
            //使用DrawMeshInstanceIndirect不需要Instantiate实例
            // boidGOs[i] = Instantiate(boidPrefab, pos, Quaternion.identity, transform) as GameObject;

            Quaternion rot = Quaternion.Slerp(transform.rotation, Random.rotation, 0.3f);
            boids[i] = new Boid(pos, rot.eulerAngles);
        }

        boidBuffer = new ComputeBuffer(numOfBoids,sizeof(float)*6);
        boidBuffer.SetData(boids);

        cs.SetBuffer(kernelHandle,"boidBuffer",boidBuffer);
        cs.SetFloat("boidSpeed",boidSpeed);
        cs.SetFloat("neighbourDistance",neighbourDistance);
        cs.SetInt("boidCount",boidCount);

        float sum = alignmentWeight + cohesionWeight + separationWeight;
        cs.SetFloat("alignmentWeight",alignmentWeight/sum);
        cs.SetFloat("cohesionWeight",cohesionWeight/sum);
        cs.SetFloat("separationWeight",separationWeight/sum);

        //将在computeBuffer中计算好的数据传递给shader
        boidmat.SetBuffer("boidBuffer",boidBuffer);
    }

    private void Update()
    {
        cs.SetVector("flockPosition",target.transform.position);
        cs.SetFloat("deltatime",Time.deltaTime);
        cs.Dispatch(kernelHandle,groupSizeX,1,1);

        //因为目前使用的是DrawMeshInstancedIndirect
        //则无需再从GPU中每帧获取数据了
        //拿取computeShader中计算好的数据
        // boidBuffer.GetData(boids);
        // for(int i=0;i<numOfBoids;i++)
        // {
        //     boidGOs[i].transform.localPosition = boids[i].position;
        //     boidGOs[i].transform.localRotation = Quaternion.LookRotation(boids[i].direction);
        // }

        Graphics.DrawMeshInstancedIndirect(boidMesh,0,boidmat,bounds,argsBuffer);
    }

    private void OnDestroy()
    {
        boidBuffer?.Release();
        argsBuffer?.Release();
    }
}
