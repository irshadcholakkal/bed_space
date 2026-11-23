const owner = "00000000-0000-0000-0000-000000000001";
const employee = "00000000-0000-0000-0000-000000000002";
const membership = "00000000-0000-0000-0000-000000000003";
const operation = "00000000-0000-0000-0000-000000000004";
const ownerEmail = "owner@example.com";
const employeeEmail = "employee@example.com";

function expect(value: unknown, message: string) {
  if (!value) throw new Error(message);
}

Deno.test("employee permissions isolate Sheets access and a rent retry keeps one payment", async () => {
  let handler!: (request: Request) => Promise<Response>;
  const serve = Deno.serve;
  const nativeFetch = globalThis.fetch;
  const settings = {
    SUPABASE_URL: "https://supabase.test",
    SUPABASE_ANON_KEY: "test-anon",
    SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
    GOOGLE_OAUTH_CLIENT_ID: "test-client",
    GOOGLE_OAUTH_CLIENT_SECRET: "test-secret",
    EMPLOYEE_TOKEN_KEY: btoa("01234567890123456789012345678901"),
  };
  const previous = Object.fromEntries(
    Object.keys(settings).map((name) => [name, Deno.env.get(name)]),
  );
  let connection: Record<string, unknown> | undefined;
  let member: Record<string, unknown> | undefined;
  const activities = new Map<string, Record<string, unknown>>();
  const payments: unknown[][] = [];
  let googleRequests = 0;
  let blocked = false;
  try {
    for (const [name, value] of Object.entries(settings)) {
      Deno.env.set(name, value);
    }
    Deno.serve = ((callback: typeof handler) => {
      handler = callback;
    }) as unknown as typeof Deno.serve;
    globalThis.fetch = async (input, init) => {
      const url = new URL(String(input));
      const method = init?.method ?? "GET";
      const json = () => JSON.parse(String(init?.body));
      if (url.pathname === "/auth/v1/user") {
        const token = new Headers(init?.headers).get("Authorization");
        if (token !== "Bearer employee" && token !== "Bearer owner") {
          return Response.json({}, { status: 401 });
        }
        const id = token === "Bearer owner" ? owner : employee;
        return Response.json({
          id,
          email: id === owner ? ownerEmail : employeeEmail,
          email_confirmed_at: "2026-01-01",
        });
      }
      if (url.hostname === "oauth2.googleapis.com") {
        googleRequests++;
        return url.pathname === "/token"
          ? Response.json({ access_token: "private-owner-access-token" })
          : Response.json({
            email: ownerEmail,
            aud: settings.GOOGLE_OAUTH_CLIENT_ID,
            expires_in: 3599,
            scope:
              "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file",
          });
      }
      if (url.hostname === "sheets.googleapis.com") {
        expect(
          url.pathname.startsWith("/v4/spreadsheets/owner-sheet"),
          "Wrong sheet",
        );
        expect(
          new Headers(init?.headers).get("Authorization") ===
            "Bearer private-owner-access-token",
          "Wrong Google credential",
        );
        if (url.pathname.endsWith(":append")) {
          payments.push(json().values[0]);
          return Response.json({});
        }
        if (url.pathname.endsWith(":clear")) {
          payments.splice(0, 1);
          return Response.json({});
        }
        if (url.pathname.endsWith(":batchGet")) {
          return Response.json({
            valueRanges: url.searchParams.getAll("ranges").map((range) => ({
              values: range.startsWith("Tenants")
                ? [[
                  "tenant",
                  "Tenant",
                  "private phone",
                  "",
                  "",
                  "",
                  "900",
                  "50",
                  "2026-01-01",
                  1,
                  true,
                ]]
                : payments,
            })),
          });
        }
        return Response.json({ spreadsheetId: "owner-sheet" });
      }
      switch (url.pathname) {
        case "/rest/v1/subscriptions":
          expect(
            url.searchParams.get("user_id") === `eq.${owner}`,
            "Must use owner's membership",
          );
          return Response.json([{
            admin_blocked: blocked,
            trial_ends_at: "2099-01-01",
          }]);
        case "/rest/v1/storage_bindings":
          return Response.json([{
            spreadsheet_id: "owner-sheet",
            google_email: ownerEmail,
          }]);
        case "/rest/v1/workspace_employee_connections":
          if (method === "POST") {
            connection = json();
            return new Response(null, { status: 204 });
          }
          return Response.json(connection ? [connection] : []);
        case "/rest/v1/workspace_employees": {
          if (method === "POST") {
            member = { id: membership, employee_id: null, ...json() };
          }
          const match = member &&
            [...url.searchParams].every(([key, value]) =>
              key === "on_conflict" ||
              (value === "is.null"
                ? member?.[key] === null
                : `eq.${member?.[key]}` === value)
            );
          if (match && method === "PATCH") Object.assign(member!, json());
          const result = Response.json(match ? [member] : []);
          if (match && method === "DELETE") member = undefined;
          return result;
        }
        case "/rest/v1/profiles":
          return Response.json([{ business_name: "Test Bedspace" }]);
        case "/rest/v1/rpc/acquire_employee_write_lock":
          return Response.json(true);
        case "/rest/v1/workspace_employee_write_locks":
          return Response.json([]);
        case "/rest/v1/workspace_employee_activity": {
          if (method === "POST") {
            const entry = json();
            activities.set(entry.operation_id, entry);
            return Response.json([entry]);
          }
          const id = url.searchParams.get("operation_id")?.slice(3) ?? "";
          const activity = activities.get(id);
          if (method === "PATCH" && activity) Object.assign(activity, json());
          return Response.json(activity ? [activity] : []);
        }
      }
      throw new Error(`Unexpected fetch ${method} ${url.pathname}`);
    };
    await import("../supabase/functions/workspace-employees/index.ts");
    const call = (who: "owner" | "employee", action: string, fields = {}) =>
      handler(
        new Request("https://supabase.test/functions/v1/workspace-employees", {
          method: "POST",
          headers: { Authorization: `Bearer ${who}` },
          body: JSON.stringify({ action, ...fields }),
        }),
      );

    expect(
      (await call("owner", "connect", { refresh_token: "owner-refresh-token" }))
        .ok,
      "Owner connect failed",
    );
    expect(
      !JSON.stringify(connection).includes("owner-refresh-token"),
      "Refresh token was stored in plaintext",
    );
    expect(
      (await call("owner", "invite", {
        email: employeeEmail,
        permissions: ["collect_rent"],
      })).ok,
      "Invite failed",
    );
    expect(
      (await call("employee", "data", { workspace: membership })).status ===
        403,
      "Pending invite grants access",
    );
    expect(
      (await call("employee", "accept", { id: membership })).ok,
      "Invite acceptance failed",
    );
    const data =
      await (await call("employee", "data", { workspace: membership })).json();
    expect(
      data.tenants?.length === 1,
      "Employee cannot see the rent collection tenant",
    );
    for (
      const hidden of [
        "private phone",
        "payments",
        "private-owner-access-token",
        "owner-sheet",
      ]
    ) {
      expect(
        !JSON.stringify(data).includes(hidden),
        `Employee response disclosed ${hidden}`,
      );
    }
    const before = googleRequests;
    expect(
      (await call("employee", "void_payment", { workspace: membership }))
        .status === 403,
      "Missing permission was ignored",
    );
    expect(googleRequests === before, "Denied payment request reached Google");
    const fields = {
      workspace: membership,
      tenant: "tenant",
      operation,
      amount: 400,
      month: "2026-01",
      date: "2026-01-05",
    };
    const recorded = await call("employee", "collect", fields);
    expect(
      recorded.ok && (await recorded.json()).receipt === operation,
      "Payment or receipt failed",
    );
    expect((await call("employee", "collect", fields)).ok, "Retry failed");
    expect(
      payments.length === 1 && payments[0][2] === 400,
      "Payment retry added a duplicate",
    );
    expect(
      activities.get(operation)?.employee_email === employeeEmail &&
        activities.get(operation)?.completed_at,
      "Collector was not audited",
    );
    const due = await (await call("employee", "rent_due", { ...fields }))
      .json();
    expect(
      due.due === 500,
      "Rent due did not include the saved partial payment",
    );
    expect(
      (await call("owner", "update", {
        id: membership,
        permissions: ["void_payments"],
      })).status === 400,
      "Voiding requires explicit history access",
    );
    expect(
      (await call("owner", "update", {
        id: membership,
        permissions: ["payment_history", "void_payments"],
      })).ok,
      "Permission update failed",
    );
    expect(
      (await call("employee", "rent_due", fields)).status === 403,
      "Removed rent permission still works",
    );
    const history =
      await (await call("employee", "data", { workspace: membership })).json();
    expect(
      history.payments?.[0]?.amount === 400,
      "Payment history permission was not applied",
    );
    const voidOperation = "00000000-0000-0000-0000-000000000005";
    const correction = {
      workspace: membership,
      operation: voidOperation,
      payment: operation,
      reason: "Wrong payment",
    };
    expect(
      (await call("employee", "void_payment", correction)).ok,
      "Voiding failed",
    );
    expect(
      (await call("employee", "void_payment", correction)).ok,
      "Voiding retry failed",
    );
    expect(payments.length === 0, "Voided payment is still in Sheets");
    const details = activities.get(voidOperation)?.details as {
      original?: { amount: number };
      reason: string;
    };
    expect(
      details?.original?.amount === 400 && details?.reason === "Wrong payment",
      "Missing void audit details",
    );
    blocked = true;
    expect(
      (await call("employee", "data", { workspace: membership })).status ===
        403,
      "Blocked owner still allows employee access",
    );
    blocked = false;
    expect(
      (await call("owner", "remove", { id: membership })).ok,
      "Revocation failed",
    );
    expect(
      (await call("employee", "data", { workspace: membership })).status ===
        403,
      "Removed employee still has access",
    );
  } finally {
    Deno.serve = serve;
    globalThis.fetch = nativeFetch;
    for (const [name, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
});
