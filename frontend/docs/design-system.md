# Design System Guide

This document is the reference for building UI in the personal finance management app. All pages must follow these conventions so the app stays visually consistent.

---

## Component Selection Guide

### Forms

| Pattern | Component |
|---|---|
| Text input | `Input` |
| Dropdown / single select | `Select` + `SelectTrigger` + `SelectContent` + `SelectItem` |
| Binary / small option set | `RadioGroup` + `RadioGroupItem` |
| Field wrapper (label + control + error) | `FormField` (shared wrapper — see below) |
| Submit / action button | `Button` |
| Validation error message | `FormMessage` (via `FormField`'s `error` prop) |

Always wrap every form field in the shared `FormField` component:

```tsx
import { FormField } from "@/components/shared/FormField";

<FormField label="Email" name="email" error={errors.email?.message}>
  <Input id="email" type="email" {...register("email")} />
</FormField>
```

### Tables

Use Shadcn UI `Table` for all list views:

```tsx
import {
  Table, TableBody, TableCell,
  TableHead, TableHeader, TableRow,
} from "@/components/ui/table";

<Table>
  <TableHeader>
    <TableRow>
      <TableHead>Name</TableHead>
      <TableHead className="text-right">Amount</TableHead>
    </TableRow>
  </TableHeader>
  <TableBody>
    {items.map((item) => (
      <TableRow key={item.id} className="cursor-pointer" onClick={...}>
        <TableCell>{item.name}</TableCell>
        <TableCell className="text-right">₹{item.amount}</TableCell>
      </TableRow>
    ))}
  </TableBody>
</Table>
```

For clickable rows, add `tabIndex={0}`, `role="button"`, and an `onKeyDown` handler for keyboard accessibility.

### Dialogs and Drawers

- Use `Dialog` for forms and confirmations on desktop.
- Use `Sheet` for slide-in panels (e.g., mobile navigation).

```tsx
import {
  Dialog, DialogContent, DialogHeader,
  DialogTitle, DialogFooter,
} from "@/components/ui/dialog";

<Dialog open={open} onOpenChange={setOpen}>
  <DialogContent className="sm:max-w-lg">
    <DialogHeader>
      <DialogTitle>Add Loan</DialogTitle>
    </DialogHeader>
    {/* form fields */}
    <DialogFooter>
      <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
      <Button onClick={handleSubmit}>Save</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

### Notifications

Use Shadcn UI `Toast` for transient feedback (API errors, success messages):

```tsx
import { useToast } from "@/hooks/use-toast";

const { toast } = useToast();
toast({ title: "Saved", description: "Your loan has been added." });
toast({ title: "Error", description: err.message, variant: "destructive" });
```

The `Toaster` component must be mounted once at the app root (already done in `main.tsx`).

### Loading States

Use `Skeleton` as a placeholder while data is being fetched:

```tsx
import { Skeleton } from "@/components/ui/skeleton";

{isLoading ? (
  <Skeleton className="h-8 w-32" />
) : (
  <span>₹{value.toLocaleString()}</span>
)}
```

### Type Badges

Use `Badge` to visually distinguish record types (loan interest type, savings type, insurance type, pension type):

```tsx
import { Badge } from "@/components/ui/badge";

<Badge variant="default">fixed</Badge>
<Badge variant="secondary">floating</Badge>
```

---

## Theme Token Reference

All color values are defined as HSL CSS custom properties in `src/globals.css`. Never use hardcoded hex or RGB values in component files — always reference a token.

### Light Mode (`:root`) and Dark Mode (`.dark`)

| Token | Intended use |
|---|---|
| `--background` | Page / app background |
| `--foreground` | Default text color |
| `--card` | Card and popover background |
| `--card-foreground` | Text inside cards |
| `--popover` | Popover / dropdown background |
| `--popover-foreground` | Text inside popovers |
| `--primary` | Primary action color (buttons, active states) |
| `--primary-foreground` | Text on primary-colored backgrounds |
| `--secondary` | Secondary / subdued backgrounds |
| `--secondary-foreground` | Text on secondary backgrounds |
| `--muted` | Muted / disabled backgrounds |
| `--muted-foreground` | Subdued / placeholder text |
| `--accent` | Hover / focus highlight backgrounds |
| `--accent-foreground` | Text on accent backgrounds |
| `--destructive` | Error / danger color |
| `--destructive-foreground` | Text on destructive backgrounds |
| `--border` | Border color for inputs, cards, dividers |
| `--input` | Input field border color |
| `--ring` | Focus ring color |
| `--radius` | Global border-radius (`0.5rem` by default) |

### Usage in Tailwind

Tailwind utility classes map directly to these tokens:

```
bg-background       → background-color: hsl(var(--background))
text-foreground     → color: hsl(var(--foreground))
text-muted-foreground → color: hsl(var(--muted-foreground))
border-border       → border-color: hsl(var(--border))
text-destructive    → color: hsl(var(--destructive))
```

---

## Layout Conventions

### PageLayout

Every authenticated page must use the shared `PageLayout` wrapper:

```tsx
import { PageLayout } from "@/components/shared/PageLayout";

export function MyPage() {
  const actionButton = <Button onClick={...}>Add Item</Button>;

  return (
    <PageLayout title="My Page" action={actionButton}>
      {/* page content */}
    </PageLayout>
  );
}
```

Props:
- `title: string` — rendered as the page heading (`<h1>`)
- `action?: React.ReactNode` — optional slot for a primary action button, rendered to the right of the heading
- `children: React.ReactNode` — page body content

### FormField

Every form field must use the shared `FormField` wrapper:

```tsx
import { FormField } from "@/components/shared/FormField";

<FormField label="Loan Number" name="loanNumber" error={errors.loanNumber}>
  <Input id="loanNumber" value={...} onChange={...} />
</FormField>
```

Props:
- `label: string` — visible label text
- `name: string` — used as the `htmlFor` on the label and the field's `id`
- `error?: string` — validation error message; renders below the field when present
- `children: React.ReactNode` — the form control (Input, Select, etc.)

### AppLayout

`AppLayout` is applied automatically by `ProtectedRoute` — you do not need to import it in page components. It provides:
- Desktop sidebar (`Sidebar`) — visible on `md+` breakpoints
- Mobile hamburger drawer (`MobileNav`) — visible below `md`
- Header with app name, user avatar, and `ThemeToggle`

---

## Adding New Shadcn UI Components

Install new components via the Shadcn CLI so the source lands under `src/components/ui/`:

```bash
npx shadcn@latest add <component-name>
# e.g.
npx shadcn@latest add accordion
npx shadcn@latest add calendar
```

Do **not** install Shadcn components via npm — the CLI copies the component source into the project so it can be customised.

After adding a component, import it with the `@/components/ui/` alias:

```tsx
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from "@/components/ui/accordion";
```

---

## Dark Mode

### How it works

1. The `useTheme` hook (`src/hooks/useTheme.ts`) reads the stored preference from `localStorage` on mount.
2. It applies or removes the `.dark` class on `document.documentElement`.
3. Shadcn UI components read CSS variables from `:root` (light) or `.dark` (dark) — toggling the class is the only runtime change needed.
4. The user's preference is persisted to `localStorage` so it survives page reloads.

### ThemeToggle

The `ThemeToggle` button is rendered in the `AppLayout` header. It calls `toggleTheme()` from `useTheme` on click. You do not need to wire it up in page components.

### Using the hook directly

If a component needs to read or change the theme:

```tsx
import { useTheme } from "@/hooks/useTheme";

const { theme, setTheme, toggleTheme } = useTheme();
// theme: "light" | "dark"
// setTheme("dark") — sets and persists
// toggleTheme()   — flips between light and dark
```

### Private browsing

If `localStorage` is unavailable, `useTheme` falls back to `"light"` without throwing. The toggle still works for the session; it just won't persist across reloads.
