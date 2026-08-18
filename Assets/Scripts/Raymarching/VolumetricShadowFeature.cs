using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricShadowFeature : ScriptableRendererFeature
{
    private VolumetricShadowPass pass;

    public override void Create()
    {
        pass = new VolumetricShadowPass
        {
            renderPassEvent = RenderPassEvent.BeforeRendering
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
            renderer.EnqueuePass(pass);
    }

    private sealed class VolumetricShadowPass : ScriptableRenderPass
    {
        private static readonly ShaderTagId[] ShaderTags =
        {
            new ShaderTagId("UniversalForward"),
            new ShaderTagId("UniversalForwardOnly"),
            new ShaderTagId("SRPDefaultUnlit")
        };

        private Material depthMaterial;

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            VolumetricLight volumetricLight = VolumetricLight.ActiveInstance;
            if (!volumetricLight || !volumetricLight.TryGetShadowData(out Camera lightCamera,
                    out RenderTexture shadowMap, out Shader depthShader, out Matrix4x4 lightMatrix))
                return;

            if (!depthMaterial || depthMaterial.shader != depthShader)
            {
                CoreUtils.Destroy(depthMaterial);
                depthMaterial = CoreUtils.CreateEngineMaterial(depthShader);
            }

            if (!lightCamera.TryGetCullingParameters(out ScriptableCullingParameters cullingParameters))
                return;

            CullingResults lightCullingResults = context.Cull(ref cullingParameters);
            CommandBuffer cmd = CommandBufferPool.Get("Volumetric Shadow Map");
            cmd.SetRenderTarget(shadowMap);
            cmd.ClearRenderTarget(true, true, Color.white);
            cmd.SetGlobalMatrix("_MyCustomLightSpaceMatrix", lightMatrix);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            SortingSettings sortingSettings = new SortingSettings(lightCamera)
            {
                criteria = SortingCriteria.CommonOpaque
            };
            DrawingSettings drawingSettings = new DrawingSettings(ShaderTags[0], sortingSettings)
            {
                overrideMaterial = depthMaterial,
                overrideMaterialPassIndex = 0
            };
            for (int i = 1; i < ShaderTags.Length; i++)
                drawingSettings.SetShaderPassName(i, ShaderTags[i]);

            FilteringSettings filteringSettings = new FilteringSettings(
                RenderQueueRange.opaque, lightCamera.cullingMask);
            context.DrawRenderers(lightCullingResults, ref drawingSettings, ref filteringSettings);
            CommandBufferPool.Release(cmd);
        }
    }
}
