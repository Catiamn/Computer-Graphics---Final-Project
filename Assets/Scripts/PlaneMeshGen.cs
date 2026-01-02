using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter),typeof(MeshRenderer))]
public class MeshGen2 : MonoBehaviour
{
    [SerializeField]
    private Vector2 size = Vector2.one;
    [SerializeField]
    private int subdivisions = -1;
    [SerializeField]
    private Material material;
    [SerializeField]
    private Vector2 offset;
    [SerializeField]
    private float angle;
    
    void Start()
    {
        CreateMesh();
    }

    void CreateMesh()
    {
        List<Vector3> vertices = new List<Vector3>();
        List<int> tris = new List<int>();
        List<Color> colors = new List<Color>();
        List<Vector2> uvs = new List<Vector2>();

        float baseX = -size.x * 0.5f;
        float baseZ = -size.y * 0.5f;

        float incX = size.x / subdivisions;
        float incZ = size.y / subdivisions;

        float rad  = angle * Mathf.Deg2Rad;
        float cos = Mathf.Cos(rad);
        float sin = Mathf.Sin(rad);

        for (int zi = 0; zi < subdivisions + 1; zi++)
        {
            for (int xi = 0; xi < subdivisions + 1; xi++)
            {
                float x = baseX + xi * incX;
                float z = baseZ + zi * incZ;

                vertices.Add(new Vector3(x, 0, z));
                colors.Add(new Color(x, z, 0, 1.0f));
                uvs.Add(new Vector2((float)xi / subdivisions,
                    (float)zi / subdivisions));
            }
        }

        int verticesPerLine = subdivisions + 1;

        for (int zi = 0; zi < subdivisions; zi++)
        {
            for (int xi = 0; xi < subdivisions; xi++)
            {
                int pivotIndex = xi + zi * verticesPerLine;

                tris.Add(pivotIndex);
                tris.Add(pivotIndex + 1 + verticesPerLine);
                tris.Add(pivotIndex + 1);

                tris.Add(pivotIndex);
                tris.Add(pivotIndex + verticesPerLine);
                tris.Add(pivotIndex + 1 + verticesPerLine);
            }
        }

        for(int i = 0; i < uvs.Count; i++)
        {
            float rotateX = uvs[i].x * cos - uvs[i].y * sin;
            float rotateY = uvs[i].x * sin + uvs[i].y * cos;
            uvs[i] = new Vector2(rotateX, rotateY);
        }

        Mesh mesh = new Mesh();
        mesh.name = "Generated Mesh";
        mesh.SetVertices(vertices);
        mesh.SetColors(colors);
        mesh.SetUVs(0, uvs);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateBounds();
        mesh.UploadMeshData(false);

        var meshFilter = GetComponent<MeshFilter>();
        meshFilter.mesh = mesh;
        var meshRenderer = GetComponent<MeshRenderer>();
        material.mainTextureOffset += offset;
    
        meshRenderer.material = material;
        
    }
}
