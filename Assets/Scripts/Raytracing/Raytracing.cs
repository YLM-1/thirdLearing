using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(Camera))]
public class Raytracing : MonoBehaviour
{
    ////////////// chapter2_1 //////////////
    public ComputeShader cs;
    public RenderTexture rt;
    ////////////// chapter2_2 //////////////
    public MeshCollector meshCollector;
    ////////////// chapter3_1 //////////////
    public Material skyboxMat;

    Camera cam;
    int kernelHandle;
    bool isInitialized;

    void Start()
    {
        ////////////// chapter2_1 //////////////
        InitCam();
        InitRT();
        ////////////// chapter2_2 //////////////
        InitShader();

        //在所有初始化结束以后isInitialized=true
        isInitialized = true;
    }

    void Update()
    {
        ////////////// chapter2_1 //////////////
        if(transform.hasChanged)
        {
            //Unity 内部不会自动帮你把它重置为 false
            //一旦你在某帧检测到它变了，你需要手动把它改回 false，这样在下一帧时，它才能正确继续监听“物体是不是又动了”。
            transform.hasChanged=false;
        }
    }

    ////////////// chapter2_1 //////////////
    //URP不会调用内置管线的OnRenderImage，改用RenderPipelineManager的相机渲染回调
    private void OnEndCameraRendering(ScriptableRenderContext context,Camera camera)
    {
        //该回调对所有相机（场景相机、预览相机等）都会触发，这里只处理本物体上的相机
        if(camera != cam)
            return;

        if (!cs || !isActiveAndEnabled || !isInitialized)
            return;
        if (rt == null || rt.width != Screen.width || rt.height != Screen.height)  
            InitRT();

        UpdateParameters();  

        cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out uint y,out _);
        int groupX = Mathf.CeilToInt((float)rt.width/x);  
        int groupY = Mathf.CeilToInt((float)rt.height/y);
        cs.Dispatch(kernelHandle,groupX,groupY,1);

        //把compute算出的纹理Blit到相机的最终目标上
        CommandBuffer cmd = CommandBufferPool.Get("Raytracing");
        cmd.Blit(rt,BuiltinRenderTextureType.CameraTarget);
        context.ExecuteCommandBuffer(cmd);
        context.Submit();
        CommandBufferPool.Release(cmd);
    }

    private void InitCam()
    {
        cam = GetComponent<Camera>();
        cam.allowHDR = true;//它的作用是让摄像机能够捕捉并输出超出常规 0~1 亮度范围、拥有更丰富光影细节的画面。
    }

    private void InitRT()
    {
        //强制指定该渲染纹理工作在线性颜色空间（Linear Color Space），不进行 sRGB 曲线的自动伽马矫正（Gamma Correction）。
        //在进行物理光照计算、向量数学运算或后处理累加时，我们必须保证数据是线性的，否则光照的叠加和衰减数学公式算出来会失真。
        rt = new RenderTexture(Screen.width,Screen.height,0,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear);
        rt.enableRandomWrite=true;
        rt.Create();
    }

    private void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        //把场景里的平面数据绑定到 CSMain 上，否则 Dispatch 会报 planeBuffer 未设置
        if (meshCollector != null)
            meshCollector.Init(cs, kernelHandle);

        ////////////// chapter3_1 //////////////    
        cs.SetTexture(kernelHandle,"skyBoxCube",skyboxMat.GetTexture("_Tex")); 
    }

    private void UpdateParameters()
    {
        cs.SetTexture(kernelHandle,"destination",rt);

        //尺寸每帧同步，窗口resize后重建rt时也能保持一致
        cs.SetFloat("width",rt.width);
        cs.SetFloat("height",rt.height);

        //将相机的“相机到世界（Camera-to-World）”矩阵传给名为 camera2World 的变量
        //GPU 必须知道相机在世界坐标系里到底在哪、朝哪个方向看
        cs.SetMatrix("camera2World",cam.cameraToWorldMatrix);
        //相机的投影矩阵负责把 3D 世界的物体压缩并投影到 2D 的屏幕上。
        //而在光线追踪中，我们的起点反而是 2D 屏幕上的每一个像素，需要“反向推导”出它在 3D 空间里的发射方向
        cs.SetMatrix("cameraInverseProjection",cam.projectionMatrix.inverse);
    }

    private void OnEnable()
    {
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    private void OnDisable()
    {
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;

        if(rt!=null)
        {
           rt.Release();
           rt = null;
        }
    }
}
