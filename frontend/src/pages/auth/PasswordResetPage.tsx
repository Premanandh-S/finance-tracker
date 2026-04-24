import { useState, type JSX } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { Input } from "@/components/ui/input.js";
import { Button } from "@/components/ui/button.js";
import { FormField } from "@/components/shared/FormField.js";
import { requestPasswordReset, confirmPasswordReset, AuthApiError } from "../../api/authApi.js";

export function PasswordResetPage(): JSX.Element {
  const navigate = useNavigate();
  const [step, setStep] = useState<"request" | "confirm">("request");
  const [identifier, setIdentifier] = useState("");
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [apiError, setApiError] = useState("");

  async function handleRequest() {
    if (!identifier.trim()) { setErrors({ identifier: "Required" }); return; }
    setErrors({}); setApiError(""); setIsLoading(true);
    try {
      await requestPasswordReset({ identifier: identifier.trim() });
      setStep("confirm");
    } catch (e) {
      setApiError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsLoading(false); }
  }

  async function handleConfirm() {
    const errs: Record<string, string> = {};
    if (!/^\d{6}$/.test(otp)) errs.otp = "Enter the 6-digit code";
    if (!newPassword) errs.newPassword = "Required";
    else if (newPassword.length < 8) errs.newPassword = "At least 8 characters";
    if (newPassword !== confirmPassword) errs.confirmPassword = "Passwords do not match";
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({}); setApiError(""); setIsLoading(true);
    try {
      await confirmPasswordReset({ identifier: identifier.trim(), otp, new_password: newPassword });
      navigate("/login");
    } catch (e) {
      setApiError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsLoading(false); }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">
            {step === "request" ? "Reset password" : "Set new password"}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {step === "request" ? (
            <>
              <p className="text-sm text-muted-foreground">Enter your phone or email and we'll send a reset code.</p>
              <FormField label="Phone or email" name="identifier" error={errors.identifier}>
                <Input id="identifier" placeholder="+14155552671 or you@example.com" value={identifier} onChange={(e) => setIdentifier(e.target.value)} disabled={isLoading} />
              </FormField>
              {apiError && <p className="text-sm text-destructive" role="alert">{apiError}</p>}
              <Button className="w-full" onClick={handleRequest} disabled={isLoading}>
                {isLoading ? "Sending…" : "Send reset code"}
              </Button>
            </>
          ) : (
            <>
              <p className="text-sm text-muted-foreground">Enter the code sent to <strong>{identifier}</strong> and your new password.</p>
              <FormField label="Verification code" name="otp" error={errors.otp}>
                <Input id="otp" inputMode="numeric" maxLength={6} placeholder="000000" value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))} disabled={isLoading} />
              </FormField>
              <FormField label="New password" name="newPassword" error={errors.newPassword}>
                <Input id="newPassword" type="password" placeholder="At least 8 characters" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} disabled={isLoading} />
              </FormField>
              <FormField label="Confirm password" name="confirmPassword" error={errors.confirmPassword}>
                <Input id="confirmPassword" type="password" placeholder="Repeat password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} disabled={isLoading} />
              </FormField>
              {apiError && <p className="text-sm text-destructive" role="alert">{apiError}</p>}
              <Button className="w-full" onClick={handleConfirm} disabled={isLoading}>
                {isLoading ? "Resetting…" : "Reset password"}
              </Button>
            </>
          )}
          <p className="text-center text-sm text-muted-foreground">
            <Link to="/login" className="underline">Back to login</Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

export default PasswordResetPage;
