import type { JSX } from "react";
import { BrowserRouter, Routes, Route, Link } from "react-router-dom";
import { LoginPage } from "./pages/auth/LoginPage.js";
import { RegisterPage } from "./pages/auth/RegisterPage.js";
import { OtpVerifyPage } from "./pages/auth/OtpVerifyPage.js";
import { PasswordResetPage } from "./pages/auth/PasswordResetPage.js";
import { DashboardPage } from "./pages/DashboardPage.js";
import { LoansPage } from "./pages/LoansPage.js";
import { LoanDetailPage } from "./pages/LoanDetailPage.js";
import { SavingsPage } from "./pages/SavingsPage.js";
import { InsurancePage, InsurancePolicyDetailPage } from "./pages/InsurancePage.js";
import { PensionsPage } from "./pages/PensionsPage.js";
import { ProtectedRoute } from "./components/auth/ProtectedRoute.js";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { Button } from "@/components/ui/button.js";

function NotFoundPage(): JSX.Element {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Page not found</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground mb-4">
            The page you are looking for does not exist.
          </p>
          <Button asChild>
            <Link to="/">Go to Dashboard</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}

export default function App(): JSX.Element {
  return (
    <BrowserRouter>
      <Routes>
        {/* Public routes */}
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/verify-otp" element={<OtpVerifyPage />} />
        <Route path="/reset-password" element={<PasswordResetPage />} />

        {/* Protected routes */}
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/loans" element={<LoansPage />} />
          <Route path="/loans/:id" element={<LoanDetailPage />} />
          <Route path="/savings" element={<SavingsPage />} />
          <Route path="/insurance" element={<InsurancePage />} />
          <Route path="/insurance/:id" element={<InsurancePolicyDetailPage />} />
          <Route path="/pensions" element={<PensionsPage />} />
        </Route>

        {/* Catch-all */}
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  );
}
