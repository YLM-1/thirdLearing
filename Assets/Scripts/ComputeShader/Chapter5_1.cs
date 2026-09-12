using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class Chapter5_1 : MonoBehaviour
{
    //shader相关数据
    [SerializeField] private ComputeShader cs;
    private ComputeBuffer ballBuffer;
    [SerializeField] private int ballCount=100;
    int kernelHandle;
    int groupSizeX;
    int numOfBall;

    //模型相关数据
    private ComputeBuffer argsBuffer;
    Mesh ballMesh;
    Bounds bounds;
    Material ballMat;

    //球体相关参数
    [SerializeField] private GameObject ballGOs;

    struct Ball
    {
      public Vector3 position;
      public Vector3 velocity;
      public Color color;  

      public Ball(Vector3 initPos,Vector3 initVelocity)
      {
        position = initPos + new Vector3((Random.value*2-1)*4,(Random.value*2-1),(Random.value*2-1));
        velocity = initVelocity + new Vector3((Random.value*2-1)*1,(Random.value*2-1)*2,(Random.value*2-1)*1);
        color = new Color(Random.value,Random.value,Random.value);
      }
    };
    Ball[] balls;

    //物理相关参数
    [SerializeField] float gravity = 2f;
    [SerializeField] float damping = 0.6f;

    private void Start()
    {
        InitShader();
        InitMaterial();
    }

    private void InitShader()
    {
     kernelHandle = cs.FindKernel("CSMain");

     cs.GetKernelThreadGroupSizes(kernelHandle,out uint x,out _,out _);
     groupSizeX = Mathf.CeilToInt((float)ballCount/(float)x);
     numOfBall = groupSizeX * (int)x;

     balls = new Ball[numOfBall];
     for(int i=0;i<numOfBall;i++)
     {
        balls[i] = new Ball(ballGOs.transform.position,-Vector3.up*2f);
     }
     ballBuffer = new ComputeBuffer(numOfBall,sizeof(float)*10);
     ballBuffer.SetData(balls);

     //Instance相关数据
     uint[] args = new uint[5] {0,0,0,0,0};
     ballMesh = ballGOs.GetComponent<MeshFilter>().sharedMesh;
     args[0] = (uint)ballMesh.GetIndexCount(0);
     args[1] = (uint)numOfBall;

     bounds = new Bounds(Vector3.zero,Vector3.one*1000);
     argsBuffer = new ComputeBuffer(1,sizeof(uint)*5,ComputeBufferType.IndirectArguments);
     argsBuffer.SetData(args);

     Bounds b = GetComponent<BoxCollider>().bounds;
     cs.SetVector("boundMin",b.min);
     cs.SetVector("boundMax",b.max);
     cs.SetFloat("gravity",gravity);
     cs.SetFloat("deltaTime",Time.deltaTime);
     cs.SetFloat("damping",damping);
     cs.SetInt("numOfBall",numOfBall);
     cs.SetFloat("radius",0.5f);      //小球的半径

     cs.SetBuffer(kernelHandle,"ballBuffer",ballBuffer);
    }

    private void InitMaterial()
    {
        ballMat = new Material(Shader.Find("Unlit/Chapter5_1"));
        ballMat.SetBuffer("ballBuffer",ballBuffer);
    }

    private void Update()
    {
        cs.Dispatch(kernelHandle,groupSizeX,1,1);
        Graphics.DrawMeshInstancedIndirect(ballMesh,0,ballMat,bounds,argsBuffer);
    }

    private void OnDestroy()
    {
        ballBuffer?.Release();
        argsBuffer?.Release();
    }
}
