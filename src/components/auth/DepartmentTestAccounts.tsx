import { useState } from "react";
import {
  Building2,
  Check,
  Copy,
  ExternalLink,
  KeyRound,
  LogIn,
  Mail,
  Shield,
  Sparkles,
  UserCheck,
} from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DEPARTMENT_TEST_ACCOUNTS,
  loginAsTestAccount,
  type DepartmentTestAccount,
} from "@/lib/demo-auth";

interface DepartmentTestAccountsProps {
  onFillCredentials: (account: DepartmentTestAccount) => void;
  onInstantLogin: (account: DepartmentTestAccount) => void;
}

export function DepartmentTestAccounts({
  onFillCredentials,
  onInstantLogin,
}: DepartmentTestAccountsProps) {
  const [selectedCategory, setSelectedCategory] = useState<string>("All");
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const categories = [
    "All",
    "Management",
    "Engineering",
    "Operations & Supply Chain",
    "Commercial & Finance",
    "HR & People",
  ] as const;

  const filteredAccounts =
    selectedCategory === "All"
      ? DEPARTMENT_TEST_ACCOUNTS
      : DEPARTMENT_TEST_ACCOUNTS.filter((acc) => acc.category === selectedCategory);

  const copyToClipboard = async (text: string, label: string, key: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedKey(key);
      toast.success(`Copied ${label} to clipboard`);
      setTimeout(() => setCopiedKey(null), 2000);
    } catch {
      toast.error("Failed to copy to clipboard");
    }
  };

  return (
    <div className="space-y-4 rounded-xl border bg-card p-4 sm:p-6 shadow-sm">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Sparkles className="size-5 text-primary" />
            <h2 className="text-lg font-semibold tracking-tight">Department Test Logins</h2>
            <Badge variant="secondary" className="text-xs font-medium">
              {DEPARTMENT_TEST_ACCOUNTS.length} Profiles Ready
            </Badge>
          </div>
          <p className="text-xs text-muted-foreground mt-0.5">
            Test the entire portal across all departments with pre-created roles and one-click access.
          </p>
        </div>
      </div>

      {/* Category Filter Pills */}
      <div className="flex flex-wrap gap-1.5 border-b pb-3">
        {categories.map((cat) => (
          <button
            key={cat}
            type="button"
            onClick={() => setSelectedCategory(cat)}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-all ${
              selectedCategory === cat
                ? "bg-primary text-primary-foreground shadow-sm"
                : "bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground"
            }`}
          >
            {cat}
            {cat === "All" ? ` (${DEPARTMENT_TEST_ACCOUNTS.length})` : ""}
          </button>
        ))}
      </div>

      {/* Accounts Grid */}
      <div className="grid gap-3 sm:grid-cols-2">
        {filteredAccounts.map((account) => {
          const emailKey = `${account.id}-email`;
          const passKey = `${account.id}-pass`;

          return (
            <div
              key={account.id}
              className="flex flex-col justify-between rounded-lg border bg-background/60 p-3.5 transition-all hover:border-primary/50 hover:bg-muted/20"
            >
              <div className="space-y-2">
                <div className="flex items-start justify-between gap-2">
                  <Badge variant="outline" className={`text-[11px] font-medium ${account.badgeColor}`}>
                    {account.department}
                  </Badge>
                  <span className="text-[11px] font-mono text-muted-foreground">
                    role: {account.role}
                  </span>
                </div>

                <div>
                  <h3 className="text-sm font-semibold text-foreground flex items-center gap-1.5">
                    <UserCheck className="size-3.5 text-primary" />
                    {account.name}
                  </h3>
                  <p className="text-xs text-muted-foreground line-clamp-2 mt-0.5">
                    {account.description}
                  </p>
                </div>

                {/* Credentials Box */}
                <div className="rounded-md border bg-muted/30 p-2 space-y-1.5 text-xs font-mono">
                  <div className="flex items-center justify-between text-muted-foreground">
                    <span className="flex items-center gap-1 text-[11px]">
                      <Mail className="size-3" />
                      <span className="text-foreground select-all">{account.email}</span>
                    </span>
                    <button
                      type="button"
                      onClick={() => copyToClipboard(account.email, "Email", emailKey)}
                      title="Copy email"
                      className="p-0.5 text-muted-foreground hover:text-foreground"
                    >
                      {copiedKey === emailKey ? (
                        <Check className="size-3 text-emerald-500" />
                      ) : (
                        <Copy className="size-3" />
                      )}
                    </button>
                  </div>
                  <div className="flex items-center justify-between text-muted-foreground border-t pt-1 border-dashed">
                    <span className="flex items-center gap-1 text-[11px]">
                      <KeyRound className="size-3" />
                      <span className="text-foreground font-semibold select-all">
                        {account.password}
                      </span>
                    </span>
                    <button
                      type="button"
                      onClick={() => copyToClipboard(account.password, "Password", passKey)}
                      title="Copy password"
                      className="p-0.5 text-muted-foreground hover:text-foreground"
                    >
                      {copiedKey === passKey ? (
                        <Check className="size-3 text-emerald-500" />
                      ) : (
                        <Copy className="size-3" />
                      )}
                    </button>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="mt-3 flex items-center gap-2 pt-2 border-t">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-8 flex-1 text-xs gap-1.5"
                  onClick={() => onFillCredentials(account)}
                >
                  <Copy className="size-3" />
                  Fill Form
                </Button>
                <Button
                  type="button"
                  size="sm"
                  className="h-8 flex-1 text-xs gap-1.5"
                  onClick={() => onInstantLogin(account)}
                >
                  <LogIn className="size-3" />
                  One-Click Sign In
                </Button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
