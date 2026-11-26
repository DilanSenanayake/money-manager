"use client";

import { useState, useTransition } from "react";
import { Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";
import {
  createCategory,
  deleteCategory,
  updateCategory,
} from "@/app/actions/categories";
import type { BudgetProgress, Category } from "@/lib/types";
import { cn } from "@/lib/utils";
import { BudgetBars } from "@/components/budgets/budget-bars";
import { RateGap } from "@/components/money/rate-notice";
import {
  CATEGORY_ICON_OPTIONS,
  CategoryIcon,
  getCategoryColor,
} from "@/components/categories/category-icon";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function BudgetsManager({
  categories,
  budgets,
  currency,
}: {
  categories: Category[];
  budgets: BudgetProgress[];
  currency: string;
}) {
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [deleting, setDeleting] = useState<Category | null>(null);
  const [pending, startTransition] = useTransition();
  const [form, setForm] = useState({
    name: "",
    icon: "circle",
    type: "expense" as "income" | "expense",
    monthly_budget: "" as string | null,
  });

  function openCreate() {
    setEditing(null);
    setForm({
      name: "",
      icon: "circle",
      type: "expense",
      monthly_budget: "",
    });
    setOpen(true);
  }

  function openEdit(category: Category) {
    setEditing(category);
    setForm({
      name: category.name,
      icon: category.icon,
      type: category.type,
      monthly_budget:
        category.monthly_budget == null ? "" : String(category.monthly_budget),
    });
    setOpen(true);
  }

  return (
    <div className="page-stack">
      <PageHeader
        title="Budgets"
        description="Category monthly limits with clear 80% / 100% warnings"
        actions={
          <Dialog
            open={open}
            onOpenChange={(next) => {
              setOpen(next);
              if (!next) setEditing(null);
            }}
          >
            <DialogTrigger asChild>
              <Button onClick={openCreate}>Add category</Button>
            </DialogTrigger>
            <DialogContent>
            <DialogHeader>
              <DialogTitle>
                {editing ? "Edit category" : "New category"}
              </DialogTitle>
            </DialogHeader>
            <div className="space-y-3">
              <div className="space-y-2">
                <Label>Name</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Icon</Label>
                <div className="flex flex-wrap gap-2">
                  {CATEGORY_ICON_OPTIONS.map((opt) => {
                    const color = getCategoryColor(opt.id, opt.label);
                    return (
                    <button
                      key={opt.id}
                      type="button"
                      title={opt.label}
                      onClick={() => setForm({ ...form, icon: opt.id })}
                      className={cn(
                        "inline-flex h-10 w-10 items-center justify-center rounded-lg border transition-[color,background-color,border-color,transform] duration-200 active:scale-95",
                        form.icon === opt.id
                          ? color.chipSelected
                          : cn(color.chip, "hover:opacity-90")
                      )}
                    >
                      <CategoryIcon icon={opt.id} name={opt.label} />
                    </button>
                    );
                  })}
                </div>
              </div>
              <div className="space-y-2">
                <Label>Type</Label>
                <Select
                  value={form.type}
                  onValueChange={(v) =>
                    setForm({ ...form, type: v as "income" | "expense" })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="expense">Expense</SelectItem>
                    <SelectItem value="income">Income</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {form.type === "expense" && (
                <div className="space-y-2">
                  <Label>Monthly budget</Label>
                  <Input
                    type="number"
                    min="0"
                    value={form.monthly_budget ?? ""}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        monthly_budget: e.target.value,
                      })
                    }
                  />
                </div>
              )}
            </div>
            <DialogFooter>
              <Button
                disabled={pending}
                onClick={() =>
                  startTransition(async () => {
                    const input = {
                      ...form,
                      monthly_budget:
                        form.type === "expense" ? form.monthly_budget : null,
                    };
                    const result = editing
                      ? await updateCategory(editing.id, input)
                      : await createCategory(input);
                    if (result.error) toast.error(result.error);
                    else {
                      toast.success(editing ? "Category updated" : "Category created");
                      setOpen(false);
                      setEditing(null);
                    }
                  })
                }
              >
                Save
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
        }
      />

      <RateGap
        currencies={[
          ...new Set(
            budgets.flatMap((budget) => budget.missingRateCurrencies ?? [])
          ),
        ]}
      />

      <Card>
        <CardHeader>
          <CardTitle>This month</CardTitle>
        </CardHeader>
        <CardContent>
          <BudgetBars budgets={budgets} currency={currency} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>All categories</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {categories.map((cat) => (
            <div
              key={cat.id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200/80 px-3 py-2 dark:border-slate-800"
            >
              <div className="flex min-w-0 items-center gap-3">
                <CategoryIcon icon={cat.icon} name={cat.name} framed />
                <div className="min-w-0">
                  <p className="font-medium">{cat.name}</p>
                  <p className="text-xs capitalize text-slate-500">{cat.type}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {cat.type === "expense" && (
                  <Input
                    className="w-full max-w-[8rem] sm:w-28"
                    type="number"
                    defaultValue={cat.monthly_budget ?? ""}
                    placeholder="Budget"
                    onBlur={(e) => {
                      const value = e.target.value.trim() === ""
                        ? null
                        : e.target.value;
                      startTransition(async () => {
                        const result = await updateCategory(cat.id, {
                          name: cat.name,
                          icon: cat.icon,
                          type: cat.type,
                          monthly_budget: value,
                        });
                        if (result.error) toast.error(result.error);
                        else toast.success("Budget updated");
                      });
                    }}
                  />
                )}
                <Button
                  type="button"
                  size="icon"
                  variant="ghost"
                  aria-label={`Edit ${cat.name}`}
                  onClick={() => openEdit(cat)}
                >
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button
                  type="button"
                  size="icon"
                  variant="ghost"
                  aria-label={`Delete ${cat.name}`}
                  onClick={() => setDeleting(cat)}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ))}
        </CardContent>
      </Card>

      <Dialog
        open={deleting !== null}
        onOpenChange={(next) => {
          if (!next) setDeleting(null);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete {deleting?.name}?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-[var(--muted)]">
            This category will be removed. Entries that used it keep their
            amounts.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleting(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={pending || !deleting}
              onClick={() => {
                if (!deleting) return;
                const id = deleting.id;
                startTransition(async () => {
                  const result = await deleteCategory(id);
                  if (result.error) toast.error(result.error);
                  else {
                    toast.success("Category deleted");
                    setDeleting(null);
                  }
                });
              }}
            >
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
