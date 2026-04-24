import { useState, type JSX } from "react";
import { useNavigate, useParams, Link } from "react-router-dom";
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

/** An individual covered under an insurance policy. */
interface CoveredIndividual {
  name: string;
  individualPolicyId: string;
}

/** A single insurance policy record. */
interface InsurancePolicy {
  id: number;
  policyNumber: string;
  institutionName: string;
  type: "term" | "health" | "auto" | "bike";
  sumAssured: number;
  nextRenewalDate: string;
  coveredIndividuals: CoveredIndividual[];
}

/** Mock data — replace with real API call when data fetching is implemented. */
const MOCK_POLICIES: InsurancePolicy[] = [
  {
    id: 1,
    policyNumber: "POL-TERM-2024-001",
    institutionName: "LIC of India",
    type: "term",
    sumAssured: 10000000,
    nextRenewalDate: "2025-04-01",
    coveredIndividuals: [
      { name: "Rahul Sharma", individualPolicyId: "IND-001-A" },
    ],
  },
  {
    id: 2,
    policyNumber: "POL-HLTH-2023-007",
    institutionName: "Star Health",
    type: "health",
    sumAssured: 500000,
    nextRenewalDate: "2025-06-15",
    coveredIndividuals: [
      { name: "Rahul Sharma", individualPolicyId: "IND-007-A" },
      { name: "Priya Sharma", individualPolicyId: "IND-007-B" },
      { name: "Arjun Sharma", individualPolicyId: "IND-007-C" },
    ],
  },
  {
    id: 3,
    policyNumber: "POL-AUTO-2024-012",
    institutionName: "HDFC ERGO",
    type: "auto",
    sumAssured: 800000,
    nextRenewalDate: "2025-03-20",
    coveredIndividuals: [
      { name: "Rahul Sharma", individualPolicyId: "IND-012-A" },
    ],
  },
  {
    id: 4,
    policyNumber: "POL-BIKE-2024-019",
    institutionName: "Bajaj Allianz",
    type: "bike",
    sumAssured: 120000,
    nextRenewalDate: "2025-05-10",
    coveredIndividuals: [
      { name: "Rahul Sharma", individualPolicyId: "IND-019-A" },
    ],
  },
];

/** Form state for the Add Insurance dialog. */
interface AddInsuranceForm {
  policyNumber: string;
  institutionName: string;
  type: "term" | "health" | "auto" | "bike" | "";
  sumAssured: string;
  nextRenewalDate: string;
}

const EMPTY_FORM: AddInsuranceForm = {
  policyNumber: "",
  institutionName: "",
  type: "",
  sumAssured: "",
  nextRenewalDate: "",
};

/** Format an ISO date string to a locale-friendly display value. */
function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

/** Map a policy type to a Badge variant. */
function badgeVariant(
  type: InsurancePolicy["type"]
): "default" | "secondary" | "outline" | "destructive" {
  switch (type) {
    case "term":
      return "default";
    case "health":
      return "secondary";
    case "auto":
      return "outline";
    case "bike":
      return "destructive";
  }
}

/**
 * InsurancePolicyDetailPage displays the covered individuals for a single
 * insurance policy.
 *
 * Requirements: 8.4
 */
export function InsurancePolicyDetailPage(): JSX.Element {
  const { id } = useParams<{ id: string }>();
  const policy = MOCK_POLICIES.find((p) => p.id === Number(id));

  if (!policy) {
    return (
      <PageLayout title="Policy Not Found">
        <p className="text-muted-foreground">
          No policy found with ID {id}.{" "}
          <Link to="/insurance" className="underline text-primary">
            Back to Insurance
          </Link>
        </p>
      </PageLayout>
    );
  }

  const backButton = (
    <Button variant="outline" asChild>
      <Link to="/insurance">← Back</Link>
    </Button>
  );

  return (
    <PageLayout
      title={`Policy ${policy.policyNumber}`}
      action={backButton}
    >
      <div className="mb-4 flex flex-wrap gap-4 text-sm text-muted-foreground">
        <span>
          <span className="font-medium text-foreground">Institution:</span>{" "}
          {policy.institutionName}
        </span>
        <span>
          <span className="font-medium text-foreground">Type:</span>{" "}
          <Badge variant={badgeVariant(policy.type)}>{policy.type}</Badge>
        </span>
        <span>
          <span className="font-medium text-foreground">Sum Assured:</span>{" "}
          ₹{policy.sumAssured.toLocaleString()}
        </span>
        <span>
          <span className="font-medium text-foreground">Next Renewal:</span>{" "}
          {formatDate(policy.nextRenewalDate)}
        </span>
      </div>

      <h2 className="text-lg font-semibold mb-2">Covered Individuals</h2>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Individual Policy ID</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {policy.coveredIndividuals.map((individual) => (
            <TableRow key={individual.individualPolicyId}>
              <TableCell className="font-medium">{individual.name}</TableCell>
              <TableCell>{individual.individualPolicyId}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </PageLayout>
  );
}

/**
 * InsurancePage displays the user's insurance policies in a table and provides
 * an "Add Insurance" dialog for entering new policy records.
 *
 * Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
 */
export function InsurancePage(): JSX.Element {
  const navigate = useNavigate();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState<AddInsuranceForm>(EMPTY_FORM);
  const [errors, setErrors] = useState<Partial<AddInsuranceForm>>({});

  function handleRowClick(policy: InsurancePolicy) {
    navigate(`/insurance/${policy.id}`);
  }

  function handleRowKeyDown(e: React.KeyboardEvent, policy: InsurancePolicy) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      navigate(`/insurance/${policy.id}`);
    }
  }

  function handleFieldChange(field: keyof AddInsuranceForm, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  }

  function validate(): boolean {
    const next: Partial<AddInsuranceForm> = {};
    if (!form.policyNumber.trim()) next.policyNumber = "Policy number is required";
    if (!form.institutionName.trim()) next.institutionName = "Institution name is required";
    if (!form.type) next.type = "Select a policy type";
    if (!form.sumAssured.trim() || isNaN(Number(form.sumAssured))) {
      next.sumAssured = "Enter a valid sum assured";
    }
    if (!form.nextRenewalDate) next.nextRenewalDate = "Next renewal date is required";
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

  const addInsuranceButton = (
    <Button onClick={() => setDialogOpen(true)}>Add Insurance</Button>
  );

  return (
    <PageLayout title="Insurance" action={addInsuranceButton}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Policy Number</TableHead>
            <TableHead>Institution</TableHead>
            <TableHead>Type</TableHead>
            <TableHead className="text-right">Sum Assured</TableHead>
            <TableHead>Next Renewal</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {MOCK_POLICIES.map((policy) => (
            <TableRow
              key={policy.id}
              className="cursor-pointer"
              onClick={() => handleRowClick(policy)}
              onKeyDown={(e) => handleRowKeyDown(e, policy)}
              tabIndex={0}
              role="button"
              aria-label={`View details for policy ${policy.policyNumber}`}
            >
              <TableCell className="font-medium">{policy.policyNumber}</TableCell>
              <TableCell>{policy.institutionName}</TableCell>
              <TableCell>
                <Badge variant={badgeVariant(policy.type)}>{policy.type}</Badge>
              </TableCell>
              <TableCell className="text-right">
                ₹{policy.sumAssured.toLocaleString()}
              </TableCell>
              <TableCell>{formatDate(policy.nextRenewalDate)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Dialog open={dialogOpen} onOpenChange={handleOpenChange}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Add Insurance</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <FormField label="Policy Number" name="policyNumber" error={errors.policyNumber}>
              <Input
                id="policyNumber"
                placeholder="e.g. POL-TERM-2025-001"
                value={form.policyNumber}
                onChange={(e) => handleFieldChange("policyNumber", e.target.value)}
              />
            </FormField>

            <FormField label="Institution Name" name="institutionName" error={errors.institutionName}>
              <Input
                id="institutionName"
                placeholder="e.g. LIC of India"
                value={form.institutionName}
                onChange={(e) => handleFieldChange("institutionName", e.target.value)}
              />
            </FormField>

            <div className="space-y-2">
              <Label htmlFor="type">Policy Type</Label>
              <Select
                value={form.type}
                onValueChange={(v) => handleFieldChange("type", v)}
              >
                <SelectTrigger id="type">
                  <SelectValue placeholder="Select policy type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="term">Term</SelectItem>
                  <SelectItem value="health">Health</SelectItem>
                  <SelectItem value="auto">Auto</SelectItem>
                  <SelectItem value="bike">Bike</SelectItem>
                </SelectContent>
              </Select>
              {errors.type && (
                <p className="text-sm text-destructive">{errors.type}</p>
              )}
            </div>

            <FormField label="Sum Assured (₹)" name="sumAssured" error={errors.sumAssured}>
              <Input
                id="sumAssured"
                type="number"
                min="0"
                placeholder="e.g. 1000000"
                value={form.sumAssured}
                onChange={(e) => handleFieldChange("sumAssured", e.target.value)}
              />
            </FormField>

            <FormField label="Next Renewal Date" name="nextRenewalDate" error={errors.nextRenewalDate}>
              <Input
                id="nextRenewalDate"
                type="date"
                value={form.nextRenewalDate}
                onChange={(e) => handleFieldChange("nextRenewalDate", e.target.value)}
              />
            </FormField>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => handleOpenChange(false)}>
              Cancel
            </Button>
            <Button onClick={handleSubmit}>Save Insurance</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageLayout>
  );
}

export default InsurancePage;
