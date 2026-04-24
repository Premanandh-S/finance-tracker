import { useState, useEffect, useRef, type JSX } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { Input } from "@/components/ui/input.js";
import { Button } from "@/components/ui/button.js";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs.js";
import { Badge } from "@/components/ui/badge.js";
import { FormField } from "@/components/shared/FormField.js";
import { login, AuthApiError } from "../../api/authApi.js";
import { useAuth } from "../../hooks/useAuth.js";

const OTP_TTL = 10 * 60;

function formatCountdown(s: number) {
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

export function LoginPage(): JSX.Element {
  const navigate = useNavigate();
  const { loginWithPassword } = useAuth();

  const [tab, setTab] = useState<"otp" | "password">("otp");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [otpSent, setOtpSent] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(OTP_TTL);
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [apiError, setApiError] = useState("");
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (otpSent) {
      setSecondsLeft(OTP_TTL);
      timerRef.current = setInterval(() => {
        setSecondsLeft((s) => {
          if (s <= 1) { clearInterval(timerRef.current!); return 0; }
          return s - 1;
        });
      }, 1000);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [otpSent]);

  async function handleOtpSend() {
    if (!identifier.trim()) { setErrors({ identifier: "Required" }); return; }
    setErrors({}); setApiError(""); setIsLoading(true);
    try {
      await login({ identifier: identifier.trim(), method: "otp" });
      setOtpSent(true);
      navigate(`/verify-otp?identifier=${encodeURIComponent(identifier.trim())}`);
    } catch (e) {
      setApiError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsLoading(false); }
  }

  async function handlePasswordLogin() {
    const errs: Record<string, string> = {};
    if (!identifier.trim()) errs.identifier = "Required";
    if (!password) errs.password = "Required";
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({}); setApiError(""); setIsLoading(true);
    try {
      await loginWithPassword(identifier.trim(), password);
      navigate("/dashboard");
    } catch (e) {
      setApiError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsLoading(false); }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Log in</CardTitle>
        </CardHeader>
        <CardContent>
          <Tabs value={tab} onValueChange={(v) => setTab(v as "otp" | "password")}>
            <TabsList className="w-full mb-4">
              <TabsTrigger value="otp" className="flex-1">OTP</TabsTrigger>
              <TabsTrigger value="password" className="flex-1">Password</TabsTrigger>
            </TabsList>

            <TabsContent value="otp" className="space-y-4">
              <FormField label="Phone or email" name="identifier" error={errors.identifier}>
                <Input
                  id="identifier"
                  placeholder="+14155552671 or you@example.com"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  disabled={isLoading}
                />
              </FormField>
              {otpSent && (
                <div className="flex items-center gap-2">
                  <Badge variant="secondary">
                    {secondsLeft > 0 ? `Expires in ${formatCountdown(secondsLeft)}` : "Expired"}
                  </Badge>
                </div>
              )}
              {apiError && <p className="text-sm text-destructive" role="alert">{apiError}</p>}
              <Button className="w-full" onClick={handleOtpSend} disabled={isLoading}>
                {isLoading ? "Sending…" : "Send OTP"}
              </Button>
            </TabsContent>

            <TabsContent value="password" className="space-y-4">
              <FormField label="Phone or email" name="identifier" error={errors.identifier}>
                <Input
                  id="identifier-pw"
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
                  placeholder="Your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                />
              </FormField>
              {apiError && <p className="text-sm text-destructive" role="alert">{apiError}</p>}
              <Button className="w-full" onClick={handlePasswordLogin} disabled={isLoading}>
                {isLoading ? "Logging in…" : "Log in"}
              </Button>
            </TabsContent>
          </Tabs>

          <div className="mt-4 text-center text-sm text-muted-foreground space-y-1">
            <p><Link to="/reset-password" className="underline">Forgot password?</Link></p>
            <p>No account? <Link to="/register" className="underline">Sign up</Link></p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default LoginPage;
