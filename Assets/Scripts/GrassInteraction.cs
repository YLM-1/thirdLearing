using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GrassInteraction : MonoBehaviour
{
    [SerializeField] private Material grassMatetrial;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if(grassMatetrial)
            grassMatetrial.SetVector("_Position",transform.position);
    }
}
