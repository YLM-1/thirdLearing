using UnityEngine;

/// <summary>
/// 让目标沿圆周实时运动（默认在 XZ 平面上绕圈）。
/// 用法：
///   1. 挂到 Target 物体上，或者把 Target 拖到 target 字段
///   2. Play 之后仍然可以在 Scene 视图里拖动它 —— 圆心会跟着一起平移，不会跳回去
///   3. 不想绕圈时取消 autoMove，就变成纯手动摆放
/// </summary>
[DisallowMultipleComponent]
public class Chapter6_4Move : MonoBehaviour
{
    [Header("目标")]
    [Tooltip("要移动的对象；留空则移动自己")]
    [SerializeField] private Transform target;

    [Header("圆周运动")]
    [Tooltip("是否自动绕圈；关掉后可以纯手动摆位置")]
    [SerializeField] private bool autoMove = true;

    [Tooltip("圆周半径（世界单位）")]
    [Min(0f)]
    [SerializeField] private float radius = 0.5f;

    [Tooltip("角速度（度/秒），360 = 每秒一圈")]
    [SerializeField] private float speed = 60f;

    [Tooltip("顺时针（从上往下看）")]
    [SerializeField] private bool clockwise = false;

    [Tooltip("起始角度（度），0 = +X 方向")]
    [SerializeField] private float startAngle = 0f;

    [Tooltip("上下浮动幅度（0 = 完全平面运动）")]
    [Min(0f)]
    [SerializeField] private float verticalBob = 0f;

    [Tooltip("上下浮动频率（次/秒）")]
    [Min(0f)]
    [SerializeField] private float bobFrequency = 0.5f;

    [Header("手动拖动")]
    [Tooltip("运行中拖动目标时，圆心是否跟着平移（推荐开启）")]
    [SerializeField] private bool followManualMove = true;

    [Tooltip("判定为\"手动拖动\"的距离阈值，太小会被浮点误差触发")]
    [SerializeField] private float dragThreshold = 1e-4f;

    // 运行时状态
    private Vector3 _center;        // 圆心
    private float _angleDeg;        // 当前角度
    private Vector3 _lastApplied;   // 上一帧脚本写入的位置
    private bool _initialized;

    private Transform Target => target != null ? target : transform;

    /// <summary>当前圆心（世界坐标），运行中可读</summary>
    public Vector3 Center => _center;

    /// <summary>圆心到目标的半径</summary>
    public float Radius
    {
        get => radius;
        set => radius = Mathf.Max(0f, value);
    }

    private void Start()
    {
        Initialize();
    }

    private void OnEnable()
    {
        if (!_initialized)
            Initialize();
    }

    private void Initialize()
    {
        Transform t = Target;
        _center = t.position;
        _angleDeg = startAngle;
        _lastApplied = t.position;
        _initialized = true;
    }

    /// <summary>运行中想换一个圆心时调用它</summary>
    public void SetCenter(Vector3 worldCenter)
    {
        _center = worldCenter;
        _lastApplied = Target.position;
    }

    private void Update()
    {
        if (!_initialized)
            Initialize();

        Transform t = Target;

        // ── 1. 检测手动拖动 ──
        // 当前位置和"上一帧脚本算出来的位置"不一致，就认为用户手动挪过它
        if (followManualMove)
        {
            Vector3 manualDelta = t.position - _lastApplied;
            if (manualDelta.sqrMagnitude > dragThreshold * dragThreshold)
                _center += manualDelta;   // 圆心跟着平移，圆不会甩出去
        }

        if (!autoMove)
        {
            _lastApplied = t.position;
            return;
        }

        // ── 2. 沿圆周推进角度 ──
        _angleDeg += (clockwise ? -1f : 1f) * speed * Time.deltaTime;
        _angleDeg = Mathf.Repeat(_angleDeg, 360f);

        float rad = _angleDeg * Mathf.Deg2Rad;

        // XZ 平面上的圆
        Vector3 offset = new Vector3(Mathf.Cos(rad), 0f, Mathf.Sin(rad)) * radius;

        // 可选的上下浮动
        if (verticalBob > 0f)
            offset.y = Mathf.Sin(Time.time * bobFrequency * Mathf.PI * 2f) * verticalBob;

        Vector3 newPos = _center + offset;
        t.position = newPos;
        _lastApplied = newPos;
    }

    private void OnDrawGizmosSelected()
    {
        Transform t = target != null ? target : transform;
        Vector3 c = (Application.isPlaying && _initialized) ? _center : t.position;

        Gizmos.color = new Color(0f, 1f, 1f, 0.8f);
        Gizmos.DrawWireSphere(c, radius);

        // 画一条半径线，方便看当前角度
        if (Application.isPlaying && _initialized)
        {
            Gizmos.color = Color.yellow;
            Gizmos.DrawLine(c, t.position);
        }
    }
}
