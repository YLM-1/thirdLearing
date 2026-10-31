using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class MeshBufferContainter
{
    //定义包含整个场景的AABB
    static readonly float size = 125f;
    //定义一个名为 Whole 的静态只读 AABB（轴aligned包围盒）对象
    static readonly AABB Whole = new AABB()
    {
        min = Vector3.one*1*-size,
        max = Vector3.one*size
    };

    //mesh的bounds,使用bounds来计算AABB
    //定义一个名为 bounds 的公共属性，当外部访问这个属性时，它会直接返回内部私有变量 _bounds 的值。
    //bounds 变成了一个只读属性。
     public Bounds bounds =>_bounds;
     //三角面的总数
     public uint trianglesLength => _trianglesLength;
     //每个三角形的莫顿码
     public ComputeBuffer mortonCodeBuffer => _mortonCodeBuffer.computeBuffer;
     //三角面数据
     public ComputeBuffer triangleIndexBuffer => _triangleIndexBuffer.computeBuffer;
     public ComputeBuffer triangleDataBuffer => _triangleDataBuffer.computeBuffer;
     public ComputeBuffer triangleAABBBuffer => _triangleAABBBuffer.computeBuffer;
     //BVH数据
     public ComputeBuffer bvhDataBuffer => _bvhDataBuffer.computeBuffer;
     public ComputeBuffer bvhLeafNodeBuffer => _bvhLeafNodeBuffer.computeBuffer;
     public ComputeBuffer bvhInternalNodeBuffer => _bvhInternalNodeBuffer.computeBuffer;
     //使用Unity的Advanced Mesh API，通过内存来访问mesh
     public GraphicsBuffer indexBuffer => _indexBuffer;
     public GraphicsBuffer vertexBuffer => _vertexBuffer;
     //材质索引
     public ComputeBuffer materialIndexBuffer => _materialIndexBuffer.computeBuffer;
     //每个三角面是否产生。接受阴影
     public ComputeBuffer shadowIndexBuffer => _shadowIndexBuffer.computeBuffer;

    private Bounds _bounds;
    private uint _trianglesLength;
    private DataBuffer<uint> _mortonCodeBuffer;
    private DataBuffer<uint> _triangleIndexBuffer;
    private DataBuffer<Triangle> _triangleDataBuffer;
    private DataBuffer<AABB> _triangleAABBBuffer;
    private DataBuffer<AABB> _bvhDataBuffer;
    private DataBuffer<LeafNode> _bvhLeafNodeBuffer;
    private DataBuffer<InternalNode> _bvhInternalNodeBuffer;
    private GraphicsBuffer _indexBuffer;
    private GraphicsBuffer _vertexBuffer;
    private DataBuffer<uint> _materialIndexBuffer;
    private DataBuffer<Vector2Int> _shadowIndexBuffer;

    public MeshBufferContainter(Mesh mesh,List<uint> materialIndices,List<Vector2Int> shadowIndices)
    {
        _mortonCodeBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT,uint.MaxValue);
        _triangleIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _triangleDataBuffer = new DataBuffer<Triangle>(Constants.DATA_ARRAY_COUNT, Triangle.NullTriangle);
        _triangleAABBBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT, AABB.NullAABB);

        _bvhDataBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT);
        _bvhLeafNodeBuffer = new DataBuffer<LeafNode>(Constants.DATA_ARRAY_COUNT, LeafNode.NullLeaf);
        _bvhInternalNodeBuffer = new DataBuffer<InternalNode>(Constants.DATA_ARRAY_COUNT, InternalNode.NullLeaf);

        _bounds = new Bounds
        {
            min = Whole.min,
            max = Whole.max,
        };
        //不使用真实场景的bounds,因为真实的mesh.bounds可能比较小
        _trianglesLength = (uint)mesh.triangles.Length / 3;

        _indexBuffer = mesh.GetIndexBuffer();
        _vertexBuffer = mesh.GetVertexBuffer(0);

        //这里存储每一个三角形材质的id
        _materialIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _materialIndexBuffer.SetData(materialIndices.ToArray());

        //这里存储每个三角形阴影的id
        _shadowIndexBuffer = new DataBuffer<Vector2Int>(Constants.DATA_ARRAY_COUNT, Vector2Int.one);
        _shadowIndexBuffer.SetData(shadowIndices.ToArray());
    }

    public void Dispose()
    {
        _mortonCodeBuffer.Dispose();
        _triangleIndexBuffer.Dispose();
        _triangleDataBuffer.Dispose();
        _triangleAABBBuffer.Dispose();
        _bvhDataBuffer.Dispose();
        _bvhLeafNodeBuffer.Dispose();
        _bvhInternalNodeBuffer.Dispose();

        _indexBuffer.Dispose();
        _vertexBuffer.Dispose();
        _materialIndexBuffer.Dispose();
        _shadowIndexBuffer.Dispose();
    }
}
