"use client";

import { useEffect, useRef, useState } from "react";
import { Calendar } from "lucide-react";
import { format, parse } from "date-fns";
import { localDateYYYYMMDD, localYesterdayYYYYMMDD } from "@/lib/dates";
import { cn } from "@/lib/utils";
import { Label } from "@/components/ui/label";

type Preset = "today" | "yesterday" | "custom";

type Props = {
  value: string;
  onChange: (date: string) => void;
  id?: string;
  label?: string;
  disabled?: boolean;
};

function resolvePreset(value: string, today: string, yesterday: string): Preset {
  if (value === today) return "today";
  if (value === yesterday) return "yesterday";
  return "custom";
}

function formatDisplay(value: string): string {
  try {
    return format(parse(value, "yyyy-MM-dd", new Date()), "MMM d, yyyy");
  } catch {
    return value;
  }
}

export function DateQuickPick({
  value,
  onChange,
  id = "entry-date",
  label = "Date",
  disabled = false,
}: Props) {
  const today = localDateYYYYMMDD();
  const yesterday = localYesterdayYYYYMMDD();
  const derived = resolvePreset(value, today, yesterday);
  const [preset, setPreset] = useState<Preset>(derived);
  const dateInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setPreset(resolvePreset(value, today, yesterday));
  }, [value, today, yesterday]);

  function openCalendar() {
    setPreset("custom");
    const el = dateInputRef.current;
    if (!el || disabled) return;
    // Defer so the input is mounted/visible before the picker opens
    requestAnimationFrame(() => {
      try {
        el.showPicker?.();
      } catch {
        el.focus();
        el.click();
      }
    });
  }

  function pickToday() {
    setPreset("today");
    onChange(today);
  }

  function pickYesterday() {
    setPreset("yesterday");
    onChange(yesterday);
  }

  return (
    <div className="space-y-2">
      <Label>{label}</Label>
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          disabled={disabled}
          onClick={pickToday}
          className={cn(
            "min-h-10 rounded-full border px-3.5 py-2 text-sm font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95 disabled:opacity-60",
            preset === "today"
              ? "border-teal-700 bg-teal-700 text-white"
              : "border-slate-200 text-slate-600 hover:border-teal-600/40"
          )}
        >
          Today
        </button>
        <button
          type="button"
          disabled={disabled}
          onClick={pickYesterday}
          className={cn(
            "min-h-10 rounded-full border px-3.5 py-2 text-sm font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95 disabled:opacity-60",
            preset === "yesterday"
              ? "border-teal-700 bg-teal-700 text-white"
              : "border-slate-200 text-slate-600 hover:border-teal-600/40"
          )}
        >
          Yesterday
        </button>
        <button
          type="button"
          disabled={disabled}
          onClick={openCalendar}
          className={cn(
            "inline-flex min-h-10 items-center gap-1.5 rounded-full border px-3.5 py-2 text-sm font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95 disabled:opacity-60",
            preset === "custom"
              ? "border-teal-700 bg-teal-700 text-white"
              : "border-slate-200 text-slate-600 hover:border-teal-600/40"
          )}
        >
          <Calendar className="h-3.5 w-3.5" />
          {preset === "custom" ? formatDisplay(value) : "Calendar"}
        </button>
      </div>

      {/* Native calendar; opened via showPicker when Calendar is tapped */}
      <input
        ref={dateInputRef}
        id={id}
        type="date"
        value={value}
        disabled={disabled}
        max={today}
        onChange={(e) => {
          const next = e.target.value;
          if (!next) return;
          onChange(next);
          setPreset(resolvePreset(next, today, yesterday));
        }}
        className={cn(
          "h-11 w-full rounded-xl border border-slate-200 bg-white px-3 text-sm text-slate-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent-ring)]",
          "disabled:opacity-60",
          preset === "custom" ? "block" : "sr-only"
        )}
      />
    </div>
  );
}
