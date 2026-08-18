using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class GetRefractTexture : MonoBehaviour
{
    private static readonly int RefractionTexId = Shader.PropertyToID("_RefractionTex");

    public GameObject targetPlane; // 水面平面
    [FormerlySerializedAs("_refractionRT")]
    public RenderTexture refractionRT = null; // 折射相机的目标纹理
    public Camera mainCamera = null; // 为空时响应所有普通相机
    public float clipPlaneOffset = 0.07f;

    private Camera _refractionCamera;

    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += UpdateCamera;
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= UpdateCamera;
        if (_refractionCamera)
        {
            _refractionCamera.targetTexture = null;
            SafeDestroy(_refractionCamera.gameObject);
        }
    }

    private static void SafeDestroy(Object obj)
    {
        if (Application.isEditor)
            DestroyImmediate(obj);
        else
            Destroy(obj);
    }

    private void UpdateCamera(ScriptableRenderContext src, Camera camera)
    {
        if (camera == _refractionCamera || camera.cameraType == CameraType.Reflection || camera.cameraType == CameraType.Preview)
            return;

        if (mainCamera != null && camera != mainCamera)
            return;

        if (targetPlane == null || refractionRT == null)
            return;

        if (_refractionCamera == null)
            _refractionCamera = CreateRefractCamera();

        UpdateRefractionCamera(camera);
        _refractionCamera.targetTexture = refractionRT;
        UniversalRenderPipeline.RenderSingleCamera(src, _refractionCamera);

        var renderer = targetPlane.GetComponent<Renderer>();
        if (renderer != null)
            renderer.sharedMaterial.SetTexture(RefractionTexId, refractionRT);
    }

    private void UpdateRefractionCamera(Camera curCamera)
    {
        UpdateCameraParams(curCamera, _refractionCamera);

        Vector3 planeNormal = targetPlane.transform.up;
        Vector3 planePos = targetPlane.transform.position - planeNormal * clipPlaneOffset;
        float d = -Vector3.Dot(planeNormal, planePos);
        Vector4 planeVec = new Vector4(planeNormal.x, planeNormal.y, planeNormal.z, d);

        Vector4 planeVecView = _refractionCamera.worldToCameraMatrix.inverse.transpose * planeVec;
        _refractionCamera.projectionMatrix = _refractionCamera.CalculateObliqueMatrix(planeVecView);
    }

    private void UpdateCameraParams(Camera srcCamera, Camera destCamera)
    {
        destCamera.transform.SetPositionAndRotation(srcCamera.transform.position, srcCamera.transform.rotation);
        destCamera.cameraType = srcCamera.cameraType;
        destCamera.clearFlags = srcCamera.clearFlags;
        destCamera.backgroundColor = srcCamera.backgroundColor;
        destCamera.farClipPlane = srcCamera.farClipPlane;
        destCamera.nearClipPlane = srcCamera.nearClipPlane;
        destCamera.focalLength = srcCamera.focalLength;
        destCamera.orthographic = srcCamera.orthographic;
        destCamera.fieldOfView = srcCamera.fieldOfView;
        destCamera.aspect = srcCamera.aspect;
        destCamera.orthographicSize = srcCamera.orthographicSize;

        destCamera.worldToCameraMatrix = srcCamera.worldToCameraMatrix;
        destCamera.projectionMatrix = srcCamera.projectionMatrix;
    }

    private Camera CreateRefractCamera()
    {
        var go = new GameObject(gameObject.name + " Refraction Camera", typeof(Camera));
        var cameraData = go.AddComponent(typeof(UniversalAdditionalCameraData)) as UniversalAdditionalCameraData;
        cameraData.requiresColorOption = CameraOverrideOption.Off;
        cameraData.requiresDepthOption = CameraOverrideOption.Off;
        cameraData.renderShadows = false;
        cameraData.SetRenderer(0);

        var refractionCamera = go.GetComponent<Camera>();
        refractionCamera.depth = -10;
        refractionCamera.enabled = false;
        go.hideFlags = HideFlags.HideAndDontSave;

        return refractionCamera;
    }
}
