using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct AABB
{
    //_dummy:只要有人（C 代码、GPU、另一个进程）会按字节读你的结构体，就必须管对齐；只被 CLR 读写，就不用管。
    public Vector3 min;
    public float _dummy0;
    public Vector3 max;
    public float _dummy1;
    public static AABB NullAABB = new AABB()
    {
        min = Vector3.zero,
        _dummy0 = 0,
        max = Vector3.zero,
        _dummy1 = 0,
    };
}

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct Triangle
{
    public Vector3 point0;
    float _dummy0;
    public Vector3 point1;
    float _dummy1;
    public Vector3 point2;
    float _dummy2;
    public Vector2 uv0;
    public Vector2 uv1;
    public Vector2 uv2;
    Vector2 _dummy3;
    //它起始 offset 必须是 16 的倍数,所以要补_dummy3
    public Vector3 normal0;
    float _dummy4;
    public Vector3 normal1;
    float _dummy5;
    public Vector3 normal2;
    float _dummy6;
    Vector3 tangent0;
    float _dummy7;
    Vector3 tangent1;
    float _dummy8;
    Vector3 tangent2;
    float _dummy9;

    int materialIndex;
    Vector3 _dummy10;

    public static Triangle NullTriangle = new Triangle()
    {
        point0 = Vector3.zero,
        _dummy0 = 0,
        point1 = Vector3.zero,
        _dummy1 = 0,
        point2 = Vector3.zero,
        _dummy2 = 0,

        uv0 = Vector2.zero,
        uv1 = Vector2.zero,
        uv2 = Vector2.zero,
        _dummy3 = Vector2.zero,

        normal0 = Vector3.zero,
        _dummy4 = 0,
        normal1 = Vector3.zero,
        _dummy5 = 0,
        normal2 = Vector3.zero,
        _dummy6 = 0,

        tangent0 = Vector3.zero,
        _dummy7 = 0,
        tangent1 = Vector3.zero,
        _dummy8 = 0,
        tangent2 = Vector3.zero,
        _dummy9 = 0,

        materialIndex = 0,
        _dummy10 = Vector3.zero,
    };
}

[StructLayout(LayoutKind.Sequential, Pack = 16)]
//叶子节点（LeafNode）：树的最底层，指向实际的三角形（或一组三角形）
public struct LeafNode
{
    public uint parent;
    public uint index;

    public static LeafNode NullLeaf = new LeafNode()
    {
        parent = 0xFFFFFFFF,
        index = 0xFFFFFFFF
    };
}

[StructLayout(LayoutKind.Sequential, Pack = 16)]
//内部节点（InternalNode）：树的中间层，每个内部节点有左右两个孩子，孩子可能是内部节点，也可能是叶子节点。
public struct InternalNode
{
    public uint leftNode;       // 左孩子在"某个数组"里的索引
    public uint leftNodeType;   // 左孩子的类型（是内部节点还是叶子）
    public uint rightNode;      // 右孩子索引
    public uint rightNodeType;  // 右孩子类型
    public uint parent;         // 父节点索引
    public uint index;          // 自己的索引（或标识）
    //在 C# 10 之前，结构体不允许显式写无参构造函数：
    public static InternalNode NullLeaf = new InternalNode()
    {
        leftNode = 0xFFFFFFFF,
        leftNodeType = 0xFFFFFFFF,
        rightNode = 0xFFFFFFFF,
        rightNodeType = 0xFFFFFFFF,
        parent = 0xFFFFFFFF,
        index = 0xFFFFFFFF
    };

    //C#10+ 可以，旧版不行	
    // public InternalNode()
    // {
    //     leftNode = 0xFFFFFFFF;
    //     leftNodeType = 0xFFFFFFFF;
    //     rightNode = 0xFFFFFFFF;
    //     rightNodeType = 0xFFFFFFFF;
    //     parent = 0xFFFFFFFF;
    //     index = 0xFFFFFFFF;
    // }
}
