## 2025-05-30 - [Graph Layout Optimization]
**Learning:** In factory graph generation, repeatedly scanning the entire node list (O(N)) to find link targets inside a loop resulted in O(N^2) complexity. This becomes a bottleneck for large factories.
**Action:** Always maintain a lookup dictionary (map) when building graph structures if you need to cross-reference nodes later. O(1) lookups are trivial to implement and massively scalable.
