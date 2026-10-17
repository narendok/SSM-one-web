/** No project-start writer is accepted yet. UI state never grants authority. */
export const salesProjectStartAvailability = {
  available: false,
  reason: "Project handover is unavailable until the protected project-start contract verifies client approval, the locked baseline and an explicit Research/POC or justified Pilot decision.",
} as const;
