using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter6_4SceneManager : MonoBehaviour
{
  public GameObject poolGO;
  public Chapter6_4 fluid;
  public RenderTexture pressureRT;
  public RenderTexture velocityRT;
  [Range(0,1f)]
  public float flowStrength=0.5f;

  //添加参数来控制水面交互效果
  public RenderTexture reflectionRT;
  bool initialized = false;
  public float _MaxPoolDisplacement = 2.0f;//控制水面的顶点位移

  [Header("水面波纹")]
  [Tooltip("压力梯度放大倍数，越大水波越明显（池底焦散那边等效放大约 60 倍）")]
  public float normalStrength = 60f;

  //反射
  [Range(0,1f)]
  public float reflectionStrength = 1f;
  [Range(0f, 0.2f)]
  public float reflectionDistort = 0.03f;

  //折射扰动效果
  [Range(0,0.1f)]
  public float depthDensity = 0.1f;
  public float refractionDistort = 0.01f;

  //焦散效果
  public Texture testMap;
  public Camera lightCamera;
  public Light sunLight;
  [Tooltip("焦散光相机的正交尺寸；<= 0 时按水面 bounds 自动计算")]
  public float causticOrthoSize = 0f;
  public float causticIntensity = 50f;
  public float bottomDepth=10f;

  Camera cam;
  Camera reflectionCam;

  [SerializeField] private Transform streamTrans;
  public float streamStrength = 100.0f;

  private IEnumerator Start()
  {
     InitPool();
     yield return StartCoroutine(InitRenderTextures());

     InitFluid();
     InitReflection();
     InitCausticCamera();
     UpdateShaderGlobals();
     UpdateReflection();
     UpdateLightCam();

     initialized = true;
  }

  private void Update()
  {
    if(!initialized)
        return;

    EnsureReflectionTexture();
    UpdateShaderGlobals();
    UpdateReflection();
    UpdateStream();
    UpdateLightCam();
  }

  private void InitPool()
  {
      fluid = poolGO.GetComponent<Chapter6_4>();
  }

   IEnumerator InitRenderTextures()
  {
        cam = Camera.main;

        while (fluid.p1 == null || fluid.v1 == null)
            yield return null;

        pressureRT = fluid.p1;
        velocityRT = fluid.v1;

        int reflectionWidth = Mathf.Max(1, cam.pixelWidth / 2);
        int reflectionHeight = Mathf.Max(1, cam.pixelHeight / 2);

        reflectionRT = new RenderTexture(
            reflectionWidth,
            reflectionHeight,
            24,
            RenderTextureFormat.DefaultHDR);
        reflectionRT.wrapMode = TextureWrapMode.Clamp;
        reflectionRT.filterMode = FilterMode.Bilinear;
        reflectionRT.Create();
   }

   private void EnsureReflectionTexture()
   {
        if (cam.pixelWidth <= 0 || cam.pixelHeight <= 0)
            return;

        int w = Mathf.Max(1, cam.pixelWidth / 2);
        int h = Mathf.Max(1, cam.pixelHeight / 2);

        if (reflectionRT != null && reflectionRT.width == w && reflectionRT.height == h)
            return;

        if (reflectionRT != null)
            reflectionRT.Release();

        reflectionRT = new RenderTexture(w, h, 24, RenderTextureFormat.DefaultHDR);
        reflectionRT.wrapMode = TextureWrapMode.Clamp;
        reflectionRT.filterMode = FilterMode.Bilinear;
        reflectionRT.Create();

        if (reflectionCam != null)
            reflectionCam.targetTexture = reflectionRT;

        Shader.SetGlobalTexture("_ReflectionRT", reflectionRT);
   }

   private void UpdateShaderGlobals()
   {
        Shader.SetGlobalFloat("_MaxPoolDisplacement", _MaxPoolDisplacement);
        Shader.SetGlobalFloat("_PoolWidth", pressureRT.width);
        Shader.SetGlobalFloat("_PoolHeight", pressureRT.height);
        Shader.SetGlobalFloat("_FlowStrength", flowStrength);
        Shader.SetGlobalFloat("_NormalStrength", normalStrength);

        // 压力场的世界 XZ 映射范围（水面和水面下的池底共用）
        if (poolGO != null)
        {
            Renderer waterRenderer = poolGO.GetComponentInChildren<Renderer>();
            if (waterRenderer != null)
            {
                Bounds b = waterRenderer.bounds;
                Shader.SetGlobalVector("_WaterMinXZ", new Vector4(b.min.x, b.min.z, 0f, 0f));
                Shader.SetGlobalVector("_WaterSizeXZ", new Vector4(Mathf.Max(b.size.x, 1e-6f), Mathf.Max(b.size.z, 1e-6f), 0f, 0f));
            }
        }

        Shader.SetGlobalFloat("_ReflectionStrength", reflectionStrength);
        Shader.SetGlobalFloat("_ReflectionDistort", reflectionDistort);

        Shader.SetGlobalFloat("_DepthDensity", depthDensity);
        Shader.SetGlobalFloat("_RefractionDistort", refractionDistort);

        Shader.SetGlobalFloat("_BottomDepth", bottomDepth);
        Shader.SetGlobalFloat("_CausticIntensity", causticIntensity);
        Shader.SetGlobalTexture("_TestMap", testMap);
   }
   
   private void InitFluid()
   {
        // RT 引用只设置一次；ComputeShader 每帧写入同一批 RT，所以水面采样是实时的
        Shader.SetGlobalTexture("_PressureRT", pressureRT);
        Shader.SetGlobalTexture("_VelocityRT", velocityRT);
   }

   private void InitReflection()
   {
       GameObject refCamGO = new GameObject("ReflectionCamera");
       reflectionCam = refCamGO.AddComponent<Camera>();

       reflectionCam.CopyFrom(cam);
       reflectionCam.targetTexture = reflectionRT;
       reflectionCam.depth = cam.depth - 1;

       reflectionCam.allowMSAA = false;
       reflectionCam.allowHDR = true;

       // 反射相机不要渲染水面自身，否则会自我采样/黑色自成像。
       // 这里把 poolGO 下所有 Renderer 都归到 Fluid 层，防止 FBX 子节点仍留在 Default 层。
       const int fluidLayer = 7;
       foreach (var r in poolGO.GetComponentsInChildren<Renderer>(true))
           r.gameObject.layer = fluidLayer;

       reflectionCam.cullingMask = cam.cullingMask & ~(1 << fluidLayer);

       Shader.SetGlobalTexture("_ReflectionRT",reflectionRT);
   }

   // 焦散光相机：不要挂在主相机下，应该固定在世界里、沿平行光方向投影
   private void InitCausticCamera()
   {
       if (lightCamera == null)
           return;

       if (sunLight == null)
       {
           sunLight = RenderSettings.sun;
           if (sunLight == null)
           {
               foreach (var l in FindObjectsOfType<Light>())
               {
                   if (l.type == LightType.Directional)
                   {
                       sunLight = l;
                       break;
                   }
               }
           }
       }

       if (sunLight == null)
       {
           Debug.LogWarning("[Caustic] 没找到 Directional Light，焦散投影会沿用当前 lightCamera 的朝向。");
           return;
       }

       // 从主相机下移出来，避免光相机跟着视线移动
       lightCamera.transform.SetParent(null, true);
       lightCamera.enabled = false;
       lightCamera.orthographic = true;
       lightCamera.nearClipPlane = 0.3f;
       lightCamera.farClipPlane = 1000f;
       lightCamera.aspect = cam.aspect;

       if (causticOrthoSize > 0.01f)
       {
           lightCamera.orthographicSize = causticOrthoSize;
       }
       else
       {
           var waterRenderer = poolGO != null ? poolGO.GetComponent<Renderer>() : null;
           if (waterRenderer != null)
           {
               Bounds b = waterRenderer.bounds;
               lightCamera.orthographicSize = Mathf.Max(b.size.x, b.size.z) * 0.5f * 1.1f;
               //Debug.Log($"[Caustic] 自动 orthoSize={lightCamera.orthographicSize:F2}，水面 bounds={b.size}");
           }
           else
           {
               lightCamera.orthographicSize = 15.14f;
           }
       }

       UpdateLightCamTransform();
   }

    private void UpdateStream()
    {
        if (streamTrans == null || poolGO == null) return;

        Bounds b = poolGO.GetComponentInChildren<Renderer>().bounds;

        Vector3 p = streamTrans.position;
        float u = Mathf.Clamp01((p.x - b.min.x) / Mathf.Max(b.size.x, 1e-6f));
        float v = Mathf.Clamp01((p.z - b.min.z) / Mathf.Max(b.size.z, 1e-6f));

        Vector3 dir = streamTrans.forward;
        fluid.ExternalForce(new Vector3(u, v, 0f),new Vector3(dir.x, dir.z, 0f) * streamStrength);
    }
   private void UpdateLightCamTransform()
   {
       if (lightCamera == null || sunLight == null)
           return;

       // 光相机放在平行光的位置、朝向和光一致
       lightCamera.transform.position = sunLight.transform.position;
       lightCamera.transform.rotation = sunLight.transform.rotation;
   }

   private void UpdateLightCam()
   {
       if (lightCamera == null)
           return;

       UpdateLightCamTransform();

       //焦散的实现就是实现一个decal，作用在水池底部和周围的模型上
       Shader.SetGlobalMatrix("_LightCamProjMatrix", GL.GetGPUProjectionMatrix(lightCamera.projectionMatrix, true) * lightCamera.worldToCameraMatrix);
   }

   private void UpdateReflection()
   {
       //建立反射相机的位置

       //1.计算position
       //1.1将相机位置从世界空间转换到水池模型的局部坐标系
       //它接收一个世界坐标点，并将其计算转换为以 poolGO 为原点、以 poolGO 的旋转为方向、以 poolGO 的缩放为尺度的局部空间坐标。
       Vector4 mainCamPos = poolGO.transform.InverseTransformPoint(cam.transform.position);
       //1.2反射相机的position是主相机关于水池模型的xz平面的镜像，即y取反
       Vector4 refCamPos = new Vector4(mainCamPos.x,-mainCamPos.y,mainCamPos.z,1f);
       //1.3将反射相机的位置从局部坐标系转换到世界坐标
       refCamPos = poolGO.transform.TransformPoint(refCamPos);
       reflectionCam.transform.position = refCamPos;

       //2.计算rotation
       //2.1将主相机的朝向从世界坐标转换到水池模型的局部坐标系
       Vector4 mainCamDir = poolGO.transform.InverseTransformDirection(cam.transform.forward);
       //2.2反射相机的朝向是主相机关于水池模型的xz平面的镜像，即y取反
       Vector4 refCamForward = new Vector4(mainCamDir.x,-mainCamDir.y,mainCamDir.z,0f);
       //2.3将反射相机的位置从局部坐标系转到世界坐标系下
       refCamForward = poolGO.transform.TransformDirection(refCamForward);

       //2.4将主摄像机的up从世界坐标转到水池模型的局部坐标系
       Vector4 mainCamUp = poolGO.transform.InverseTransformDirection(cam.transform.up);
       //2.5反射相机的up是主相机关于水池模型的xz平面的镜像，即y取反
       Vector4 refCamUp = new Vector4(mainCamUp.x,-mainCamUp.y,mainCamUp.z,0f);
       //2.6将反射相机的up从局部坐标系转到世界坐标系下      
       refCamUp = poolGO.transform.TransformDirection(refCamUp);

       reflectionCam.transform.LookAt(refCamPos+refCamForward,refCamUp);

       //此时已经计算好position和rotation，接下来计算oblique matrix;

       //将水池模型的position转换到反射相机空间
       Vector3 worldNormal = poolGO.transform.up;
       if (Vector3.Dot(cam.transform.position - poolGO.transform.position, worldNormal) < 0f)
           worldNormal = -worldNormal;

       Vector3 poolPosInCameraSpace = reflectionCam.worldToCameraMatrix.MultiplyPoint(poolGO.transform.position);
       Vector3 poolNormalInCameraSpace = reflectionCam.worldToCameraMatrix.MultiplyVector(worldNormal);

       //构建近裁剪平面，平面方程dot(n,p-p0),float4(x,y,z,-dot(n,p))
       float np = -Vector3.Dot(poolNormalInCameraSpace,poolPosInCameraSpace);
       Vector4 clipPlaneCameraSpace = new Vector4(poolNormalInCameraSpace.x,poolNormalInCameraSpace.y,poolNormalInCameraSpace.z,np);

       Matrix4x4 newMat = cam.CalculateObliqueMatrix(clipPlaneCameraSpace);//计算的矩阵是从相机空间到裁剪空间的矩阵，裁剪平面是相机空间下的平面
       reflectionCam.projectionMatrix = newMat;

       //传递给shader的接口需要是世界空间，而非相机空间
       Shader.SetGlobalMatrix("_ReflectionCamProjMatrix",GL.GetGPUProjectionMatrix(reflectionCam.projectionMatrix,true)*reflectionCam.worldToCameraMatrix);
       Shader.SetGlobalVector("_ReflectionCamPos",reflectionCam.transform.position);
   }

   private void OnDestroy()
   {
       if (reflectionRT != null)
       {
           reflectionRT.Release();
           Destroy(reflectionRT);
       }

       if (reflectionCam != null)
           Destroy(reflectionCam.gameObject);
   }
}
