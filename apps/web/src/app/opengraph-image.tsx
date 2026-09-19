import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";

export const alt = "Smart Money Manager - Take control of your money";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const runtime = "nodejs";

export default async function OpenGraphImage() {
  const logoData = await readFile(
    join(process.cwd(), "public/icons/smart_money_manager_logo_gold1.png"),
  );
  const logoSrc = `data:image/png;base64,${logoData.toString("base64")}`;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "#0d9488",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={logoSrc}
          width={282}
          height={220}
          alt=""
        />
        <div
          style={{
            display: "flex",
            marginTop: 28,
            color: "#ffffff",
            fontSize: 52,
            fontWeight: 700,
            letterSpacing: -1.2,
          }}
        >
          Smart Money Manager
        </div>
        <div
          style={{
            display: "flex",
            marginTop: 14,
            color: "#ccfbf1",
            fontSize: 28,
          }}
        >
          Take control of your money
        </div>
      </div>
    ),
    { ...size }
  );
}
