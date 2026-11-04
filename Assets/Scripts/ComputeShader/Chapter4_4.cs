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

    [SerializeField] private float boidSpeed = 1f;
    [SerializeField] private float neighbourDistance = 0.1f;
    [SerializeField] private int boidCount = 10;
    [SerializeField] private float spawnRadius = 1f;
    [SerializeField] private GameObject boidPrefab;
    [SerializeField] private Transform target;

    [Header("水池边界")]
    [Tooltip("拖入 chinese garden pool bottom (1)，用它的包围盒限制鱼的活动范围；留空则不限制")]
    [SerializeField] private Transform poolBounds;

    [Tooltip("离池壁 / 池底 / 水面的安全距离（世界单位）")]
    [SerializeField] private float poolMargin = 0.05f;

    [Header("上下弹性")]
    [Tooltip("垂直弹簧强度：越大越快回到自己的舒适高度")]
    [SerializeField] private float poolSpring = 3f;

    [Tooltip("垂直阻尼：抑制上下振荡")]
    [SerializeField] private float poolDamping = 2f;

    [Tooltip("撞到池壁 / 池底 / 水面后的反弹系数（0 = 贴住，1 = 完全反弹）")]
    [Range(0f, 1f)]
    [SerializeField] private float poolBounce = 0.4f;

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

    [Header("渲染调整")]
    [Tooltip("模型整体缩放。Shader 不会读取模型自身的缩放，模型多大就画多大，用这个统一放大/缩小")]
    [SerializeField] private float boidScale = 1f;

    [Tooltip("模型朝向修正（欧拉角）。约定模型朝 +Z；如果鱼横着、倒着游，就在这里修正")]
    [SerializeField] private Vector3 boidRotationFix = Vector3.zero;

    [Tooltip("可选的鱼身贴图，留空则使用纯色（灰白）")]
    [SerializeField] private Texture2D boidTexture;

    private ComputeBuffer argsBuffer;
    // 运行时材质副本：避免把贴图/缩放写进 .mat 资源，导致资源变脏
    private Material runtimeMat;

    // 水池活动范围（世界空间）
    private Vector3 poolMin, poolMax;
    private bool usePool;

    private void Start()
    {
        if (cs == null || boidmat == null || target == null || boidPrefab == null)
        {
            Debug.LogError("[Chapter4_4] 请先在 Inspector 里指定 cs / boidmat / target / boidPrefab", this);
            enabled = false;
            return;
        }

        CachePoolBounds();
        InitShader();
        InitMesh();
    }

    /// <summary>
    /// 用 poolBounds 下所有 Renderer 的世界包围盒算出鱼的活动范围。
    /// 自动带上模型自身的缩放和位移，不用手填尺寸。
    /// </summary>
    private void CachePoolBounds()
    {
        usePool = false;
        if (poolBounds == null) return;

        bool inited = false;
        Bounds b = new Bounds();

        foreach (var r in poolBounds.GetComponentsInChildren<Renderer>())
        {
            if (r == null || !r.enabled) continue;
            if (!inited) { b = r.bounds; inited = true; }
            else b.Encapsulate(r.bounds);
        }

        if (!inited)
        {
            Debug.LogWarning("[Chapter4_4] poolBounds 下没有可用的 Renderer，退回默认生成方式", this);
            return;
        }

        poolMin = b.min + Vector3.one * poolMargin;
        poolMax = b.max - Vector3.one * poolMargin;

        if (poolMin.x >= poolMax.x || poolMin.y >= poolMax.y || poolMin.z >= poolMax.z)
        {
            Debug.LogWarning($"[Chapter4_4] 水池包围盒太小（poolMargin 是否过大？），忽略水池约束。bounds.size={b.size}", this);
            return;
        }

        usePool = true;
        Debug.Log($"[Chapter4_4] 水池边界 min={poolMin} max={poolMax} 可用范围={poolMax - poolMin}", this);
    }

    private void InitMesh()
    {
        //.sharedMesh只获取对原始网格资源的引用（Reference），不会在内存中创建任何新的 Mesh 副本。
        //.mesh隐式地在内存中克隆（Duplicate）出一份全新的 Mesh 实例

        // 普通模型用 MeshFilter，骨骼模型（比如鱼）只有 SkinnedMeshRenderer，
        // 所以两种都要找，否则会抛 MissingComponentException 并让 boidMesh 变成 null。
        MeshFilter mf = boidPrefab.GetComponentInChildren<MeshFilter>(true);
        SkinnedMeshRenderer smr = boidPrefab.GetComponentInChildren<SkinnedMeshRenderer>(true);

        if (mf != null && mf.sharedMesh != null)
            boidMesh = mf.sharedMesh;
        else if (smr != null)
            boidMesh = smr.sharedMesh;

        if (boidMesh == null)
        {
            Debug.LogError($"[Chapter4_4] boidPrefab「{boidPrefab.name}」上找不到 MeshFilter 或 SkinnedMeshRenderer 的 Mesh", this);
            enabled = false;
            return;
        }

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
            Vector3 pos;
            if (usePool)
            {
                // 在水池包围盒里随机（Y 也是随机的，所以每条鱼初始高度不同）
                pos = new Vector3(
                    Random.Range(poolMin.x, poolMax.x),
                    Random.Range(poolMin.y, poolMax.y),
                    Random.Range(poolMin.z, poolMax.z));
            }
            else
            {
                pos = transform.position + Random.insideUnitSphere * spawnRadius;
            }
            //使用DrawMeshInstanceIndirect不需要Instantiate实例
            // boidGOs[i] = Instantiate(boidPrefab, pos, Quaternion.identity, transform) as GameObject;

            Quaternion rot = Quaternion.Slerp(transform.rotation, Random.rotation, 0.3f);
            Vector3 dir = rot * Vector3.forward;
            dir.y = 0f;                                        // 初始速度压平到 XZ 平面
            if (dir.sqrMagnitude < 1e-4f) dir = Vector3.forward; // 方向正好垂直时的兜底，避免 normalize 出零向量
            // direction 存的是「方向向量」，不能直接塞欧拉角（(0,0,0) 会变成零向量）
            boids[i] = new Boid(pos, dir.normalized);
        }

        boidBuffer = new ComputeBuffer(numOfBoids,sizeof(float)*6);
        boidBuffer.SetData(boids);

        cs.SetBuffer(kernelHandle,"boidBuffer",boidBuffer);
        cs.SetFloat("boidSpeed",boidSpeed);
        cs.SetFloat("neighbourDistance",neighbourDistance);
        cs.SetInt("boidCount",boidCount);

        // 水池边界 + 上下弹性
        cs.SetVector("poolMin", poolMin);
        cs.SetVector("poolMax", poolMax);
        cs.SetFloat("usePool", usePool ? 1f : 0f);
        cs.SetFloat("poolSpring", poolSpring);
        cs.SetFloat("poolDamping", poolDamping);
        cs.SetFloat("poolBounce", poolBounce);

        float sum = alignmentWeight + cohesionWeight + separationWeight;
        cs.SetFloat("alignmentWeight",alignmentWeight/sum);
        cs.SetFloat("cohesionWeight",cohesionWeight/sum);
        cs.SetFloat("separationWeight",separationWeight/sum);

        // 用运行时材质副本，所有参数只作用在这份副本上，不会弄脏项目里的 .mat
        runtimeMat = new Material(boidmat) { name = boidmat.name + " (Runtime)" };

        //将在computeBuffer中计算好的数据传递给shader
        runtimeMat.SetBuffer("boidBuffer",boidBuffer);
        runtimeMat.SetFloat("_BoidScale", Mathf.Max(0.0001f, boidScale));
        runtimeMat.SetMatrix("_BoidRotationFix", Matrix4x4.Rotate(Quaternion.Euler(boidRotationFix)));

        if (boidTexture != null)
            runtimeMat.SetTexture("_BaseMap", boidTexture);
    }

    private void Update()
    {
        if (boidMesh == null || runtimeMat == null) return;

        // 目标点也夹进水池，否则鱼会全部被吸到墙上堆着
        Vector3 flockPos = target.transform.position;
        if (usePool)
        {
            flockPos.x = Mathf.Clamp(flockPos.x, poolMin.x, poolMax.x);
            flockPos.y = Mathf.Clamp(flockPos.y, poolMin.y, poolMax.y);
            flockPos.z = Mathf.Clamp(flockPos.z, poolMin.z, poolMax.z);
        }
        cs.SetVector("flockPosition", flockPos);
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

        Graphics.DrawMeshInstancedIndirect(boidMesh,0,runtimeMat,bounds,argsBuffer);
    }

    private void OnDestroy()
    {
        boidBuffer?.Release();
        argsBuffer?.Release();

        if (runtimeMat != null)
            Destroy(runtimeMat);
    }
}
