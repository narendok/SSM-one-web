import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useState, useRef } from "react";
import { CircuitBoard, Loader2, Sparkles, Building2, UserCheck, ShieldCheck } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ThemeToggle } from "@/components/theme/ThemeToggle";
import { DepartmentTestAccounts } from "@/components/auth/DepartmentTestAccounts";
import {
  DEPARTMENT_TEST_ACCOUNTS,
  loginAsTestAccount,
  verifyTestCredentials,
  type DepartmentTestAccount,
} from "@/lib/demo-auth";

export const Route = createFileRoute("/auth")({
  validateSearch: (search: Record<string, unknown>) => ({
    next: typeof search.next === "string" ? search.next : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Sign in — SSMone" },
      { name: "description", content: "Sign in to the SSMone operations workspace." },
      { property: "og:title", content: "Sign in — SSMone" },
      { property: "og:description", content: "Sign in to the SSMone operations workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();
  const { next } = Route.useSearch();
  const destination = next?.startsWith("/") && !next.startsWith("//") ? next : "/";
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const formRef = useRef<HTMLFormElement>(null);

  const handleFillCredentials = (account: DepartmentTestAccount) => {
    setEmail(account.email);
    setPassword(account.password);
    toast.info(`Filled credentials for ${account.name}`, {
      description: `${account.email} / ${account.password}`,
    });
    formRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
  };

  const handleInstantLogin = (account: DepartmentTestAccount) => {
    setLoading(true);
    try {
      loginAsTestAccount(account);
      toast.success(`Welcome, ${account.name}`, {
        description: `Logged in as ${account.roleLabel} (${account.department})`,
      });
      const target = destination !== "/" ? destination : account.defaultPath;
      navigate({ to: target });
    } catch (e: any) {
      toast.error("Failed to start session: " + (e?.message ?? "Unknown error"));
    } finally {
      setLoading(false);
    }
  };

  async function handleSignIn(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);

    // 1. Check if matches pre-created department test account
    const testMatch = verifyTestCredentials(email, password);
    if (testMatch) {
      loginAsTestAccount(testMatch);
      setLoading(false);
      toast.success(`Welcome, ${testMatch.name}`, {
        description: `Signed in to ${testMatch.department}`,
      });
      const target = destination !== "/" ? destination : testMatch.defaultPath;
      return navigate({ to: target });
    }

    // 2. Otherwise fall back to remote Supabase auth
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setLoading(false);
    if (error) return toast.error(error.message);
    toast.success("Welcome back");
    navigate({ to: destination });
  }

  async function handleGoogle() {
    setLoading(true);
    const result = await lovable.auth.signInWithOAuth("google", {
      redirect_uri: `${window.location.origin}${destination}`,
    });
    if (result.error) {
      setLoading(false);
      toast.error(result.error.message);
      return;
    }
    if (result.redirected) return;
    navigate({ to: destination });
  }

  return (
    <div className="relative min-h-screen grid lg:grid-cols-12 bg-background">
      <div className="absolute top-4 right-4 z-20">
        <ThemeToggle />
      </div>

      {/* Left Hero Sidebar */}
      <div className="hidden lg:flex lg:col-span-4 xl:col-span-4 flex-col justify-between p-8 xl:p-12 bg-primary text-primary-foreground sticky top-0 h-screen overflow-y-auto">
        <div className="flex items-center gap-2 text-xl font-semibold">
          <CircuitBoard className="h-6 w-6" /> SSMone
        </div>
        <div className="space-y-4 my-auto py-12">
          <div className="inline-flex items-center gap-1.5 rounded-full bg-primary-foreground/10 px-3 py-1 text-xs font-medium text-primary-foreground">
            <Sparkles className="size-3.5" /> Multi-Department Portal
          </div>
          <h1 className="text-3xl xl:text-4xl font-bold leading-tight">
            One workspace for every operating team.
          </h1>
          <p className="text-primary-foreground/80 text-sm leading-relaxed">
            Coordinating engineering, BOM sourcing, PCB validation, procurement, stores, quality (APQP/PPAP), shop floor production, sales CRM, finance milestones, and HR administration.
          </p>
          <div className="pt-4 space-y-2 border-t border-primary-foreground/20 text-xs text-primary-foreground/90">
            <div className="flex items-center gap-2">
              <ShieldCheck className="size-4 shrink-0" />
              <span>Full role-based access control with 11 department test accounts</span>
            </div>
            <div className="flex items-center gap-2">
              <UserCheck className="size-4 shrink-0" />
              <span>One-click instant login enabled for complete portal testing</span>
            </div>
          </div>
        </div>
        <p className="text-xs text-primary-foreground/60">XYZ Pvt Ltd · SSMone Enterprise Operations</p>
      </div>

      {/* Right Content Area */}
      <div className="lg:col-span-8 xl:col-span-8 flex flex-col items-center justify-start p-4 sm:p-8 lg:p-10 max-h-screen overflow-y-auto">
        <div className="w-full max-w-3xl space-y-8 my-auto py-6">
          <div className="lg:hidden flex items-center justify-between">
            <div className="flex items-center gap-2 text-xl font-semibold">
              <CircuitBoard className="h-6 w-6 text-primary" /> SSMone
            </div>
          </div>

          {/* Sign In Card */}
          <div className="rounded-xl border bg-card p-6 shadow-sm space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold tracking-tight">Sign in to SSMone</h2>
                <p className="text-xs text-muted-foreground mt-0.5">
                  Enter your credentials or choose a department test account below.
                </p>
              </div>

              {/* Quick Preset Selector Dropdown */}
              <div className="flex items-center gap-2">
                <span className="text-xs text-muted-foreground hidden sm:inline">Quick Fill:</span>
                <select
                  aria-label="Quick fill department credentials"
                  className="h-8 rounded-md border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-ring"
                  onChange={(e) => {
                    const acc = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === e.target.value);
                    if (acc) handleFillCredentials(acc);
                  }}
                  defaultValue=""
                >
                  <option value="" disabled>Select department to autofill...</option>
                  {DEPARTMENT_TEST_ACCOUNTS.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.department} ({acc.roleLabel})
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <form ref={formRef} onSubmit={handleSignIn} className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label htmlFor="auth-email">Email Address</Label>
                  <Input
                    id="auth-email"
                    name="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="e.g. admin@ssmone.internal"
                    required
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="auth-password">Password</Label>
                  <Input
                    id="auth-password"
                    name="password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter password"
                    required
                  />
                </div>
              </div>

              <div className="flex flex-col sm:flex-row gap-3 pt-2">
                <Button className="flex-1" disabled={loading}>
                  {loading && <Loader2 className="h-4 w-4 animate-spin mr-2" />} Sign in
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={handleGoogle}
                  disabled={loading}
                  className="sm:w-48"
                >
                  Continue with Google
                </Button>
              </div>
            </form>
          </div>

          {/* Department Test Logins Explorer */}
          <DepartmentTestAccounts
            onFillCredentials={handleFillCredentials}
            onInstantLogin={handleInstantLogin}
          />

          {/* Public careers / notice */}
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 rounded-lg border bg-muted/20 p-4 text-xs text-muted-foreground">
            <span>Public job application pages and candidate tracking are now live.</span>
            <Button asChild variant="link" className="h-auto p-0 text-xs">
              <Link to="/careers">Open Careers Portal →</Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
