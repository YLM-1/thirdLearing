using UnityEngine;

/// <summary>
/// 单条鱼的行为控制器
/// 由 FlockController 自动挂载/初始化，无需手动添加
/// </summary>
[DisallowMultipleComponent]
public class FishAgent : MonoBehaviour
{
    private FlockController _controller;
    private Vector3 _velocity;
    private float _bobPhase;
    private float _speedFactor;   // 每条鱼的速度个体差异

    public Vector3 Velocity => _velocity;

    /// <summary>由 FlockController 调用，初始化鱼的状态</summary>
    public void Init(FlockController controller)
    {
        _controller = controller;
        _bobPhase = Random.Range(0f, Mathf.PI * 2f);
        _speedFactor = Random.Range(0.85f, 1.15f);

        Vector3 dir = Random.onUnitSphere;
        _velocity = dir * (controller.maxSpeed * _speedFactor * Random.Range(0.6f, 1f));
        if (_velocity.sqrMagnitude < 0.0001f)
            _velocity = transform.forward * controller.minSpeed;
    }

    private void Update()
    {
        if (_controller == null)
        {
#if UNITY_2022_2_OR_NEWER
            _controller = Object.FindFirstObjectByType<FlockController>();
#else
            _controller = Object.FindObjectOfType<FlockController>();
#endif
            if (_controller == null) return;
            Init(_controller);
        }

        float dt = Mathf.Min(Time.deltaTime, 0.05f);
        if (dt <= 0f) return;

        Vector3 accel = ComputeAcceleration();
        _velocity += accel * dt;
        ClampSpeed();
        Move(dt);
        UpdateRotation(dt);
    }

    // ─────────────── 核心：计算加速度 ───────────────
    private Vector3 ComputeAcceleration()
    {
        FlockController c = _controller;

        Vector3 pos = transform.position;
        Vector3 forwardDir = _velocity.sqrMagnitude > 0.0001f
            ? _velocity.normalized
            : transform.forward;

        // 三个原则的累加
        Vector3 sepAcc = Vector3.zero;
        Vector3 aliAcc = Vector3.zero;
        Vector3 cohAcc = Vector3.zero;
        int sepCount = 0, aliCount = 0, cohCount = 0;

        float maxRadius = Mathf.Max(c.separationRadius, Mathf.Max(c.alignmentRadius, c.cohesionRadius));
        float maxRadiusSqr = maxRadius * maxRadius;

        var fish = c.AllFish;
        for (int i = 0; i < fish.Count; i++)
        {
            FishAgent other = fish[i];
            if (other == null || other == this) continue;

            Vector3 offset = other.transform.position - pos;
            float sqrDist = offset.sqrMagnitude;
            if (sqrDist > maxRadiusSqr || sqrDist < 0.000001f) continue;

            // 视野过滤
            if (c.fieldOfView > 0f && c.fieldOfView < 359.9f)
            {
                float angle = Vector3.Angle(forwardDir, offset);
                if (angle > c.fieldOfView * 0.5f) continue;
            }

            float dist = Mathf.Sqrt(sqrDist);

            // 分离：距离越近排斥越强（方向为远离邻居）
            if (dist < c.separationRadius)
            {
                sepAcc -= offset / sqrDist;
                sepCount++;
            }

            // 对齐：累加邻居速度
            if (dist < c.alignmentRadius)
            {
                aliAcc += other.Velocity;
                aliCount++;
            }

            // 聚合：累加邻居位置
            if (dist < c.cohesionRadius)
            {
                cohAcc += other.transform.position;
                cohCount++;
            }
        }

        Vector3 accel = Vector3.zero;

        // ① 分离
        if (sepCount > 0)
        {
            Vector3 desired = (sepAcc / sepCount).normalized * c.maxSpeed;
            accel += Steer(desired) * c.separationWeight;
        }

        // ② 对齐
        if (aliCount > 0)
        {
            Vector3 desired = (aliAcc / aliCount).normalized * c.maxSpeed;
            accel += Steer(desired) * c.alignmentWeight;
        }

        // ③ 聚合
        if (cohCount > 0)
        {
            Vector3 center = cohAcc / cohCount;
            Vector3 desired = (center - pos).normalized * c.maxSpeed;
            accel += Steer(desired) * c.cohesionWeight;
        }

        // ④ 边界回避
        accel += ComputeBoundaryForce() * c.boundaryWeight;

        // ⑤ 障碍物回避
        if (c.enableObstacleAvoidance)
            accel += ComputeAvoidForce() * c.avoidWeight;

        // ⑥ 跟随目标
        if (c.enableFollowTarget && c.followTarget != null)
        {
            Vector3 toTarget = c.followTarget.position - pos;
            if (toTarget.sqrMagnitude > 0.01f)
            {
                Vector3 desired = toTarget.normalized * c.maxSpeed;
                accel += Steer(desired) * c.followWeight;
            }
        }

        // ⑦ 自然起伏
        if (c.enableBob && c.bobAmount > 0f)
        {
            float bob = Mathf.Sin(Time.time * c.bobFrequency + _bobPhase) * c.bobAmount;
            accel += Vector3.up * bob * c.maxSpeed;
        }

        // 总加速度限幅
        return Vector3.ClampMagnitude(accel, c.maxSteerForce);
    }

    /// <summary>转向力 = 期望速度 - 当前速度，并限制在最大转向力内</summary>
    private Vector3 Steer(Vector3 desired)
    {
        Vector3 steer = desired - _velocity;
        return Vector3.ClampMagnitude(steer, _controller.maxSteerForce);
    }

    // ─────────────── 边界回避 ───────────────
    private Vector3 ComputeBoundaryForce()
    {
        FlockController c = _controller;
        Vector3 center = c.transform.position + c.boundaryCenter;
        Vector3 half = c.boundarySize * 0.5f;
        Vector3 offset = transform.position - center;

        float nx = half.x > 0.0001f ? offset.x / half.x : 0f;
        float ny = half.y > 0.0001f ? offset.y / half.y : 0f;
        float nz = half.z > 0.0001f ? offset.z / half.z : 0f;

        float inner = 1f - c.boundaryPadding;

        Vector3 push = new Vector3(
            BoundaryAxisForce(nx, inner),
            BoundaryAxisForce(ny, inner),
            BoundaryAxisForce(nz, inner));

        return push * c.maxSpeed;
    }

    private static float BoundaryAxisForce(float n, float inner)
    {
        float a = Mathf.Abs(n);
        if (a <= inner) return 0f;

        float t = (a - inner) / Mathf.Max(0.0001f, 1f - inner);
        if (a > 1f) t = 1f + (a - 1f) * 3f;   // 出界后加速拉回
        return -Mathf.Sign(n) * Mathf.Min(t, 5f);
    }

    // ─────────────── 障碍物回避 ───────────────
    private Vector3 ComputeAvoidForce()
    {
        FlockController c = _controller;
        Vector3 dir = _velocity.sqrMagnitude > 0.0001f ? _velocity.normalized : transform.forward;

        if (Physics.SphereCast(transform.position, 0.5f, dir, out RaycastHit hit,
                c.avoidDistance, c.obstacleLayer, QueryTriggerInteraction.Ignore))
        {
            Vector3 avoidDir = Vector3.Reflect(dir, hit.normal);
            avoidDir.y += 0.2f;   // 稍微向上偏，避免贴地
            return avoidDir.normalized * c.maxSpeed;
        }

        return Vector3.zero;
    }

    // ─────────────── 速度限幅 ───────────────
    private void ClampSpeed()
    {
        FlockController c = _controller;
        float maxV = c.maxSpeed * _speedFactor;
        float minV = c.minSpeed * _speedFactor;

        float speed = _velocity.magnitude;
        if (speed > maxV && speed > 0.0001f)
            _velocity *= maxV / speed;
        else if (speed < minV && speed > 0.0001f)
            _velocity *= minV / speed;
        else if (speed <= 0.0001f)
            _velocity = transform.forward * minV;
    }

    // ─────────────── 位置更新（带硬边界兜底） ───────────────
    private void Move(float dt)
    {
        FlockController c = _controller;
        Vector3 newPos = transform.position + _velocity * dt;

        Vector3 center = c.transform.position + c.boundaryCenter;
        Vector3 half = c.boundarySize * 0.5f;
        Vector3 local = newPos - center;

        local.x = Mathf.Clamp(local.x, -half.x * 1.1f, half.x * 1.1f);
        local.y = Mathf.Clamp(local.y, -half.y * 1.1f, half.y * 1.1f);
        local.z = Mathf.Clamp(local.z, -half.z * 1.1f, half.z * 1.1f);

        transform.position = center + local;
    }

    // ─────────────── 朝向更新 ───────────────
    private void UpdateRotation(float dt)
    {
        FlockController c = _controller;
        Vector3 lookDir = _velocity;

        if (lookDir.sqrMagnitude < 0.0001f) return;
        if (c.reverseForward) lookDir = -lookDir;

        Quaternion targetRot = Quaternion.LookRotation(lookDir.normalized, Vector3.up);
        float t = 1f - Mathf.Exp(-c.rotationSharpness * dt);
        transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, t);
    }
}