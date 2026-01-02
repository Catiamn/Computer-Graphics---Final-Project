using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
public class DeformationController : MonoBehaviour
{
    [Header("Deformation Settings")]
    [SerializeField] private float amplitude = 0.5f;
    [SerializeField] private float frequency = 1.0f;
    [SerializeField] private float speed = 1.0f;
    [SerializeField] private float radius = 2.0f;
    [SerializeField] private Vector3 deformationCenter = Vector3.zero;
    
    [Header("Mesh Type")]
    [SerializeField] private bool isWaving;
    [SerializeField] private bool isCloth;
    
    [Header("Mesh Recovery")]
    [SerializeField] private float recoveryRate = 0.5f;
    private float _maxDeformation;
    
    [Header("Performance")]
    [SerializeField] private bool updateContinuously = true;
    [Range(1, 60)] public int updateRate = 60;
    
    // Compute shader resources
    [SerializeField] private ComputeShader deformationComputeShader;
    private ComputeBuffer _verticesBuffer;
    private ComputeBuffer _normalsBuffer;
    private ComputeBuffer _deformedVerticesBuffer;
    private ComputeBuffer _maxDeformationBuffer;
    
    // Mesh data
    private Mesh _originalMesh;
    private Mesh _deformedMesh;
    private Vector3[] _originalVertices;
    private Vector3[] _originalNormals;
    
    // Material property block for passing buffer to shader
    private MaterialPropertyBlock _propertyBlock;
    private Renderer _meshRenderer;
    
    // Timing
    private float _timeAccumulator;
    
    void Start()
    {
        _maxDeformation = amplitude;
        InitializeMeshData();
        InitializeComputeBuffers();
        InitializeMaterial();
    }
    
    void InitializeMeshData()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        _originalMesh = meshFilter.mesh;
        
        // Create a copy of the mesh for deformation
        _deformedMesh = Instantiate(_originalMesh);
        meshFilter.mesh = _deformedMesh;
        
        // Get original vertices and normals
        _originalVertices = _originalMesh.vertices;
        _originalNormals = _originalMesh.normals;
        
        _meshRenderer = GetComponent<Renderer>();
    }
    
    void InitializeComputeBuffers()
    {
        int vertexCount = _originalVertices.Length;
        
        // Create compute buffers
        _verticesBuffer = new ComputeBuffer(vertexCount, sizeof(float) * 3);
        _normalsBuffer = new ComputeBuffer(vertexCount, sizeof(float) * 3);
        _deformedVerticesBuffer = new ComputeBuffer(vertexCount, sizeof(float) * 3);
        _maxDeformationBuffer = new ComputeBuffer(vertexCount, sizeof(float));
        float[] initialDeformation = new float[vertexCount];
        
        // Set buffer data
        _verticesBuffer.SetData(_originalVertices);
        _normalsBuffer.SetData(_originalNormals);
        
        // Initialize deformed vertices with original positions
        _deformedVerticesBuffer.SetData(_originalVertices);
        _maxDeformationBuffer.SetData(initialDeformation);
    }
    
    void InitializeMaterial()
    {
        _propertyBlock = new MaterialPropertyBlock();
        _meshRenderer.GetPropertyBlock(_propertyBlock);
        
        // Set the compute buffer to material
        _propertyBlock.SetBuffer("deformedVerticesBuffer", _deformedVerticesBuffer);
        _meshRenderer.SetPropertyBlock(_propertyBlock);
    }
    
    void Update()
    {
        if (!updateContinuously)
            return;
        
        // For objects that wave constantly.
        _timeAccumulator += Time.deltaTime;
        float updateInterval = 1f / updateRate;
        
        if (_timeAccumulator >= updateInterval)
        {
            ExecuteDeformation();
            _timeAccumulator = 0f;
        }
    }

    private void ExecuteDeformation()
    {
        if (!deformationComputeShader)
        {
            Debug.LogError("Compute Shader not assigned!");
            return;
        }
        
        // Find kernel index
        int kernelIndex = deformationComputeShader.FindKernel("CSMain");
        
        // Set buffers
        deformationComputeShader.SetBuffer(kernelIndex, "verticesBuffer", _verticesBuffer);
        deformationComputeShader.SetBuffer(kernelIndex, "normalsBuffer", _normalsBuffer);
        deformationComputeShader.SetBuffer(kernelIndex, "deformedVerticesBuffer", _deformedVerticesBuffer);
        deformationComputeShader.SetBuffer(kernelIndex, "maxDeformationBuffer", _maxDeformationBuffer );
        
        // Set parameters
        deformationComputeShader.SetFloat("_Time", Time.time);
        deformationComputeShader.SetFloat("_Amplitude", amplitude);
        deformationComputeShader.SetFloat("_Frequency", frequency);
        deformationComputeShader.SetFloat("_Speed", speed);
        deformationComputeShader.SetVector("_DeformationCenter", deformationCenter);
        deformationComputeShader.SetFloat("_Radius", radius);
        deformationComputeShader.SetBool("_IsWaving",  isWaving);
        deformationComputeShader.SetBool("_IsCloth",  isCloth);
        deformationComputeShader.SetFloat("_RecoveryRate", recoveryRate); // Adjust as needed
        deformationComputeShader.SetFloat("_MaxDeformation", _maxDeformation);
        deformationComputeShader.SetFloat("_DeltaTime", Time.deltaTime);
        
        // Calculate thread groups (64 threads per group)
        int threadGroups = Mathf.CeilToInt(_originalVertices.Length / 64f);
        
        // Dispatch compute shader
        deformationComputeShader.Dispatch(kernelIndex, threadGroups, 1, 1);
        
        // Update mesh with deformed vertices
        UpdateMeshVertices();
    }
    
    void UpdateMeshVertices()
    {
        // Get deformed vertices from GPU
        Vector3[] deformedVertices = new Vector3[_originalVertices.Length];
        _deformedVerticesBuffer.GetData(deformedVertices);
        
        // Apply to mesh
        _deformedMesh.vertices = deformedVertices;
        
        // Recalculate normals for lighting
        _deformedMesh.RecalculateNormals();
        _deformedMesh.RecalculateBounds();
    }
    
    // Public method to trigger deformation manually
    public void TriggerDeformationAtPoint(Vector3 point, float force)
    {
        deformationCenter = transform.InverseTransformPoint(point);
        amplitude = force;
        ExecuteDeformation();
    }
    
    void OnDestroy()
    {
        // Release compute buffers to prevent memory leaks
        _verticesBuffer?.Release();
        _normalsBuffer?.Release();
        _deformedVerticesBuffer?.Release();
        _maxDeformationBuffer?.Release();
    }
    
    void OnDrawGizmosSelected()
    {
        // Visualize deformation center
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.TransformPoint(deformationCenter), radius);
    }
}