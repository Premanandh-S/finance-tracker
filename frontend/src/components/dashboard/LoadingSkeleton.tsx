/**
 * LoadingSkeleton.tsx
 *
 * Renders four skeleton placeholder cards shown while the dashboard data is
 * loading. Each placeholder mimics the shape of a SummaryCard.
 */

import type { JSX } from "react";
import { Card, CardContent, CardHeader } from "@/components/ui/card.js";
import { Skeleton } from "@/components/ui/skeleton.js";

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Renders four skeleton placeholder cards for the dashboard loading state.
 *
 * @example
 * ```tsx
 * if (loading) return <LoadingSkeleton />;
 * ```
 */
export function LoadingSkeleton(): JSX.Element {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {Array.from({ length: 4 }).map((_, i) => (
        <Card key={i} aria-busy="true" aria-label="Loading">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between gap-2">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-8 w-20" />
            </div>
            <Skeleton className="h-8 w-32 mt-1" />
          </CardHeader>
          <CardContent className="space-y-2">
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-5/6" />
            <Skeleton className="h-4 w-4/6" />
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

export default LoadingSkeleton;
