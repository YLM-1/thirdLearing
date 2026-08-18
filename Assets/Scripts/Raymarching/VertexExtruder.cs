using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VertexExtruder : MonoBehaviour
{
    [SerializeField] private Transform light;
    [SerializeField] private Material volumeLightMaterial;

    private void Update()
    {
        if(!light||!volumeLightMaterial)
            return;

        volumeLightMaterial.SetVector("_WorldLightPos",light.position);    
    }
}
