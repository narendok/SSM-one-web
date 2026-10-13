import { createFileRoute } from "@tanstack/react-router";
import { DriveBrowser } from "@/components/drive/DriveBrowser";

export const Route = createFileRoute("/_authenticated/drive")({
  validateSearch: (search: Record<string, unknown>) => {
    const result: { node?: string; department?: string; salesEntry?: boolean } = {};
    if (typeof search.node === "string") result.node = search.node;
    if (typeof search.department === "string") result.department = search.department;
    if (search.salesEntry === true) result.salesEntry = true;
    return result;
  },
  head: () => ({
    meta: [
      { title: "Drive — PartsBench document vault" },
      {
        name: "description",
        content: "Project files, gerbers, firmware, CAD models and the PPAP audit package in one place.",
      },
      { property: "og:title", content: "Drive — PartsBench document vault" },
      {
        property: "og:description",
        content: "Project files, gerbers, firmware, CAD models and the PPAP audit package in one place.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: DrivePage,
});

function DrivePage() {
  const { node, department, salesEntry } = Route.useSearch();
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Drive</h1>
        <p className="text-sm text-muted-foreground">
          Browse the existing controlled project and department folder hierarchy available to your account.
        </p>
      </div>
      <DriveBrowser initialNodeId={node} departmentId={department} restrictedFolderId={salesEntry && node ? node : null} />
    </div>
  );
}
