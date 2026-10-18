import { createFileRoute } from "@tanstack/react-router";
import { ApplicationStatusLookup } from "@/components/hr/ApplicationStatusLookup";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export const Route = createFileRoute("/application-status")({
  head: () => ({
    meta: [
      { title: "Application status — XYZ Pvt Ltd" },
      { name: "description", content: "Check the progress of your XYZ Pvt Ltd job application." },
      { property: "og:title", content: "Application status — XYZ Pvt Ltd" },
      { property: "og:description", content: "Check the progress of your XYZ Pvt Ltd job application." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ApplicationStatusPage,
});

function ApplicationStatusPage() {
  return (
    <main className="grid min-h-screen place-items-center bg-background px-6 py-16">
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle>Application status</CardTitle>
          <CardDescription>Use the reference received after you submitted your application.</CardDescription>
        </CardHeader>
        <CardContent><ApplicationStatusLookup /></CardContent>
      </Card>
    </main>
  );
}