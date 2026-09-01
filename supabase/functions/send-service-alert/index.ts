import { cert, getApps, initializeApp } from "npm:firebase-admin/app";
import { getMessaging } from "npm:firebase-admin/messaging";

const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");

if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount) });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const payload = await request.json();
  const record = payload.record ?? payload;
  const title = record.title ?? record.alert_title ?? record.name ?? "Transport Service Update";
  const message = record.message ?? record.description ?? record.details ?? record.body ?? "A new public transport service alert is available.";
  const alertId = record.id ?? record.alert_id ?? record.service_alert_id ?? "";

  await getMessaging().send({
    topic: "service-alerts",
    notification: { title: String(title), body: String(message) },
    data: {
      alert_id: String(alertId),
      type: String(record.type ?? record.alert_type ?? "Service Update"),
      mode: String(record.mode ?? record.transport_mode ?? "All"),
    },
    android: {
      priority: "high",
      notification: { channelId: "service_alerts" },
    },
  });

  return Response.json({ sent: true });
});
