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

    public void SetMaterial(Material m)
    {
        material = m;
    }

    public void SetTarget(RTHandle colorHandle, FullScreenEffect effect, int downSample, int interaction, int dualBoxBlurInteration)
    {
        cameraColorTarget = colorHandle;
        this.effect = effect;
        this.downSample = Mathf.Max(1, downSample);
        this.interaction = Mathf.Max(1, interaction);
        this.dualBoxBlurInteration = Mathf.Clamp(dualBoxBlurInteration, 1, kMaxDualBoxBlurLevels);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // pass 自己管理 RT，避免和相机的 active attachment 冲突
        ResetTarget();

        var desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.msaaSamples = 1;
        desc.depthBufferBits = (int)DepthBits.None;

        if (effect == FullScreenEffect.Gaussian||effect == FullScreenEffect.Bloom)
        {
            // 降采样：只有需要降采样的效果才会 downSample > 1
            desc.width = Mathf.Max(1, desc.width / downSample);
            desc.height = Mathf.Max(1, desc.height / downSample);

            // 垂直/水平模糊都在同一张半分辨率 RT 上做，保证步长一致
            RenderingUtils.ReAllocateIfNeeded(ref gaussianTemp, desc, name: "_GaussianTemp");
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
        }
        RenderingUtils.ReAllocateIfNeeded(ref copiedColor, desc, name: "_FullScreenPassColorCopy");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (material == null || cameraColorTarget == null || copiedColor == null)
            return;

        if (effect == FullScreenEffect.DualBoxBlur && dualBoxBlurRT[0] == null)
            return;

        if (effect == FullScreenEffect.Gaussian && gaussianTemp == null)
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
        //扣除高亮区域
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,copiedColor);
        Blitter.BlitCameraTexture(cmd,copiedColor,cameraColorTarget,material,2);

        //高斯模糊
        BlitGaussian(cmd);

        //最终混合
        Blitter.BlitCameraTexture(cmd,cameraColorTarget,)
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
