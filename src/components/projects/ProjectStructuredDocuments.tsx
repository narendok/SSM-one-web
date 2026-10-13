import { FileLock2, RefreshCw } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import { documentAccessBoundaryMessage } from "@/lib/structured-lifecycle-document-access";
import { structuredLifecyclePlanForDepartment } from "@/lib/structured-lifecycle-document-plan";

type ProjectStructuredDocumentsProps = { projectId: string; projectDepartmentId: string | null };
type Department = { id: string; code: string | null; name: string };

export function ProjectStructuredDocuments({ projectId, projectDepartmentId }: ProjectStructuredDocumentsProps) {
  const department = useQuery({
    queryKey: ["project-structured-documents-department", projectId, projectDepartmentId],
    enabled: Boolean(projectDepartmentId),
    retry: false,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("departments")
        .select("id,code,name")
        .eq("id", projectDepartmentId ?? "")
        .maybeSingle();
      if (error) throw error;
      return data as Department | null;
    },
  });

  if (!projectDepartmentId) {
    return <UnavailableProjectDocuments reason="This project has no recorded department scope, so no document category can be selected." />;
  }
  if (department.isLoading) return <Card className="p-5 text-sm text-muted-foreground">Loading the recorded project department…</Card>;
  if (department.isError) return <UnavailableProjectDocuments reason="The recorded project department could not be read." onRetry={() => void department.refetch()} />;
  if (!department.data?.code) return <UnavailableProjectDocuments reason="The recorded project department has no active category mapping." />;

  const categories = structuredLifecyclePlanForDepartment(department.data.code);
  return (
    <section aria-label="Project documents" className="space-y-4">
      <div>
        <h2 className="text-base font-semibold">Project documents</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Categories mapped to {department.data.name}. Visibility is not document authorization.
        </p>
      </div>
      <Card className="border-amber-500/40 bg-amber-500/5 p-4">
        <div className="flex gap-3">
          <FileLock2 className="mt-0.5 size-4 shrink-0 text-amber-600" />
          <p className="text-sm">{documentAccessBoundaryMessage()}</p>
        </div>
      </Card>
      {categories.length ? (
        <div className="grid gap-3 md:grid-cols-2">
          {categories.map((template) => (
            <Card key={template.kind} className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-medium">{template.label}</p>
                  <p className="mt-1 text-sm text-muted-foreground">{template.description}</p>
                </div>
                <Badge variant="secondary">{template.materializationState === "DEPLOYMENT_PENDING" ? "Save pending" : "Local export only"}</Badge>
              </div>
              <p className="mt-3 text-xs text-muted-foreground">
                {template.requiresExplicitResponsibility ? "Interdisciplinary responsibility must be assigned explicitly. " : "A current responsible-person assignment is required. "}
                {template.materializationState === "DEPLOYMENT_PENDING"
                  ? "The reviewed Drive save path is still disabled."
                  : "Editable DOCX export stays local; Drive save, history, and download are unavailable."}
              </p>
            </Card>
          ))}
        </div>
      ) : <Card className="p-5 text-sm text-muted-foreground">No document categories are mapped to this project department.</Card>}
    </section>
  );
}

function UnavailableProjectDocuments({ reason, onRetry }: { reason: string; onRetry?: () => void }) {
  return <Card role="alert" className="flex flex-wrap items-center justify-between gap-3 border-destructive/40 p-5 text-sm text-destructive"><span>{reason} {documentAccessBoundaryMessage()}</span>{onRetry && <Button variant="outline" size="sm" onClick={onRetry}><RefreshCw className="size-3.5" /> Retry</Button>}</Card>;
}