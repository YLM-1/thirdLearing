using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 鱼群（Boids）管理器
/// Boids 三原则：分离 Separation、对齐 Alignment、聚合 Cohesion
/// 挂到场景中的空物体上即可使用
/// </summary>
[DisallowMultipleComponent]
public class FlockController : MonoBehaviour
{
    #region ═══ 鱼模型设置 ═══
    [Header("═══ 鱼模型设置 ═══")]
    [Tooltip("鱼的模型 Prefab（可在此处随时更换）。留空则使用下方程序生成的简易鱼模型")]
    public GameObject fishPrefab;

    [Tooltip("当鱼模型 Prefab 为空时，自动用基础几何体拼出一个简易鱼模型")]
    public bool useProceduralModel = true;

    [Tooltip("鱼模型统一缩放倍数")]
    [Range(0.05f, 10f)]
    public float modelScale = 1f;

    [Tooltip("在统一缩放基础上的随机缩放范围（X=最小，Y=最大），让鱼群大小有差异")]
    public Vector2 randomScaleRange = new Vector2(0.85f, 1.15f);

    [Tooltip("鱼的颜色（未指定自定义材质时生效）")]
    public Color fishColor = new Color(1f, 0.55f, 0.2f, 1f);

    [Tooltip("自定义材质（留空则按上面的颜色自动生成材质）")]
    public Material fishMaterial;

    [Tooltip("颜色随机变化幅度，让每条鱼颜色略有差异（0 = 完全一致）")]
    [Range(0f, 0.5f)]
    public float colorVariation = 0.1f;

    [Tooltip("模型游动方向反了的话勾选此项（一般模型朝 +Z，若倒着游就勾选）")]
    public bool reverseForward = false;

    [Tooltip("生成时移除鱼身上的碰撞体，避免鱼之间物理碰撞破坏鱼群效果")]
    public bool disableFishColliders = true;
    #endregion

    #region ═══ 鱼群生成 ═══
    [Header("═══ 鱼群生成 ═══")]
    [Tooltip("鱼的数量")]
    [Range(1, 2000)]
    public int fishCount = 80;

    [Tooltip("生成区域的球体半径（鱼群会随机分布在这个球体内）")]
    [Range(0.1f, 100f)]
    public float spawnRadius = 8f;
    #endregion

    #region ═══ Boids 三原则 ═══
    [Header("═══ 分离 Separation（避免拥挤） ═══")]
    [Tooltip("分离力权重：越大鱼越不愿意挤在一起")]
    [Range(0f, 20f)]
    public float separationWeight = 3f;

    [Tooltip("分离感知半径：小于这个距离的邻居会产生排斥")]
    [Range(0.1f, 20f)]
    public float separationRadius = 1.2f;

    [Header("═══ 对齐 Alignment（朝向一致） ═══")]
    [Tooltip("对齐力权重：越大鱼越倾向与邻居游向一致")]
    [Range(0f, 20f)]
    public float alignmentWeight = 1.2f;

    [Tooltip("对齐感知半径")]
    [Range(0.1f, 30f)]
    public float alignmentRadius = 3f;

    [Header("═══ 聚合 Cohesion（聚集成群） ═══")]
    [Tooltip("聚合力权重：越大鱼越倾向靠近邻居中心")]
    [Range(0f, 20f)]
    public float cohesionWeight = 1f;

    [Tooltip("聚合感知半径")]
    [Range(0.1f, 30f)]
    public float cohesionRadius = 5f;
    #endregion

    #region ═══ 运动参数 ═══
    [Header("═══ 运动参数 ═══")]
    [Tooltip("最大游动速度")]
    [Range(0.1f, 50f)]
    public float maxSpeed = 6f;

    [Tooltip("最小游动速度（防止鱼停在原地）")]
    [Range(0f, 20f)]
    public float minSpeed = 2f;

    [Tooltip("最大转向力：越大转向越灵活、越急")]
    [Range(0.1f, 100f)]
    public float maxSteerForce = 10f;

    [Tooltip("视野角度（度），0 或 360 表示全向视野；鱼只能看到该角度内的邻居")]
    [Range(0f, 360f)]
    public float fieldOfView = 300f;

    [Tooltip("转向平滑度，越大转向越灵敏")]
    [Range(0.1f, 30f)]
    public float rotationSharpness = 8f;

    [Tooltip("是否让鱼在游动时上下轻微起伏，更自然")]
    public bool enableBob = true;

    [Tooltip("起伏幅度")]
    [Range(0f, 1f)]
    public float bobAmount = 0.05f;

    [Tooltip("起伏频率")]
    [Range(0f, 10f)]
    public float bobFrequency = 2f;
    #endregion

    #region ═══ 边界设置 ═══
    [Header("═══ 边界设置 ═══")]
    [Tooltip("边界盒子中心（相对鱼群管理器的偏移）")]
    public Vector3 boundaryCenter = Vector3.zero;

    [Tooltip("边界盒子大小（XYZ 轴长）")]
    public Vector3 boundarySize = new Vector3(30f, 12f, 30f);

    [Tooltip("边界回避力权重")]
    [Range(0f, 50f)]
    public float boundaryWeight = 6f;

    [Tooltip("提前多远开始回避边界（占半轴长的比例，0~1）")]
    [Range(0f, 0.95f)]
    public float boundaryPadding = 0.15f;
    #endregion

    #region ═══ 障碍物回避 ═══
    [Header("═══ 障碍物回避 ═══")]
    [Tooltip("是否启用障碍物回避")]
    public bool enableObstacleAvoidance = true;

    [Tooltip("障碍物所在的 Layer（请手动指定，否则默认不检测任何物体）")]
    public LayerMask obstacleLayer = 0;

    [Tooltip("障碍物检测距离（鱼身前多远开始转向）")]
    [Range(0.1f, 30f)]
    public float avoidDistance = 4f;

    [Tooltip("避障力权重")]
    [Range(0f, 50f)]
    public float avoidWeight = 5f;
    #endregion

    #region ═══ 跟随目标（可选） ═══
    [Header("═══ 跟随目标（可选） ═══")]
    [Tooltip("鱼群是否跟随某个目标（例如玩家、摄像机）")]
    public bool enableFollowTarget = false;

    [Tooltip("跟随的目标 Transform")]
    public Transform followTarget;

    [Tooltip("跟随目标的吸引力权重")]
    [Range(0f, 20f)]
    public float followWeight = 2f;
    #endregion

    #region ═══ 调试 ═══
    [Header("═══ 调试 ═══")]
    [Tooltip("在 Scene 视图中绘制边界框和生成范围")]
    public bool drawGizmos = true;

    [Tooltip("是否允许运行时按 R 键重新生成鱼群")]
    public bool enableRegenerateKey = true;
    #endregion

    // ─────────────── 运行时数据 ───────────────
    private readonly List<FishAgent> _allFish = new List<FishAgent>();
    public IReadOnlyList<FishAgent> AllFish => _allFish;

    private Material _baseMaterial;

    // ─────────────── 生命周期 ───────────────
    private void Start()
    {
        GenerateFlock();
    }

    private void Update()
    {
        if (enableRegenerateKey && Input.GetKeyDown(KeyCode.R))
            GenerateFlock();
    }

    private void OnDestroy()
    {
        _allFish.Clear();
    }

    /// <summary>重新生成整个鱼群（Inspector 右键也可调用）</summary>
    [ContextMenu("重新生成鱼群")]
    public void GenerateFlock()
    {
        ClearFlock();

        if (fishCount <= 0) return;

        Vector3 center = transform.position + boundaryCenter;
        Vector3 half = boundarySize * 0.5f;

        for (int i = 0; i < fishCount; i++)
        {
            // 在球体内随机取点，再夹到边界盒内
            Vector3 spawnPos = center + Random.insideUnitSphere * spawnRadius;
            spawnPos = new Vector3(
                Mathf.Clamp(spawnPos.x, center.x - half.x, center.x + half.x),
                Mathf.Clamp(spawnPos.y, center.y - half.y, center.y + half.y),
                Mathf.Clamp(spawnPos.z, center.z - half.z, center.z + half.z));

            GameObject model = CreateFishModel(i);
            model.transform.SetParent(transform, true);
            model.transform.position = spawnPos;
            model.transform.rotation = Random.rotation;

            FishAgent agent = model.GetComponent<FishAgent>();
            if (agent == null) agent = model.AddComponent<FishAgent>();
            agent.Init(this);

            _allFish.Add(agent);
        }
    }

    /// <summary>清除当前所有鱼</summary>
    public void ClearFlock()
    {
        for (int i = 0; i < _allFish.Count; i++)
        {
            if (_allFish[i] != null)
                DestroySafe(_allFish[i].gameObject);
        }
        _allFish.Clear();
    }

    /// <summary>运行时更换鱼模型（会重新生成整群鱼）</summary>
    public void SetFishModel(GameObject newPrefab)
    {
        fishPrefab = newPrefab;
        useProceduralModel = newPrefab == null;
        GenerateFlock();
    }

    // ─────────────── 鱼模型创建 ───────────────
    private GameObject CreateFishModel(int index)
    {
        GameObject go;
        if (fishPrefab != null)
        {
            go = Instantiate(fishPrefab);
            go.name = "Fish_" + index;
        }
        else if (useProceduralModel)
        {
            go = CreateProceduralFish(index);
        }
        else
        {
            go = new GameObject("Fish_Empty_" + index);
        }

        float scale = modelScale * Random.Range(randomScaleRange.x, randomScaleRange.y);
        go.transform.localScale = Vector3.one * scale;

        ApplyColor(go);

        if (disableFishColliders)
        {
            foreach (var col in go.GetComponentsInChildren<Collider>(true))
                DestroySafe(col);
        }

        return go;
    }

    /// <summary>用基础几何体拼一个简易鱼模型（身体+尾巴+背鳍+眼睛）</summary>
    private GameObject CreateProceduralFish(int index)
    {
        var root = new GameObject("Fish_Procedural_" + index);

        // 身体：拉长的球
        var body = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        body.name = "Body";
        body.transform.SetParent(root.transform, false);
        body.transform.localScale = new Vector3(0.35f, 0.4f, 0.8f);
        DestroySafe(body.GetComponent<Collider>());

        // 尾巴：压扁的球
        var tail = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        tail.name = "Tail";
        tail.transform.SetParent(root.transform, false);
        tail.transform.localPosition = new Vector3(0f, 0f, -0.48f);
        tail.transform.localScale = new Vector3(0.30f, 0.35f, 0.06f);
        DestroySafe(tail.GetComponent<Collider>());

        // 背鳍：竖起的薄片
        var fin = GameObject.CreatePrimitive(PrimitiveType.Cube);
        fin.name = "Fin";
        fin.transform.SetParent(root.transform, false);
        fin.transform.localPosition = new Vector3(0f, 0.22f, 0f);
        fin.transform.localScale = new Vector3(0.03f, 0.18f, 0.35f);
        DestroySafe(fin.GetComponent<Collider>());

        // 眼睛
        CreateEye(root.transform, 0.12f);
        CreateEye(root.transform, -0.12f);

        return root;
    }

    private void CreateEye(Transform parent, float x)
    {
        var eye = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        eye.name = "Eye";
        eye.transform.SetParent(parent, false);
        eye.transform.localPosition = new Vector3(x, 0.08f, 0.28f);
        eye.transform.localScale = Vector3.one * 0.07f;
        DestroySafe(eye.GetComponent<Collider>());
    }

    // ─────────────── 材质与颜色 ───────────────
    private void ApplyColor(GameObject go)
    {
        var renderers = go.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0) return;

        // 用户指定了材质：直接使用（共享）
        if (fishMaterial != null)
        {
            foreach (var r in renderers) r.sharedMaterial = fishMaterial;
            return;
        }

        if (_baseMaterial == null)
        {
            Shader shader = FindDefaultShader();
            _baseMaterial = new Material(shader);
        }

        Color c = fishColor;
        if (colorVariation > 0.0001f)
        {
            Color.RGBToHSV(c, out float h, out float s, out float v);
            h = Mathf.Repeat(h + Random.Range(-colorVariation, colorVariation), 1f);
            v = Mathf.Clamp01(v + Random.Range(-colorVariation, colorVariation) * 0.4f);
            c = Color.HSVToRGB(h, s, v);
        }

        // 每条鱼一个材质实例（数量大时可改为共享材质以节省内存）
        var mat = new Material(_baseMaterial) { color = c };
        foreach (var r in renderers) r.sharedMaterial = mat;
    }

    private static Shader FindDefaultShader()
    {
        Shader s = Shader.Find("Universal Render Pipeline/Lit");
        if (s != null) return s;
        s = Shader.Find("HDRP/Lit");
        if (s != null) return s;
        s = Shader.Find("Standard");
        if (s != null) return s;
        s = Shader.Find("Unlit/Color");
        if (s != null) return s;
        return Shader.Find("Sprites/Default");
    }

    // ─────────────── 工具方法 ───────────────
    private static void DestroySafe(Object obj)
    {
        if (obj == null) return;
        if (Application.isPlaying) Destroy(obj);
        else DestroyImmediate(obj);
    }

    // ─────────────── Gizmos ───────────────
    private void OnDrawGizmosSelected()
    {
        if (!drawGizmos) return;

        Vector3 center = transform.position + boundaryCenter;

        Gizmos.color = new Color(0f, 1f, 1f, 0.6f);
        Gizmos.DrawWireCube(center, boundarySize);

        Gizmos.color = new Color(1f, 1f, 0f, 0.25f);
        Gizmos.DrawWireSphere(center, spawnRadius);

        if (enableFollowTarget && followTarget != null)
        {
            Gizmos.color = Color.green;
            Gizmos.DrawLine(center, followTarget.position);
        }
    }
}