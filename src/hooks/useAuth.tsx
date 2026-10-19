import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";
import {
  getStoredTestSession,
  clearStoredTestSession,
  DEMO_AUTH_CHANGE_EVENT,
  type StoredDemoSession,
} from "@/lib/demo-auth";

type Role = "admin" | "member" | "purchase" | "storekeeper" | "project_manager" | "lead_engineer";

interface AuthCtx {
  user: User | null;
  session: Session | null;
  role: Role | null;
  displayName: string | null;
  employeeStatus: string | null;
  permissions: string[];
  loading: boolean;
  signOut: () => Promise<void>;
}

const Ctx = createContext<AuthCtx>({
  user: null,
  session: null,
  role: null,
  displayName: null,
  employeeStatus: null,
  permissions: [],
  loading: true,
  signOut: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<Role | null>(null);
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [employeeStatus, setEmployeeStatus] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  const loadIdentity = useCallback(async (user: User) => {
    const [roleResult, profileResult, employeeResult] = await Promise.all([
      supabase.from("user_roles").select("role").eq("user_id", user.id).maybeSingle(),
      supabase.from("profiles").select("display_name").eq("id", user.id).maybeSingle(),
      supabase.from("employees").select("id, display_name, employment_status").eq("user_id", user.id).maybeSingle(),
    ]);

    setRole((roleResult.data?.role as Role | undefined) ?? "member");
    setDisplayName(employeeResult.data?.display_name ?? profileResult.data?.display_name ?? user.user_metadata?.display_name ?? null);
    setEmployeeStatus(employeeResult.data?.employment_status ?? null);

    if (!employeeResult.data?.id) {
      setPermissions([]);
      return;
    }

    const { data } = await supabase
      .from("employee_access_roles")
      .select("access_roles(access_role_permissions(permissions(key)))")
      .eq("employee_id", employeeResult.data.id);
    const keys = (data ?? []).flatMap((assignment) => {
      const accessRole = assignment.access_roles as unknown as { access_role_permissions?: { permissions?: { key?: string | null } | null }[] } | null;
      return (accessRole?.access_role_permissions ?? []).flatMap((item) => item.permissions?.key ? [item.permissions.key] : []);
    });
    setPermissions([...new Set(keys)]);
  }, []);

  const applyDemoSession = useCallback((demo: StoredDemoSession | null) => {
    if (demo) {
      setSession(demo.session);
      setRole(demo.role);
      setDisplayName(demo.displayName);
      setEmployeeStatus("active");
      setPermissions(demo.permissions);
      setLoading(false);
      return true;
    }
    return false;
  }, []);

  useEffect(() => {
    const initialDemo = getStoredTestSession();
    if (initialDemo) {
      applyDemoSession(initialDemo);
    }

    const handleDemoChange = (e: Event) => {
      const customEvent = e as CustomEvent<StoredDemoSession | null>;
      if (customEvent.detail) {
        applyDemoSession(customEvent.detail);
      } else {
        supabase.auth.getSession().then(async ({ data }) => {
          setSession(data.session);
          if (data.session) {
            await loadIdentity(data.session.user);
          } else {
            setRole(null);
            setDisplayName(null);
            setEmployeeStatus(null);
            setPermissions([]);
          }
        });
      }
    };

    if (typeof window !== "undefined") {
      window.addEventListener(DEMO_AUTH_CHANGE_EVENT, handleDemoChange);
    }

    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      const currentDemo = getStoredTestSession();
      if (currentDemo) {
        applyDemoSession(currentDemo);
        return;
      }
      setSession(s);
      if (s) {
        void loadIdentity(s.user).finally(() => setLoading(false));
      } else {
        setRole(null);
        setDisplayName(null);
        setEmployeeStatus(null);
        setPermissions([]);
        setLoading(false);
      }
    });

    supabase.auth.getSession().then(async ({ data }) => {
      const currentDemo = getStoredTestSession();
      if (currentDemo) {
        applyDemoSession(currentDemo);
        return;
      }
      setSession(data.session);
      if (data.session) await loadIdentity(data.session.user);
    }).catch(() => {
      const currentDemo = getStoredTestSession();
      if (currentDemo) {
        applyDemoSession(currentDemo);
        return;
      }
      setRole(null);
      setDisplayName(null);
      setEmployeeStatus(null);
      setPermissions([]);
    }).finally(() => {
      if (!getStoredTestSession()) setLoading(false);
    });

    return () => {
      if (typeof window !== "undefined") {
        window.removeEventListener(DEMO_AUTH_CHANGE_EVENT, handleDemoChange);
      }
      sub.subscription.unsubscribe();
    };
  }, [loadIdentity, applyDemoSession]);

  const signOut = async () => {
    clearStoredTestSession();
    await supabase.auth.signOut();
  };

  return (
    <Ctx.Provider value={{ user: session?.user ?? null, session, role, displayName, employeeStatus, permissions, loading, signOut }}>
      {children}
    </Ctx.Provider>
  );
}

export const useAuth = () => useContext(Ctx);
