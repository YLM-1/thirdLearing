using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class Chapter6_1 : MonoBehaviour
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
    ComputeBuffer clumpsRawBuffer;
    Vector3 grassBoundsMin;
    Vector3 grassBoundsMax;

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
        InitMaterialParameters();
    }

    private void Update()
    {
        UpdateMaterialParameters();

        if(useFrustumCulling)
        {
            //每次更新数据的时候，需要使用SetCounterValue把 clumpsBuffer 这个 GPU 缓冲区的“计数器”重置为 0
            clumpsBuffer.SetCounterValue(0);
            cs.SetBuffer(kernelLeanGrass,"clumpsBuffer",clumpsBuffer);
            if(!useClipSpace)
            {
                //方法一：计算每个instance物体包围盒的顶点是否在视锥体内，计算均在世界空间下进行
                Vector4[] planes = GetFrustumPlane(Camera.main);
                cs.SetVectorArray("planes",planes);
                cs.DisableKeyword("UseClipSpace");
            }
            else
            {
                //方法二：计算AABB的每个顶点在裁剪空间下的齐次坐标
                //如果有一个点(x,y,z)在世界空间中，变换到裁剪空间是(x',y',z')
                //又因为你裁剪空间的视锥体变成一个边长为1的立方体，所以
                //-1<x'<1&&-1<y<1&&-1<z<1或者-w<x'<w&&-w<y<w&&-w<z<w
                Matrix4x4 viewMatrix = Camera.main.worldToCameraMatrix;//世界空间到相机空间
                //获取相机的投影矩阵 (Projection Matrix: 相机空间 -> 裁剪空间)
                //注意：必须使用 GL.GetGPUProjectionMatrix 处理不同平台（DirectX/OpenGL/Vulkan）的 API 差异
                Matrix4x4 projMatrix = GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false);
                Matrix4x4 vp = projMatrix*viewMatrix;

                cs.SetMatrix("vp",vp);
                cs.EnableKeyword("UseClipSpace");
            }
        }
        cs.Dispatch(kernelLeanGrass,groupSizeX,1,1);
        //此时会有草的残余
        //所以用我们要算实际渲染的草的个数，利用CopyCount(从哪个 Buffer 取数量，把数量放到哪个Buffer,放到目标 Buffer 的第几个字节)
        //sizeof(uint)=4,刚好是对应grassCount的那个位置
        if(useFrustumCulling)
        {
            ComputeBuffer.CopyCount(clumpsBuffer,argsBuffer,sizeof(uint));  
        } 

        Graphics.DrawMeshInstancedIndirect(mesh,0,mat,bounds,argsBuffer);
    }

    private void OnDestroy()
    {
        argsBuffer?.Release();
        clumpsBuffer?.Release();
        clumpsRawBuffer?.Release();
    }
}
