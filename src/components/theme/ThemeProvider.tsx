import React, { createContext, useContext, useEffect, useState, useMemo } from "react";

export type Theme = "light" | "dark" | "slate" | "system";
export type ResolvedTheme = "light" | "dark" | "slate";

export interface ThemeContextType {
  theme: Theme;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

const STORAGE_KEY = "ssm-theme";

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

function getSystemTheme(): "light" | "dark" {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = STORAGE_KEY,
}: {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
}) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === "undefined") return defaultTheme;
    try {
      const stored = localStorage.getItem(storageKey) || localStorage.getItem("theme");
      if (stored === "light" || stored === "dark" || stored === "slate" || stored === "system") {
        return stored;
      }
    } catch {
      // ignore localStorage errors (e.g. private browsing)
    }
    return defaultTheme;
  });

  const [systemTheme, setSystemTheme] = useState<"light" | "dark">(getSystemTheme);

  // Sync with system changes when theme === "system"
  useEffect(() => {
    if (typeof window === "undefined") return;
    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = (e: MediaQueryListEvent) => {
      setSystemTheme(e.matches ? "dark" : "light");
    };

    mediaQuery.addEventListener("change", handler);
    return () => mediaQuery.removeEventListener("change", handler);
  }, []);

  // Sync across tabs
  useEffect(() => {
    if (typeof window === "undefined") return;
    const onStorage = (e: StorageEvent) => {
      if ((e.key === storageKey || e.key === "theme") && e.newValue) {
        if (e.newValue === "light" || e.newValue === "dark" || e.newValue === "slate" || e.newValue === "system") {
          setThemeState(e.newValue);
        }
      }
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, [storageKey]);

  const resolvedTheme: ResolvedTheme = theme === "system" ? systemTheme : theme;

  // Apply to document element
  useEffect(() => {
    if (typeof window === "undefined") return;
    const root = document.documentElement;
    root.classList.remove("dark", "slate");
    if (resolvedTheme === "slate") {
      root.classList.add("dark", "slate");
      root.style.colorScheme = "dark";
    } else if (resolvedTheme === "dark") {
      root.classList.add("dark");
      root.style.colorScheme = "dark";
    } else {
      root.style.colorScheme = "light";
    }
  }, [resolvedTheme]);

  const setTheme = (newTheme: Theme) => {
    setThemeState(newTheme);
    try {
      localStorage.setItem(storageKey, newTheme);
      // keep 'theme' key updated for backwards compatibility
      localStorage.setItem("theme", newTheme);
    } catch {
      // ignore
    }
  };

  const toggleTheme = () => {
    setTheme(resolvedTheme === "dark" || resolvedTheme === "slate" ? "light" : "dark");
  };

  const value = useMemo(
    () => ({
      theme,
      resolvedTheme,
      setTheme,
      toggleTheme,
    }),
    [theme, resolvedTheme]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
