using System.Security.Cryptography;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

internal class FullScreenRenderPass : ScriptableRenderPass
{
    static readonly ProfilingSampler k_ProfilingSampler = new ProfilingSampler("FullScreenPass");

    Material material;
    RTHandle cameraColorTarget;
    RTHandle copiedColor;      // 临时 RT，避免 shader 读自己正在写的 RT
    RTHandle gaussianTemp;     // Gaussian 的半分辨率 ping-pong RT
    FullScreenEffect effect;
    //Gaussian
    int downSample = 1;
    int interaction = 1;
    //DualBoxBlur
    int dualBoxBlurInteration = 1;
    const int kMaxDualBoxBlurLevels = 5;
    readonly RTHandle[] dualBoxBlurRT = new RTHandle[kMaxDualBoxBlurLevels];

    //Bloom
    int bloomIteration = 3;
    const int kMaxBloomIteration = 6;

    //Glitch
    int glitchPass = 0;

    public void SetMaterial(Material m)
    {
        material = m;
    }

    public void SetGlitchPass(int pass)
    {
        glitchPass = Mathf.Clamp(pass, 0, 2);
    }

    public void SetTarget(RTHandle colorHandle, FullScreenEffect effect, int downSample, int interaction, int dualBoxBlurInteration, int bloomIteration = 3)
    {
        cameraColorTarget = colorHandle;
        this.effect = effect;
        this.downSample = Mathf.Max(1, downSample);
        this.interaction = Mathf.Max(1, interaction);
        this.dualBoxBlurInteration = Mathf.Clamp(dualBoxBlurInteration, 1, kMaxDualBoxBlurLevels);
        this.bloomIteration = Mathf.Clamp(bloomIteration, 1, kMaxBloomIteration);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // pass 自己管理 RT，避免和相机的 active attachment 冲突
        ResetTarget();

        var desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.msaaSamples = 1;
        desc.depthBufferBits = (int)DepthBits.None;

        if (effect == FullScreenEffect.Gaussian)
        {
            // Gaussian 的垂直/水平都在 half-res 上做
            desc.width = Mathf.Max(1, desc.width / downSample);
            desc.height = Mathf.Max(1, desc.height / downSample);

            RenderingUtils.ReAllocateIfNeeded(ref gaussianTemp, desc, name: "_GaussianTemp");
            RenderingUtils.ReAllocateIfNeeded(ref copiedColor, desc, name: "_FullScreenPassColorCopy");
        }
        else if (effect == FullScreenEffect.Bloom)
        {
            // Bloom：原图保持全分辨率，亮度图/模糊图用 half-res
            var bloomDesc = desc;
            bloomDesc.width = Mathf.Max(1, desc.width / downSample);
            bloomDesc.height = Mathf.Max(1, desc.height / downSample);

            RenderingUtils.ReAllocateIfNeeded(ref gaussianTemp, bloomDesc, name: "_BloomBright");
            RenderingUtils.ReAllocateIfNeeded(ref dualBoxBlurRT[0], bloomDesc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_BloomTemp");
            RenderingUtils.ReAllocateIfNeeded(ref copiedColor, desc, name: "_BloomOriginal");
        }
        else if (effect == FullScreenEffect.DualBoxBlur)
        {
            int levels = Mathf.Clamp(dualBoxBlurInteration, 1, kMaxDualBoxBlurLevels);
            for (int i = 0; i < levels; i++)
            {
                var d = desc;
                d.width = Mathf.Max(1, desc.width >> (i + 1));
                d.height = Mathf.Max(1, desc.height >> (i + 1));

                RenderingUtils.ReAllocateIfNeeded(ref dualBoxBlurRT[i], d,FilterMode.Bilinear, TextureWrapMode.Clamp,name: $"_DualBoxBlur{i}");
            }
            RenderingUtils.ReAllocateIfNeeded(ref copiedColor, desc, name: "_FullScreenPassColorCopy");
        }
        else if(effect == FullScreenEffect.MotionBlur)
        {
            var motionDsc = desc;
            RenderingUtils.ReAllocateIfNeeded(ref copiedColor,desc,name:"_MotionBlurA");
            copiedColor.rt.MarkRestoreExpected();
        }
        else
        {
            RenderingUtils.ReAllocateIfNeeded(ref copiedColor, desc, name: "_FullScreenPassColorCopy");
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (material == null || cameraColorTarget == null || copiedColor == null)
            return;

        if (effect == FullScreenEffect.DualBoxBlur && dualBoxBlurRT[0] == null)
            return;

        if (effect == FullScreenEffect.Gaussian && gaussianTemp == null)
            return;

        if (effect == FullScreenEffect.Bloom && (gaussianTemp == null || dualBoxBlurRT[0] == null))
            return;

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, k_ProfilingSampler))
        {
            switch (effect)
            {
                case FullScreenEffect.ColorBlit:
                case FullScreenEffect.Grayscale:
                    BlitSinglePass(cmd);
                    break;
                case FullScreenEffect.Gaussian:
                    BlitGaussian(cmd);
                    break;
                case FullScreenEffect.DualBoxBlur:
                    DualBoxBlur(cmd);
                    break;
                case FullScreenEffect.Bloom:
                    BlitBloom(cmd);
                    break;
                case FullScreenEffect.EdgeDetection:
                     BlitEdgeDetection(cmd);
                     break;
                case FullScreenEffect.MotionBlur:
                     BlitMotionBlur(cmd);
                     break;
                case FullScreenEffect.Vignette:
                     BlitVignette(cmd);
                     break;
                case FullScreenEffect.Glitch:
                     BlitGlitch(cmd);
                     break;
            }
        }
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        CommandBufferPool.Release(cmd);
    }

    // 单 pass 效果：默认拷贝到临时 RT，再用材质 pass 0 画回相机颜色
    void BlitSinglePass(CommandBuffer cmd)
    {
        Blitter.BlitCameraTexture(cmd, cameraColorTarget, copiedColor);
        Blitter.BlitCameraTexture(cmd, copiedColor, cameraColorTarget, material, 0);
    }

    // 高斯模糊：先降到半分辨率，再在半分辨率上垂直/水平 ping-pong，最后升采样
    void BlitGaussian(CommandBuffer cmd)
    {
        // 降采样
        Blitter.BlitCameraTexture(cmd, cameraColorTarget, copiedColor, 0f, true);

        for (int i = 0; i < interaction; i++)
        {
            // 垂直：half-res -> half-res
            Blitter.BlitCameraTexture(cmd, copiedColor, gaussianTemp, material, 0);

            // 水平：half-res -> half-res
            Blitter.BlitCameraTexture(cmd, gaussianTemp, copiedColor, material, 1);
        }

        // 升采样回全分辨率
        Blitter.BlitCameraTexture(cmd, copiedColor, cameraColorTarget, 0f, true);
    }

    // Dual Box Blur：逐级降采样，再逐级升采样，最后 copy 回相机
    void DualBoxBlur(CommandBuffer cmd)
    {
        int levels = Mathf.Clamp(dualBoxBlurInteration, 1, kMaxDualBoxBlurLevels);

        // 降采样
        RTHandle downSrc = cameraColorTarget;
        for (int i = 0; i < levels; i++)
        {
            Blitter.BlitCameraTexture(cmd, downSrc, dualBoxBlurRT[i], material, 0);
            downSrc = dualBoxBlurRT[i];
        }

        // 升采样
        RTHandle upSrc = dualBoxBlurRT[levels - 1];
        for (int j = levels - 2; j >= 0; j--)
        {
            Blitter.BlitCameraTexture(cmd, upSrc, dualBoxBlurRT[j], material, 1);
            upSrc = dualBoxBlurRT[j];
        }

        // 最后一步只做 copy，不要再走 Upfrag，否则会二次模糊甚至黑屏
        // bilinear = true：upSrc 是半分辨率，直接点采样会像素化
        Blitter.BlitCameraTexture(cmd, upSrc, cameraColorTarget, 0.0f, true);
    }

    void BlitBloom(CommandBuffer cmd)
    {
        // 1. 保存原图
        Blitter.BlitCameraTexture(cmd, cameraColorTarget, copiedColor);

        // 2. 提取高亮 + 降到 half-res
        Blitter.BlitCameraTexture(cmd, copiedColor, gaussianTemp, material, 2);

        // 3. 垂直 + 水平模糊
        for (int i = 0; i < bloomIteration; i++)
        {
            Blitter.BlitCameraTexture(cmd, gaussianTemp, dualBoxBlurRT[0], material, 0);
            Blitter.BlitCameraTexture(cmd, dualBoxBlurRT[0], gaussianTemp, material, 1);
        }

        // 4. 原图 + 模糊高亮，合成回相机
        cmd.SetGlobalTexture("_BloomTex", gaussianTemp.rt);
        Blitter.BlitCameraTexture(cmd, copiedColor, cameraColorTarget, material, 3);
    }

    void BlitEdgeDetection(CommandBuffer cmd)
    {
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor);
        Blitter.BlitCameraTexture(cmd, copiedColor, cameraColorTarget, material, 0);
    }

    void BlitMotionBlur(CommandBuffer cmd)
    {
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor,material,0);
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor,material,1);
        Blitter.BlitCameraTexture(cmd,copiedColor,cameraColorTarget);
    }

    void BlitVignette(CommandBuffer cmd)
    {
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor);
        Blitter.BlitCameraTexture(cmd,copiedColor,cameraColorTarget,material,0);
    }

    void BlitGlitch(CommandBuffer cmd)
    {
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor);
        // glitchPass: 0 = RGBSplit，1 = ImageBlock
        Blitter.BlitCameraTexture(cmd,copiedColor,cameraColorTarget,material,glitchPass);
    }

    public void Dispose()
    {
        copiedColor?.Release();
        copiedColor = null;

        gaussianTemp?.Release();
        gaussianTemp = null;

        for (int i = 0; i < kMaxDualBoxBlurLevels; i++)
        {
            dualBoxBlurRT[i]?.Release();
            dualBoxBlurRT[i] = null;
        }
    }
}
