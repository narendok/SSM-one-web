import { FileLock2 } from "lucide-react";
import { Card } from "@/components/ui/card";
import { documentAccessBoundaryMessage, projectStructuredDocumentAvailability } from "@/lib/structured-lifecycle-document-access";

type ProjectStructuredDocumentsProps = { projectId: string; projectDepartmentId: string | null };

export function ProjectStructuredDocuments({ projectId, projectDepartmentId }: ProjectStructuredDocumentsProps) {
  const availability = projectStructuredDocumentAvailability();
  return (
    <section aria-label="Project documents" className="space-y-4">
      <div>
        <h2 className="text-base font-semibold">Project documents</h2>
        <p className="mt-1 text-sm text-muted-foreground">Private document access requires a backend-verified responsible-person assignment.</p>
      </div>
      <Card className="border-amber-500/40 bg-amber-500/5 p-4">
        <div className="flex gap-3">
          <FileLock2 className="mt-0.5 size-4 shrink-0 text-amber-600" />
          <p className="text-sm">{availability.reason} {documentAccessBoundaryMessage()}</p>
        </div>
      </Card>
    </section>
  );
}