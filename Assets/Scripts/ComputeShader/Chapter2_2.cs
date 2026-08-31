using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter2_2 : MonoBehaviour
{
    public ComputeShader shader;
    public int texResolution = 512;

    public Renderer renderer;
    public RenderTexture outputTexture;
    public int circleCount=5;

    int circlesHandle;
    int clearHandle;

    struct Circle
    {
        public Vector2 origPos;
        public Vector2 velocity;
        public float radius;
    }

    Circle[] circles;
    ComputeBuffer cb;

    void Start()
    {
        outputTexture = new RenderTexture(texResolution, texResolution, 0);
        outputTexture.enableRandomWrite = true;
        outputTexture.Create();

        renderer = GetComponent<Renderer>();

        InitData();
        InitShader();
    }

    void Update()
    {
        DispatchKernel();
    }

    void InitData()
    {
        uint threadGroupSizeX;
        shader.GetKernelThreadGroupSizes(circlesHandle,out threadGroupSizeX,out _,out _);
        int total = (int)threadGroupSizeX*circleCount;
        circles = new Circle[total];

        float radius = 20f;
        float velocity = 100;
        for(int i=0;i<total;i++)
        {
            Circle circle = new Circle();
            circle.origPos = new Vector2(Random.value*texResolution,Random.value*texResolution);
            circle.velocity = new Vector2(Random.value*velocity,Random.value*velocity);
            circle.radius = Random.value*radius;
            circles[i] = circle;
        }

    }
    void InitShader()
    {
        shader.SetInt("texResolution", texResolution);
        shader.SetTexture(circlesHandle, "Result", outputTexture);

        clearHandle = shader.FindKernel("Clear");
        shader.SetTexture(clearHandle, "Result", outputTexture);

        renderer.material.SetTexture("_BaseMap", outputTexture);

        //第二步：创建ComputeBuffer
        int stride = (2+2+1)*sizeof(float);
        cb = new ComputeBuffer(circles.Length,stride);

        //第三步：拷贝数据数组到ComputeBuffer
        cb.SetData(circles);

        //第四步：传递Buffer到kernel
        shader.SetBuffer(circlesHandle,"circles",cb);
    }

    void DispatchKernel()
    {
        shader.Dispatch(clearHandle, texResolution / 8, texResolution / 8, 1);

        shader.SetFloat("time", Time.time);
        shader.Dispatch(circlesHandle,circleCount, 1, 1);
    }

    private void OnDestroy()
    {
        cb.Dispose();
    }
}
