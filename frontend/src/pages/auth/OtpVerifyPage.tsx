import { useState, useEffect, useRef, useCallback, type JSX } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { Input } from "@/components/ui/input.js";
import { Button } from "@/components/ui/button.js";
import { Progress } from "@/components/ui/progress.js";
import { FormField } from "@/components/shared/FormField.js";
import { requestOtp, AuthApiError } from "../../api/authApi.js";
import { useAuth } from "../../hooks/useAuth.js";

const OTP_TTL = 10 * 60;

export function OtpVerifyPage(): JSX.Element {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const identifier = searchParams.get("identifier") ?? "";
  const { loginWithOtp } = useAuth();

  const [otp, setOtp] = useState("");
  const [secondsLeft, setSecondsLeft] = useState(OTP_TTL);
  const [isVerifying, setIsVerifying] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [error, setError] = useState("");
  const [resendMsg, setResendMsg] = useState("");
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    setSecondsLeft(OTP_TTL);
    timerRef.current = setInterval(() => {
      setSecondsLeft((s) => { if (s <= 1) { clearInterval(timerRef.current!); return 0; } return s - 1; });
    }, 1000);
  }, []);

  useEffect(() => { startTimer(); return () => { if (timerRef.current) clearInterval(timerRef.current); }; }, [startTimer]);

  const isExpired = secondsLeft === 0;
  const progress = (secondsLeft / OTP_TTL) * 100;

  async function handleVerify() {
    if (otp.length !== 6) { setError("Enter the 6-digit code"); return; }
    if (isExpired) { setError("Code expired — request a new one"); return; }
    setError(""); setIsVerifying(true);
    try {
      await loginWithOtp(identifier, otp);
      navigate("/dashboard");
    } catch (e) {
      setError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsVerifying(false); }
  }

  async function handleResend() {
    setError(""); setResendMsg(""); setIsResending(true);
    try {
      await requestOtp({ identifier });
      setOtp(""); setResendMsg("New code sent."); startTimer();
    } catch (e) {
      setError(e instanceof AuthApiError ? e.message : "Something went wrong");
    } finally { setIsResending(false); }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Verify code</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Enter the 6-digit code sent to <strong>{identifier || "your phone or email"}</strong>.
          </p>
          <Progress value={progress} className="h-1" />
          <p className="text-xs text-muted-foreground">
            {isExpired ? "Code expired" : `Expires in ${String(Math.floor(secondsLeft / 60)).padStart(2, "0")}:${String(secondsLeft % 60).padStart(2, "0")}`}
          </p>
          <FormField label="Verification code" name="otp" error={error}>
            <Input
              id="otp"
              inputMode="numeric"
              maxLength={6}
              placeholder="000000"
              value={otp}
              onChange={(e) => { setOtp(e.target.value.replace(/\D/g, "").slice(0, 6)); setError(""); }}
              disabled={isVerifying || isExpired}
            />
          </FormField>
          {resendMsg && <p className="text-sm text-green-600" role="status">{resendMsg}</p>}
          <Button className="w-full" onClick={handleVerify} disabled={isVerifying || isExpired}>
            {isVerifying ? "Verifying…" : "Verify"}
          </Button>
          <Button variant="outline" className="w-full" onClick={handleResend} disabled={!isExpired || isResending}>
            {isResending ? "Sending…" : "Resend code"}
          </Button>
          <p className="text-center text-sm text-muted-foreground">
            <Link to="/login" className="underline">Back to login</Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

export default OtpVerifyPage;
