import { useState, useEffect, useCallback } from "react";

type Theme = "light" | "dark";

/**
 * Reads the stored theme from localStorage.
 * Falls back to "light" if storage is unavailable or the value is absent.
 */
function getStoredTheme(): Theme {
  try {
    const stored = localStorage.getItem("theme");
    if (stored === "light" || stored === "dark") return stored;
  } catch {
    // localStorage unavailable (e.g. private browsing with storage blocked)
  }
  return "light";
}

/**
 * Applies or removes the `.dark` class on <html> based on the given theme.
 */
function applyTheme(theme: Theme): void {
  if (theme === "dark") {
    document.documentElement.classList.add("dark");
  } else {
    document.documentElement.classList.remove("dark");
  }
}

/**
 * Hook for managing the application color theme.
 *
 * @returns An object with the current theme, a setter, and a toggle function.
 *
 * @example
 * const { theme, setTheme, toggleTheme } = useTheme();
 */
export function useTheme(): {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
} {
  const [theme, setThemeState] = useState<Theme>(getStoredTheme);

  // Apply theme class on mount and whenever theme changes
  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  const setTheme = useCallback((newTheme: Theme) => {
    try {
      localStorage.setItem("theme", newTheme);
    } catch {
      // Ignore storage errors — theme still works for the session
    }
    setThemeState(newTheme);
  }, []);

  const toggleTheme = useCallback(() => {
    setTheme(theme === "light" ? "dark" : "light");
  }, [theme, setTheme]);

  return { theme, setTheme, toggleTheme };
}
