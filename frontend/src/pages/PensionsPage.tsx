import { useState, type JSX } from "react";
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

/** A single pension instrument record. */
interface PensionInstrument {
  id: number;
  pensionId: string;
  institutionName: string;
  type: "EPF" | "NPS";
  monthlyContribution: number;
  contributionStartDate: string;
  maturityDate?: string;
  totalContributions: number;
}

/** Mock data — replace with real API call when data fetching is implemented. */
const MOCK_PENSIONS: PensionInstrument[] = [
  {
    id: 1,
    pensionId: "EPF-2019-001",
    institutionName: "EPFO",
    type: "EPF",
    monthlyContribution: 5400,
    contributionStartDate: "2019-07-01",
    totalContributions: 388800,
  },
  {
    id: 2,
    pensionId: "NPS-2021-003",
    institutionName: "SBI Pension Funds",
    type: "NPS",
    monthlyContribution: 3000,
    contributionStartDate: "2021-04-01",
    maturityDate: "2055-04-01",
    totalContributions: 144000,
  },
  {
    id: 3,
    pensionId: "NPS-2022-007",
    institutionName: "HDFC Pension Management",
    type: "NPS",
    monthlyContribution: 2000,
    contributionStartDate: "2022-01-01",
    maturityDate: "2060-01-01",
    totalContributions: 72000,
  },
];

/** Form state for the Add Pension dialog. */
interface AddPensionForm {
  pensionId: string;
  institutionName: string;
  type: "EPF" | "NPS" | "";
  monthlyContribution: string;
  contributionStartDate: string;
  maturityDate: string;
}

const EMPTY_FORM: AddPensionForm = {
  pensionId: "",
  institutionName: "",
  type: "",
  monthlyContribution: "",
  contributionStartDate: "",
  maturityDate: "",
};

/**
 * PensionsPage displays the user's pension instruments in a table and provides
 * an "Add Pension" dialog for entering new pension records.
 *
 * Requirements: 9.1, 9.2, 9.3, 9.4
 */
export function PensionsPage(): JSX.Element {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState<AddPensionForm>(EMPTY_FORM);
  const [errors, setErrors] = useState<Partial<AddPensionForm>>({});

  function handleFieldChange(field: keyof AddPensionForm, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  }

  function validate(): boolean {
    const next: Partial<AddPensionForm> = {};
    if (!form.pensionId.trim()) next.pensionId = "Pension ID is required";
    if (!form.institutionName.trim()) next.institutionName = "Institution name is required";
    if (!form.type) next.type = "Select a pension type";
    if (!form.monthlyContribution.trim() || isNaN(Number(form.monthlyContribution))) {
      next.monthlyContribution = "Enter a valid monthly contribution";
    }
    if (!form.contributionStartDate) next.contributionStartDate = "Contribution start date is required";
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

  const addPensionButton = (
    <Button onClick={() => setDialogOpen(true)}>Add Pension</Button>
  );

  return (
    <PageLayout title="Pensions" action={addPensionButton}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Pension ID</TableHead>
            <TableHead>Institution</TableHead>
            <TableHead>Type</TableHead>
            <TableHead className="text-right">Monthly Contribution</TableHead>
            <TableHead className="text-right">Total Contributions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {MOCK_PENSIONS.map((pension) => (
            <TableRow key={pension.id}>
              <TableCell className="font-medium">{pension.pensionId}</TableCell>
              <TableCell>{pension.institutionName}</TableCell>
              <TableCell>
                <Badge variant={pension.type === "EPF" ? "default" : "secondary"}>
                  {pension.type}
                </Badge>
              </TableCell>
              <TableCell className="text-right">
                ₹{pension.monthlyContribution.toLocaleString()}
              </TableCell>
              <TableCell className="text-right">
                ₹{pension.totalContributions.toLocaleString()}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Dialog open={dialogOpen} onOpenChange={handleOpenChange}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Add Pension</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <FormField label="Pension ID" name="pensionId" error={errors.pensionId}>
              <Input
                id="pensionId"
                placeholder="e.g. EPF-2025-001"
                value={form.pensionId}
                onChange={(e) => handleFieldChange("pensionId", e.target.value)}
              />
            </FormField>

            <FormField label="Institution Name" name="institutionName" error={errors.institutionName}>
              <Input
                id="institutionName"
                placeholder="e.g. EPFO"
                value={form.institutionName}
                onChange={(e) => handleFieldChange("institutionName", e.target.value)}
              />
            </FormField>

            <div className="space-y-2">
              <Label htmlFor="type">Pension Type</Label>
              <Select
                value={form.type}
                onValueChange={(v) => handleFieldChange("type", v)}
              >
                <SelectTrigger id="type">
                  <SelectValue placeholder="Select pension type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="EPF">EPF (Employees' Provident Fund)</SelectItem>
                  <SelectItem value="NPS">NPS (National Pension System)</SelectItem>
                </SelectContent>
              </Select>
              {errors.type && (
                <p className="text-sm text-destructive">{errors.type}</p>
              )}
            </div>

            <FormField label="Monthly Contribution (₹)" name="monthlyContribution" error={errors.monthlyContribution}>
              <Input
                id="monthlyContribution"
                type="number"
                min="0"
                placeholder="e.g. 5000"
                value={form.monthlyContribution}
                onChange={(e) => handleFieldChange("monthlyContribution", e.target.value)}
              />
            </FormField>

            <FormField label="Contribution Start Date" name="contributionStartDate" error={errors.contributionStartDate}>
              <Input
                id="contributionStartDate"
                type="date"
                value={form.contributionStartDate}
                onChange={(e) => handleFieldChange("contributionStartDate", e.target.value)}
              />
            </FormField>

            <FormField label="Maturity Date (optional)" name="maturityDate" error={errors.maturityDate}>
              <Input
                id="maturityDate"
                type="date"
                value={form.maturityDate}
                onChange={(e) => handleFieldChange("maturityDate", e.target.value)}
              />
            </FormField>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => handleOpenChange(false)}>
              Cancel
            </Button>
            <Button onClick={handleSubmit}>Save Pension</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageLayout>
  );
}

export default PensionsPage;
