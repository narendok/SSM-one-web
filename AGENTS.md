# Project rules

- Keep candidate-part submission as a pending, database-owned transaction with all source and authorization checks before replay; this prevents inventory and BOM paths from becoming implicit approval paths.
- Keep deviation-note submission separate from legacy project changes and candidate approvals; approval authority, customer approval, closure, and caller reads require independently accepted protected contracts.