import { CheckCircle2, FileLock2, FolderOpen, UserRound } from "lucide-react";
import { useNavigate } from "@tanstack/react-router";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { projectStructuredDocumentAvailability } from "@/lib/structured-lifecycle-document-access";

type ProjectStructuredDocumentsProps = {
  projectId: string;
  projectDepartmentId: string | null;
  onOpenFolder: () => void;
};

export function ProjectStructuredDocuments({ onOpenFolder }: ProjectStructuredDocumentsProps) {
  const availability = projectStructuredDocumentAvailability();
  return (
    <section aria-label="Project documents" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-medium text-primary">Department workspace</p>
          <h2 className="mt-1 text-xl font-semibold">Project documents</h2>
          <p className="mt-1 text-sm text-muted-foreground">Your project folder and document access in one place.</p>
        </div>
        <Button variant="outline" onClick={onOpenFolder}>
          <FolderOpen /> Open folder
        </Button>
      </div>

      <Card className="overflow-hidden">
        <div className="border-b bg-muted/40 px-5 py-4">
          <div className="flex flex-wrap items-center gap-2">
            <FileLock2 className="size-4 text-primary" />
            <h3 className="font-semibold">Document access</h3>
            <Badge variant="secondary" className="ml-auto">Assignment needed</Badge>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            A current assignment is needed before private project documents can be shown here.
          </p>
        </div>
        <div className="grid divide-y sm:grid-cols-2 sm:divide-x sm:divide-y-0">
          <div className="flex gap-3 p-5">
            <UserRound className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
            <div>
              <p className="text-sm font-medium">Assigned to you</p>
              <p className="mt-1 text-sm text-muted-foreground">No current document assignment is available.</p>
            </div>
          </div>
          <div className="flex gap-3 p-5">
            <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
            <div>
              <p className="text-sm font-medium">What you can do now</p>
              <p className="mt-1 text-sm text-muted-foreground">Open the project folder to work with the files you already have access to.</p>
            </div>
          </div>
        </div>
      </Card>

      {!availability.available && <p className="text-xs text-muted-foreground">Document details will appear after your current assignment is confirmed.</p>}
    </section>
  );
}