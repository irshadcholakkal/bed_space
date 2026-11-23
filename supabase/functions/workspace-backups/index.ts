import { timingSafeEqual } from "node:crypto";
import { database, required } from "../_shared/backend.ts";
import { refreshGoogleAccess } from "../_shared/google-session.mjs";

import {
  counts,
  findBackup,
  readRecoveryFile,
  readTabs,
  RecoveryError,
  recoveryFile,
  refreshBackup,
  replaceTabs,
} from "./workbook.ts";
const week = 7 * 24 * 60 * 60 * 1000;

type Binding = { spreadsheet_id: string; google_email: string };
type Backup = Binding & {
  due_at: string;
  encrypted_refresh_token: string;
  last_backup_at: string | null;
  last_file_id: string | null;
  last_error: string | null;
};

function scope(table: string, column: string, id: string) {
  return `${table}?${new URLSearchParams({ [column]: `eq.${id}` })}`;
}

function update(path: string, body: object, method = "PATCH") {
  return database(path, { method, body: JSON.stringify(body) });
}

function decode(value: string) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

async function tokenKey() {
  const bytes = decode(required("BACKUP_TOKEN_KEY"));
  if (bytes.length !== 32) throw new Error("Invalid backup encryption key");
  return await crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

const encoder = new TextEncoder();

async function encrypt(token: string, owner: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: encoder.encode(owner) },
    await tokenKey(),
    encoder.encode(token),
  );
  return [iv, new Uint8Array(encrypted)].map((bytes) =>
    btoa(String.fromCharCode(...bytes))
  ).join(".");
}

async function decrypt(value: string, owner: string) {
  const [iv, encrypted] = value.split(".");
  const clear = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: decode(iv), additionalData: encoder.encode(owner) },
    await tokenKey(),
    decode(encrypted),
  );
  return new TextDecoder().decode(clear);
}

function access(token: string, email: string) {
  return refreshGoogleAccess({
    refreshToken: token,
    email,
    clientId: required("GOOGLE_OAUTH_CLIENT_ID"),
    clientSecret: required("GOOGLE_OAUTH_CLIENT_SECRET"),
  });
}

async function binding(owner: string): Promise<Binding | undefined> {
  const [result] = await database(scope("storage_bindings", "user_id", owner));
  return result;
}

function matches(backup?: Backup, current?: Binding) {
  return !!backup && !!current &&
    backup.spreadsheet_id === current.spreadsheet_id &&
    backup.google_email === current.google_email;
}

async function run(owner: string, dispatchedAt: string) {
  const path = scope("workspace_backups", "owner_id", owner) + "&" +
    new URLSearchParams({ dispatched_at: `eq.${dispatchedAt}` });
  const [backup]: Backup[] = await database(path);
  if (!backup) return;
  if (!matches(backup, await binding(owner))) {
    await database(path, { method: "DELETE" });
    return;
  }

  let tokens;
  try {
    tokens = await access(
      await decrypt(backup.encrypted_refresh_token, owner),
      backup.google_email,
    );
  } catch {
    await update(path, {
      last_error: "Reconnect Google and enable backups again in Settings.",
    });
    throw new Error("Backup Google connection failed");
  }
  if (tokens.refresh_token) {
    await update(path, {
      encrypted_refresh_token: await encrypt(tokens.refresh_token, owner),
    });
  }
  try {
    const file = await refreshBackup(
      owner,
      backup.spreadsheet_id,
      tokens.access_token,
    );
    const finished = Date.now();
    await update(path, {
      last_backup_at: new Date(finished).toISOString(),
      last_file_id: file,
      last_error: null,
      due_at: new Date(finished + week).toISOString(),
      dispatched_at: null,
    });
  } catch {
    await update(path, {
      last_error: "Google Drive backup failed. The scheduler will retry.",
    });
    throw new Error("Backup copy failed");
  }
}

Deno.serve(async (request) => {
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
  };
  const reply = (body: object, status = 200) =>
    Response.json(body, { status, headers });
  if (request.method === "OPTIONS") return new Response(null, { headers });
  if (request.method !== "POST") {
    return reply({ error: "Method not allowed" }, 405);
  }

  try {
    const cronHeader = request.headers.get("x-backup-secret");
    if (cronHeader !== null) {
      const provided = encoder.encode(cronHeader);
      const expected = encoder.encode(required("BACKUP_CRON_SECRET"));
      if (
        provided.length !== expected.length ||
        !timingSafeEqual(provided, expected)
      ) {
        return reply({ error: "Unauthorized" }, 401);
      }
      const { owner_id, dispatched_at } = await request.json();
      if (
        typeof owner_id !== "string" || !/^[0-9a-f-]{36}$/i.test(owner_id) ||
        typeof dispatched_at !== "string" ||
        !Number.isFinite(Date.parse(dispatched_at))
      ) {
        return reply({ error: "Invalid scheduled backup" }, 400);
      }
      await run(owner_id, dispatched_at);
      return reply({ ok: true });
    }

    const auth = await fetch(`${required("SUPABASE_URL")}/auth/v1/user`, {
      headers: {
        apikey: required("SUPABASE_ANON_KEY"),
        Authorization: request.headers.get("Authorization") ?? "",
      },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return reply({ error: "Sign in to manage backups." }, 401);
    const user = await auth.json();
    if (!user.email_confirmed_at) {
      return reply({ error: "Verify your account first." }, 403);
    }

    const input = await request.json();
    const path = scope("workspace_backups", "owner_id", user.id);
    if (input.action === "disable") {
      await database(path, { method: "DELETE" });
      return reply({ enabled: false });
    }

    const current = await binding(user.id);
    if (
      ["report", "recovery_file", "preview_restore", "restore"].includes(
        input.action,
      )
    ) {
      if (!current) {
        return reply({ error: "Connect your workspace first." }, 409);
      }
      if (
        typeof input.access_token !== "string" || !input.access_token ||
        input.access_token.length > 4096
      ) {
        return reply({ error: "Reconnect Google and try again." }, 400);
      }

      if (input.spreadsheet_id !== current.spreadsheet_id) {
        return reply({
          error: "The workspace changed. Preview the recovery file again.",
        }, 409);
      }
      const token = input.access_token;
      if (input.action === "report") {
        return reply({ tabs: await readTabs(current.spreadsheet_id, token) });
      }
      if (input.action === "recovery_file") {
        const source = input.from_weekly_backup
          ? await findBackup(user.id, token)
          : current.spreadsheet_id;
        if (!source) {
          return reply({ error: "The first weekly backup is pending." }, 409);
        }
        return reply(recoveryFile(user.id, await readTabs(source, token)));
      }

      const tabs = readRecoveryFile(user.id, input.file);
      if (input.action === "preview_restore") {
        return reply({
          counts: counts(tabs),
          spreadsheet_id: current.spreadsheet_id,
        });
      }
      await replaceTabs(current.spreadsheet_id, token, tabs);
      return reply({ restored: true });
    }

    const [backup]: Backup[] = await database(path);
    if (input.action === "status") {
      if (!matches(backup, current)) return reply({ enabled: false });
      return reply({
        enabled: true,
        next_backup_at: backup.due_at,
        last_backup_at: backup.last_backup_at,
        last_error: backup.last_error,
        last_file_id: backup.last_file_id,
      });
    }
    if (input.action !== "enable") {
      return reply({ error: "Unknown action" }, 400);
    }
    if (!current) return reply({ error: "Connect your workspace first." }, 409);
    if (
      typeof input.refresh_token !== "string" || !input.refresh_token ||
      input.refresh_token.length > 4096
    ) {
      return reply({ error: "Reconnect Google and try again." }, 400);
    }

    let tokens;
    try {
      tokens = await access(input.refresh_token, current.google_email);
    } catch {
      return reply({ error: "Reconnect Google and try again." }, 409);
    }
    const encrypted = await encrypt(
      tokens.refresh_token ?? input.refresh_token,
      user.id,
    );
    if (matches(backup, current)) {
      await update(path, {
        encrypted_refresh_token: encrypted,
        last_error: null,
      });
    } else {
      await database("workspace_backups", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify({
          owner_id: user.id,
          spreadsheet_id: current.spreadsheet_id,
          google_email: current.google_email,
          encrypted_refresh_token: encrypted,
          due_at: new Date().toISOString(),
          dispatched_at: null,
          last_backup_at: null,
          last_file_id: null,
          last_error: null,
        }),
      });
    }
    return reply({ enabled: true });
  } catch (error) {
    if (error instanceof RecoveryError) {
      return reply({ error: error.message }, 422);
    }
    return reply(
      { error: "Workspace data is temporarily unavailable." },
      503,
    );
  }
});
