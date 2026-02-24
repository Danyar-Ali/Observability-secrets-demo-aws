import express from "express";
import client from "prom-client";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const app = express();
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpReqDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
});
register.registerMetric(httpReqDuration);

const REGION = process.env.AWS_REGION || "eu-central-1";
const SECRET_ID = process.env.SECRET_ID;
const sm = new SecretsManagerClient({ region: REGION });

let cachedSecret = null;

async function getSecretJson() {
  if (!SECRET_ID) return {};
  if (cachedSecret) return cachedSecret;

  const res = await sm.send(new GetSecretValueCommand({ SecretId: SECRET_ID }));
  const raw = res.SecretString
    ? res.SecretString
    : Buffer.from(res.SecretBinary).toString("utf8");

  cachedSecret = JSON.parse(raw);
  return cachedSecret;
}

app.get("/health", (req, res) => res.json({ ok: true }));

app.get("/whoami", async (req, res) => {
  const start = process.hrtime.bigint();
  try {
    const secret = await getSecretJson();
    res.json({ service: "demo-api", apiKey: secret.API_KEY ? "present" : "missing" });
  } finally {
    const end = process.hrtime.bigint();
    const seconds = Number(end - start) / 1e9;
    httpReqDuration.labels(req.method, "/whoami", String(res.statusCode)).observe(seconds);
  }
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

app.listen(process.env.PORT || 8080, () => console.log("API running"));