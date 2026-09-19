using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Chapter6_1_CommandBuffer : MonoBehaviour
{
    //草的相关系数
    [SerializeField] private ComputeShader cs;
    [SerializeField] private GameObject grassPerfab;
    [SerializeField] private float pitchScale=1f;
    [SerializeField] private float density=1f;
    [Range(0,5f)]
    [SerializeField] private float grassScale=1f;
    [Range(0,45f)]
    [SerializeField] private float leanMax=1f;
    [SerializeField]private Material mat;

    //风的控制
    [SerializeField] private float windDirection=300f;
    [SerializeField] private float windSpeed=1f;
    [SerializeField] private float windScale=10f;

    //草地
    [SerializeField] private GameObject terrainPrefab;
    [SerializeField] private LayerMask terrainLayer;

    //角色和草地互动相关
    [SerializeField] private Transform character;
    [SerializeField] private float trampleRadius = 3f;

    struct GrassClump
    {
        public Vector3 position;
        public float lean;
        public float noise;
        public float trample;
        public Quaternion quaternion;

        public GrassClump(Vector3 pos)
        {
            position = pos;
            lean = 0;
            noise = Random.value*2-1;
            quaternion = Quaternion.identity;
            trample = 0;
        }
    };

    GrassClump[] clumpsArray;
    Mesh mesh;
    ComputeBuffer clumpsBuffer;
    ComputeBuffer argsBuffer;
    Bounds bounds;
    uint[] argsArray = new uint[5]{0,0,0,0,0};
    int kernelLeanGrass;
    int grassCount;
    int groupSizeX;

    //视锥体剔除优化
    [SerializeField] private bool useFrustumCulling = true;
    [SerializeField] private bool useClipSpace = true;
    [SerializeField] private bool useHIZ;
    [SerializeField] private Shader depthTextureShader;//生成自定义的mipmapLevel
    [SerializeField] private RenderTexture depthTexture;
    Material depthTextureMaterial;
    ComputeBuffer clumpsRawBuffer;
    Vector3 grassBoundsMin;
    Vector3 grassBoundsMax;

    //Command Buffer 由 Chapter6_1_CommandBufferFeature 在 AfterRenderingOpaques 执行
    public static Chapter6_1_CommandBuffer Instance { get; private set; }

    private bool hizReady;
    private int[] hizTempIds;
    private bool isOpenGL;
    private int hizSize;

    private void InitComputeBuffer()
    {
        mesh = grassPerfab.GetComponentInChildren<MeshFilter>().sharedMesh;
        Bounds grassBounds = mesh.bounds;

        grassBoundsMin = grassBounds.min*grassScale;
        grassBoundsMax = grassBounds.max*grassScale;

        kernelLeanGrass = cs.FindKernel("LeanGrass");
        bounds = new Bounds(Vector3.zero,Vector3.one*100);

        int total = (int)((pitchScale/grassBounds.extents.x/grassScale)*(pitchScale/grassBounds.extents.z/grassScale)*density);
        cs.GetKernelThreadGroupSizes(kernelLeanGrass,out uint x,out _,out _);
        groupSizeX = Mathf.CeilToInt((float)total/x);
        
        grassCount =(int)(groupSizeX *x);

        argsArray[0] = mesh.GetIndexCount(0);
        argsArray[1] = (uint)grassCount;
        argsBuffer  = new ComputeBuffer(1,5*sizeof(uint),ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(argsArray);

        clumpsArray = new GrassClump[grassCount];
    }

    private void InitDefaultBuffer()
    {
        clumpsBuffer = new ComputeBuffer(grassCount,sizeof(float)*10);
        clumpsBuffer.SetData(clumpsArray);//此时Buffer为空
        cs.SetBuffer(kernelLeanGrass,"clumpsBuffer",clumpsBuffer);

        cs.DisableKeyword("UseFrustumCulling");
    }

    private void InitPositionsArray()
    {
        Bounds bounds = terrainPrefab.GetComponent<MeshFilter>().sharedMesh.bounds;
        float yMax = bounds.extents.y+1;
        for(int i=0;i<grassCount;i++)
        {
            //在平地上进行
            float x = Random.Range(-pitchScale*0.5f,pitchScale*0.5f);
            float z = Random.Range(-pitchScale*0.5f,pitchScale*0.5f);
            Vector3 pos = new Vector3(x,yMax,z);

            //在terrain上进行
            RaycastHit hit;
            if(Physics.Raycast(pos,Vector3.down,out hit,100,terrainLayer.value))
            {
                pos.y = hit.point.y;
                clumpsArray[i] = new GrassClump(pos);
            }
        }
    }

    private void InitMaterialParameters()
    {
        mat.SetBuffer("clumpsBuffer",clumpsBuffer);
        mat.SetFloat("grassScale",grassScale);
        mat.SetFloat("leanMax",leanMax);
    }
    
    private void InitHIZ()
    {
        Camera.main.GetUniversalAdditionalCameraData().requiresDepthTexture = true;

        if(depthTextureShader != null)
            depthTextureMaterial = new Material(depthTextureShader);
        else
            Debug.LogWarning("Chapter6_1: depthTextureShader 未赋值,Hi-Z 降采样无法执行。", this);

        hizTempIds = new int[32];
        for(int i=0;i<hizTempIds.Length;i++)
            hizTempIds[i] = Shader.PropertyToID("_GrassHIZTemp" + i);

        if(depthTexture!=null)
           depthTexture.Release();

        //NextPowerOfTwo:返回大于或等于给定数值的、最小的 2 的幂,因为Hi-Z是建立在 2×2 逐级降采样的金字塔上的，尺寸必须是 2 的幂
        int depthTextureSize = Mathf.NextPowerOfTwo(Mathf.Max(Screen.width,Screen.height));
        depthTexture = new RenderTexture(depthTextureSize,depthTextureSize,0,RenderTextureFormat.RHalf);//RHalf只存r通道单精度
        depthTexture.autoGenerateMips = false;//不自动生成 mipmap，因为自动生成的是颜色平均，不是深度最小/最大，不适合 Hi-Z；
        depthTexture.useMipMap = true;
        //不采用Bilinear,采用point最近邻采样,深度纹理存的是数值（距离值），不是颜色图片。
        //深度贴图两个相邻像素，一个深度值 0.1，一个 0.9。
        //Point：要么拿 0.1，要么拿 0.9，数值真实。
        depthTexture.filterMode = FilterMode.Point;
        depthTexture.Create();

        //摄像机一般就是默认OpenGL
        Matrix4x4 defaultProj = Camera.main.projectionMatrix;
        //GL.GetGPUProjectionMatrix 用于将 Unity 的标准投影矩阵转换为符合当前渲染 API（DirectX、OpenGL、Vulkan 等）要求的 GPU 投影矩阵。
        Matrix4x4 gpuProj = GL.GetGPUProjectionMatrix(defaultProj,false);
        isOpenGL = defaultProj.Equals(gpuProj);
        hizSize = depthTextureSize;
        cs.SetBool("isOpenGL",isOpenGL);
        cs.SetInt("depthTextureSize",depthTextureSize);
    }

    private Vector4 GetPlane(Vector3 point,Vector3 normal)
    {
        //一个点和一个法向量可以确定一个平面
        //平面的方程：Ax+By+Cz+D=0;
        //A,B,C刚好对应normal的xyz,然后求出D;
        float D = -Vector3.Dot(point,normal);
        Vector4 plane = new Vector4(normal.x,normal.y,normal.z,D);
        return plane;
    }

    private Vector4 GetPlane(Vector3 a,Vector3 b,Vector3 c)
    {
        Vector3 normal = Vector3.Normalize(Vector3.Cross(b-a,c-a));
        return GetPlane(a,normal);
    }

    //得到远裁剪面的4个点
    private Vector3[] GetCameraFarClipPlanePoint(Camera cam)
    {
        Transform transform = cam.transform;
        float dist = cam.farClipPlane;
        float halfFov = Mathf.Deg2Rad*cam.fieldOfView*0.5f;

        float upLen = dist*Mathf.Tan(halfFov);
        float rightLen = upLen*cam.aspect;
        Vector3 up = upLen*transform.up;
        Vector3 right = rightLen*transform.right;
        Vector3 farCenterPoint = transform.position + transform.forward*dist;

        Vector3[] points = new Vector3[4];
        points[0] = farCenterPoint - up - right;//左下
        points[1] = farCenterPoint - up + right;//右下
        points[2] = farCenterPoint + up - right;//左上
        points[3] = farCenterPoint + up + right;//右上
        return points;
    }

    private Vector4[] GetFrustumPlane(Camera cam)
    {
        Vector4[] planes = new Vector4[6];

        Transform transform = cam.transform;
        Vector3 cameraPosition = transform.position;
        Vector3[] points = GetCameraFarClipPlanePoint(cam);

        //传的点我们以顺时针传
        planes[0] = GetPlane(cameraPosition,points[0],points[2]);
        planes[1] = GetPlane(cameraPosition,points[2],points[3]);
        planes[2] = GetPlane(cameraPosition,points[3],points[1]);
        planes[3] = GetPlane(cameraPosition,points[1],points[0]);
        planes[4] = GetPlane(transform.position+transform.forward*cam.nearClipPlane,-transform.forward);
        planes[5] = GetPlane(transform.position+transform.forward*cam.farClipPlane,transform.forward);

        return planes;
    }

    private void InitFrustumCulling()
    {
        //clumpsBuffer:用于存变化的数据，clumpsRawBuffer用于存刚开始所有的grass数据
        //在显存（GPU）中开辟一块动态追加队列（Append 队列），用来存放数量会随时变化的草（GrassClump）数据。
        clumpsBuffer = new ComputeBuffer(grassCount,sizeof(float)*10,ComputeBufferType.Append);
        //此处不需要SetData,具体的数据来源于ComputeShader
        //此处也不需要SetBuffer,因为Buffer大小汇编

        clumpsRawBuffer = new ComputeBuffer(grassCount,sizeof(float)*10);
        clumpsRawBuffer.SetData(clumpsArray);
        cs.SetBuffer(kernelLeanGrass,"clumpsRawBuffer",clumpsRawBuffer);

        cs.SetFloats("grassBoundsMin",new float[3]{grassBoundsMin.x,grassBoundsMin.y,grassBoundsMin.z});
        cs.SetFloats("grassBoundsMax",new float[3]{grassBoundsMax.x,grassBoundsMax.y,grassBoundsMax.z});
        cs.SetInt("grassCount",grassCount);

        //使用宏定义
        cs.EnableKeyword("UseFrustumCulling");
    }

    private void UpdateMaterialParameters()
    {
        cs.SetFloat("leanMax",leanMax * Mathf.PI / 180);
        cs.SetFloat("windDirection",windDirection);
        cs.SetFloat("windSpeed",windSpeed);
        cs.SetFloat("windScale",windScale);
        cs.SetFloat("time",Time.time);  

        cs.SetVector("tramplePos",character.position);
        cs.SetFloat("trampleRadius",trampleRadius);
    }

    private void OnEnable()
    {
        Instance = this;
    }

    private void OnDisable()
    {
        if(Instance==this)
            Instance = null;
    }

    private void Start()
    {
        InitComputeBuffer();
        InitPositionsArray();

        if(useFrustumCulling)
        {
            InitFrustumCulling();
        }
        else
        {
            InitDefaultBuffer();   
        }

        if(useHIZ)
        {
            InitHIZ();
            hizReady = depthTextureMaterial != null;
        }
        else
            hizReady = false;

        if(hizReady)
            cs.EnableKeyword("UseHIZ");
        else
            cs.DisableKeyword("UseHIZ");

        InitMaterialParameters();
    }

    public void RecordGrass(CommandBuffer cmd, Camera camera)
    {
        if(cs==null||mat==null||mesh==null||clumpsBuffer==null||argsBuffer==null)
            return;

        Matrix4x4 viewMatrix = camera.worldToCameraMatrix;
        Matrix4x4 projMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix,false);
        Matrix4x4 vp = projMatrix*viewMatrix;
        cmd.SetComputeMatrixParam(cs,"vp",vp);

        //每帧参数全部通过命令缓冲设置，避免依赖 ComputeShader 的持久绑定
        cmd.SetComputeFloatParam(cs,"leanMax",leanMax * Mathf.PI / 180);
        cmd.SetComputeFloatParam(cs,"windDirection",windDirection);
        cmd.SetComputeFloatParam(cs,"windSpeed",windSpeed);
        cmd.SetComputeFloatParam(cs,"windScale",windScale);
        cmd.SetComputeFloatParam(cs,"time",Time.time);
        cmd.SetComputeVectorParam(cs,"tramplePos",character.position);
        cmd.SetComputeFloatParam(cs,"trampleRadius",trampleRadius);

        if(useFrustumCulling)
        {
            cmd.SetComputeIntParam(cs,"grassCount",grassCount);
            cmd.SetComputeFloatParams(cs,"grassBoundsMin",new float[3]{grassBoundsMin.x,grassBoundsMin.y,grassBoundsMin.z});
            cmd.SetComputeFloatParams(cs,"grassBoundsMax",new float[3]{grassBoundsMax.x,grassBoundsMax.y,grassBoundsMax.z});
            cmd.SetComputeBufferParam(cs,kernelLeanGrass,"clumpsRawBuffer",clumpsRawBuffer);

            if(!useClipSpace)
            {
                Vector4[] planes = GetFrustumPlane(camera);
                cmd.SetComputeVectorArrayParam(cs,"planes",planes);
            }
        }

        if(hizReady)
        {
            RecordHIZ(cmd);
            cmd.SetComputeIntParam(cs,"isOpenGL",isOpenGL?1:0);
            cmd.SetComputeIntParam(cs,"depthTextureSize",hizSize);
            cmd.SetComputeTextureParam(cs,kernelLeanGrass,"hizTexture",depthTexture);
        }

        cmd.SetComputeBufferParam(cs,kernelLeanGrass,"clumpsBuffer",clumpsBuffer);
        cmd.SetGlobalBuffer("clumpsBuffer", clumpsBuffer); // 确保 Material Pass 渲染时能拿到最新的 Buffer

        if(useFrustumCulling)
            cmd.SetBufferCounterValue(clumpsBuffer,0);

        cmd.DispatchCompute(cs,kernelLeanGrass,groupSizeX,1,1);

        if(useFrustumCulling)
            cmd.CopyCounterValue(clumpsBuffer,argsBuffer,sizeof(uint));

        cmd.DrawMeshInstancedIndirect(mesh,0,mat,0,argsBuffer);
    }

    private void RecordHIZ(CommandBuffer cmd)
    {
        int w = depthTexture.width;
        int mipmapLevel = 0;
        int prevId = -1;

        //16×16,所以后面computeShader中算mipmap需要log2(depthTextureSize)-4
        while(w>8)
        {
            int currentId = hizTempIds[mipmapLevel];
            cmd.GetTemporaryRT(currentId,w,w,0,FilterMode.Point,RenderTextureFormat.RHalf);

            if(prevId<0)
                cmd.Blit(null,currentId,depthTextureMaterial,1);
            else
                cmd.Blit(prevId,currentId,depthTextureMaterial,0);

            if(prevId>=0)
                cmd.ReleaseTemporaryRT(prevId);

            cmd.CopyTexture(currentId,0,0,depthTexture,0,mipmapLevel);

            prevId = currentId;

            w/=2;
            mipmapLevel++;  
        }   

        if(prevId>=0)
            cmd.ReleaseTemporaryRT(prevId);
    }

    private void Update()
    {
        UpdateMaterialParameters();

        if(useFrustumCulling&&useClipSpace)
            cs.EnableKeyword("UseClipSpace");
        else
            cs.DisableKeyword("UseClipSpace");
    }

    private void OnDestroy()
    {
        if(Instance==this)
            Instance = null;

        argsBuffer?.Release();
        clumpsBuffer?.Release();
        clumpsRawBuffer?.Release();

        if(depthTextureMaterial!=null)
            Destroy(depthTextureMaterial);

        if(depthTexture!=null)
           depthTexture.Release();
    }
}
