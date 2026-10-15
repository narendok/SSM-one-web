# Managed preview dependency alignment — 16 October 2026

Lovable diagnosis did not provide an actual remote failing command/error; it identified package.json/Bun 2.26.5 versus npm lock 2.25.3 in its managed source. Treat that as an observed install inconsistency, not proven root cause or proof that the platform requires 2.26.5.

Reconciled 1ac3b89/9079fa4/5b1082d normally. Retained the managed 2.26.5 dependency/Bun entries for a bounded compatibility trial, restored previewAuthStorage to exact prior bc1c4f7 content, and aligned both npm root requirement and resolved package entry to 2.26.5 using actual official tarball metadata. Downloaded the official Bun-locked tarball, verified SHA512 integrity against the tracked lock, and installed those verified package bytes locally. No new credentials, auth/session changes, backend or Publish.

Production build with actual installed config 2.26.5 passed. Eleven focused task/handover tests passed. TypeScript checked separately in tool output. Package.json, Bun and npm lock now agree. Previous successful builds using 2.25.3 do not establish managed acceptance; the next managed preview status/readback must be inspected before claiming recovery. No further credit-consuming generation requested. Historical auth edits remain in Git ancestry but current source restores prior behavior.
