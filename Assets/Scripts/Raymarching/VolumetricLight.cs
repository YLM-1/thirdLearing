using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]

[RequireComponent(typeof(Light))]
public class VolumetricLight : MonoBehaviour
{
    public static VolumetricLight ActiveInstance { get; private set; }

    //聚光灯的相关参数
    [SerializeField] private float spotAngle = 30f;
    [SerializeField] private float range = 10f;
    [SerializeField] private float intensity = 1f;
    [SerializeField] private Color color = Color.white;
    [SerializeField] private Light lightInstance;
    [SerializeField] private Transform cone;
    [SerializeField] private Camera cam;
    [SerializeField] private RenderTexture shadowMap;
    [SerializeField] private int shadowMapSize = 1024;
    [SerializeField] private Shader castShadow;
    [SerializeField] private float lightShadowBias;
    [SerializeField] private float shadowIntensity = -0.5f;
    [SerializeField] private Texture2D dither;
    private RenderTexture oldShadowMap;
    private int oldShadowMapSize = 1024;
    private Matrix4x4 nMat;
    private Matrix4x4 lightSpaceMatrix;

    private void OnEnable()
    {
        ActiveInstance = this;
    }

    private void OnDisable()
    {
        if(ActiveInstance == this)
            ActiveInstance = null;
    }

    private void Start()
    {
        InitLight();
        InitRT();  
        InitCam();

        nMat = new Matrix4x4();  
        nMat.SetRow(0,new Vector4(1,0,0,0));
        nMat.SetRow(1,new Vector4(0,-1,0,0));
        nMat.SetRow(2,new Vector4(0,0,1,0));
        nMat.SetRow(3,new Vector4(0,0,0,1));
    }

    private void Update()
    {
        if(!lightInstance)
            InitLight();
        if(!shadowMap || shadowMapSize != oldShadowMapSize)
            InitRT();
        if(!cam)
            InitCam();

        UpdateLight();
        UpdateShadowData();
        UpdateRaymarching();
    }

    private void InitLight()
    {
        lightInstance = GetComponent<Light>();
        if(!lightInstance)
            lightInstance = gameObject.AddComponent<Light>();
    }
    private void InitRT()
    {
        if(oldShadowMap)
            oldShadowMap.Release();

        shadowMap = new RenderTexture(
            shadowMapSize,
            shadowMapSize,
            24,
            RenderTextureFormat.ARGB32,
            RenderTextureReadWrite.Linear);
        shadowMap.filterMode = FilterMode.Point;
        shadowMap.wrapMode = TextureWrapMode.Clamp;
        oldShadowMapSize = shadowMapSize;
        oldShadowMap = shadowMap;

        if(cam)
            cam.targetTexture = shadowMap;
    }

    private void InitCam()
    {
        cam = GetComponent<Camera>();
        if(!cam)
            cam = gameObject.AddComponent<Camera>();
        cam.backgroundColor = Color.white;
        cam.orthographic = false;
        cam.depth = -2;
        cam.clearFlags = CameraClearFlags.Color;//清屏方式
        cam.targetTexture = shadowMap;    
        cam.enabled = false;
    }

    private void UpdateLight()
    {
        lightInstance.spotAngle = spotAngle;
        lightInstance.range = range;
        lightInstance.intensity = intensity;
        lightInstance.color = color;

        cam.fieldOfView = spotAngle;
        cam.aspect = 1f;
        cam.nearClipPlane = Mathf.Min(0.1f, range * 0.01f);
        cam.farClipPlane = range;

        float size = range*Mathf.Tan(Mathf.Deg2Rad*0.5f*spotAngle);
        cone.localScale = new Vector3(size,range/2,size);//构造cone时将中心点移动到cone的中心
    }

    private void UpdateShadowData()
    {
        if(cam==null)
        {
            InitCam();
        }
        Matrix4x4 proj = GL.GetGPUProjectionMatrix(cam.projectionMatrix,false);
        Shader.SetGlobalFloat("_MyCustomLightShadowBias",lightShadowBias);
        lightSpaceMatrix = proj*nMat*cam.worldToCameraMatrix;
        Shader.SetGlobalMatrix("_MyCustomLightSpaceMatrix",lightSpaceMatrix);
    }

    public bool TryGetShadowData(out Camera lightCamera, out RenderTexture target,
        out Shader depthShader, out Matrix4x4 matrix)
    {
        lightCamera = cam;
        target = shadowMap;
        depthShader = castShadow;
        matrix = lightSpaceMatrix;
        return lightCamera && target && depthShader;
    }

    private void UpdateRaymarching()
    {
        Shader.SetGlobalVector("_VolumetricLightPos",new Vector4(transform.position.x,transform.position.y,transform.position.z,intensity));
        Shader.SetGlobalColor("_VolumetricLightColor",color);
        Shader.SetGlobalFloat("_MyCustomShadowIntensity",shadowIntensity);
        Shader.SetGlobalTexture("_MyCustomShadowMap",shadowMap);
        Shader.SetGlobalTexture("_Dither",dither ? dither : Texture2D.whiteTexture);

        Vector3 lightForward = transform.TransformVector(Vector3.forward).normalized;
        float cosLightAngle = Mathf.Cos(Mathf.Deg2Rad*spotAngle/2f);
        Shader.SetGlobalVector("_VolumetricLightForward",new Vector4(lightForward.x,lightForward.y,lightForward.z,cosLightAngle));
    }
}
