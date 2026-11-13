using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RainScreenRenderPass : ScriptableRenderPass
{
    RTHandle cameraColorTarget;
    RTHandle copiedColor;
    private Material material;
    public void SetTarget(RTHandle cameraColorTagert)
    {
        this.cameraColorTarget = cameraColorTagert;
    }
    public void SetMaterial(Material mat)
    {
        material = mat;
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ResetTarget();
        var desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.msaaSamples = 1;
        desc.depthBufferBits = (int)DepthBits.None;
        desc.useMipMap = true;
        RenderingUtils.ReAllocateIfNeeded(ref copiedColor,desc,name:"_RainPassColorCopy");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(material == null || cameraColorTarget == null)
           return;

        CommandBuffer cmd = new CommandBuffer();
        Blitter.BlitCameraTexture(cmd, cameraColorTarget, copiedColor);
        Blitter.BlitCameraTexture(cmd,copiedColor,cameraColorTarget,material,0);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
    }

    public void Dispose()
    {
        copiedColor?.Release();
        copiedColor = null;
    }
}
