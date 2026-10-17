using System.Collections;
using System.Collections.Generic;
using UnityEditor.SceneManagement;
using UnityEngine;

public class Ocean : MonoBehaviour
{
    private Camera cam;
    private Camera reflectCam;
    private Camera refractCam;
    [SerializeField] private Transform waterPlane;
    [SerializeField] private RenderTexture reflectionRT;
    [SerializeField] private RenderTexture refractionRT;
    //水面所在的独立层：反射/折射相机不能渲染它
    private int waterLayer;
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

        InitTextures();
        InitReflection();
        InitRefraction();
    }

    private void Update()
    {
        UpdateReflection();
        UpdateRefraction();
    }

    private void CreateTexture(ref RenderTexture rt)
    {
        rt = new RenderTexture(cam.pixelWidth,cam.pixelHeight,16);
        rt.Create();
    }

    private void InitTextures()
    {
        CreateTexture(ref reflectionRT);
        CreateTexture(ref refractionRT);
    }
    private void InitReflection()
    {
        GameObject camObj = new GameObject("ReflectCamera");
        reflectCam = camObj.AddComponent<Camera>();

        reflectCam.CopyFrom(cam);
        reflectCam.targetTexture = reflectionRT;
        reflectCam.depth = cam.depth-1;
        // 反射相机不要渲染水面自身，否则会自我采样/黑色自成像
        reflectCam.cullingMask = cam.cullingMask & ~(1 << waterLayer);

        Shader.SetGlobalTexture("_ReflectionRT",reflectionRT);
    }

    private void InitRefraction()
    {
        GameObject camObj = new GameObject("RefractCamera");
        refractCam = camObj.AddComponent<Camera>();

        refractCam.CopyFrom(cam);
        refractCam.targetTexture = refractionRT;
        //渲染顺序：折射 -> 反射 -> 主相机
        refractCam.depth = reflectCam.depth-1;
        // 和反射相机一样不能渲染水面自身，
        // 否则折射贴图会把水面自己采进去，造成自采样/闪烁
        refractCam.cullingMask = cam.cullingMask & ~(1 << waterLayer);

        Shader.SetGlobalTexture("_RefractionRT",refractionRT);
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

        //注意：position/forward/up 都镜像后得到的是左手系，而 LookAt 只能重建右手系，
        //相机的 right 会被算成 -R·right，所以这张RT相对正确反射是左右镜像的。
        //这里保留这种写法，由 shader（OceanPro.hlsl 中的 reflectUV）把 X 翻回来采样。

        //此时已经计算好position和rotation，接下来计算oblique matrix;

       //将水池模型的position转换到反射相机空间
       Vector3 poolPosInCameraSpace = reflectCam.worldToCameraMatrix.MultiplyPoint(waterPlane.transform.position);
       Vector3 poolNormalInCameraSpace = reflectCam.worldToCameraMatrix.MultiplyVector(waterPlane.transform.up);

       //构建近裁剪平面，平面方程dot(n,p-p0),float4(x,y,z,-dot(n,p))
       float np = -Vector3.Dot(poolNormalInCameraSpace,poolPosInCameraSpace);
       Vector4 clipPlaneCameraSpace = new Vector4(poolNormalInCameraSpace.x,poolNormalInCameraSpace.y,poolNormalInCameraSpace.z,np);

       Matrix4x4 newMat = cam.CalculateObliqueMatrix(clipPlaneCameraSpace);//计算的矩阵是从相机空间到裁剪空间的矩阵，裁剪平面是相机空间下的平面
       reflectCam.projectionMatrix = newMat;

       //传递给shader的接口需要是世界空间，而非相机空间
       Shader.SetGlobalMatrix("_ReflectionCamProjMatrix",GL.GetGPUProjectionMatrix(reflectCam.projectionMatrix,true)*reflectCam.worldToCameraMatrix);
       Shader.SetGlobalVector("_ReflectionCamPos",reflectCam.transform.position);
    }

    private void UpdateRefraction()
    {
        //折射相机就是"去掉了水面"的主相机：
        // 1.position/rotation 直接跟随主相机，不需要像反射那样做镜像
        refractCam.transform.SetPositionAndRotation(cam.transform.position,cam.transform.rotation);
        // 2.投影矩阵也用主相机的，保证折射贴图和主相机屏幕像素一一对应，
        //   shader 里就可以直接用 screenUV + 法线偏移 采样 _RefractionRT
        refractCam.projectionMatrix = cam.projectionMatrix;

        // 3.和反射一样把矩阵传给shader，方便用世界坐标反推折射贴图UV
        Shader.SetGlobalMatrix("_RefractionCamProjMatrix",GL.GetGPUProjectionMatrix(refractCam.projectionMatrix,true)*refractCam.worldToCameraMatrix);
        Shader.SetGlobalVector("_RefractionCamPos",refractCam.transform.position);
    }

    private void OnDestroy() 
    {
        reflectionRT?.Release();
        refractionRT?.Release();
    }
}
