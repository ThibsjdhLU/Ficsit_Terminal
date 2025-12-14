## 2025-05-30 - [Graph Layout Optimization]
**Learning:** In factory graph generation, repeatedly scanning the entire node list (O(N)) to find link targets inside a loop resulted in O(N^2) complexity. This becomes a bottleneck for large factories.
**Action:** Always maintain a lookup dictionary (map) when building graph structures if you need to cross-reference nodes later. O(1) lookups are trivial to implement and massively scalable.

## 2025-05-30 - [UUID Generation Optimization]
**Learning:** In Swift, `String(format:)` and `UUID(uuidString:)` are expensive when called in a tight loop (like O(N) graph node generation).
**Action:** When generating deterministic UUIDs from hashes, construct the `uuid_t` tuple (bytes) directly and use `UUID(uuid: ...)` instead of intermediate string formatting. This avoids heap allocations and parsing overhead.
