#!/usr/bin/env python3
from pathlib import Path
import hashlib
import sys

root = Path(__file__).resolve().parents[3]
contract = root / "supabase/pending/20261013_structured_lifecycle_docx_project_responsibility_update_contract.sql"
bundle = root / "docs/evidence/20261013_structured_lifecycle_docx_project_responsibility_update_source_review_bundle.txt"
text = contract.read_text()
expected_hash = "REPLACE_AFTER_HASH"
actual_hash = hashlib.sha256(contract.read_bytes()).hexdigest()
required = (
    "responsibility_revision integer NOT NULL DEFAULT 1",
    "JOIN public.project_team_members team_membership",
    "Assigned responsible and reviewer employees must be active department project-team members",
    "structured-docx-reassignment-request",
    "FOR KEY SHARE",
    "REVOKE ALL ON FUNCTION public.reassign_project_structured_docx_responsibility",
)
if actual_hash != expected_hash or not all(fragment in text for fragment in required):
    sys.exit("Responsibility update contract no longer matches the exact reviewed source")
if bundle.exists() and actual_hash not in bundle.read_text():
    sys.exit("Responsibility update review bundle does not contain the exact contract hash")
print("STRUCTURED_LIFECYCLE_DOCX_PROJECT_RESPONSIBILITY_UPDATE_STATIC_CHECK_PASS")