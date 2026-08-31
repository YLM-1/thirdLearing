using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter1_3 : MonoBehaviour
{
    public string kernelName;
    public ComputeShader shader;
    public int texResolution=512;
    public Renderer render;
    public RenderTexture outputTexture;
    private int kernelHandle;

    private void Start()
    {
        //创建"配置/对象"
        outputTexture = new RenderTexture(texResolution,texResolution,0);
        outputTexture.enableRandomWrite = true;
        //GPU真正分配渲染目标
        outputTexture.Create();

        render = GetComponent<Renderer>();

        InitShader();
    }

    private void InitShader()
    {
        kernelHandle = shader.FindKernel(kernelName);

        shader.SetInt("texResolution",texResolution);
        //将texture给Compute Shader
        shader.SetTexture(kernelHandle,"Result",outputTexture);
        //把texture给材质Shader用于最终的展示
        render.material.SetTexture("_BaseMap",outputTexture);
    }

    private void Update()
    {
        if(Input.GetKeyUp(KeyCode.D))
        {
            //进一步理解：
            //threadGroupX:表示图片处理的X方向要开多少个线程组
            //threadGroupY:表示图片处理的Y方向要开多少个线程组
            //threadGroupZ:表示图片处理的Z方向要开多少个线程组
            //举例当前:Dispatch的时候，开了 64 (= 512 / 8) * 32 (= 512 / 16) * 1 组的线程组
            shader.Dispatch(kernelHandle,texResolution/8,texResolution/8,1);
        }
    }
}
