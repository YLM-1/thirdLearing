using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

public class BVH : MonoBehaviour
{
    [SerializeField] private Transform meshParent;
    [SerializeField] private ComputeShader meshDataShader;
    [SerializeField] private Mesh mesh;

    //模型数据结构
    struct MeshVertex
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 tangent;
        public Vector2 uv;
    }
    MeshBufferContainter container;

    //材质数据结构
    struct MaterialData
    {
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;
        public uint materialType;
        public MaterialData(Material mat)
        {
            albedo = new Vector3(mat.color.linear.r, mat.color.linear.g, mat.color.linear.b);
            metallic = mat.GetFloat("_Metallic");
            smoothness = mat.GetFloat("_Glossiness");
            transparent = -1;
            emissionColor = Vector3.zero;
            materialType=0;

            if((int)mat.GetFloat("_Surface")==1)
            {
                transparent = mat.color.a;
                materialType = 1;
            }

            if(mat.IsKeywordEnabled("_EMISSION"))
            {
                Color color = mat.GetColor("_EmissionColor");
                emissionColor = new Vector3(color.r,color.g,color.b);
                materialType = 2;
            }   
        }
    }

    ComputeBuffer materialDataBuffer;

    ////////////// chapter4_3 //////////////
    public void Init(ComputeShader cs,int kernelHandle)
    {
        ComputeShader rayTracingShader = cs;
        int kernel = kernelHandle;

        //1.初始化mesh
        InitMesh(out mesh , out List<uint>materialIndices,out List<Material> materials, out List<Vector2Int> shadowIndices);

        //初始化material
        InitMaterialData(materials);

        //3.使用Mesh buffer container
        container = new MeshBufferContainter(mesh,materialIndices,shadowIndices);

        ////////////// chapter4_4 //////////////
        MeshData.Calculate(container.trianglesLength,
            container.vertexBuffer,
            container.indexBuffer,
            container.materialIndexBuffer,  
            container.shadowIndexBuffer,
            container.bounds,
            meshDataShader,
    /*out */container.triangleAABBBuffer,
    /*out */container.triangleDataBuffer,
    /*out */container.triangleIndexBuffer,
    /*out */container.mortonCodeBuffer);
    }

    private void InitMesh(out Mesh mesh,
        out List<uint> materialIndices,
        out List<Material> materials,
        out List<Vector2Int> shadowIndices)
    {
        mesh = null;
        MeshRenderer[] mrs = (from mr in meshParent.GetComponentsInChildren<MeshRenderer>(false)
                              where mr.enabled && mr.gameObject.activeInHierarchy
                              select mr).ToArray();
        //mesh顶点相关数据存储在这些数组中
        List<int> indices = new List<int>();       
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector3> tangents = new List<Vector3>();
        List<Vector2> uvs = new List<Vector2>();

        //材质：这里存储每个三角形面的材质id               
        materialIndices = new List<uint>();
        materials = new List<Material>();

        //阴影：这里存储的每个三角面的cast/recive shadow
        shadowIndices = new List<Vector2Int>();

        //没有可合并的模型时直接返回，避免访问 mrs[0] 越界
        if (mrs.Length == 0)
            return;

        //开始合并模型
        int indexOffset = 0;
        uint materialIndex = 0;
        Bounds encompassingAABB = mrs[0].bounds;

        foreach(MeshRenderer mr in mrs)
        {
            //得到每个模型的顶点数据
            Mesh m = mr.GetComponent<MeshFilter>().sharedMesh;
            var _indices = m.triangles.Select( i=>i+indexOffset);
            //将顶点，发现，切线从局部坐标变换到世界坐标系
            var _vertices = m.vertices.Select(v => mr.transform.TransformPoint(v));
            var _normals = m.normals.Select(n => mr.transform.TransformVector(n));
            var _tangents = m.tangents.Select(t => mr.transform.TransformVector(t));
            var _uvs = m.uv;
            
            indices.AddRange(_indices);
            vertices.AddRange(_vertices);
            normals.AddRange(_normals);
            tangents.AddRange(_tangents);
            uvs.AddRange(_uvs);

            //2.处理材质，这里时处理当前模型的三角面，而不是顶点
            //Where:保留满足条件的元素
            int[] polygons = m.triangles.Where((value,index)=>index%3==0).ToArray();
            Material mat = mr.sharedMaterial;

            //如果当前模型的材质已经在material里，就用已有的材质id赋值
            if(materials.Contains(mat))
            {
                uint index = (uint)materials.IndexOf(mat);//IndexOf(mat):查找 mat 在这个列表里第一次出现的下标
                //Select:把每个元素转换成新元素(加工厂)
                materialIndices.AddRange(polygons.Select(i=>index));
            }
            //如果当前模型的材质不在mateials里，则将这个material添加进来
            else
            {
                materialIndices.AddRange(polygons.Select(i => materialIndex));
                materials.Add(mat);
                materialIndex+=1;
            }

            //3.处理阴影，使用2个int来存储阴影数据:第一个int:cast shadow,第二个int:receive shadow
            shadowIndices.AddRange(polygons.Select(i => new Vector2Int(mr.shadowCastingMode == ShadowCastingMode.On ? 1 : 0, mr.receiveShadows ? 1 : 0)));

            //迭代好一个mesh后，index需要做偏移
            indexOffset += m.vertices.Length;
            
            //同时也更新一下AABB
            encompassingAABB.min = Vector3.Min(encompassingAABB.min, m.bounds.min);
            encompassingAABB.max = Vector3.Max(encompassingAABB.max, m.bounds.max);

            // 开始合并 mesh
            int vertexCount = vertices.Count;
            int indexCount = indices.Count;

            // 1. 创建一个新的 mesh
            mesh = new Mesh();

            // 2. 设置 mesh 的顶点数据结构
            // Byte Address Buffer：读写时按 buffer 内数据的 byte 偏移寻址，方便直接访问底层数据
            // 对应 HLSL 里的 ByteAddressBuffer / RWByteAddressBuffer
            //原始字节，按 byte offset 访问
            mesh.indexBufferTarget |= GraphicsBuffer.Target.Raw;
            mesh.vertexBufferTarget |= GraphicsBuffer.Target.Raw;

            // Vertex position: float32 x 3
            VertexAttributeDescriptor pDesc = new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3);
            // Vertex normal: float32 x 3
            VertexAttributeDescriptor nDesc = new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float32, 3);
            // Vertex tangent: float32 x 3
            VertexAttributeDescriptor tDesc = new VertexAttributeDescriptor(VertexAttribute.Tangent, VertexAttributeFormat.Float32, 3);
            // Vertex uv: float32 x 2
            VertexAttributeDescriptor uvDesc = new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2);

            // 设置顶点数据结构
            mesh.SetVertexBufferParams(vertexCount, pDesc, nDesc, tDesc, uvDesc);
            // 设置索引数据
            // IndexFormat.UInt16：2 byte，范围 0-65535
            // IndexFormat.UInt32：4 byte，范围 0-4294967295
            mesh.SetIndexBufferParams(indexCount, IndexFormat.UInt32);
            // 不重新计算包围盒：MeshUpdateFlags.DontRecalculateBounds
            mesh.SetSubMesh(0, new SubMeshDescriptor(0, indexCount), MeshUpdateFlags.DontRecalculateBounds);

            // 填充顶点数据
            MeshVertex[] vertexArray = new MeshVertex[vertexCount];
            for (var i = 0; i < vertexCount; ++i)
            {
                vertexArray[i].position = vertices[i];
                vertexArray[i].normal = normals[i];
                vertexArray[i].tangent = tangents[i];
                vertexArray[i].uv = uvs[i];
            }
            mesh.SetVertexBufferData(vertexArray, 0, 0, vertexCount);
            mesh.bounds = encompassingAABB;

            // 填充索引数据
            mesh.SetIndexBufferData(indices, 0, 0, indexCount);
        }
    }
    void InitMaterialData(List<Material> materials)
    {
        MaterialData[] datas = (from m in materials select new MaterialData(m)).ToArray();
        materialDataBuffer = new ComputeBuffer(materials.Count, Marshal.SizeOf(typeof(MaterialData)));
        materialDataBuffer.SetData(datas);
    }
}
