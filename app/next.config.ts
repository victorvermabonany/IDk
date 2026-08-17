import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Vercel packages the runtime itself. Standalone output remains enabled for
  // the checked-in Docker deployment path, where the self-contained server is
  // required.
  output: process.env.VERCEL ? undefined : "standalone",
};

export default nextConfig;
