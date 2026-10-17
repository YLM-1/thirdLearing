using UnityEditor;
using UnityEngine;

/// <summary>
/// 生成高密度海面网格，替换默认 plane.obj（100x100），
/// 让 Gerstner 的短波长有足够顶点采样，避免频闪。
/// 菜单：Tools/Ocean/Generate High-Res Plane Mesh
/// </summary>
public static class OceanPlaneMeshGenerator
{
    const string AssetPath = "Assets/Models/OceanPlane_HighRes.asset";
    const int Segments = 300;          // 300x300 网格 -> 顶点间距 2000/300 ≈ 6.7 单位
    const float SizeX = 1000f;         // 与 plane.obj 一致
    const float SizeZ = 1000f;
    // plane.obj 的包围盒中心，保持一致，避免换网格后水面位置变化
    static readonly Vector3 Center = new Vector3(-58.281906f, 0f, 39.079208f);

    [MenuItem("Tools/Ocean/Generate High-Res Plane Mesh")]
    public static void Generate()
    {
        Mesh mesh = AssetDatabase.LoadAssetAtPath<Mesh>(AssetPath);
        bool isNew = mesh == null;
        if (isNew) mesh = new Mesh { name = "OceanPlane_HighRes" };
        else mesh.Clear();

        mesh.indexFormat = Segments * Segments * 6 > 65535
            ? UnityEngine.Rendering.IndexFormat.UInt32
            : UnityEngine.Rendering.IndexFormat.UInt16;

        int row = Segments + 1;
        int vcount = row * row;

        var vertices = new Vector3[vcount];
        var uvs = new Vector2[vcount];
        var triangles = new int[Segments * Segments * 6];

        float halfX = SizeX * 0.5f;
        float halfZ = SizeZ * 0.5f;

        for (int z = 0; z <= Segments; z++)
        {
            float tz = (float)z / Segments;
            for (int x = 0; x <= Segments; x++)
            {
                float tx = (float)x / Segments;
                int i = z * row + x;
                vertices[i] = new Vector3(
                    Center.x + Mathf.Lerp(-halfX, halfX, tx),
                    Center.y,
                    Center.z + Mathf.Lerp(-halfZ, halfZ, tz));
                uvs[i] = new Vector2(tx, tz);
            }
        }

        int t = 0;
        for (int z = 0; z < Segments; z++)
        {
            for (int x = 0; x < Segments; x++)
            {
                int i = z * row + x;
                // 第一个三角形
                triangles[t++] = i;
                triangles[t++] = i + row;
                triangles[t++] = i + 1;
                // 第二个三角形
                triangles[t++] = i + 1;
                triangles[t++] = i + row;
                triangles[t++] = i + row + 1;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();

        // 保证法线朝上（朝 +Y），否则会因背面剔除看不见
        if (mesh.normals.Length > 0 && mesh.normals[0].y < 0f)
        {
            for (int i = 0; i < triangles.Length; i += 3)
            {
                int tmp = triangles[i + 1];
                triangles[i + 1] = triangles[i + 2];
                triangles[i + 2] = tmp;
            }
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
        }

        mesh.RecalculateTangents();
        mesh.RecalculateBounds();

        if (isNew) AssetDatabase.CreateAsset(mesh, AssetPath);
        else
        {
            EditorUtility.SetDirty(mesh);
            AssetDatabase.SaveAssets();
        }

        AssetDatabase.Refresh();
        Selection.activeObject = mesh;
        Debug.Log($"[Ocean] 高密度海面网格已生成: {AssetPath} ({vcount} verts, {Segments * Segments * 2} tris)");
    }
}
