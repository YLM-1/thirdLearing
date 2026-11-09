using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// 可选的后处理效果
public enum FullScreenEffect
{
    ColorBlit,
    Grayscale,
    Gaussian,
    DualBoxBlur,
    Bloom,
};

internal class FullScreenRenderFeature : ScriptableRendererFeature
{
    [Header("Effect")]
    public FullScreenEffect effect = FullScreenEffect.ColorBlit;

    [Header("ColorBlit")]
    public Shader colorBlitShader;
    [Range(0f, 1f)] public float colorIntensity = 1f;
    public Color tintColor = Color.white;

    [Header("Grayscale")]
    public Shader grayscaleShader;
    [Range(0f, 1f)] public float grayIntensity = 1f;

    [Header("GaussianBlur")]
    public Shader gaussianShader;
    [Range(0.1f,3f)]public float blurSize = 1f;
    [Range(1, 5)] public int downSample = 3;
    [Range(1, 5)] public int interaction = 2;

    [Header("DualBoxBlur")]
    public Shader dualBoxBlurShader;
    [Range(0,5)]public int dualBoxBlurInteration = 2;
    [Range(0.1f,3f)]public float dualBoxBlurSize = 0.4f;

    [Header("Bloom")]
    public Shader bloomShader;
    public float greyThreshold = 0.1f;

    Material material;
    FullScreenRenderPass pass;

    public override void Create()
    {
        // OnValidate 会反复调用 Create()，这里必须幂等，否则会不停 new pass / 泄漏临时 RT
        if (pass == null)
        {
            pass = new FullScreenRenderPass
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
            };
        }
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType != CameraType.Game)
            return;

        Shader shader = GetShader(effect);
        if (shader == null)
            return;

        // 材质缓存：只有切换了效果（shader 变了）才重建
        if (material == null || material.shader != shader)
        {
            if (material != null)
                CoreUtils.Destroy(material);

            material = CoreUtils.CreateEngineMaterial(shader);
        }

        if (material == null)
            return;

        // 按当前选择的效果传参
        switch (effect)
        {
            case FullScreenEffect.ColorBlit:
                material.SetFloat("_Intensity", colorIntensity);
                material.SetVector("_Color", tintColor);
                break;

            case FullScreenEffect.Grayscale:
                material.SetFloat("_Intensity", grayIntensity);
                break;

            case FullScreenEffect.Gaussian:
                material.SetFloat("_BlurSize", blurSize);
                break;
            case FullScreenEffect.DualBoxBlur:
                material.SetFloat("_DualBoxBlurSize",dualBoxBlurSize);
                break;
            case FullScreenEffect.Bloom:
                material.SetFloat("_GreyThreshold",greyThreshold);
                break;
        }

        pass.SetMaterial(material);
        renderer.EnqueuePass(pass);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType != CameraType.Game)
            return;

        if (pass == null)
            return;

        // 只有 Gaussian 需要降采样，其它效果保持全分辨率，否则会糊
        int ds = effect == FullScreenEffect.Gaussian ? downSample : 1;

        pass.SetTarget(renderer.cameraColorTargetHandle, effect, ds, interaction,dualBoxBlurInteration);
    }

    Shader GetShader(FullScreenEffect e)
    {
        switch (e)
        {
            case FullScreenEffect.ColorBlit: return colorBlitShader;
            case FullScreenEffect.Grayscale: return grayscaleShader;
            case FullScreenEffect.Gaussian: return gaussianShader;
            case FullScreenEffect.DualBoxBlur: return dualBoxBlurShader;
            case FullScreenEffect.Bloom: return bloomShader;
            default: return null;
        }
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
        CoreUtils.Destroy(material);
    }
}
