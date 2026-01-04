using UnityEngine;

public class ObjectController : MonoBehaviour
{
    [SerializeField] private DeformationController deformator;
    [SerializeField] private float deformationForce = 1.0f;
    [SerializeField] private float radius = 1.0f;
    void FixedUpdate()
    {
           deformator.TriggerDeformationAtPoint(transform.position,deformationForce, radius);
    }
}
