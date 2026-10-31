using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class Ocean : MonoBehaviour
{
    private Camera cam;
    private Camera reflectCam;
    [SerializeField] private Transform waterPlane;
    [SerializeField] private RenderTexture reflectionRT;
    //反射用的裁剪平面沿水面向法线方向抬一点点，避免水面自己和水线处的深度冲突（闪烁亮边）
    [SerializeField] private float clipPlaneOffset = 0.07f;
    //private Camera refractCam;
    //[SerializeField] private RenderTexture refractionRT;
    //水面所在的独立层：反射/折射相机不能渲染它
    private int waterLayer;
    private int hiddenFromSubCameras;
    private void Start()
    {
        cam = Camera.main;

        //水面必须放在单独的一层（Fluid）。
        //否则折射相机会把水面自己也渲染进 _RefractionRT，而水面 shader 又去采样这张 RT，
        //形成"自己采样自己"的反馈环，表现出来就是水面持续频闪。
        waterLayer = LayerMask.NameToLayer("Fluid");
        if (waterLayer < 0) waterLayer = 7;
        foreach (var r in waterPlane.GetComponentsInChildren<Renderer>(true))
        {
            r.gameObject.layer = waterLayer;
        }

        hiddenFromSubCameras = 1 << waterLayer;
        int uiLayer = LayerMask.NameToLayer("UI");
        if (uiLayer >= 0) hiddenFromSubCameras |= 1 << uiLayer;

        InitTextures();
        InitReflection();
        //InitRefraction();     //旧折射方案，已改用 _CameraOpaqueTexture
    }

    private void Update()
    {
        UpdateReflection();
        //UpdateRefraction();   //旧折射方案，已改用 _CameraOpaqueTexture
        CheckRenderTextureSize();
    }

    private RenderTexture CreateTexture(string name, bool useMipMap)
    {
        //窗口最小化时 pixelWidth 可能是 0，直接 new 会拿到非法尺寸
        var rt = new RenderTexture(Mathf.Max(cam.pixelWidth, 1), Mathf.Max(cam.pixelHeight, 1), 24, RenderTextureFormat.DefaultHDR);
        rt.name = name;
        rt.useMipMap = useMipMap;
        rt.autoGenerateMips = useMipMap;
        rt.wrapMode = TextureWrapMode.Clamp;
        rt.Create();
        return rt;
    }

    //Game 视图/窗口大小变化后 RT 尺寸不会自己跟着变，反射会整体拉伸 —— 检测到尺寸变了就重建
    private void CheckRenderTextureSize()
    {
        if (reflectionRT == null || cam == null) return;
        if (cam.pixelWidth <= 0 || cam.pixelHeight <= 0) return;   //窗口最小化时跳过

        int w = cam.pixelWidth;
        int h = cam.pixelHeight;
        if (reflectionRT.width == w && reflectionRT.height == h) return;

        reflectionRT.Release();
        reflectionRT = CreateTexture("_OceanReflectionRT", true);
        reflectCam.targetTexture = reflectionRT;
        Shader.SetGlobalTexture("_ReflectionRT", reflectionRT);
    }

    private void InitTextures()
    {
        //只有反射需要 mip（模糊），折射不模糊，开 mip 纯浪费显存和带宽
        reflectionRT = CreateTexture("_OceanReflectionRT", true);
        //refractionRT = CreateTexture("_OceanRefractionRT", false);   //旧折射方案
    }
    private void InitReflection()
    {
        GameObject camObj = new GameObject("ReflectCamera");
        reflectCam = camObj.AddComponent<Camera>();

        reflectCam.CopyFrom(cam);
        reflectCam.targetTexture = reflectionRT;
        reflectCam.depth = cam.depth-1;
        // 反射相机不要渲染水面自身（会自我采样），也不要渲染 UI 层
        reflectCam.cullingMask = cam.cullingMask & ~hiddenFromSubCameras;
        // 反射相机在水下、朝向和主相机相反，遮挡剔除数据是按主视角烘的，开着会让倒影里的物件闪没
        reflectCam.useOcclusionCulling = false;
        SetupSubCameraData(reflectCam);

        Shader.SetGlobalTexture("_ReflectionRT",reflectionRT);
    }

    // private void InitRefraction()
    // {
    //     GameObject camObj = new GameObject("RefractCamera");
    //     refractCam = camObj.AddComponent<Camera>();

    //     refractCam.CopyFrom(cam);
    //     refractCam.targetTexture = refractionRT;
    //     //渲染顺序：折射 -> 反射 -> 主相机
    //     refractCam.depth = reflectCam.depth-1;
    //     // 和反射相机一样不能渲染水面自身，
    //     // 否则折射贴图会把水面自己采进去，造成自采样/闪烁
    //     refractCam.cullingMask = cam.cullingMask & ~hiddenFromSubCameras;
    //     SetupSubCameraData(refractCam);

    //     Shader.SetGlobalTexture("_RefractionRT",refractionRT);
    // }

    //给渲染到 RT 的虚拟相机补上 URP 的相机数据，并把"深度/不透明色拷贝"关掉。
    //不关的话 URP 会按 URP Asset 的全局设置（RequireDepthTexture / RequireOpaqueTexture 都开着），
    //给每台渲染到 RT 的相机各做一次全屏 CopyDepth + CopyColor —— 这两张图没人采样，纯浪费。
    private static void SetupSubCameraData(Camera subCam)
    {
        var data = subCam.gameObject.AddComponent<UniversalAdditionalCameraData>();
        data.requiresColorOption = CameraOverrideOption.Off;
        data.requiresDepthOption = CameraOverrideOption.Off;
    }

    private void UpdateReflection()
    {
        //建立反射相机

        //1.计算position
        Vector4 mainCamPos = waterPlane.InverseTransformPoint(cam.transform.position);
        Vector4 reflectPos = new Vector4(mainCamPos.x,-mainCamPos.y,mainCamPos.z,1f);
        reflectPos = waterPlane.TransformPoint(reflectPos);
        reflectCam.transform.position = reflectPos;

        //2.计算rotation
        Vector4 mainCamDir = waterPlane.InverseTransformDirection(cam.transform.forward);
        Vector4 reflectDirForward = new Vector4(mainCamDir.x,-mainCamDir.y,mainCamDir.z,0);
        reflectDirForward = waterPlane.TransformDirection(reflectDirForward);
        reflectCam.transform.forward = reflectDirForward;

        Vector4 mainCamUp = waterPlane.InverseTransformDirection(cam.transform.up);
        Vector4 reflectDirUp = new Vector4(mainCamUp.x,-mainCamUp.y,mainCamUp.z,0);
        reflectDirUp = waterPlane.TransformDirection(reflectDirUp);
        reflectCam.transform.up = reflectDirUp;

        reflectCam.transform.LookAt(reflectPos+reflectDirForward,reflectDirUp);

        //此时已经计算好position和rotation，接下来计算oblique matrix;

       //将水池模型的position转换到反射相机空间
       //沿法线抬高一点点：否则水面自己/水线处容易出现深度冲突，表现为岸边闪一条亮边
       Vector3 planePos = waterPlane.transform.position + waterPlane.transform.up * clipPlaneOffset;
       Vector3 poolPosInCameraSpace = reflectCam.worldToCameraMatrix.MultiplyPoint(planePos);
       Vector3 poolNormalInCameraSpace = reflectCam.worldToCameraMatrix.MultiplyVector(waterPlane.transform.up);

       //构建近裁剪平面，平面方程dot(n,p-p0),float4(x,y,z,-dot(n,p))
       float np = -Vector3.Dot(poolNormalInCameraSpace,poolPosInCameraSpace);
       Vector4 clipPlaneCameraSpace = new Vector4(poolNormalInCameraSpace.x,poolNormalInCameraSpace.y,poolNormalInCameraSpace.z,np);

       //必须用反射相机自己的投影矩阵来算（用主相机的话，两边的投影参数一旦不一致就会歪）
       reflectCam.projectionMatrix = reflectCam.CalculateObliqueMatrix(clipPlaneCameraSpace);
    }

    // private void UpdateRefraction()
    // {
    //     //折射相机就是"去掉了水面"的主相机：
    //     // 1.position/rotation 直接跟随主相机，不需要像反射那样做镜像
    //     refractCam.transform.SetPositionAndRotation(cam.transform.position,cam.transform.rotation);
    //     // 2.投影矩阵也用主相机的，保证折射贴图和主相机屏幕像素一一对应，
    //     //   shader 里就可以直接用 screenUV + 法线偏移 采样 _RefractionRT
    //     refractCam.projectionMatrix = cam.projectionMatrix;

    //     // 3.和反射一样把矩阵传给shader，方便用世界坐标反推折射贴图UV
    //     Shader.SetGlobalMatrix("_RefractionCamProjMatrix",GL.GetGPUProjectionMatrix(refractCam.projectionMatrix,true)*refractCam.worldToCameraMatrix);
    //     Shader.SetGlobalVector("_RefractionCamPos",refractCam.transform.position);
    // }

    private void OnDestroy() 
    {
        reflectionRT?.Release();
        //refractionRT?.Release();   //旧折射方案
        //运行时 new 出来的反射相机不会随场景卸载自动消失，手动销毁
        if (reflectCam != null) Destroy(reflectCam.gameObject);
    }
}
