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
    EdgeDetection,
    MotionBlur,
    Vignette,
    Glitch,
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
    [Range(0f, 1f)] public float greyThreshold = 0.1f;
    [Range(0f, 5f)] public float bloomIntensity = 1f;
    [Range(0.1f, 10f)] public float bloomBlurSize = 1f;
    // 高斯模糊重复次数：每轮 = 一次垂直 + 一次水平，次数越多光晕越宽越软
    [Range(1, 6)] public int bloomIteration = 3;

    [Header("EdgeDetection")]
    public Shader edgeDetection;
    public Color edgeColor = Color.white;

    [Header("MotionBlur")]
    public Shader motionBlur;
    [Range(0,1f)]public float motionAmount = 0.3f;

    [Header("Vignette")]
    public Shader vignetteShader;
    public Color vignetteColor = Color.black;
    [Range(0,1f)] public float vignetteRadius  = 0.1f;
    [Range(0,1f)] public float vignetteSoftness = 0.1f;
    public float vignettePower = 5;
    [Range(0,2f)]public float vignetteIntensity = 1;

    [Header("Glitch")]
    public Shader glitchShader;
    public float amplitude = 2;
    public float amount = 1;

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

        if (pass == null)
            Create();

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
                material.SetFloat("_GreyThreshold", greyThreshold);
                material.SetFloat("_BloomIntensity", bloomIntensity);
                material.SetFloat("_BlurSize", bloomBlurSize);
                break;
            case FullScreenEffect.EdgeDetection:
                material.SetVector("_EdgeColor",edgeColor);
                break;
            case FullScreenEffect.MotionBlur:
                material.SetFloat("_MotionAmount",motionAmount);
                break;
            case FullScreenEffect.Vignette:
                material.SetFloat("_VignetteSoftness",vignetteSoftness);
                material.SetFloat("_VignetteRadius",vignetteRadius);
                material.SetFloat("_VignettePower",vignettePower);
                material.SetFloat("_VignetteIntensity",vignetteIntensity);
                material.SetColor("_VignetteColor",vignetteColor);
                break;
            case FullScreenEffect.Glitch:
                material.SetFloat("_Amplitude",amplitude);
                material.SetFloat("_Amount",amount);
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

        // Gaussian 和 Bloom 都需要降采样，其它效果保持全分辨率
        int ds = (effect == FullScreenEffect.Gaussian || effect == FullScreenEffect.Bloom)? downSample: 1;

        pass.SetTarget(renderer.cameraColorTargetHandle, effect, ds, interaction, dualBoxBlurInteration, bloomIteration);
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
            case FullScreenEffect.EdgeDetection:return edgeDetection;
            case FullScreenEffect.MotionBlur:return motionBlur;
            case FullScreenEffect.Vignette:return vignetteShader;
            case FullScreenEffect.Glitch:return glitchShader;
            default: return null;
        }
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
        CoreUtils.Destroy(material);
    }
}
