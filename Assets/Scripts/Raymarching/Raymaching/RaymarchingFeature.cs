using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// URP 版的全屏 Blit（替代 OnRenderImage）。
/// 现在只做一件事：把世界空间视锥四角传给 shader，让 shader 输出每个像素的射线方向。
/// 用法：URP-HighFidelity-Renderer.asset -> Add Renderer Feature -> RaymarchingFeature
/// </summary>
public class RaymarchingFeature : ScriptableRendererFeature
{
    public Shader shader;
    private Material mat;
    private Pass pass;
    //Create() 并不负责每一帧绘制屏幕，而是负责准备渲染所需要的对象，并告诉 URP 我们希望在哪个阶段执行。
    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("Hidden/RaymarchingFullscreen");

        mat = shader ? CoreUtils.CreateEngineMaterial(shader) : null;

        pass = new Pass(mat)
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
        };
    }

    //每次 URP 准备渲染摄像机时，询问我们的 Feature：有没有自定义任务需要加入？
    //AddRenderPasses()：决定把哪个 Pass 加入渲染队列
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!mat)
            return;

        Camera camera = renderingData.cameraData.camera;
        if (camera.cameraType != CameraType.Game && camera.cameraType != CameraType.SceneView)
            return;

        pass.Setup(camera);
        renderer.EnqueuePass(pass);
    }

    //SetupRenderPasses()：为 Pass 准备它执行时需要使用的资源。
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (!mat)
            return;

        pass.SetTarget(renderer.cameraColorTargetHandle);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(mat);
    }

    private sealed class Pass : ScriptableRenderPass
    {
        private Material material;
        private RTHandle colorTarget;
        private Camera camera;

        public Pass(Material material)
        {
            this.material = material;
        }

        public void SetTarget(RTHandle target)
        {
            colorTarget = target;
        }

        public void Setup(Camera camera)
        {
            this.camera = camera;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(colorTarget);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!material || camera == null)
                return;

            material.SetMatrix("_FrustumCorners", GetFrustumCorners(camera));

            CommandBuffer cmd = CommandBufferPool.Get();
            Blitter.BlitCameraTexture(cmd, colorTarget, colorTarget, material, 0);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // 和原来一样：世界空间四角（方向），shader 里不再乘矩阵
        private Matrix4x4 GetFrustumCorners(Camera cam)
        {
            float camFov = cam.fieldOfView;
            float camAspect = cam.aspect;

            Matrix4x4 frustumCorners = Matrix4x4.identity;

            float fovHalf = camFov * 0.5f;
            float tanFov = Mathf.Tan(fovHalf * Mathf.Deg2Rad);

            Vector3 toTop = cam.transform.up * tanFov;
            Vector3 toRight = cam.transform.right * tanFov * camAspect;

            Vector3 topLeft = cam.transform.forward - toRight + toTop;
            Vector3 topRight = cam.transform.forward + toRight + toTop;
            Vector3 bottomLeft = cam.transform.forward - toRight - toTop;
            Vector3 bottomRight = cam.transform.forward + toRight - toTop;

            frustumCorners.SetRow(0, bottomLeft);
            frustumCorners.SetRow(1, bottomRight);
            frustumCorners.SetRow(2, topRight);
            frustumCorners.SetRow(3, topLeft);

            return frustumCorners;
        }
    }
}
