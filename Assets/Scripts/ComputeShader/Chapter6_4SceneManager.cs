using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter6_4SceneManager : MonoBehaviour
{
  public GameObject poolGO;
  public Chapter6_4 fluid;
  public RenderTexture pressureRT;
  public RenderTexture velocityRT;

  //添加参数来控制水面交互效果
  public RenderTexture reflectionRT;
  bool initialized = false;
  public float _MaxPoolDisplacement = 2.0f;

  Camera cam;
  Camera reflectionCam;

  private IEnumerator Start()
  {
     InitPool();
     yield return StartCoroutine(InitRenderTextures());

     InitFluid();
     InitReflection();
  }

  private void Update()
  {
    if(!initialized)
        return;
    UpdateReflection();
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

        reflectionRT = new RenderTexture(cam.pixelWidth,cam.pixelHeight,24);
        reflectionRT.enableRandomWrite = true;
        reflectionRT.Create();
   }
   
   private void InitFluid()
   {
        Shader.SetGlobalTexture("_PressureRT", pressureRT);
        Shader.SetGlobalTexture("_VelocityRT", velocityRT);
        Shader.SetGlobalFloat("_MaxPoolDisplacement",_MaxPoolDisplacement);
        Shader.SetGlobalFloat("_PoolWidth",cam.pixelWidth);
        Shader.SetGlobalFloat("_PoolHeight",cam.pixelHeight);
   }

   private void InitReflection()
   {
       GameObject refCamGO = new GameObject("ReflectionCamera");
       reflectionCam = refCamGO.AddComponent<Camera>();

       reflectionCam.CopyFrom(cam);
       reflectionCam.targetTexture = reflectionRT;
       reflectionCam.depth = cam.depth-1;
       // 反射相机不要渲染水面自身，否则会自我采样/黑色自成像
       reflectionCam.cullingMask = cam.cullingMask & ~(1 << 7);

       Shader.SetGlobalTexture("_ReflectionRT",reflectionRT);
       initialized=true;
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
       Vector3 poolPosInCameraSpace = reflectionCam.worldToCameraMatrix.MultiplyPoint(poolGO.transform.position);
       Vector3 poolNormalInCameraSpace = reflectionCam.worldToCameraMatrix.MultiplyVector(poolGO.transform.up);

       //构建近裁剪平面，平面方程dot(n,p-p0),float4(x,y,z,-dot(n,p))
       float np = -Vector3.Dot(poolNormalInCameraSpace,poolPosInCameraSpace);
       Vector4 clipPlaneCameraSpace = new Vector4(poolNormalInCameraSpace.x,poolNormalInCameraSpace.y,poolNormalInCameraSpace.z,np);

       Matrix4x4 newMat = cam.CalculateObliqueMatrix(clipPlaneCameraSpace);//计算的矩阵是从相机空间到裁剪空间的矩阵，裁剪平面是相机空间下的平面
       reflectionCam.projectionMatrix = newMat;

       //传递给shader的接口需要是世界空间，而非相机空间
       Shader.SetGlobalMatrix("_ReflectionCamProjMatrix",GL.GetGPUProjectionMatrix(reflectionCam.projectionMatrix,true)*reflectionCam.worldToCameraMatrix);
       Shader.SetGlobalVector("_ReflectionCamPos",reflectionCam.transform.position);
   }
}
