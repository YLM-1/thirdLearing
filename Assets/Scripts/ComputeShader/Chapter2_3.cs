using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter2_3 : MonoBehaviour
{
    public GameObject perfab;
    public int teapotCount = 17;

    public ComputeShader shader;
    public float radius = 10f;
    public float speed = 2f;
    Transform[] teapots;
    ComputeBuffer cb;
    Vector3[] output; 
    int kernelHandle;
    int groupSizeX;
    // Start is called before the first frame update
    void Start()
    {
        teapots = new Transform[teapotCount];
        for(int i=0;i<teapotCount;i++)
        {
            teapots[i] = Instantiate(perfab,transform).transform;
        }
        kernelHandle = shader.FindKernel("Teapots");

        uint threadGroupSizeX;//寻找x轴的线程一组的数
        shader.GetKernelThreadGroupSizes(kernelHandle,out threadGroupSizeX,out _,out _);
        groupSizeX = (int)((teapotCount+threadGroupSizeX-1)/threadGroupSizeX);
        
        output = new Vector3[teapotCount];

        //创建ComputeBuffer
        int stride = 3*4;
        cb = new ComputeBuffer(teapotCount,stride);

        //传递Buffer到kernel中,注意这里的Compute buffer是空
        shader.SetBuffer(kernelHandle,"Result",cb);
    }

    // Update is called once per frame
    void Update()
    {
        //发送命令：让GPU在后台开始计算
        shader.SetFloat("radius",radius);
        shader.SetFloat("time",Time.time*speed);
        shader.Dispatch(kernelHandle,groupSizeX,1,1);

        //这里是ComputeShader的Teapots中拿来计算好的数据,CPU等待GPU算完，并拷贝回内存
        cb.GetData(output);

        //更新位置
        for(int i = 0;i<teapotCount;i++)
        {
            teapots[i].localPosition = output[i];
        }
    }

    private void OnDestroy()
    {
        cb.Dispose();
    }
}
