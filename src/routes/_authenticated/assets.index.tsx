import { createFileRoute } from "@tanstack/react-router";
import { PermissionGate } from "@/components/PermissionGate";
import { AssetRegisterWorkspace } from "@/components/assets/AssetRegisterWorkspace";

export const Route = createFileRoute("/_authenticated/assets/")({
  head: () => ({
    meta: [
      { title: "Assets & Machinery — SSM One" },
      { name: "description", content: "Production machinery, service & maintenance equipment, and calibrated instruments." },
      { property: "og:title", content: "Assets & Machinery — SSM One" },
    ],
  }),
  component: () => (
    <PermissionGate permission="assets.view" fallback={<div className="p-6 text-sm text-muted-foreground">You do not have access to asset and machinery records.</div>}>
      <AssetRegisterWorkspace />
    </PermissionGate>
  ),
});
