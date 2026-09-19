    using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Chapter6_1_CommandBufferFeature : ScriptableRendererFeature
{
    private GrassCommandBufferPass pass;

    public override void Create()
    {
        pass = new GrassCommandBufferPass
        {
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        pass.ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return;

        if (Chapter6_1_CommandBuffer.Instance == null)
            return;

        renderer.EnqueuePass(pass);
    }

    private sealed class GrassCommandBufferPass : ScriptableRenderPass
    {
        private static readonly ProfilingSampler s_Sampler = new ProfilingSampler("Grass HiZ/Cull/Draw");

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            Chapter6_1_CommandBuffer grass = Chapter6_1_CommandBuffer.Instance;
            if (grass == null)
                return;

            Camera camera = renderingData.cameraData.camera;

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, s_Sampler))
            {
                grass.RecordGrass(cmd, camera);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
}
