# SSM One Web documentation

This is the single active documentation folder for the web portal and its backend.

- [Web portal master plan](planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md): web/backend delivery and integration handoff only.
- [Optimized document catalogue](planning/SSM_ONE_DOCUMENT_CATALOGUE.md): reference inventory, not another delivery plan.
- [Evidence](evidence/README.md): web verification reports and implementation checkpoints; dated claims retain their original scope.
- Android build plan (`SSMApplication3/docs/planning/SSM_ONE_ANDROID_BUILD_PLAN.md`): separate mobile implementation/build queue in the Android project.

Technical interface contracts and pending SQL remain in their established source locations; do not treat proposals as installed operations. Original source/reference data remains under planning/sources. Dated backup snapshots retain their original docs layout and are immutable.

Active local documentation lives directly in SSMOneWeb/docs, separate from application code in source/. GitHub/Lovable version these files under repository docs/. The local source checkout excludes docs/ to avoid another physical copy; documentation sync uses an isolated Git index and preserves current remote application code. Android planning remains in its own repository.
