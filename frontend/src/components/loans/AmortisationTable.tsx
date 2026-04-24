import type { JSX } from "react";
import type { AmortisationEntry } from "@/api/loansApi.js";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Converts a paise integer to a formatted rupee string using the en-IN locale.
 *
 * @param paise - Monetary value in paise (smallest currency unit).
 * @returns Formatted string, e.g. "₹2,50,000.00".
 */
export function formatCurrency(paise: number): string {
  return `₹${(paise / 100).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
}

/**
 * Formats an ISO 8601 date string as a locale-friendly display value.
 *
 * @param isoDate - ISO 8601 date string (e.g. "2025-08-05").
 * @returns Formatted string, e.g. "5 Aug 2025".
 */
function formatDate(isoDate: string): string {
  return new Date(isoDate).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface AmortisationTableProps {
  schedule: AmortisationEntry[];
}

/**
 * AmortisationTable renders a loan's amortisation schedule in a tabular
 * format with columns for period, payment date, payment amount, principal,
 * interest, and remaining balance.
 *
 * Monetary values are displayed in rupees (converted from paise).
 * Dates are formatted using the en-IN locale.
 *
 * Requirements: 13.3
 */
export function AmortisationTable({ schedule }: AmortisationTableProps): JSX.Element {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">Period</TableHead>
          <TableHead>Payment Date</TableHead>
          <TableHead className="text-right">Payment Amount</TableHead>
          <TableHead className="text-right">Principal</TableHead>
          <TableHead className="text-right">Interest</TableHead>
          <TableHead className="text-right">Remaining Balance</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {schedule.map((entry) => (
          <TableRow key={entry.period}>
            <TableCell>{entry.period}</TableCell>
            <TableCell>{formatDate(entry.payment_date)}</TableCell>
            <TableCell className="text-right tabular-nums">
              {formatCurrency(entry.payment_amount)}
            </TableCell>
            <TableCell className="text-right tabular-nums">
              {formatCurrency(entry.principal)}
            </TableCell>
            <TableCell className="text-right tabular-nums">
              {formatCurrency(entry.interest)}
            </TableCell>
            <TableCell className="text-right tabular-nums">
              {formatCurrency(entry.remaining_balance)}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

export default AmortisationTable;
