"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { createCategory, updateCategory } from "@/app/actions/categories";
import type { BudgetProgress, Category } from "@/lib/types";
import { cn } from "@/lib/utils";
import { BudgetBars } from "@/components/budgets/budget-bars";
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
  const [pending, startTransition] = useTransition();
  const [form, setForm] = useState({
    name: "",
    icon: "circle",
    type: "expense" as "income" | "expense",
    monthly_budget: 0 as number | null,
  });

  return (
    <div className="page-stack">
      <PageHeader
        title="Budgets"
        description="Category monthly limits with clear 80% / 100% warnings"
        actions={
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button>Add category</Button>
            </DialogTrigger>
            <DialogContent>
            <DialogHeader>
              <DialogTitle>New category</DialogTitle>
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
                    value={form.monthly_budget ?? 0}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        monthly_budget: Number(e.target.value),
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
                    const result = await createCategory({
                      ...form,
                      monthly_budget:
                        form.type === "expense" ? form.monthly_budget : null,
                    });
                    if (result.error) toast.error(result.error);
                    else {
                      toast.success("Category created");
                      setOpen(false);
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
              {cat.type === "expense" && (
                <div className="flex items-center gap-2">
                  <Input
                    className="w-full max-w-[8rem] sm:w-28"
                    type="number"
                    defaultValue={cat.monthly_budget ?? ""}
                    placeholder="Budget"
                    onBlur={(e) => {
                      const value = e.target.value
                        ? Number(e.target.value)
                        : null;
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
                </div>
              )}
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
