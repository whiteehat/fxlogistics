// supabase/functions/send-quote-email/index.ts
//
// Fires when a row is inserted into `quote_requests`.
// Wired up via: Supabase Dashboard → Database → Webhooks
// (table: quote_requests, event: Insert, target: this Edge Function)
//
// Deploy with:
//   supabase functions deploy send-quote-email
// Set secrets with:
//   supabase secrets set RESEND_API_KEY=your_resend_key
//   supabase secrets set QUOTE_NOTIFY_EMAIL=info@fxlogistics.org
//   supabase secrets set QUOTE_FROM_EMAIL="FX Logistics Website <quotes@yourdomain.com>"

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record ?? {};

    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    const TO_EMAIL = Deno.env.get("QUOTE_NOTIFY_EMAIL") || "info@fxlogistics.org";
    const FROM_EMAIL = Deno.env.get("QUOTE_FROM_EMAIL") || "onboarding@resend.dev";

    if (!RESEND_API_KEY) {
      return new Response(JSON.stringify({ error: "RESEND_API_KEY not set" }), { status: 500 });
    }

    const isQuote = (record.request_type || "quote") === "quote";
    const subject = isQuote
      ? `New Price Quote Request — ${record.full_name || "Unknown"}`
      : `New Contact Message — ${record.full_name || "Unknown"}`;

    const row = (label: string, value: unknown) =>
      value ? `<tr><td style="padding:4px 10px 4px 0;color:#52616F;font-size:13px;"><strong>${label}</strong></td><td style="padding:4px 0;font-size:13px;">${value}</td></tr>` : "";

    const html = `
      <div style="font-family:Tahoma,Geneva,sans-serif;max-width:520px;">
        <h2 style="color:#0B3A66;margin-bottom:4px;">${isQuote ? "New Price Quote Request" : "New Contact Message"}</h2>
        <p style="color:#52616F;font-size:13px;margin-top:0;">Submitted via fxlogistics.org</p>
        <table>
          ${row("Name", record.full_name)}
          ${row("Email", record.email)}
          ${row("Phone", record.phone)}
          ${row("Company", record.company)}
          ${row("Service", record.service_type)}
          ${row("Origin", record.origin)}
          ${row("Destination", record.destination)}
          ${row("Cargo description", record.cargo_description)}
          ${row("Weight (kg)", record.weight_kg)}
          ${row("Volume (cbm)", record.volume_cbm)}
          ${row("Preferred mode", record.preferred_mode)}
          ${row("Notes / Message", record.notes)}
        </table>
      </div>
    `;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [TO_EMAIL],
        reply_to: record.email || undefined,
        subject,
        html,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      return new Response(JSON.stringify({ error: errText }), { status: 502 });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
