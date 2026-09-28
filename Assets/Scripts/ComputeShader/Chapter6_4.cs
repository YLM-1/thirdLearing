using System.Collections;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using UnityEngine;

public class Chapter6_4 : MonoBehaviour
{
   [SerializeField] private ComputeShader cs;
   [SerializeField] private int texsolution = 1024;
   [SerializeField] private Texture2D texture;
   [SerializeField] private Camera cam;
   [SerializeField] private LayerMask fluidLayer;
   private Material mat;
   private Vector3 lastPos,curPos;
    private int groupSizeX;
   private int groupSizeY;
   //Step:Force
   private int kernelForce;
    [SerializeField] private RenderTexture v0;
   [SerializeField] private RenderTexture v1;

   //Step:Advect
   private int kernelAdvect;
   [SerializeField] private float advectSpeed=1f;

   //Step:Diffusion
   private int kernelDiffusion;
   [SerializeField] private int diffusionIterateCount = 20;
   [SerializeField] private float viscosity = 0.5f;

   //Step:Projection
   private int kernelDivergence;
   [SerializeField] private RenderTexture div;

   //Step:Display
   private int kernelDisplay;
    [SerializeField] private RenderTexture col0;
   [SerializeField] private RenderTexture col1;

   //Step1:Force
   [SerializeField] private float force = 40000f;
   [SerializeField] private float radius = 0.001f;//经验参数,可以是1/贴图大小，也可以根据运用到的模型的大小调节

    private void Start()
    {
        CreateTextures();
        InitComputeShader();

        Graphics.Blit(texture,col0);
    }

    private void OnValidate()
    {
        cs.SetFloat("radius",radius);
        cs.SetFloat("advectSpeed",advectSpeed);

        cs.SetFloat("viscosity",viscosity);
    }

    private void Update()
    {
        //Step1:外力Force;
        ExternalForce();

        //Step2:周围像素流动带来的数值
        Advect();

        //Step3:周围像素扩散带来的数值
        Diffusion();

        //Step4:当前像素和周围像素的碰撞
        Projection();

        //Step5:展示效果
        Display();
    }

    private RenderTexture CreateTexture(RenderTextureFormat format = RenderTextureFormat.ARGBHalf)
    {
        var rt = new RenderTexture(texsolution,texsolution,0,format);
        rt.enableRandomWrite = true;
        rt.Create();
        return rt;
    }

    private void CreateTextures()
    {
        //RGHalf是可以表示+-值的贴图类型
        v0 = CreateTexture(RenderTextureFormat.RGHalf);
        v1 = CreateTexture(RenderTextureFormat.RGHalf);

        col0 = CreateTexture();
        col1 = CreateTexture();

        div = CreateTexture(RenderTextureFormat.RHalf);
    }

    private void InitComputeShader()
    {
        kernelForce = cs.FindKernel("Force");
        kernelAdvect = cs.FindKernel("Advect");
        kernelDisplay = cs.FindKernel("Display");
        kernelDiffusion = cs.FindKernel("Diffusion");
        kernelDivergence = cs.FindKernel("Divergence");

        cs.GetKernelThreadGroupSizes(kernelForce,out uint x,out uint y,out _);
        groupSizeX = Mathf.CeilToInt(texsolution/(float)x);
        groupSizeY = Mathf.CeilToInt(texsolution/(float)y);

        cs.SetFloat("width",texsolution);
        cs.SetFloat("height",texsolution);

        mat = GetComponent<MeshRenderer>().material;
    }

    private Vector3 GetUserInput()
    {
        Vector3 curPos = Vector3.zero;

        Ray ray = cam.ScreenPointToRay(Input.mousePosition);//发射从摄像机到鼠标的射线

        if(Physics.Raycast(ray,out RaycastHit hitInfo,100f,fluidLayer))
        {
            //hitInfo.textureCoord 返回的是碰撞点在网格（Mesh）上的 UV 坐标，取值范围通常在 0-1之间。
            curPos = hitInfo.textureCoord;
        }
        else
             curPos = lastPos;
        return curPos;     
    }

    private void SwapTexture(ref RenderTexture v0,ref RenderTexture v1)
    {
        RenderTexture tt = v0;
        v0 = v1;
        v1 = tt;
    }

    private void ExternalForce()
    {
        //按下鼠标左键的那一帧
        if(Input.GetMouseButtonDown(0))
        {
            lastPos = GetUserInput();
        }
        //按下鼠标期间
        if(Input.GetMouseButton(0))
        {
            curPos = GetUserInput();
        }

        cs.SetVector("forcePos",curPos);
        cs.SetVector("forceVector",(curPos-lastPos)*force);

        cs.SetTexture(kernelForce,"input0",v0);
        cs.SetTexture(kernelForce,"output",v1);
        cs.SetFloat("deltaTime",Time.deltaTime);

        cs.Dispatch(kernelForce,groupSizeX,groupSizeY,1);

        //ref 关键字用于按引用传递参数
        SwapTexture(ref v0,ref v1);
        lastPos = curPos;
    }
    private void Advect()
    {
        cs.SetTexture(kernelAdvect,"input0",v0);
        cs.SetTexture(kernelAdvect,"input1",v0);
        cs.SetTexture(kernelAdvect,"output",v1);
        
        cs.Dispatch(kernelAdvect,groupSizeX,groupSizeY,1);

        SwapTexture(ref v0,ref v1);
    }
    private void Diffusion()
    {
        for(int i=0;i<diffusionIterateCount;i++)
        {
            cs.SetTexture(kernelDiffusion,"input0",v0);
            cs.SetTexture(kernelDiffusion,"input1",v0);
            cs.SetTexture(kernelDiffusion,"output",v1);

            cs.Dispatch(kernelDiffusion,groupSizeX,groupSizeY,1);

            SwapTexture(ref v0,ref v1);
        }
    }

    private void Projection()
    {
        //计算Divergence
        cs.SetTexture(kernelDivergence,"input0",v0);
        cs.SetTexture(kernelDivergence,"div",div);
        cs.Dispatch(kernelDivergence,groupSizeX,groupSizeY,1);
    }

    private void Display()
    {
        cs.SetTexture(kernelDisplay,"input0",v0);
        cs.SetTexture(kernelDisplay,"inputColor",col0);
        cs.SetTexture(kernelDisplay,"outputColor",col1);

        cs.Dispatch(kernelDisplay,groupSizeX,groupSizeY,1);
        mat.SetTexture("_BaseMap",div);

        SwapTexture(ref col0,ref col1);
    }
}
