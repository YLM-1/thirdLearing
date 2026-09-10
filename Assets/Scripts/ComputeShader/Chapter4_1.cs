using System.Collections;
using System.Collections.Generic;
//using Unity.Mathematics;
using UnityEngine;

public class Chapter4_1 : MonoBehaviour
{
    public ComputeShader cs;
    public Shader particleShader;

    public Camera cam;
    public float distance=10f;
    public GameObject debugObject;
    
    public int particleCount=10000;
    public float initialRadius=20f;
    public float speed = 2f;
    private ComputeBuffer particleBuffer;

    int kernelHandle;
    int groupSizeX;

    Material mat;

    struct Particle
    {
        public Vector3 position;
        public Vector3 velocity;
        public float lifetime;
        public Vector3 color;
    };

    private void Start()
    {
        kernelHandle = cs.FindKernel("CSMain");
        cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out uint y,out _);
        groupSizeX =Mathf.CeilToInt((float)particleCount / (float)x);

        //初始化粒子数组
        Particle[] particles = new Particle[particleCount];
        for(int i=0;i<particleCount;i++)
        {
            particles[i].position = Random.insideUnitSphere*initialRadius;
            particles[i].velocity = Vector3.zero;
            particles[i].lifetime = Random.value;
            particles[i].color = Random.insideUnitSphere;
        }
        
        //填充ComputeBuffer
        particleBuffer = new ComputeBuffer(particleCount,sizeof(float)*10);
        particleBuffer.SetData(particles);

        //传递ComputeBuffer到ComputeShader
        cs.SetBuffer(kernelHandle,"particleBuffer",particleBuffer);

        //初始化绘制粒子的Shader
        mat = new Material(particleShader);
        mat.SetBuffer("particleBuffer",particleBuffer);
    }

    private void OnRenderObject()
    {
       mat.SetPass(0);
       Graphics.DrawProceduralNow(MeshTopology.Points, 1, particleCount);
    }

    private void Update()
    {
        //将鼠标的屏幕坐标转换到世界坐标
        Vector3 mousePos = Input.mousePosition;
        mousePos.z = cam.nearClipPlane+distance;
        Vector3 worldPosition = cam.ScreenToWorldPoint(mousePos);
        //debugObject.transform.position = worldPosition;

        cs.SetFloats("worldPosition",new float[3]{worldPosition.x,worldPosition.y,worldPosition.z} );
        cs.SetFloat("speed",speed);
        cs.SetFloat("deltaTime",Time.deltaTime);
        cs.Dispatch(kernelHandle,groupSizeX,1,1);
    }
 
    private void OnDestroy()
    {
        particleBuffer?.Release();
    }
}
