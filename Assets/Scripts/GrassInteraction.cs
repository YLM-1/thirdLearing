using UnityEngine;

[ExecuteInEditMode]
public class GrassInteraction : MonoBehaviour
{
    [SerializeField] private Material grassMatetrial;

    [Tooltip("把交互点从胶囊中心下移到脚底，让草在角色脚下弯曲")]
    [SerializeField] private float groundOffset = 0.05f;

    private CharacterController controller;
    private static readonly int PositionID = Shader.PropertyToID("_Position");

    private void Awake()
    {
        controller = GetComponent<CharacterController>();
    }

    private void Update()
    {
        if (grassMatetrial == null)
        {
            return;
        }

        Vector3 interactionPosition = transform.position;

        // CharacterController 的轴心在胶囊中心，草长在地面上，
        // 所以把交互点移到胶囊底部，否则草只会被角色腰部附近影响。
        if (controller != null)
        {
            interactionPosition.y += controller.center.y - controller.height * 0.5f;
        }

        interactionPosition.y += groundOffset;
        grassMatetrial.SetVector(PositionID, interactionPosition);
    }
}
