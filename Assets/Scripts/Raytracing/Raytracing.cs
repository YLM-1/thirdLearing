using System.Collections;
using System.Collections.Generic;
// using System.Numerics;
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

    ////////////// chapter3_4 //////////////
    public Light mainLight;
    public Color shadowColor;
    public float shadowIntensity = 1f;

    ////////////// chapter3_4 //////////////
    public bool aliasing;
    public RenderTexture convergedRT;
    Material addMaterial;
    public int samplePrePixel = 0;

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

        ////////////// chapter3_4 //////////////
        InitLight();
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

        if(!aliasing)
        {
            //把compute算出的纹理Blit到相机的最终目标上
            CommandBuffer cmd = CommandBufferPool.Get("Raytracing");
            cmd.Blit(rt,BuiltinRenderTextureType.CameraTarget);
            context.ExecuteCommandBuffer(cmd);
            context.Submit();
            CommandBufferPool.Release(cmd);

            // 关闭抗锯齿时，顺便把采样计数清零，防止再次开启时直接跳到很高的混合权重
            samplePrePixel = 0;
        }
        else
        {
            // --- 如果开启抗锯齿，使用累积混合 (AddShader) ---
            addMaterial.SetFloat("_SamplePrePixel", samplePrePixel);

            // 1. 将当前 Compute Shader 算出的新帧 (rt) 和历史累积纹理 (convergedRT) 进行 Blend 混合
            Graphics.Blit(rt, convergedRT, addMaterial);

            // 2. 将混合好的最终结果 Blit 到相机的最终目标（Screen / CameraTarget）
            CommandBuffer cmd = CommandBufferPool.Get("RaytracingAA");
            cmd.Blit(convergedRT, BuiltinRenderTextureType.CameraTarget);
            context.ExecuteCommandBuffer(cmd);
            context.Submit();
            CommandBufferPool.Release(cmd);

            // 3. 采样计数递增，让下一帧的新帧权重变得更小（历史积累更稳定）
            samplePrePixel++;
        }   
    }

    private void InitCam()
    {
        cam = GetComponent<Camera>();
        cam.allowHDR = true;//它的作用是让摄像机能够捕捉并输出超出常规 0~1 亮度范围、拥有更丰富光影细节的画面。
    }

    private void InitRT()
    {
        CreateRT(ref rt);
        CreateRT(ref convergedRT);
        samplePrePixel++;
    }

    private void CreateRT(ref RenderTexture rt)
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
        if(addMaterial == null)
           addMaterial = new Material(Shader.Find("MyCustom/AddMaterial"));   

        ////////////// chapter3_1 //////////////    
        cs.SetTexture(kernelHandle,"skyBoxCube",skyboxMat.GetTexture("_Tex")); 
    }

    private void InitLight()
    {
        Vector3 dir = mainLight.transform.forward;
        cs.SetVector("lightParameter",new Vector4(dir.x,dir.y,dir.z,mainLight.intensity));
        cs.SetVector("lightColor",mainLight.color);
        cs.SetVector("shadowParameter",new Vector4(shadowColor.r,shadowColor.g,shadowColor.b,shadowIntensity));
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

        ////////////// chapter3_5 //////////////
        cs.SetVector("pixelOffset", new Vector4(Random.value, Random.value, 0, 0));
        
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
