using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter2_1 : MonoBehaviour
{
    public ComputeShader shader;
    public int texResolution = 512;

    public Renderer renderer;
    public RenderTexture outputTexture;
    [SerializeField] private Vector2 velocity;

    int circlesHandle;
    int clearHandle;

    void Start()
    {
        outputTexture = new RenderTexture(texResolution, texResolution, 0);
        outputTexture.enableRandomWrite = true;
        outputTexture.Create();

        renderer = GetComponent<Renderer>();

        InitShader();
    }

    void Update()
    {
        DispatchKernel();
    }

    void InitShader()
    {
        circlesHandle = shader.FindKernel("Circles");
        shader.SetInt("texResolution", texResolution);
        shader.SetTexture(circlesHandle, "Result", outputTexture);
        shader.SetVector("velocity",velocity);

        clearHandle = shader.FindKernel("Clear");
        shader.SetTexture(clearHandle, "Result", outputTexture);

        renderer.material.SetTexture("_BaseMap", outputTexture);
    }

    void DispatchKernel()
    {
        shader.Dispatch(clearHandle, texResolution / 8, texResolution / 8, 1);

        shader.SetFloat("time", Time.time);
        shader.Dispatch(circlesHandle, 5, 1, 1);
    }
}
