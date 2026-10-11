using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Raytracing : MonoBehaviour
{
    ////////////// chapter2_1 //////////////
    [SerializeField] private ComputeShader cs;
    [SerializeField] private RenderTexture rt;

    Camera cam;
    int kernelHandle;
    bool isInitialized;

    void Start()
    {
        ////////////// chapter2_1 //////////////
        InitCam();
        InitRT();
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
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CustomRender(destination);
    }

    private void CustomRender(RenderTexture destination)
    {
        if (!cs || !isActiveAndEnabled || !isInitialized)
            return;
        Graphics.Blit(rt,destination);    
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
        rt = new RenderTexture(cam.pixelWidth,cam.pixelHeight,0,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear);
        rt.enableRandomWrite=true;
        rt.Create();
    }

    private void OnDisable()
    {
        if(rt!=null)
           rt.Release();
    }
}
