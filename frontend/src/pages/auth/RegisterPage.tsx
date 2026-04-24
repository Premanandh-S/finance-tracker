import { useState, type JSX } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { Input } from "@/components/ui/input.js";
import { Button } from "@/components/ui/button.js";
import { FormField } from "@/components/shared/FormField.js";
import { register, AuthApiError } from "../../api/authApi.js";

export function RegisterPage(): JSX.Element {
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [apiError, setApiError] = useState("");

  async function handleSubmit() {
    const errs: Record<string, string> = {};
    if (!identifier.trim()) errs.identifier = "Required";
    if (!password) errs.password = "Required";
    else if (password.length < 8) errs.password = "At least 8 characters";
    if (password !== confirmPassword) errs.confirmPassword = "Passwords do not match";
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({}); setApiError(""); setIsLoading(true);
    try {
      await register({ identifier: identifier.trim(), password });
      navigate(`/verify-otp?identifier=${encodeURIComponent(identifier.trim())}`);
    } catch (e) {
      setApiError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsLoading(false); }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Create account</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <FormField label="Phone or email" name="identifier" error={errors.identifier}>
            <Input
              id="identifier"
              placeholder="+14155552671 or you@example.com"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              disabled={isLoading}
            />
          </FormField>
          <FormField label="Password" name="password" error={errors.password}>
            <Input
              id="password"
              type="password"
              placeholder="At least 8 characters"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={isLoading}
            />
          </FormField>
          <FormField label="Confirm password" name="confirmPassword" error={errors.confirmPassword}>
            <Input
              id="confirmPassword"
              type="password"
              placeholder="Repeat password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              disabled={isLoading}
            />
          </FormField>
          {apiError && <p className="text-sm text-destructive" role="alert">{apiError}</p>}
          <Button className="w-full" onClick={handleSubmit} disabled={isLoading}>
            {isLoading ? "Creating…" : "Register"}
          </Button>
          <p className="text-center text-sm text-muted-foreground">
            Already have an account? <Link to="/login" className="underline">Log in</Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

export default RegisterPage;
