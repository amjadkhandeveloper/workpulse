import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("id, role, client_id")
      .eq("id", user.id)
      .single();
    const role = profile?.role as string | undefined;
    if (role !== "admin" && role !== "client") {
      return json({ error: "Admin or client only" }, 403);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const body = await req.json();

    if (body.action === "create_client") {
      if (role !== "admin") return json({ error: "Admin only" }, 403);
      const username = requiredUsername(body.username, body.email);
      const tenantId = crypto.randomUUID();
      const { error: tenantError } = await admin.from("clients").insert({
        id: tenantId,
        name: body.name,
        contact_name: body.name,
        email: body.email,
        phone: body.mobile ?? null,
      });
      if (tenantError) return json({ error: tenantError.message }, 400);

      const { data, error } = await admin.auth.admin.createUser({
        email: body.email,
        password: body.password,
        email_confirm: true,
        user_metadata: {
          name: body.name,
          mobile: body.mobile,
          username,
        },
        app_metadata: { role: "client", client_id: tenantId },
      });
      if (error) {
        await admin.from("clients").delete().eq("id", tenantId);
        return json({ error: error.message }, 400);
      }
      await admin.from("profiles").update({
        name: body.name,
        mobile: body.mobile,
        photo_url: body.photo_url ?? null,
        username,
        role: "client",
        client_id: tenantId,
      }).eq("id", data.user.id);
      return json({ id: data.user.id, client_id: tenantId });
    }

    if (body.action === "create") {
      let clientId = body.client_id as string | undefined;
      if (role === "client") {
        clientId = profile?.client_id as string | undefined;
      } else if (!clientId) {
        return json({ error: "Select a client for this user" }, 400);
      }

      const { data: tenant } = await admin
        .from("clients")
        .select("id")
        .eq("id", clientId)
        .single();
      if (!tenant) {
        return json({ error: "Invalid client" }, 400);
      }

      const username = requiredUsername(body.username, body.email);
      const { data, error } = await admin.auth.admin.createUser({
        email: body.email,
        password: body.password,
        email_confirm: true,
        user_metadata: {
          name: body.name,
          mobile: body.mobile,
          username,
        },
        app_metadata: { role: "user", client_id: clientId },
      });
      if (error) return json({ error: error.message }, 400);
      await admin.from("profiles").update({
        name: body.name,
        mobile: body.mobile,
        photo_url: body.photo_url ?? null,
        username,
        role: "user",
        client_id: clientId,
      }).eq("id", data.user.id);
      return json({ id: data.user.id });
    }

    if (body.action === "delete") {
      const targetId = body.user_id as string;
      const { data: target } = await admin
        .from("profiles")
        .select("id, role, client_id")
        .eq("id", targetId)
        .single();
      if (!target) return json({ error: "User not found" }, 404);
      if (role === "client") {
        if (target.role !== "user" || target.client_id !== profile?.client_id) {
          return json({ error: "You can only delete your own users" }, 403);
        }
      } else if (target.role === "admin") {
        return json({ error: "Cannot delete an admin" }, 403);
      }
      const { error } = await admin.auth.admin.deleteUser(targetId);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (error) {
    return json({ error: String(error) }, 400);
  }
});

function requiredUsername(username: unknown, email: unknown): string {
  const fromBody = typeof username === "string" ? username.trim() : "";
  if (fromBody.length >= 2) return fromBody;
  const fromEmail = typeof email === "string" ? email.split("@")[0]?.trim() ?? "" : "";
  if (fromEmail.length >= 2) return fromEmail;
  throw new Error("Username is required");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
