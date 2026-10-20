import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/login")({
  validateSearch: (search: Record<string, unknown>) => ({
    next: typeof search.next === "string" ? search.next : undefined,
  }),
  beforeLoad: ({ search }) => {
    throw redirect({
      to: "/auth",
      search: { next: search.next || undefined },
    });
  },
  component: () => null,
});
