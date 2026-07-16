# Sugiyama placement qualification

Railway supports two internal placement adapters:

- Dagre, the production default.
- Sugiyama, a pure MoonBit shadow-qualified alternative.

Both adapters feed the same deterministic hierarchy stage and orthogonal router.
The adapter boundary returns canonical `layout_core.ObjectId` boxes, ranks, and
level heights; routing does not depend on which placement implementation ran.

## Qualification fixtures

The white-box shadow suite covers four deterministic graph families:

| Fixture | Shape | Purpose |
| --- | --- | --- |
| sparse | 50 nodes, two forward edges per node where available | Normal layered DAG |
| dense | 4 layers × 5 nodes, complete bipartite edges between adjacent layers | Crossing pressure |
| nested | Two container levels plus an external node | Hierarchy compatibility |
| long-edge | 30-node chain plus 20 ten-rank edges | Virtual nodes and long routing |

The separate Railway scale gate covers 10, 50, and 200-node sparse fixtures.

## Required thresholds

For every shadow fixture:

- Both adapters must emit every object and edge.
- Every edge must have a route with at least two points.
- Node and label overlap counts must be zero.
- Sugiyama crossings must be no greater than the larger of:
  - five times the edge count, or
  - four times Dagre's crossing count plus 20.
- Sugiyama long detours must be no greater than Dagre's count plus half the
  edge count.
- Sugiyama routes must use at most 10 points per edge.
- Sugiyama total route length must be no greater than four times Dagre's.

These are qualification thresholds, not evidence that Sugiyama should replace
Dagre by default. A default change requires tighter quality thresholds, stable
runtime data across CI targets, and a separate decision.
