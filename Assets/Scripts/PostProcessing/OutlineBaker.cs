using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using Unity.Jobs;
using Unity.Collections;

public class OutlineBaker : AssetPostprocessor {
    static bool bExecuting = false;

    [MenuItem("Test/BakeMesh1!", false, 50)]
    public static void BakeMesh() {
        Object obj = Selection.activeObject;

        string path = AssetDatabase.GetAssetPath(obj);
        string ext = Path.GetExtension(path);

        if (ext == ".fbx") {
            bExecuting = true;

            string newPath = Path.GetDirectoryName(path) + "/copy_@@@" + Path.GetFileName(path);
            Debug.Log($"new path = {newPath}");
            AssetDatabase.CopyAsset(path, newPath);
        } else {
            Debug.LogError($"必须对.fbx文件进行此操作!");
        }
    }

    static void OnPostOver(string path, bool isCopy) {
        if (isCopy) {
            string srcPath = path.Replace("copy_@@@", "");
            Debug.Log($"复制体后处理完毕,本体的path={srcPath}");
            AssetDatabase.ImportAsset(srcPath);
        } else {
            Debug.Log($"烘焙完毕!关闭开关!");
            bExecuting = false;
        }
    }

    void OnPreprocessModel() {
        if (!bExecuting) return;

        ModelImporter importer = assetImporter as ModelImporter;

        if (!assetImporter.assetPath.Contains("copy_@@@")) return;

        importer.importNormals = ModelImporterNormals.Calculate;
        importer.normalCalculationMode = ModelImporterNormalCalculationMode.AngleWeighted;
        importer.normalSmoothingAngle = 180f;

        importer.importAnimation = false;
        importer.materialImportMode = ModelImporterMaterialImportMode.None;
    }

    void OnPostprocessModel(GameObject go) {
        if (!bExecuting) return;

        if (go.name.Contains("copy_@@@")) {
            OnPostOver(assetPath, true);
        } else {
            Debug.Log($"本体进入流程!");
            string copyPath = Path.GetDirectoryName(assetPath) + "/copy_@@@" + Path.GetFileName(assetPath);
            Debug.Log($"复制体的Path = {copyPath}");
            GameObject cGo = AssetDatabase.LoadAssetAtPath<GameObject>(copyPath);

            Dictionary<string, Mesh> dic_name2mesh_src = GetMesh(go);
            Dictionary<string, Mesh> dic_name2mesh_copy = GetMesh(cGo);

            foreach (var item in dic_name2mesh_src) {
                if (dic_name2mesh_copy.TryGetValue(item.Key, out Mesh smthMesh)) {
                    item.Value.colors = GetColor(item.Value, smthMesh);
                    EditorUtility.SetDirty(item.Value);
                }
            }

            AssetDatabase.SaveAssets();

            string copyAssetPath = copyPath;
            AssetDatabase.DeleteAsset(copyAssetPath);

            OnPostOver("", false);
        }
    }

    Dictionary<string, Mesh> GetMesh(GameObject go) {
        Dictionary<string, Mesh> dic = new();
        foreach (var item in go.GetComponentsInChildren<MeshFilter>()) {
            string n = item.name.Replace("copy_@@@", "");
            dic.TryAdd(n, item.sharedMesh);
        }
        if (dic.Count == 0) {
            foreach (var item in go.GetComponentsInChildren<SkinnedMeshRenderer>()) {
                string n = item.name.Replace("copy_@@@", "");
                dic.TryAdd(n, item.sharedMesh);
            }
        }

        return dic;
    }

    Color[] GetColor(Mesh srcMesh, Mesh smthMesh) {
        int lenSrc = srcMesh.vertices.Length;
        int lenSmth = smthMesh.vertices.Length;

        NativeArray<Vector3> arr_vert_smth = new(smthMesh.vertices, Allocator.Persistent);
        NativeArray<Vector3> arr_normal_smth = new(smthMesh.normals, Allocator.Persistent);

        NativeParallelMultiHashMap<Vector3, Vector3> vert2normal = new(lenSmth, Allocator.Persistent);

        CollectNormalJob collectJob = new() {
            verts = arr_vert_smth,
            normals = arr_normal_smth,
            vert2normal = vert2normal.AsParallelWriter()
        };
        JobHandle collectHandle = collectJob.Schedule(lenSmth, 128);
        collectHandle.Complete();

        NativeArray<Vector3> arr_vert_src = new(srcMesh.vertices, Allocator.Persistent);
        NativeArray<Vector3> arr_nor_src = new(srcMesh.normals, Allocator.Persistent);
        NativeArray<Vector4> arr_tgt_src = new(srcMesh.tangents, Allocator.Persistent);

        NativeArray<Color> arr_color = new(lenSrc, Allocator.Persistent);

        BakeNormalJob bakeJob = new() {
            normals = arr_nor_src,
            verts = arr_vert_src,
            tangents = arr_tgt_src,
            vert2normal = vert2normal,
            colors = arr_color
        };
        JobHandle bakeHandle = bakeJob.Schedule(lenSrc, 128);
        bakeHandle.Complete();

        Color[] cols = new Color[lenSrc];
        arr_color.CopyTo(cols);

        vert2normal.Dispose();
        arr_vert_smth.Dispose();
        arr_normal_smth.Dispose();
        arr_vert_src.Dispose();
        arr_nor_src.Dispose();
        arr_tgt_src.Dispose();
        arr_color.Dispose();

        return cols;
    }

    struct CollectNormalJob : IJobParallelFor {
        [ReadOnly] public NativeArray<Vector3> verts;
        [ReadOnly] public NativeArray<Vector3> normals;
        public NativeParallelMultiHashMap<Vector3, Vector3>.ParallelWriter vert2normal;

        public void Execute(int index) {
            vert2normal.Add(verts[index], normals[index]);
        }
    }

    struct BakeNormalJob : IJobParallelFor {
        [ReadOnly] public NativeArray<Vector3> normals;
        [ReadOnly] public NativeArray<Vector3> verts;
        [ReadOnly] public NativeArray<Vector4> tangents;
        [ReadOnly] public NativeParallelMultiHashMap<Vector3, Vector3> vert2normal;

        public NativeArray<Color> colors;

        public void Execute(int index) {
            Vector3 newNormal = Vector3.zero;

            if (vert2normal.TryGetFirstValue(verts[index], out Vector3 normal, out NativeParallelMultiHashMapIterator<Vector3> it)) {
                newNormal += normal;
                while (vert2normal.TryGetNextValue(out normal, ref it)) {
                    newNormal += normal;
                }
            }

            newNormal = newNormal.normalized;

            if (newNormal == Vector3.zero) {
                colors[index] = new Color(0.5f, 0.5f, 0.5f, 1f);
                return;
            }

            Vector3 bitangent = (Vector3.Cross(normals[index], (Vector3)tangents[index]) * tangents[index].w).normalized;

            Matrix4x4 tbn = new(
                (Vector3)tangents[index],
                bitangent,
                normals[index],
                Vector4.zero
            );
            tbn = tbn.transpose;

            Vector3 finalNormal = tbn.MultiplyVector(newNormal).normalized;

            Color col = new(
                finalNormal.x * 0.5f + 0.5f,
                finalNormal.y * 0.5f + 0.5f,
                finalNormal.z * 0.5f + 0.5f,
                1
            );

            colors[index] = col;
        }
    }
}
