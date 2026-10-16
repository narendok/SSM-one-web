# Shared feasibility field meaning — 16 October 2026

Corrected the actual SharedFeasibilityAnalysis component: existing review assumptions and risks render separately under their actual field meanings. Previously, risks were used as Internal remarks when assumptions existed, or folded into Conditions when they did not. That implied an independently saved remark record that does not exist. The separate remark area now explicitly says independent internal remarks are unavailable. Existing source findings remain internal and do not become client highlights. Example editors remain explicitly memory-only.

Nine focused component DOM tests passed, including separate assumptions/risks, one occurrence of private risk text and client-preview exclusion. TypeScript noEmit and production Vite build passed. No backend mutations, new persistence contract, browser/live acceptance or screenshot claimed. Independent saved notes/publication still require the planned protected contract.
