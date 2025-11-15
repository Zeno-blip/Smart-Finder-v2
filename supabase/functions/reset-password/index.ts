// supabase/functions/reset-password/index.ts
// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.7";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
        },
    });
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "POST") {
        return json(405, { error: "Method not allowed" });
    }

    try {
        const payload = await req.json().catch(() => ({}));
        const rawEmail = String(payload.email ?? "").trim().toLowerCase();
        const redirectTo =
            String(payload.redirectTo ?? "").trim() ||
            Deno.env.get("APP_REDIRECT_RESET") ||
            "smartfinder://reset";

        // 1) Basic email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(rawEmail)) {
            return json(400, { error: "Valid email is required" });
        }

        const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
        const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        if (!SUPABASE_URL || !SERVICE_KEY) {
            console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
            return json(500, { error: "Server misconfigured" });
        }

        const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

        // 2) Check if user exists in your 'users' table
        const { data: user, error: userErr } = await supabase
            .from("users")
            .select("id, full_name, email")
            .eq("email", rawEmail)
            .maybeSingle();

        if (userErr) {
            console.error("User lookup error:", userErr);
            return json(500, { error: userErr.message ?? "User lookup failed" });
        }

        if (!user) {
            // Don't leak which emails exist
            return json(200, {
                message: "If that email exists, a reset link was sent.",
            });
        }

        // 3) Generate a recovery link (does NOT send the email)
        const { data: linkData, error: linkErr } =
            await supabase.auth.admin.generateLink({
                type: "recovery",
                email: rawEmail,
                options: { redirectTo },
            });

        if (linkErr) {
            console.error("generateLink(recovery) error:", linkErr);
            return json(500, {
                error: linkErr.message ?? "Failed to generate reset link",
            });
        }

        // supabase-js v2 keeps the link under data.properties.action_link
        const actionLink =
            (linkData as any)?.properties?.action_link ??
            (linkData as any)?.action_link ??
            null;

        if (!actionLink) {
            console.error("No action_link returned from generateLink:", linkData);
            return json(500, { error: "No reset link returned from Supabase" });
        }

        // 4) Send the email via SendGrid Web API
        const SG_KEY =
            Deno.env.get("SG_RESET_PROD") ?? Deno.env.get("SENDGRID_API_KEY");
        const FROM_EMAIL = Deno.env.get("FROM_EMAIL");
        const FROM_NAME = Deno.env.get("FROM_NAME") ?? "Smart Finder";

        if (!SG_KEY || !FROM_EMAIL) {
            console.error(
                "Missing SG_RESET_PROD/SENDGRID_API_KEY or FROM_EMAIL in secrets",
            );
            return json(500, {
                error: "Missing SendGrid configuration on the server",
            });
        }

        const fullName = (user as any).full_name ?? "";
        const greeting = fullName ? `Hi ${fullName},` : "Hi there,";

        const mailBody = {
            personalizations: [{ to: [{ email: rawEmail }] }],
            from: { email: FROM_EMAIL, name: FROM_NAME },
            subject: "Reset your Smart Finder password",
            content: [
                {
                    type: "text/plain",
                    value:
                        `${greeting}\n\n` +
                        `We received a request to reset the password for your Smart Finder account.\n\n` +
                        `Tap the link below to choose a new password:\n\n` +
                        `${actionLink}\n\n` +
                        `If you did not request this, you can safely ignore this email.\n\n` +
                        `— Smart Finder`,
                },
            ],
        };

        const sgRes = await fetch("https://api.sendgrid.com/v3/mail/send", {
            method: "POST",
            headers: {
                Authorization: `Bearer ${SG_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(mailBody),
        });

        if (!sgRes.ok) {
            const text = await sgRes.text();
            console.error("SendGrid error:", text);
            return json(500, { error: "sendgrid_failed", detail: text });
        }

        // ✅ All good
        return json(200, {
            message: "Password reset email sent successfully",
        });
    } catch (e: any) {
        console.error("reset-password fatal:", e);
        return json(500, { error: e?.message ?? "Unexpected error" });
    }
});
