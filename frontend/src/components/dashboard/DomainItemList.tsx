/**
 * DomainItemList.tsx
 *
 * A generic list component used within each dashboard domain section.
 * Renders a table-like list of items with configurable columns. Each row is
 * clickable. Optionally renders an alert badge on rows whose ID appears in
 * `alertIds`.
 */

import type { JSX } from "react";
import { Badge } from "@/components/ui/badge.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Definition for a single column in the item list. */
export interface ColumnDef<T> {
  /** Column header label. */
  header: string;
  /** Accessor function that returns the display value for a given item. */
  accessor: (item: T) => string | number;
}

export interface DomainItemListProps<T extends { id: number }> {
  /** Array of domain items to render. */
  items: T[];
  /** Column definitions controlling which fields are shown and how. */
  columns: ColumnDef<T>[];
  /** Called when a row is clicked. */
  onItemClick: (item: T) => void;
  /** Message to display when `items` is empty. */
  emptyMessage: string;
  /**
   * IDs of items that should display an alert badge.
   * When provided alongside `alertLabel`, matching rows show the badge.
   */
  alertIds?: number[];
  /** Text to display in the alert badge (e.g. "Due this month"). */
  alertLabel?: string;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Renders a list of domain items with configurable columns.
 *
 * Each row is keyboard-accessible and calls `onItemClick` when activated.
 * Rows whose `id` appears in `alertIds` render an alert badge with `alertLabel`.
 * When `items` is empty, renders `emptyMessage` instead.
 *
 * @template T - Item type; must have a numeric `id` field.
 *
 * @example
 * ```tsx
 * <DomainItemList
 *   items={data.loans.items}
 *   columns={[
 *     { header: "Identifier", accessor: (l) => l.loan_identifier },
 *     { header: "Balance", accessor: (l) => formatCurrency(l.outstanding_balance) },
 *   ]}
 *   onItemClick={(loan) => navigate(`/loans/${loan.id}`)}
 *   emptyMessage="No loans yet."
 *   alertIds={pendingIds}
 *   alertLabel="Due this month"
 * />
 * ```
 */
export function DomainItemList<T extends { id: number }>({
  items,
  columns,
  onItemClick,
  emptyMessage,
  alertIds,
  alertLabel,
}: DomainItemListProps<T>): JSX.Element {
  if (items.length === 0) {
    return (
      <p className="text-sm text-muted-foreground py-2">{emptyMessage}</p>
    );
  }

  const alertSet = alertIds ? new Set(alertIds) : null;

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b">
            {columns.map((col) => (
              <th
                key={col.header}
                className="text-left py-1 pr-3 font-medium text-muted-foreground whitespace-nowrap"
              >
                {col.header}
              </th>
            ))}
            {alertSet && alertLabel && <th className="text-left py-1 pr-3" />}
          </tr>
        </thead>
        <tbody>
          {items.map((item) => {
            const hasAlert = alertSet ? alertSet.has(item.id) : false;

            return (
              <tr
                key={item.id}
                className="border-b last:border-0 cursor-pointer hover:bg-muted/50 transition-colors"
                onClick={() => onItemClick(item)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    onItemClick(item);
                  }
                }}
                tabIndex={0}
                role="button"
                aria-label={`View item ${item.id}`}
              >
                {columns.map((col) => (
                  <td
                    key={col.header}
                    className="py-2 pr-3 whitespace-nowrap"
                  >
                    {col.accessor(item)}
                  </td>
                ))}
                {alertSet && alertLabel && (
                  <td className="py-2 pr-3 whitespace-nowrap">
                    {hasAlert && (
                      <Badge variant="destructive" className="text-xs">
                        {alertLabel}
                      </Badge>
                    )}
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export default DomainItemList;
