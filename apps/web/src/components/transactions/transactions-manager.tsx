"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil, Plus, Trash2 } from "lucide-react";
import {
  createTransaction,
  deleteTransaction,
  updateTransaction,
} from "@/app/actions/transactions";
import type { Account, Category, Transaction } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { localDateYYYYMMDD } from "@/lib/dates";
import {
  fromMerchantAndNotes,
  toMerchantAndNotes,
  transactionTitle,
} from "@/lib/transaction-description";
import type { TransactionInput } from "@/lib/schemas";
import { CategoryIcon } from "@/components/categories/category-icon";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { DateQuickPick } from "@/components/ui/date-quick-pick";
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

function emptyForm(accounts: Account[]): TransactionInput {
  return {
    account_id: accounts[0]?.id ?? "",
    category_id: null,
    amount: 0,
    type: "expense",
    date: localDateYYYYMMDD(),
    merchant: "",
    notes: null,
    is_recurring: false,
    recurring_frequency: null,
    transfer_to_account_id: null,
  };
}

function formFromTransaction(tx: Transaction): TransactionInput {
  return {
    account_id: tx.account_id,
    category_id: tx.category_id,
    amount: Number(tx.amount),
    type: tx.type === "transfer" ? "expense" : tx.type,
    date: tx.date,
    merchant: fromMerchantAndNotes(tx.merchant, tx.notes),
    notes: null,
    is_recurring: tx.is_recurring,
    recurring_frequency: tx.recurring_frequency,
    transfer_to_account_id: null,
  };
}

function payloadFromForm(form: TransactionInput): TransactionInput {
  const { merchant, notes } = toMerchantAndNotes(form.merchant ?? "");
  return { ...form, merchant, notes };
}

export function TransactionsManager({
  transactions,
  accounts,
  categories,
  defaultCurrency = "USD",
  initialFilters = {},
}: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [filters, setFilters] = useState(initialFilters);
  const [form, setForm] = useState<TransactionInput>(() => emptyForm(accounts));

  const isEditing = editingId !== null;

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

  function openCreate() {
    setEditingId(null);
    setForm(emptyForm(accounts));
    setOpen(true);
  }

  function openEdit(tx: Transaction) {
    if (tx.type === "transfer" || tx.transfer_pair_id) {
      toast.error("Edit transfers by deleting and recreating them");
      return;
    }
    setEditingId(tx.id);
    setForm(formFromTransaction(tx));
    setOpen(true);
  }

  function onDialogChange(next: boolean) {
    setOpen(next);
    if (!next) {
      setEditingId(null);
      setForm(emptyForm(accounts));
    }
  }

  function submit() {
    startTransition(async () => {
      const payload = payloadFromForm(form);
      const result = isEditing
        ? await updateTransaction(editingId, payload)
        : await createTransaction(payload);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(isEditing ? "Transaction updated" : "Transaction saved");
      onDialogChange(false);
      router.refresh();
    });
  }

  return (
    <div className="page-stack">
      <PageHeader
        title="Activity"
        description="Income, expenses, and internal transfers"
        actions={
          <Dialog open={open} onOpenChange={onDialogChange}>
            <DialogTrigger asChild>
              <Button onClick={openCreate}>
                <Plus className="h-4 w-4" />
                Add
              </Button>
            </DialogTrigger>
            <DialogContent className="gap-0 p-0 sm:p-0">
              <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
                <DialogTitle>
                  {isEditing ? "Edit transaction" : "New transaction"}
                </DialogTitle>
              </DialogHeader>
              <div className="min-h-0 flex-1 space-y-3 overflow-y-auto overscroll-contain px-5 py-4 sm:px-6">
                <div className="space-y-2">
                  <Label>Type</Label>
                  <Select
                    value={form.type}
                    disabled={isEditing}
                    onValueChange={(v) =>
                      setForm({
                        ...form,
                        type: v as TransactionInput["type"],
                        category_id: null,
                        transfer_to_account_id:
                          v === "transfer" ? form.transfer_to_account_id : null,
                      })
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="expense">Expense</SelectItem>
                      <SelectItem value="income">Income</SelectItem>
                      {!isEditing && (
                        <SelectItem value="transfer">Transfer</SelectItem>
                      )}
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
                {form.type === "transfer" && !isEditing && (
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
                      onValueChange={(v) =>
                        setForm({ ...form, category_id: v })
                      }
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Category" />
                      </SelectTrigger>
                      <SelectContent>
                        {filteredCategories.map((c) => (
                          <SelectItem key={c.id} value={c.id}>
                            <span className="inline-flex items-center gap-2">
                              <CategoryIcon
                                icon={c.icon}
                                name={c.name}
                                className="h-3.5 w-3.5"
                              />
                              {c.name}
                            </span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}
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
                <DateQuickPick
                  value={form.date}
                  onChange={(date) => setForm({ ...form, date })}
                />
                <div className="space-y-2">
                  <Label htmlFor="tx-description">Description</Label>
                  <Textarea
                    id="tx-description"
                    placeholder="What was this for? (optional)"
                    rows={2}
                    maxLength={1000}
                    value={form.merchant ?? ""}
                    onChange={(e) =>
                      setForm({ ...form, merchant: e.target.value })
                    }
                  />
                </div>
                {form.type !== "transfer" && (
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                    <label className="flex min-h-10 items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        className="h-4 w-4"
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
                        <SelectTrigger className="w-full sm:w-36">
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
              <DialogFooter className="shrink-0 border-t border-[var(--border)] px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:px-6 sm:pb-4">
                <Button className="w-full sm:w-auto" onClick={submit} disabled={pending}>
                  {pending ? "Saving…" : isEditing ? "Update" : "Save"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        }
      />

      <Card>
        <CardContent className="grid gap-3 pt-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
          <Input
            placeholder="Search description…"
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
          const canEdit = tx.type !== "transfer" && !tx.transfer_pair_id;
          return (
            <div
              key={tx.id}
              className="surface flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
            >
              <div className="flex min-w-0 items-center gap-3">
                <CategoryIcon
                  icon={tx.category?.icon}
                  name={tx.category?.name}
                  framed
                />
                <div className="min-w-0">
                  <p className="truncate font-medium">
                    {transactionTitle(tx)}
                  </p>
                  <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-[var(--muted)]">
                    <span>{tx.date}</span>
                    <Badge
                      variant={
                        tx.type === "income"
                          ? "success"
                          : tx.type === "expense"
                            ? "danger"
                            : "default"
                      }
                      className="capitalize"
                    >
                      {tx.type}
                    </Badge>
                    {tx.account && <span>{tx.account.name}</span>}
                    {tx.is_recurring && (
                      <Badge variant="accent">{tx.recurring_frequency}</Badge>
                    )}
                  </div>
                </div>
              </div>
              <div className="flex items-center justify-between gap-2 sm:justify-end">
                <p
                  className={`shrink-0 text-sm font-semibold tabular-nums sm:text-base ${
                    sign === "+"
                      ? "text-[var(--success)]"
                      : "text-[var(--danger)]"
                  }`}
                >
                  {sign}
                  {formatMoney(Number(tx.amount), currency)}
                </p>
                <div className="flex items-center gap-1">
                  {canEdit && (
                    <Button
                      size="icon"
                      variant="ghost"
                      aria-label="Edit transaction"
                      onClick={() => openEdit(tx)}
                    >
                      <Pencil className="h-4 w-4" />
                    </Button>
                  )}
                  <Button
                    size="icon"
                    variant="ghost"
                    aria-label="Delete transaction"
                    onClick={() =>
                      startTransition(async () => {
                        const result = await deleteTransaction(tx.id);
                        if (result.error) toast.error(result.error);
                        else {
                          toast.success("Deleted");
                          router.refresh();
                        }
                      })
                    }
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </div>
          );
        })}
        {transactions.length === 0 && (
          <p className="py-8 text-center text-sm text-[var(--muted)]">
            No transactions found.
          </p>
        )}
      </div>
    </div>
  );
}
