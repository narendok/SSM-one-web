import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { FolderKanban, Layers, Plus, Settings } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { fetchProjects } from "@/lib/projects";
import { ProjectDialog } from "@/components/projects/ProjectDialog";
import { ProjectAnalysisSummary } from "@/components/projects/ProjectAnalysisSummary";
import { useAuth } from "@/hooks/useAuth";

export const Route = createFileRoute("/_authenticated/projects/")({
  validateSearch: (search: Record<string, unknown>) => ({
    tab: typeof search.tab === "string" ? search.tab : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Projects — PartsBench" },
      { name: "description", content: "Every hardware project with its files, firmware builds and CAD models." },
      { property: "og:title", content: "Projects — PartsBench" },
      {
        property: "og:description",
        content: "Every hardware project with its files, firmware builds and CAD models.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ProjectsPage,
});

function ProjectsPage() {
  const { role } = useAuth();
  const search = Route.useSearch();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const { data: projects = [], isLoading } = useQuery({ queryKey: ["projects"], queryFn: fetchProjects });

  const activeTab = search.tab === "analysis" ? "analysis" : "all";
  const [selectedProjectId, setSelectedProjectId] = useState<string | null>(null);
  const selectedProject = projects.find((p) => p.id === selectedProjectId) ?? projects[0] ?? null;

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Projects</h1>
          <p className="text-sm text-muted-foreground">
            Complete project lifecycle delivery, cross-department stage gates, and engineering analysis.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {role === "admin" && (
            <Button onClick={() => setCreating(true)} size="sm">
              <Plus className="h-4 w-4 mr-1" /> Add project
            </Button>
          )}
          <Button asChild variant="outline" size="sm">
            <Link to="/settings/projects">
              <Settings className="h-4 w-4 mr-1" /> Manage
            </Link>
          </Button>
        </div>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b pb-3">
        <Tabs
          value={activeTab}
          onValueChange={(val) => {
            void navigate({
              search: { tab: val === "analysis" ? "analysis" : undefined },
            });
          }}
        >
          <TabsList>
            <TabsTrigger value="all" className="flex items-center gap-2">
              <FolderKanban className="size-4" />
              All Projects ({projects.length})
            </TabsTrigger>
            <TabsTrigger value="analysis" className="flex items-center gap-2">
              <Layers className="size-4" />
              Project Analysis (Page 1)
            </TabsTrigger>
          </TabsList>
        </Tabs>

        {activeTab === "analysis" && projects.length > 0 && selectedProject && (
          <div className="flex items-center gap-2">
            <span className="text-xs font-medium text-muted-foreground">Active Project:</span>
            <Select
              value={selectedProject.id}
              onValueChange={(val) => setSelectedProjectId(val)}
            >
              <SelectTrigger className="h-8 w-72 text-xs">
                <SelectValue placeholder="Select project" />
              </SelectTrigger>
              <SelectContent>
                {projects.map((p) => (
                  <SelectItem key={p.id} value={p.id} className="text-xs">
                    <span className="font-mono mr-1.5 text-muted-foreground">{p.code}</span>
                    {p.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}
      </div>

      {activeTab === "analysis" ? (
        isLoading ? (
          <Card className="p-8 text-center text-muted-foreground">Loading analysis…</Card>
        ) : !selectedProject ? (
          <Card className="p-8 text-center text-muted-foreground">No projects found to analyze.</Card>
        ) : (
          <ProjectAnalysisSummary project={selectedProject} />
        )
      ) : (
        isLoading ? (
          <Card className="p-8 text-center text-muted-foreground">Loading…</Card>
        ) : projects.length === 0 ? (
          <Card className="p-8 text-center text-muted-foreground">
            No projects yet — add one under Manage and its folder tree is created automatically.
          </Card>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {projects.map((p) => (
              <Link key={p.id} to="/projects/$projectId" params={{ projectId: p.id }} search={{ tab: undefined }}>
                <Card className="p-4 h-full hover:border-primary/50 transition-colors">
                  <div className="flex items-center gap-2">
                    <span className="h-8 w-2 rounded-sm" style={{ background: p.color }} />
                    <FolderKanban className="h-4 w-4 text-muted-foreground" />
                    <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{p.code}</span>
                    {p.status === "archived" && <Badge variant="secondary">archived</Badge>}
                  </div>
                  <p className="mt-2 font-medium">{p.name}</p>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    <Badge variant="outline">{p.project_stage.replaceAll("_", " ")}</Badge>
                    <Badge variant="secondary">{p.health_status}</Badge>
                    {p.revision && <Badge variant="outline">rev {p.revision}</Badge>}
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )
      )}
      <ProjectDialog open={creating} onOpenChange={setCreating} onSaved={() => void queryClient.invalidateQueries({ queryKey: ["projects"] })} />
    </div>
  );
}
