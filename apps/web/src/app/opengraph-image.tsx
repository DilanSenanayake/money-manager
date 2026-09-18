import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";

export const alt = "Smart Money Manager - Take control of your money";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const runtime = "nodejs";

export default async function OpenGraphImage() {
  const logoData = await readFile(join(process.cwd(), "public/brand/logo.png"));
  const logoSrc = `data:image/png;base64,${logoData.toString("base64")}`;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#0d9488",
        }}
      >
        {/* Keep text in the center so WhatsApp’s small crop stays readable */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            width: 900,
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={logoSrc}
            width={220}
            height={220}
            alt=""
            style={{ borderRadius: 48 }}
          />
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              marginTop: 32,
              color: "#ffffff",
              fontSize: 80,
              fontWeight: 800,
              letterSpacing: -1.5,
              lineHeight: 1.05,
              textAlign: "center",
            }}
          >
            <div style={{ display: "flex" }}>Smart Money</div>
            <div style={{ display: "flex" }}>Manager</div>
          </div>
          <div
            style={{
              display: "flex",
              marginTop: 20,
              color: "#ecfdf5",
              fontSize: 40,
              fontWeight: 600,
              lineHeight: 1.2,
              textAlign: "center",
            }}
          >
            Take control of your money
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
