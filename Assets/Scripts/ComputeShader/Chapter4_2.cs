using System.Collections;
using System.Collections.Generic;
//using Unity.Mathematics;
using UnityEngine;

public class Chapter4_2 : MonoBehaviour
{
    public ComputeShader cs;
    public Shader particleShader;

    public Camera cam;
    public float distance=10f;
    public GameObject debugObject;
    
    //ComputeSahder生成粒子相关
    public int particleCount=10000;
    public float initialRadius=20f;
    public float speed = 2f;

    //绘制四边形相关
    public float quadSize = 0.1f;
    public Texture2D texture;
    
    private ComputeBuffer particleBuffer;
    private ComputeBuffer vertexBuffer;

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
    struct Vertex
    {
        public Vector3 position;
        public Vector2 uv;
    }

    private void Start()
    {
        kernelHandle = cs.FindKernel("CSMain");
        cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out uint y,out _);
        groupSizeX =Mathf.CeilToInt((float)particleCount / (float)x);

        //初始化粒子数组
        Particle[] particles = new Particle[particleCount];

        int vertexCount = particleCount*6;
        Vertex[] vertices = new Vertex[vertexCount];
        int index=0;
        for(int i=0;i<particleCount;i++)
        {
            particles[i].position = Random.insideUnitSphere*initialRadius;
            particles[i].velocity = Vector3.zero;
            particles[i].lifetime = Random.value;
            particles[i].color = Random.insideUnitSphere;

            index=i*6;
            //初始化Vertex
            //左下角到左上角的顶点
            vertices[index].uv.Set(0,0);
            vertices[index+1].uv.Set(0,1);
            vertices[index+2].uv.Set(1,1);

            //左下角到右上角
            vertices[index+3].uv.Set(0,0);
            vertices[index+4].uv.Set(1,1);
            vertices[index+5].uv.Set(1,0);
        }
        
        //填充ComputeBuffer
        particleBuffer = new ComputeBuffer(particleCount,sizeof(float)*10);
        particleBuffer.SetData(particles);

        vertexBuffer = new ComputeBuffer(vertexCount,sizeof(float)*5);
        vertexBuffer.SetData(vertices);

        //传递ComputeBuffer到ComputeShader
        cs.SetBuffer(kernelHandle,"particleBuffer",particleBuffer);
        cs.SetBuffer(kernelHandle,"vertexBuffer",vertexBuffer);

        //初始化绘制粒子的Shader
        mat = new Material(particleShader);
        mat.SetBuffer("vertexBuffer",vertexBuffer);
        mat.SetTexture("_BaseMap",texture);
    }

    private void OnRenderObject()
    {
       mat.SetPass(0);
       Graphics.DrawProceduralNow(MeshTopology.Triangles, 6, particleCount);
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
        cs.SetFloat("halfSize",quadSize*0.5f);
        cs.Dispatch(kernelHandle,groupSizeX,1,1);
    }
 
    private void OnDestroy()
    {
        particleBuffer?.Release();
        vertexBuffer?.Release();
    }
}
