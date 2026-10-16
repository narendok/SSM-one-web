# Highlight draft adapters — local preparation, 16 October 2026

Prepared separate strict highlight-draft save/read schemas and caller-authenticated server entry points. They call only save_requirement_highlight_draft/read_own_requirement_highlight_draft, validate author/source/version/request/body and require a separate matching readback. No internal-note read/copy or publication routine is called. Deployment and publication capability remain unavailable. Identity derives from authenticated server context; browser-supplied authority is rejected. No browser editor or client projection changed.

Validation: 26 focused internal-note/highlight adapter tests passed; final draft-only run passed all 13 cases after capability naming clarification. TypeScript noEmit passed. Initial concurrent build failed with a native memory-allocation error. Retried build alone with transient RAYON_NUM_THREADS=2 after typecheck completed; production build passed and prior environment was restored. Build-generated unrelated route files restored.

RPC responses are mocked here; local SQL persistence evidence is separate. These are pending source adapters, not accepted managed RPCs, client publication, browser persistence or notification delivery. No screenshots for unavailable UI. Work is committed locally only while the previously requested public GitHub push approval remains unresolved.
