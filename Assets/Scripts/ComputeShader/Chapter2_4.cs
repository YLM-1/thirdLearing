using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Chapter2_4 : MonoBehaviour
{
    public ComputeShader cs;
    public float radius = 1f;
    [Range(0,1)]
    public float range = 0f;

    int kernelHandle;
    Mesh mesh;

    struct Vertex
    {
        public Vector3 position;
        public Vector3 normal;

        public Vertex(Vector3 p,Vector3 n)
        {
            position = p;
            normal = n;
        }
    };

    Vertex[] srcVertexArray;
    Vertex[] dstVertexArray;

    ComputeBuffer srcVertexBuffer;
    ComputeBuffer dstVertexBuffer;

    private void InitMesh()
    {
        mesh = GetComponent<MeshFilter>().mesh;
        srcVertexArray = new Vertex[mesh.vertexCount];

        for(int i=0;i<mesh.vertexCount;i++)
        {
            srcVertexArray[i] = new Vertex(mesh.vertices[i],mesh.normals[i]);
        }

        dstVertexArray = (Vertex[])srcVertexArray.Clone();
    }

    private void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        srcVertexBuffer = new ComputeBuffer(srcVertexArray.Length,sizeof(float)*6);
        srcVertexBuffer.SetData(srcVertexArray);
        cs.SetBuffer(kernelHandle,"srcVertexBuffer",srcVertexBuffer);

        dstVertexBuffer = new ComputeBuffer(dstVertexArray.Length,sizeof(float)*6);
        dstVertexBuffer.SetData(dstVertexArray);
        cs.SetBuffer(kernelHandle,"dstVertexBuffer",dstVertexBuffer);
    }
    void Start()
    {
        InitMesh();
        InitShader();
    }

    void Update()
    {
        cs.SetFloat("range",range);
        cs.SetFloat("radius",radius);
        cs.Dispatch(kernelHandle,srcVertexArray.Length,1,1);

        //从Compute Shader中获得已经计算好的顶点数据
        dstVertexBuffer.GetData(dstVertexArray);

        //将新的顶点数据填充到一个新的数组里
        Vector3[] vertices = new Vector3[dstVertexArray.Length];
        for(int i=0;i<dstVertexArray.Length;i++)
        {
            vertices[i] = new Vector3(dstVertexArray[i].position.x,dstVertexArray[i].position.y,dstVertexArray[i].position.z);
        }

        //将新的法线数据填充到一个新的数组里
        Vector3[] normals = new Vector3[dstVertexArray.Length];
        for(int i=0;i<dstVertexArray.Length;i++)
        {
            normals[i] = new Vector3(dstVertexArray[i].normal.x,dstVertexArray[i].normal.y,dstVertexArray[i].normal.z);
        }

        mesh.vertices = vertices;
        mesh.normals = normals;
    }

    private void OnDestroy()
    {
        srcVertexBuffer.Dispose();
        dstVertexBuffer.Dispose();
    }
}
