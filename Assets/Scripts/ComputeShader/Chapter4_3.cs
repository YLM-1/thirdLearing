using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class Chapter4_3 : MonoBehaviour
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

    private void Start()
    {
        InitShader();
    }

    private void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out _,out _);
        groupSizeX = Mathf.CeilToInt(boidCount/x);
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
            boidGOs[i] = Instantiate(boidPrefab, pos, Quaternion.identity, transform) as GameObject;

            boids[i] = new Boid(pos, boidGOs[i].transform.forward);
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
    }

    private void Update()
    {
        cs.SetVector("flockPosition",target.transform.position);
        cs.SetFloat("deltatime",Time.deltaTime);
        cs.Dispatch(kernelHandle,groupSizeX,1,1);

        boidBuffer.GetData(boids);
        for(int i=0;i<numOfBoids;i++)
        {
            boidGOs[i].transform.localPosition = boids[i].position;
            boidGOs[i].transform.localRotation = Quaternion.LookRotation(boids[i].direction);
        }
    }

    private void OnDestroy()
    {
        boidBuffer?.Release();
    }
}
