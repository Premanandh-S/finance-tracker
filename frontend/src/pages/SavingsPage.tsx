import { useState, type JSX } from "react";
import { useNavigate } from "react-router-dom";
import { PageLayout } from "@/components/shared/PageLayout.js";
import { FormField } from "@/components/shared/FormField.js";
import { Button } from "@/components/ui/button.js";
import { Badge } from "@/components/ui/badge.js";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table.js";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog.js";
import { Input } from "@/components/ui/input.js";
import { Label } from "@/components/ui/label.js";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select.js";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group.js";

/** A single savings instrument record. */
interface SavingsInstrument {
  id: number;
  savingsId: string;
  institutionName: string;
  type: "FD" | "RD";
  amountContributed: number;
  currentValue: number;
  startDate: string;
  maturityDate?: string;
  nextPaymentDate?: string;
}

/** Mock data — replace with real API call when data fetching is implemented. */
const MOCK_SAVINGS: SavingsInstrument[] = [
  {
    id: 1,
    savingsId: "FD-2024-001",
    institutionName: "SBI",
    type: "FD",
    amountContributed: 500000,
    currentValue: 537500,
    startDate: "2024-01-15",
    maturityDate: "2025-01-15",
  },
  {
    id: 2,
    savingsId: "RD-2023-004",
    institutionName: "HDFC Bank",
    type: "RD",
    amountContributed: 120000,
    currentValue: 128400,
    startDate: "2023-06-01",
    maturityDate: "2025-06-01",
    nextPaymentDate: "2025-02-01",
  },
  {
    id: 3,
    savingsId: "FD-2024-007",
    institutionName: "ICICI Bank",
    type: "FD",
    amountContributed: 250000,
    currentValue: 261250,
    startDate: "2024-07-10",
    maturityDate: "2026-07-10",
  },
];

/** Form state for the Add Savings dialog. */
interface AddSavingsForm {
  savingsId: string;
  institutionName: string;
  institutionType: string;
  type: "FD" | "RD" | "";
  amountContributed: string;
  startDate: string;
  maturityDate: string;
  nextPaymentDate: string;
}

const EMPTY_FORM: AddSavingsForm = {
  savingsId: "",
  institutionName: "",
  institutionType: "",
  type: "",
  amountContributed: "",
  startDate: "",
  maturityDate: "",
  nextPaymentDate: "",
};

/** Format an ISO date string to a locale-friendly display value. */
function formatDate(iso: string | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

/**
 * SavingsPage displays the user's savings instruments in a table and provides
 * an "Add Savings" dialog for entering new savings records.
 *
 * Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
 */
export function SavingsPage(): JSX.Element {
  const navigate = useNavigate();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState<AddSavingsForm>(EMPTY_FORM);
  const [errors, setErrors] = useState<Partial<AddSavingsForm>>({});

  function handleRowClick(saving: SavingsInstrument) {
    navigate(`/savings/${saving.id}`);
  }

  function handleRowKeyDown(e: React.KeyboardEvent, saving: SavingsInstrument) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      navigate(`/savings/${saving.id}`);
    }
  }

  function handleFieldChange(field: keyof AddSavingsForm, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  }

  function validate(): boolean {
    const next: Partial<AddSavingsForm> = {};
    if (!form.savingsId.trim()) next.savingsId = "Savings ID is required";
    if (!form.institutionName.trim()) next.institutionName = "Institution name is required";
    if (!form.type) next.type = "Select a savings type";
    if (!form.amountContributed.trim() || isNaN(Number(form.amountContributed))) {
      next.amountContributed = "Enter a valid amount";
    }
    if (!form.startDate) next.startDate = "Start date is required";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;
    // In a real app, POST to the API here.
    setDialogOpen(false);
    setForm(EMPTY_FORM);
    setErrors({});
  }

  function handleOpenChange(open: boolean) {
    setDialogOpen(open);
    if (!open) {
      setForm(EMPTY_FORM);
      setErrors({});
    }
  }

  const addSavingsButton = (
    <Button onClick={() => setDialogOpen(true)}>Add Savings</Button>
  );

  return (
    <PageLayout title="Savings" action={addSavingsButton}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Savings ID</TableHead>
            <TableHead>Institution</TableHead>
            <TableHead>Type</TableHead>
            <TableHead className="text-right">Current Value</TableHead>
            <TableHead>Maturity Date</TableHead>
            <TableHead>Next Payment</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {MOCK_SAVINGS.map((saving) => (
            <TableRow
              key={saving.id}
              className="cursor-pointer"
              onClick={() => handleRowClick(saving)}
              onKeyDown={(e) => handleRowKeyDown(e, saving)}
              tabIndex={0}
              role="button"
              aria-label={`View details for savings ${saving.savingsId}`}
            >
              <TableCell className="font-medium">{saving.savingsId}</TableCell>
              <TableCell>{saving.institutionName}</TableCell>
              <TableCell>
                <Badge variant={saving.type === "FD" ? "default" : "secondary"}>
                  {saving.type}
                </Badge>
              </TableCell>
              <TableCell className="text-right">
                ₹{saving.currentValue.toLocaleString()}
              </TableCell>
              <TableCell>{formatDate(saving.maturityDate)}</TableCell>
              <TableCell>{formatDate(saving.nextPaymentDate)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Dialog open={dialogOpen} onOpenChange={handleOpenChange}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Add Savings</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <FormField label="Savings ID" name="savingsId" error={errors.savingsId}>
              <Input
                id="savingsId"
                placeholder="e.g. FD-2025-001"
                value={form.savingsId}
                onChange={(e) => handleFieldChange("savingsId", e.target.value)}
              />
            </FormField>

            <FormField label="Institution Name" name="institutionName" error={errors.institutionName}>
              <Input
                id="institutionName"
                placeholder="e.g. SBI"
                value={form.institutionName}
                onChange={(e) => handleFieldChange("institutionName", e.target.value)}
              />
            </FormField>

            <div className="space-y-2">
              <Label>Savings Type</Label>
              <RadioGroup
                value={form.type}
                onValueChange={(v) => handleFieldChange("type", v)}
                className="flex gap-6"
              >
                <div className="flex items-center gap-2">
                  <RadioGroupItem value="FD" id="type-fd" />
                  <Label htmlFor="type-fd">FD (Fixed Deposit)</Label>
                </div>
                <div className="flex items-center gap-2">
                  <RadioGroupItem value="RD" id="type-rd" />
                  <Label htmlFor="type-rd">RD (Recurring Deposit)</Label>
                </div>
              </RadioGroup>
              {errors.type && (
                <p className="text-sm text-destructive">{errors.type}</p>
              )}
            </div>

            <FormField label="Amount Contributed (₹)" name="amountContributed" error={errors.amountContributed}>
              <Input
                id="amountContributed"
                type="number"
                min="0"
                placeholder="e.g. 100000"
                value={form.amountContributed}
                onChange={(e) => handleFieldChange("amountContributed", e.target.value)}
              />
            </FormField>

            <FormField label="Start Date" name="startDate" error={errors.startDate}>
              <Input
                id="startDate"
                type="date"
                value={form.startDate}
                onChange={(e) => handleFieldChange("startDate", e.target.value)}
              />
            </FormField>

            <div className="space-y-2">
              <Label htmlFor="institutionType">Institution Type</Label>
              <Select
                value={form.institutionType}
                onValueChange={(v) => handleFieldChange("institutionType", v)}
              >
                <SelectTrigger id="institutionType">
                  <SelectValue placeholder="Select institution type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="bank">Bank</SelectItem>
                  <SelectItem value="post_office">Post Office</SelectItem>
                  <SelectItem value="nbfc">NBFC</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <FormField label="Maturity Date" name="maturityDate" error={errors.maturityDate}>
              <Input
                id="maturityDate"
                type="date"
                value={form.maturityDate}
                onChange={(e) => handleFieldChange("maturityDate", e.target.value)}
              />
            </FormField>

            <FormField label="Next Payment Date" name="nextPaymentDate" error={errors.nextPaymentDate}>
              <Input
                id="nextPaymentDate"
                type="date"
                value={form.nextPaymentDate}
                onChange={(e) => handleFieldChange("nextPaymentDate", e.target.value)}
              />
            </FormField>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => handleOpenChange(false)}>
              Cancel
            </Button>
            <Button onClick={handleSubmit}>Save Savings</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageLayout>
  );
}

export default SavingsPage;
