import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Sign in",
  description:
    "Sign in to Smart Money Manager. AI makes adding an expense take seconds.",
};

export default function LoginLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
