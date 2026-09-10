using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter1_2 : MonoBehaviour
{
   public ComputeShader shader;
   public int texResolution = 512;
   public Renderer renderer;
   public RenderTexture outputTexture;
   int kernelHandle;

   void Start()
     {
         outputTexture = new RenderTexture(texResolution, texResolution, 0);

         //将此处属性标记为true,这样才能将数据写入
         outputTexture.enableRandomWrite = true;
         outputTexture.Create();

         renderer = GetComponent<Renderer>();

         InitShader();
     }

   void InitShader()
   {
         //kernelHandle 就是把耗时的高级函数名（如 "CSMain"）先翻译成 GPU 喜闻乐见的快捷数字代号（如 0）并存起来
         kernelHandle = shader.FindKernel("CSMain");
         //把管道接入(ComputeShader)水源，负责填充数据
         shader.SetTexture(kernelHandle,"Result",outputTexture);
         //把管道接入(Material渲染)水龙头，负责读取并展示数据
         renderer.material.SetTexture("_BaseMap",outputTexture);
   }

   void Update()
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
