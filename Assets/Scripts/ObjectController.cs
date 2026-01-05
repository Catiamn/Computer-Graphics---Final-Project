using UnityEngine;

public class ObjectController : MonoBehaviour
{
    [SerializeField] private float deformationForce = 1.0f;
    [SerializeField] private float radius = 1.0f;
    void FixedUpdate()
    {
        if(Physics.Raycast(transform.position, -transform.up, out RaycastHit hit, Mathf.Infinity))
           if (hit.transform.TryGetComponent(out DeformationController deformer))
            deformer.TriggerDeformationAtPoint(transform.position,deformationForce, radius);
    }
}
