using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class MoveMent : MonoBehaviour
{
    [Header("移动")]
    [SerializeField] private float walkSpeed = 3f;
    [SerializeField] private float runSpeed = 6f;

    [Tooltip("水平速度变化快慢，越大加速和刹车越干脆")]
    [SerializeField] private float acceleration = 20f;

    [Range(0f, 1f)]
    [Tooltip("在空中时保留的操控比例")]
    [SerializeField] private float airControl = 0.35f;

    [Header("跳跃与重力")]
    [SerializeField] private float jumpHeight = 1.5f;
    [SerializeField] private float gravity = -9.81f;

    [Header("转向")]
    [Tooltip("角色朝移动方向转身的速度")]
    [SerializeField] private float rotationSpeed = 12f;

    private CharacterController controller;
    private Transform cameraTransform;

    private Vector3 horizontalVelocity;
    private float verticalVelocity;
    private bool grounded;

    private void Awake()
    {
        controller = GetComponent<CharacterController>();
    }

    private void Start()
    {
        ResolveCamera();
    }

    private void Update()
    {
        // 摄像机可能还没生成或切换，每帧检查一次
        if (cameraTransform == null)
        {
            ResolveCamera();
        }

        grounded = controller.isGrounded;
        if (grounded && verticalVelocity < 0f)
        {
            // 贴地时给一个向下的速度，避免在斜坡或台阶上悬空抖动
            verticalVelocity = -2f;
        }

        Vector3 input = new Vector3(
            Input.GetAxisRaw("Horizontal"),
            0f,
            Input.GetAxisRaw("Vertical"));

        // 斜向输入归一化，避免斜着走比直线走更快
        if (input.sqrMagnitude > 1f)
        {
            input.Normalize();
        }

        Vector3 moveDirection = GetCameraRelativeDirection(input);

        float targetSpeed = Input.GetKey(KeyCode.LeftShift) ? runSpeed : walkSpeed;
        Vector3 targetVelocity = moveDirection * targetSpeed;

        float accel = grounded ? acceleration : acceleration * airControl;
        horizontalVelocity = Vector3.MoveTowards(
            horizontalVelocity,
            targetVelocity,
            accel * Time.deltaTime);

        if (moveDirection.sqrMagnitude > 0.0001f)
        {
            Quaternion targetRotation = Quaternion.LookRotation(moveDirection, Vector3.up);
            float t = 1f - Mathf.Exp(-rotationSpeed * Time.deltaTime);
            transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, t);
        }

        if (grounded && Input.GetKeyDown(KeyCode.Space))
        {
            verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);
        }

        verticalVelocity += gravity * Time.deltaTime;

        // 水平与竖直速度合并成一次 Move，避免重复的碰撞和贴地检测
        Vector3 motion = horizontalVelocity + Vector3.up * verticalVelocity;
        controller.Move(motion * Time.deltaTime);
    }

    private void ResolveCamera()
    {
        if (Camera.main != null)
        {
            cameraTransform = Camera.main.transform;
        }
    }

    private Vector3 GetCameraRelativeDirection(Vector3 input)
    {
        if (cameraTransform == null)
        {
            return input;
        }

        // 只使用摄像机的水平朝向，抬头/低头不会影响移动
        Vector3 forward = cameraTransform.forward;
        Vector3 right = cameraTransform.right;
        forward.y = 0f;
        right.y = 0f;

        forward = forward.sqrMagnitude > 0.0001f ? forward.normalized : Vector3.forward;
        right = right.sqrMagnitude > 0.0001f ? right.normalized : Vector3.right;

        return forward * input.z + right * input.x;
    }
}
