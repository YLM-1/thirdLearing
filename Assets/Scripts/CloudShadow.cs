using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CloudShadow : MonoBehaviour
{
    private Camera cam;
    void Start()
    {
        OnWillRenderObject();//物体被摄像机渲染前的那一刻，执行一些准备工作
    }
    private void OnWillRenderObject()//每帧渲染的时候运行
    {
        if(cam==null)
            cam = Camera.main;
        float dist = cam.farClipPlane-cam.nearClipPlane;
        Vector3 pos = cam.transform.position;
        Vector3 ray = cam.transform.forward*dist;
        Vector3 destPos = pos+ray;
        transform.position = destPos;

        Vector3 scale = Vector3.one;
        float h = cam.orthographic?cam.orthographicSize*2f: Mathf.Tan(cam.fieldOfView * Mathf.Deg2Rad * 0.5f) * dist * 2f;
        transform.localScale = new Vector3(h*cam.aspect/scale.x,h*scale.y,1f);

        bool gameView = Camera.current == null || Camera.current == Camera.main;
        if (gameView)
            transform.rotation = Quaternion.LookRotation(destPos - pos, cam.transform.up);
    }
}
