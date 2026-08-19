import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "School Platform",
  description: "A secure, modular school management platform.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

