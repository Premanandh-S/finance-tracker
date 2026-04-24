import type { JSX } from "react";
import { Navigate, Outlet } from "react-router-dom";
import { AppLayout } from "@/components/layout/AppLayout.js";

/**
 * ProtectedRoute wraps authenticated routes.
 *
 * Checks for an auth token in localStorage. If absent, redirects to /login.
 * If present, renders the matched child route inside AppLayout.
 */
export function ProtectedRoute(): JSX.Element {
  let isAuthenticated = false;
  try {
    isAuthenticated = Boolean(localStorage.getItem("auth_token"));
  } catch {
    // localStorage unavailable — treat as unauthenticated
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return (
    <AppLayout>
      <Outlet />
    </AppLayout>
  );
}

export default ProtectedRoute;
