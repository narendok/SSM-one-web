# Full web Git workspace — 14 October 2026

SSMOneWeb is now the Git repository root, connected to https://github.com/narendok/ssmone1.git on main. Application files, AGENTS.md, README.md and docs/ live directly here and are tracked by the same Git repository. Sparse checkout is disabled. There is no nested source directory and no manual documentation mirror.

Historical backups are preserved at sibling SSMOneWebBackups/backups. The previous workspace docs, administrative tools and root metadata are retained in its timestamped workspace-layout-before-root-sync capture. They are historical recovery copies, not active working documentation. No backup contents or application source were deleted.

Validation: git rev-parse --show-toplevel returned the SSMOneWeb root; the full checkout was clean before editing these layout notes; docs/ is tracked normally; source/ does not exist. Application and backend files retain the prior synced commit's contents. Normal Git add/commit/pull/push now handles code and docs together. This change does not install pending backend operations or publish the portal. Android remains in SSMApplication3.
