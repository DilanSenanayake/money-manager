"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";
import {
  createTransaction,
  deleteTransaction,
} from "@/app/actions/transactions";
import type { Account, Category, Transaction } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { localDateYYYYMMDD } from "@/lib/dates";
import type { TransactionInput } from "@/lib/schemas";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
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
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";

type Props = {
  transactions: Transaction[];
  accounts: Account[];
  categories: Category[];
  defaultCurrency?: string;
  initialFilters?: {
    q?: string;
    account_id?: string;
    category_id?: string;
    type?: string;
    from?: string;
    to?: string;
  };
};

export function TransactionsManager({
  transactions,
  accounts,
  categories,
  defaultCurrency = "USD",
  initialFilters = {},
}: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const [filters, setFilters] = useState(initialFilters);
  const [form, setForm] = useState<TransactionInput>({
    account_id: accounts[0]?.id ?? "",
    category_id: null,
    amount: 0,
    type: "expense",
    date: localDateYYYYMMDD(),
    merchant: "",
    notes: "",
    is_recurring: false,
    recurring_frequency: null,
    transfer_to_account_id: null,
  });

  const filteredCategories = useMemo(
    () =>
      categories.filter((c) =>
        form.type === "transfer"
          ? false
          : form.type === "income"
            ? c.type === "income"
            : c.type === "expense"
      ),
    [categories, form.type]
  );

  function applyFilters() {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    router.push(`/transactions?${params.toString()}`);
  }

  function submit() {
    startTransition(async () => {
      const result = await createTransaction(form);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Transaction saved");
      setOpen(false);
    });
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl tracking-tight">Transactions</h1>
          <p className="text-sm text-slate-500">
            Income, expenses, and internal transfers
          </p>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="h-4 w-4" />
              Add
            </Button>
          </DialogTrigger>
          <DialogContent className="max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>New transaction</DialogTitle>
            </DialogHeader>
            <div className="space-y-3">
              <div className="space-y-2">
                <Label>Type</Label>
                <Select
                  value={form.type}
                  onValueChange={(v) =>
                    setForm({
                      ...form,
                      type: v as TransactionInput["type"],
                      category_id: null,
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="expense">Expense</SelectItem>
                    <SelectItem value="income">Income</SelectItem>
                    <SelectItem value="transfer">Transfer</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>
                  {form.type === "transfer" ? "From account" : "Account"}
                </Label>
                <Select
                  value={form.account_id}
                  onValueChange={(v) => setForm({ ...form, account_id: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select account" />
                  </SelectTrigger>
                  <SelectContent>
                    {accounts.map((a) => (
                      <SelectItem key={a.id} value={a.id}>
                        {a.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              {form.type === "transfer" && (
                <div className="space-y-2">
                  <Label>To account</Label>
                  <Select
                    value={form.transfer_to_account_id ?? undefined}
                    onValueChange={(v) =>
                      setForm({ ...form, transfer_to_account_id: v })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Destination" />
                    </SelectTrigger>
                    <SelectContent>
                      {accounts
                        .filter((a) => a.id !== form.account_id)
                        .map((a) => (
                          <SelectItem key={a.id} value={a.id}>
                            {a.name}
                          </SelectItem>
                        ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
              {form.type !== "transfer" && (
                <div className="space-y-2">
                  <Label>Category</Label>
                  <Select
                    value={form.category_id ?? undefined}
                    onValueChange={(v) => setForm({ ...form, category_id: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Category" />
                    </SelectTrigger>
                    <SelectContent>
                      {filteredCategories.map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label>Amount</Label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    value={form.amount || ""}
                    onChange={(e) =>
                      setForm({ ...form, amount: Number(e.target.value) })
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>Date</Label>
                  <Input
                    type="date"
                    value={form.date}
                    onChange={(e) => setForm({ ...form, date: e.target.value })}
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label>Merchant</Label>
                <Input
                  value={form.merchant ?? ""}
                  onChange={(e) =>
                    setForm({ ...form, merchant: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label>Notes</Label>
                <Textarea
                  value={form.notes ?? ""}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                />
              </div>
              {form.type !== "transfer" && (
                <div className="flex items-center gap-3">
                  <label className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={form.is_recurring}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          is_recurring: e.target.checked,
                          recurring_frequency: e.target.checked
                            ? "monthly"
                            : null,
                        })
                      }
                    />
                    Recurring
                  </label>
                  {form.is_recurring && (
                    <Select
                      value={form.recurring_frequency ?? "monthly"}
                      onValueChange={(v) =>
                        setForm({
                          ...form,
                          recurring_frequency:
                            v as TransactionInput["recurring_frequency"],
                        })
                      }
                    >
                      <SelectTrigger className="w-32">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="weekly">Weekly</SelectItem>
                        <SelectItem value="monthly">Monthly</SelectItem>
                        <SelectItem value="yearly">Yearly</SelectItem>
                      </SelectContent>
                    </Select>
                  )}
                </div>
              )}
            </div>
            <DialogFooter>
              <Button onClick={submit} disabled={pending}>
                {pending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardContent className="grid gap-3 pt-6 md:grid-cols-6">
          <Input
            placeholder="Search merchant…"
            value={filters.q ?? ""}
            onChange={(e) => setFilters({ ...filters, q: e.target.value })}
          />
          <Select
            value={filters.account_id ?? "all"}
            onValueChange={(v) =>
              setFilters({
                ...filters,
                account_id: v === "all" ? undefined : v,
              })
            }
          >
            <SelectTrigger>
              <SelectValue placeholder="Account" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All accounts</SelectItem>
              {accounts.map((a) => (
                <SelectItem key={a.id} value={a.id}>
                  {a.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select
            value={filters.type ?? "all"}
            onValueChange={(v) =>
              setFilters({ ...filters, type: v === "all" ? undefined : v })
            }
          >
            <SelectTrigger>
              <SelectValue placeholder="Type" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All types</SelectItem>
              <SelectItem value="income">Income</SelectItem>
              <SelectItem value="expense">Expense</SelectItem>
              <SelectItem value="transfer">Transfer</SelectItem>
            </SelectContent>
          </Select>
          <Input
            type="date"
            value={filters.from ?? ""}
            onChange={(e) => setFilters({ ...filters, from: e.target.value })}
          />
          <Input
            type="date"
            value={filters.to ?? ""}
            onChange={(e) => setFilters({ ...filters, to: e.target.value })}
          />
          <Button variant="secondary" onClick={applyFilters}>
            Filter
          </Button>
        </CardContent>
      </Card>

      <div className="space-y-2">
        {transactions.map((tx) => {
          const currency = tx.account?.currency ?? defaultCurrency;
          const sign =
            tx.type === "income" ||
            (tx.type === "transfer" &&
              (tx as Transaction & { transfer_direction?: string })
                .transfer_direction === "in")
              ? "+"
              : "-";
          return (
            <div
              key={tx.id}
              className="flex items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-white/90 px-4 py-3 dark:border-slate-800 dark:bg-slate-950/70"
            >
              <div className="min-w-0">
                <p className="truncate font-medium">
                  {tx.merchant || tx.category?.name || tx.type}
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-500">
                  <span>{tx.date}</span>
                  <Badge className="capitalize">{tx.type}</Badge>
                  {tx.account && <span>{tx.account.name}</span>}
                  {tx.is_recurring && (
                    <Badge className="bg-teal-50 text-teal-800">
                      {tx.recurring_frequency}
                    </Badge>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <p
                  className={`font-semibold ${
                    sign === "+" ? "text-teal-700" : "text-rose-600"
                  }`}
                >
                  {sign}
                  {formatMoney(Number(tx.amount), currency)}
                </p>
                <Button
                  size="icon"
                  variant="ghost"
                  onClick={() =>
                    startTransition(async () => {
                      const result = await deleteTransaction(tx.id);
                      if (result.error) toast.error(result.error);
                      else toast.success("Deleted");
                    })
                  }
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
          );
        })}
        {transactions.length === 0 && (
          <p className="text-sm text-slate-500">No transactions found.</p>
        )}
      </div>
    </div>
  );
}
