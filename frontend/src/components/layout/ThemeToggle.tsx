import type { JSX } from "react";
import { Sun, Moon } from "lucide-react";
import { Button } from "@/components/ui/button.js";
import { useTheme } from "@/hooks/useTheme.js";

/**
 * ThemeToggle renders a ghost icon button that switches between light and dark mode.
 *
 * Shows a sun icon when the current theme is dark (clicking switches to light),
 * and a moon icon when the current theme is light (clicking switches to dark).
 */
export function ThemeToggle(): JSX.Element {
  const { theme, toggleTheme } = useTheme();

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={toggleTheme}
      aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
    >
      {theme === "dark" ? (
        <Sun className="h-5 w-5" />
      ) : (
        <Moon className="h-5 w-5" />
      )}
    </Button>
  );
}
