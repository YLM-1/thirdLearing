using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TestPlaneReflect : MonoBehaviour
{
    public GameObject targetPlane; // 传递对称平面
    public RenderTexture reflectionRT = null; // 虚拟相机的目标纹理
    public Camera mainCamera = null; // 主相机 自己控制好了
    public float clipPlaneOffset = 0.07f;
    
    private Camera _reflectionCamera; // 虚拟相机
    
    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += UpdateCamera;
    }
    
    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= UpdateCamera;
        if(_reflectionCamera) {  // 释放相机
            _reflectionCamera.targetTexture = null;
            SafeDestroy(_reflectionCamera.gameObject);
        }
    }
    
    //安全释放对象 我是不懂得 后面对比找bug的时候 可以看下是否与此有关 
    private static void SafeDestroy(Object obj) {
        if (Application.isEditor) {
            DestroyImmediate(obj);  //TODO
        }
        else {
            Destroy(obj);   //TODO
        }
    }

    private void UpdateCamera(ScriptableRenderContext src, Camera camera)
    {
        if (camera == _reflectionCamera || camera.cameraType == CameraType.Reflection || camera.cameraType == CameraType.Preview)
            return;

        if (mainCamera != null && camera != mainCamera)
            return;
        
        if (targetPlane == null || reflectionRT == null) 
        {
            return;
        }
        if (_reflectionCamera == null) { // 创建相机 后面对比看看手动给scene相机会不会产生影响
            _reflectionCamera = CreateReflectCamera();
        }
        bool oldInvertCulling = GL.invertCulling;
        try
        {
            GL.invertCulling = !oldInvertCulling; // 反转Culling
            // 用当前渲染的相机 去配置虚拟相机 是合理的 确实应该针对每个渲染相机而言
            UpdateReflectionCamera(camera);  // 设置相机位置和方向等参数 
            // 设定渲染目标
            _reflectionCamera.targetTexture = reflectionRT;
            // render planar reflections  开始渲染函数
            UniversalRenderPipeline.RenderSingleCamera(src, _reflectionCamera);
        }
        finally
        {
            GL.invertCulling = oldInvertCulling;
        }
    }
    
    Matrix4x4 CaculateReflectMatrix(Vector4 planeVec)
    {
        Vector3 normal = new Vector3(planeVec.x, planeVec.y, planeVec.z);
        var d = planeVec.w;
        var reflectM = new Matrix4x4();
        reflectM.m00 = 1 - 2 * normal.x * normal.x;
        reflectM.m01 = -2 * normal.x * normal.y;
        reflectM.m02 = -2 * normal.x * normal.z;
        reflectM.m03 = -2 * d * normal.x;

        reflectM.m10 = -2 * normal.x * normal.y;
        reflectM.m11 = 1 - 2 * normal.y * normal.y;
        reflectM.m12 = -2 * normal.y * normal.z;
        reflectM.m13 = -2 * d * normal.y;

        reflectM.m20 = -2 * normal.x * normal.z;
        reflectM.m21 = -2 * normal.y * normal.z;
        reflectM.m22 = 1 - 2 * normal.z * normal.z;
        reflectM.m23 = -2 * d * normal.z;

        reflectM.m30 = 0;
        reflectM.m31 = 0;
        reflectM.m32 = 0;
        reflectM.m33 = 1;
        return reflectM;
    }
    
    private void UpdateReflectionCamera(Camera curCamera) {
        if (targetPlane == null) {
            Debug.LogError("target plane is null!");
        }
        // 先同步相机的基本属性
        UpdateCameraParams(curCamera, _reflectionCamera);
        // 更改view和pro
        Vector3 planeNormal = targetPlane.transform.up;
        Vector3 planePos = targetPlane.transform.position + planeNormal * clipPlaneOffset;
        var d = -Vector3.Dot(planeNormal, planePos);
        Vector4 planeVec = new Vector4(planeNormal.x, planeNormal.y, planeNormal.z, d);
        // 1 更改view
        Matrix4x4 reflectM = CaculateReflectMatrix(planeVec);
        _reflectionCamera.worldToCameraMatrix = curCamera.worldToCameraMatrix * reflectM;
        // 2 更改透视矩阵 先得到相机空间下的平面 这个和博客里的实现似乎不太一样
        Vector4 planeVecView = _reflectionCamera.worldToCameraMatrix.inverse.transpose * planeVec;
        // 3 用unity封装的api 得到 以新平面为near的新透视矩阵
        Matrix4x4 newProMatrix = _reflectionCamera.CalculateObliqueMatrix(planeVecView);
        _reflectionCamera.projectionMatrix = newProMatrix;

        
    }
    
    void UpdateCameraParams(Camera srcCamera, Camera destCamera)
    {
        destCamera.transform.position = srcCamera.transform.position;
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
    }
    
    private Camera CreateReflectCamera() {
        // 首先创建camera对象+给定名字
        var go = new GameObject(gameObject.name + " Planar Reflection Camera",typeof(Camera));
        // 需要给上固定需要的cameraData组件
        var cameraData = go.AddComponent(typeof(UniversalAdditionalCameraData)) as UniversalAdditionalCameraData;
        // 一些属性设置 后面那个setrender 应该是rendering data 这里选择我们的0
        cameraData.requiresColorOption = CameraOverrideOption.Off;
        cameraData.requiresDepthOption = CameraOverrideOption.Off;
        cameraData.renderShadows = false;
        cameraData.SetRenderer(0);  // 根据 render list 的索引选择 render TODO
        
        // 位置应该是无所谓的 后面会重新指定
        var t = transform;
        var reflectionCamera = go.GetComponent<Camera>();
        reflectionCamera.transform.SetPositionAndRotation(transform.position, t.rotation);  // 相机初始位置设为当前 gameobject 位置
        // 优先级需要比main camera的小 也就是更优先渲染
        reflectionCamera.depth = -10;  // 渲染优先级 [-100, 100]
        // 定位false 就无法被管线自动渲染，只能脚本控制自定义渲染 我是这么理解的
        reflectionCamera.enabled = false;
        go.hideFlags = HideFlags.HideAndDontSave;

        return reflectionCamera;
    }
}
