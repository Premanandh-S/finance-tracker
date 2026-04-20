import type { JSX } from "react";
import { LoginPage } from "./pages/LoginPage.js";
import { SignUpPage } from "./pages/SignUpPage.js";
import { OtpVerifyPage } from "./pages/OtpVerifyPage.js";
import { PasswordResetPage } from "./pages/PasswordResetPage.js";

/**
 * Simple path-based router using window.location.pathname.
 * No react-router dependency needed at this stage.
 */
function getCurrentPage(): string {
  return window.location.pathname;
}

export default function App(): JSX.Element {
  const path = getCurrentPage();

  if (path === "/signup") {
    return <SignUpPage />;
  }

  if (path === "/otp/verify") {
    const params = new URLSearchParams(window.location.search);
    const identifier = params.get("identifier") ?? "";
    return <OtpVerifyPage identifier={identifier} />;
  }

  if (path === "/password/reset") {
    return <PasswordResetPage />;
  }

  // Default: login page
  return <LoginPage />;
}
