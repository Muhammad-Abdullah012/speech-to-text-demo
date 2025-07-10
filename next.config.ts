import nextPWA from "next-pwa";

const withPWA = nextPWA({ dest: "public", register: true });

const nextConfig = {
  /* config options here */
  output: "standalone" as const
};

export default withPWA(nextConfig);
