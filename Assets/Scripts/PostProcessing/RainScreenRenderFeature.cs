using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RainScreenRenderFeature : ScriptableRendererFeature
{
    public Shader shader;
    public float rainSpeed = 1f;
    [Range(0,1f)]public float traiLength = 0.8f;
    [Range(0,1f)]public float rainAmount = 0.5f;
    [Range(0,0.05f)]public float rainHeight = 0.02f;
    public Vector2 rainShape = new Vector2(1.5f,1);
    private RainScreenRenderPass pass;
    private Material material;

    public override void Create()
    {
        if(pass == null)
        {
            pass = new RainScreenRenderPass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
            };
        }

        if(material == null)
           material = CoreUtils.CreateEngineMaterial(shader);
        pass.SetMaterial(material);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(renderingData.cameraData.cameraType!=CameraType.Game||shader == null)
           return;
        if (pass == null)
            Create();
        renderer.EnqueuePass(pass);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if(renderingData.cameraData.cameraType!=CameraType.Game)
           return;
        if(pass==null)
           return;
        material.SetFloat("_RainSpeed",rainSpeed);
        material.SetFloat("_TraiLength",traiLength);
        material.SetFloat("_RainAmount",rainAmount);
        material.SetFloat("_RainHeight",rainHeight);
        material.SetVector("_RainShape",rainShape);
        pass.SetTarget(renderer.cameraColorTargetHandle);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();

        if (material != null)
            CoreUtils.Destroy(material);
    }
}
