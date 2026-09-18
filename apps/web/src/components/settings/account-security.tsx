"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { changePassword, deleteOwnAccount } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

export function AccountSecurity() {
  const [passwordPending, startPassword] = useTransition();
  const [deletePending, startDelete] = useTransition();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deletePassword, setDeletePassword] = useState("");

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>Password</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="space-y-2">
            <Label htmlFor="current-password">Current password</Label>
            <Input
              id="current-password"
              type="password"
              autoComplete="current-password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="new-password">New password</Label>
            <Input
              id="new-password"
              type="password"
              autoComplete="new-password"
              minLength={8}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="confirm-password">Confirm new password</Label>
            <Input
              id="confirm-password"
              type="password"
              autoComplete="new-password"
              minLength={8}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
            />
          </div>
          <Button
            disabled={passwordPending}
            onClick={() => {
              if (newPassword !== confirmPassword) {
                toast.error("New passwords do not match");
                return;
              }
              startPassword(async () => {
                const result = await changePassword({
                  currentPassword,
                  newPassword,
                });
                if (result.error) toast.error(result.error);
                else {
                  toast.success("Password updated");
                  setCurrentPassword("");
                  setNewPassword("");
                  setConfirmPassword("");
                }
              });
            }}
          >
            Update password
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Delete account</CardTitle>
          <CardDescription>
            This removes your login, wallets, and transactions. It cannot be
            undone.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
            Delete account
          </Button>
        </CardContent>
      </Card>

      <Dialog
        open={deleteOpen}
        onOpenChange={(open) => {
          setDeleteOpen(open);
          if (!open) setDeletePassword("");
        }}
      >
        <DialogContent className="gap-0 overflow-hidden p-0 sm:p-0">
          <div className="flex max-h-[min(92dvh,100svh)] min-h-0 flex-col sm:max-h-[min(84vh,720px)]">
            <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
              <DialogTitle>Delete account</DialogTitle>
              <DialogDescription>
                Enter your password to permanently delete this account and all
                money records.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-3 px-5 py-4 sm:px-6">
              <div className="space-y-2">
                <Label htmlFor="delete-password">Password</Label>
                <Input
                  id="delete-password"
                  type="password"
                  autoComplete="current-password"
                  value={deletePassword}
                  onChange={(e) => setDeletePassword(e.target.value)}
                />
              </div>
            </div>
            <DialogFooter className="shrink-0 border-t border-[var(--border)] px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:px-6 sm:pb-4">
              <Button
                type="button"
                variant="outline"
                onClick={() => setDeleteOpen(false)}
                disabled={deletePending}
              >
                Cancel
              </Button>
              <Button
                variant="destructive"
                disabled={deletePending}
                onClick={() =>
                  startDelete(async () => {
                    const result = await deleteOwnAccount(deletePassword);
                    if (result?.error) toast.error(result.error);
                  })
                }
              >
                {deletePending ? "Deleting…" : "Delete account"}
              </Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
