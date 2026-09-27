import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Create account",
  description:
    "Create a free Smart Money Manager account. AI fills expense details in seconds. You confirm. No card. No bank login.",
};

export default function SignupLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
