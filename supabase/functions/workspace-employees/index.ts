import { database, required } from "../_shared/backend.ts";
import { refreshGoogleAccess } from "../_shared/google-session.mjs";

const permissions = [
  "occupancy",
  "bookings",
  "collect_rent",
  "payment_history",
  "void_payments",
];
const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const monthPattern = /^\d{4}-(0[1-9]|1[0-2])$/;
const datePattern = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
type Row = (string | number | boolean)[];
type Input = Record<string, unknown>;

class RequestError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

function query(table: string, filters: Record<string, string>, extra = "") {
  return `${table}?${new URLSearchParams(Object.fromEntries(
    Object.entries(filters).map(([key, value]) => [key, `eq.${value}`]),
  ))}${extra}`;
}
async function change(
  path: string,
  method: string,
  body?: unknown,
  prefer?: string,
) {
  return await database(path, {
    method,
    body: body === undefined ? undefined : JSON.stringify(body),
    ...(prefer ? { headers: { Prefer: prefer } } : {}),
  });
}
async function key() {
  const bytes = Uint8Array.from(
    atob(required("EMPLOYEE_TOKEN_KEY")),
    (char) => char.charCodeAt(0),
  );
  if (bytes.length !== 32) throw new Error("Invalid employee encryption key");
  return await crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}
function encode(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes));
}
function decode(value: string) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}
async function encrypt(token: string, owner: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const text = new TextEncoder();
  const cipher = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: text.encode(owner) },
    await key(),
    text.encode(token),
  );
  return `${encode(iv)}.${encode(new Uint8Array(cipher))}`;
}
async function decrypt(token: string, owner: string) {
  const [iv, cipher] = token.split(".");
  const plain = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: decode(iv),
      additionalData: new TextEncoder().encode(owner),
    },
    await key(),
    decode(cipher),
  );
  return new TextDecoder().decode(plain);
}
async function googleToken(refreshToken: string, email: string) {
  try {
    return (await refreshGoogleAccess({
      refreshToken,
      email,
      clientId: required("GOOGLE_OAUTH_CLIENT_ID"),
      clientSecret: required("GOOGLE_OAUTH_CLIENT_SECRET"),
    })).access_token;
  } catch {
    throw new RequestError(
      "The workspace owner needs to reconnect Google in Employees.",
      503,
    );
  }
}
async function storage(owner: string) {
  const [subscription] = await database(
    query("subscriptions", { user_id: owner }),
  );
  if (
    !subscription || subscription.suspended || subscription.admin_blocked ||
    Math.max(
        Date.parse(subscription.trial_ends_at),
        Date.parse(subscription.paid_until || subscription.trial_ends_at),
      ) <= Date.now()
  ) {
    throw new RequestError("The workspace membership is inactive.", 403);
  }
  const [binding] = await database(
    query("storage_bindings", { user_id: owner }),
  );
  if (!binding) {
    throw new RequestError("The owner needs to connect a workspace.", 409);
  }
  return binding;
}

function sheetApi(sheet: string, token: string) {
  const root = `https://sheets.googleapis.com/v4/spreadsheets/${
    encodeURIComponent(sheet)
  }`;
  async function request(path: string, method = "GET", body?: unknown) {
    const reply = await fetch(root + path, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        "Cache-Control": "no-cache",
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(15000),
    });
    if (!reply.ok) {
      throw new RequestError(
        "Google Sheets could not complete the request.",
        502,
      );
    }
    return await reply.json();
  }
  return {
    request,
    async read(...ranges: string[]): Promise<Row[][]> {
      const params = new URLSearchParams({
        valueRenderOption: "UNFORMATTED_VALUE",
      });
      ranges.forEach((range) => params.append("ranges", range));
      const reply = await request(`/values:batchGet?${params}`);
      return reply.valueRanges.map((range: { values?: Row[] }) =>
        range.values ?? []
      );
    },
    append(range: string, row: Row) {
      return request(
        `/values/${
          encodeURIComponent(range)
        }:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS`,
        "POST",
        { values: [row] },
      );
    },
    update(data: { range: string; values: Row[] }[]) {
      return request("/values:batchUpdate", "POST", {
        valueInputOption: "RAW",
        data,
      });
    },
    async addCheckedInTenant(
      tenant: Row,
      bedIndex: number,
      bookingIndex: number,
    ) {
      const metadata = await request(
        "?fields=sheets.properties(sheetId,title)",
      );
      const ids = new Map<string, number>(metadata.sheets.map(
        (
          { properties }: { properties: { title: string; sheetId: number } },
        ) => [properties.title, properties.sheetId],
      ));
      for (const tab of ["Tenants", "Beds", "Bookings"]) {
        if (!ids.has(tab)) {
          throw new RequestError("A required Sheet tab is missing.", 502);
        }
      }
      const cells = (values: Row) => ({
        values: Array.from(values, (value) => ({
          userEnteredValue: typeof value === "number"
            ? { numberValue: value }
            : typeof value === "boolean"
            ? { boolValue: value }
            : { stringValue: String(value ?? "") },
        })),
      });
      const update = (
        tab: string,
        row: number,
        column: number,
        value: string,
      ) => ({
        updateCells: {
          start: { sheetId: ids.get(tab), rowIndex: row, columnIndex: column },
          rows: [cells([value])],
          fields: "userEnteredValue",
        },
      });
      return request(":batchUpdate", "POST", {
        requests: [
          {
            appendCells: {
              sheetId: ids.get("Tenants"),
              rows: [cells(tenant)],
              fields: "userEnteredValue",
            },
          },
          update("Beds", bedIndex + 1, 3, "OCCUPIED"),
          update("Bookings", bookingIndex + 1, 12, "checkedIn"),
        ],
      });
    },
  };
}
type Sheet = ReturnType<typeof sheetApi>;
const rows = (values: Row[]) => values.filter((row) => row[0]);
const find = (values: Row[], id: unknown) =>
  values.findIndex((row) => row[0] && String(row[0]) === String(id ?? ""));
const active = (row: Row) => String(row[10] ?? true).toLowerCase() === "true";
const dubaiDay = () =>
  new Date(Date.now() + 4 * 3600000).toISOString().slice(0, 10);

async function workspaceData(sheet: Sheet, granted: string[]) {
  const occupancy = granted.includes("occupancy") ||
    granted.includes("bookings");
  const collect = granted.includes("collect_rent");
  const [buildings, rooms, beds, tenants] = occupancy
    ? await sheet.read(
      "Buildings!A2:B",
      "Rooms!A2:C",
      "Beds!A2:D",
      "Tenants!A2:L",
    )
    : [[], [], [], collect ? (await sheet.read("Tenants!A2:L"))[0] : []];
  const result: Input = {
    permissions: granted,
    buildings: rows(buildings).map(([id, name]) => ({ id, name })),
    rooms: rows(rooms).map(([id, building, name]) => ({ id, building, name })),
    beds: rows(beds).map(([id, room, type, status]) => ({
      id,
      room,
      type,
      status,
    })),
    tenants: rows(tenants).filter(active).map((row) => ({
      id: row[0],
      name: row[1],
      ...(occupancy ? { room: row[4], bed: row[5] } : {}),
    })),
  };
  if (occupancy) {
    const [bookings] = await sheet.read("Bookings!A2:N");
    const reserved = rows(bookings).filter((row) => row[12] === "reserved");
    result.reserved_beds = reserved.map((row) => row[5]);
    if (granted.includes("bookings")) {
      result.bookings = reserved.map((row) => ({
        id: row[0],
        name: row[1],
        bed: row[5],
        date: row[6],
      }));
    }
  }
  if (granted.includes("payment_history")) {
    const [payments, allTenants, bookings] = await sheet.read(
      "Payments!A2:E",
      "Tenants!A2:B",
      "Bookings!A2:B",
    );
    const names = new Map(
      [...rows(bookings), ...rows(allTenants)].map(
        (row) => [String(row[0]), row[1]],
      ),
    );
    result.payments = rows(payments).map((row) => ({
      ...payment(row),
      tenant_name: names.get(String(row[1])),
    }));
  }
  return result;
}
function payment(row: Row) {
  return {
    id: row[0],
    tenant: row[1],
    amount: row[2],
    month: row[3],
    date: row[4],
  };
}
function validateDate(value: unknown, pattern: RegExp): string {
  if (typeof value !== "string" || !pattern.test(value)) {
    throw new RequestError("Enter a valid date.");
  }
  if (pattern === datePattern) {
    const date = new Date(`${value}T00:00:00Z`);
    if (!Number.isFinite(+date) || date.toISOString().slice(0, 10) !== value) {
      throw new RequestError("Enter a valid date.");
    }
  }
  return value;
}
function field(value: unknown, label: string, max = 128): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new RequestError(`Enter a valid ${label}.`);
  }
  return value.trim();
}

Deno.serve(async (request: Request) => {
  const origin = new URL(
    Deno.env.get("APP_URL") || "https://bedspace.thepercentagecompany.com",
  ).origin;
  const headers = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  };
  const reply = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers });
  if (request.method === "OPTIONS") return new Response(null, { headers });
  if (request.method !== "POST") {
    return reply({ error: "Method not allowed." }, 405);
  }
  try {
    const auth = await fetch(`${required("SUPABASE_URL")}/auth/v1/user`, {
      headers: {
        apikey: required("SUPABASE_ANON_KEY"),
        Authorization: request.headers.get("authorization") || "",
      },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) throw new RequestError("Sign in to continue.", 401);
    const user = await auth.json();
    if (!user.email_confirmed_at || !user.email) {
      throw new RequestError("Verify your email to continue.", 403);
    }
    const email = String(user.email).toLowerCase();
    const input: Input = await request.json();
    const action = input.action;
    const own = (table: string, filters: Record<string, string> = {}) =>
      query(table, { owner_id: user.id, ...filters });
    if (action === "members") {
      return reply({
        members: await database(own("workspace_employees")),
        activity: await database(
          query(
            "workspace_employee_activity",
            { owner_id: user.id },
            "&completed_at=not.is.null&order=completed_at.desc&limit=50",
          ),
        ),
        connected: (await database(
          query(
            "workspace_employee_connections",
            { owner_id: user.id },
            "&select=owner_id",
          ),
        )).length > 0,
      });
    }
    if (action === "connect") {
      const binding = await storage(user.id);
      const refresh = field(input.refresh_token, "Google connection", 4096);
      const token = await googleToken(refresh, binding.google_email);
      await sheetApi(binding.spreadsheet_id, token).request(
        "?fields=spreadsheetId",
      );
      await change(
        "workspace_employee_connections?on_conflict=owner_id",
        "POST",
        {
          owner_id: user.id,
          spreadsheet_id: binding.spreadsheet_id,
          google_email: binding.google_email,
          encrypted_refresh_token: await encrypt(refresh, user.id),
        },
        "resolution=merge-duplicates,return=minimal",
      );
      return reply({});
    }
    if (action === "invite" || action === "update" || action === "remove") {
      if (action === "remove" || action === "update") {
        if (typeof input.id !== "string" || !uuid.test(input.id)) {
          throw new RequestError("Invalid employee.");
        }
      }
      if (action === "remove") {
        await change(
          own("workspace_employees", { id: String(input.id) }),
          "DELETE",
        );
        return reply({});
      }
      const binding = await storage(user.id);
      const [connection] = await database(
        own("workspace_employee_connections", {}),
      );
      if (
        connection?.spreadsheet_id !== binding.spreadsheet_id ||
        connection?.google_email !== binding.google_email
      ) {
        throw new RequestError(
          "Connect Google for employee access first.",
          409,
        );
      }
      const selected = input.permissions;
      if (
        !Array.isArray(selected) || !selected.length ||
        selected.some((p) => !permissions.includes(p)) ||
        (selected.includes("void_payments") &&
          !selected.includes("payment_history"))
      ) {
        throw new RequestError("Choose at least one valid permission.");
      }
      if (action === "update") {
        await change(
          own("workspace_employees", { id: String(input.id) }),
          "PATCH",
          { permissions: [...new Set(selected)] },
        );
      } else {
        const recipient = field(input.email, "employee email", 254)
          .toLowerCase();
        if (
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient) || recipient === email
        ) {
          throw new RequestError("Enter a different, valid employee email.");
        }
        const added = await change(
          "workspace_employees?on_conflict=owner_id,email",
          "POST",
          {
            owner_id: user.id,
            email: recipient,
            permissions: [...new Set(selected)],
          },
          "resolution=ignore-duplicates,return=representation",
        );
        if (!added?.length) {
          throw new RequestError(
            "This employee already has an invitation.",
            409,
          );
        }
      }
      return reply({});
    }

    if (action === "workspaces" || action === "accept") {
      const enrolled = await database(
        query("workspace_employees", { employee_id: user.id, email }),
      );
      const pending = await database(
        query("workspace_employees", { email }, "&employee_id=is.null"),
      );
      if (action === "accept") {
        const member = pending.find((row: Input) => row.id === input.id);
        if (!member) {
          throw new RequestError(
            "This invitation is no longer available.",
            404,
          );
        }
        const accepted = await change(
          query(
            "workspace_employees",
            { id: String(member.id), email },
            "&employee_id=is.null",
          ),
          "PATCH",
          { employee_id: user.id },
        );
        if (!accepted?.length) {
          throw new RequestError(
            "This invitation is no longer available.",
            404,
          );
        }
        return reply({});
      }
      const workspaces = await Promise.all(
        [...enrolled, ...pending].map(async (member) => {
          const [profile] = await database(
            query(
              "profiles",
              { user_id: member.owner_id },
              "&select=business_name,display_name",
            ),
          );
          return {
            id: member.id,
            name: profile?.business_name || profile?.display_name ||
              "Bedspace workspace",
            permissions: member.permissions,
            pending: !member.employee_id,
          };
        }),
      );
      return reply({ workspaces });
    }

    if (typeof input.workspace !== "string" || !uuid.test(input.workspace)) {
      throw new RequestError("Select a workspace.");
    }
    const [member] = await database(
      query("workspace_employees", {
        id: input.workspace,
        employee_id: user.id,
        email,
      }),
    );
    if (!member) {
      throw new RequestError(
        "You no longer have access to this workspace.",
        403,
      );
    }
    const needs: Record<string, string> = {
      rent_due: "collect_rent",
      collect: "collect_rent",
      void_payment: "void_payments",
      book: "bookings",
      check_in: "bookings",
      check_out: "bookings",
      assign_bed: "bookings",
    };
    if (
      action !== "data" &&
      (typeof action !== "string" || !Object.hasOwn(needs, action) ||
        !member.permissions.includes(needs[action]))
    ) {
      throw new RequestError(
        "You do not have permission for that action.",
        403,
      );
    }
    const binding = await storage(member.owner_id);
    const [connection] = await database(
      query("workspace_employee_connections", { owner_id: member.owner_id }),
    );
    if (
      connection?.spreadsheet_id !== binding.spreadsheet_id ||
      connection?.google_email !== binding.google_email
    ) {
      throw new RequestError(
        "The workspace owner needs to reconnect Google in Employees.",
        503,
      );
    }
    const token = await googleToken(
      await decrypt(connection.encrypted_refresh_token, member.owner_id),
      connection.google_email,
    );
    const sheet = sheetApi(binding.spreadsheet_id, token);
    if (action === "data") {
      return reply(await workspaceData(sheet, member.permissions));
    }
    if (action === "rent_due") {
      const month = validateDate(input.month, monthPattern);
      const [tenants, payments] = await sheet.read(
        "Tenants!A2:L",
        "Payments!A2:E",
      );
      const tenant = tenants[find(tenants, input.tenant)];
      if (!tenant || !active(tenant)) {
        throw new RequestError("This tenant is no longer active.", 409);
      }
      const rent = Number(tenant[6]) || 0;
      const paid = rows(payments).filter((row) =>
        String(row[1]) === String(tenant[0]) && row[3] === month
      )
        .reduce((sum, row) => sum + (Number(row[2]) || 0), 0);
      return reply({
        rent,
        paid,
        due: Math.max(0, Math.round((rent - paid) * 100) / 100),
      });
    }
    return reply(await perform(sheet, member, email, String(action), input));
  } catch (error) {
    return error instanceof RequestError
      ? reply({ error: error.message }, error.status)
      : reply({
        error: "The employee request could not be completed. Please try again.",
      }, 502);
  }
});

async function perform(
  sheet: Sheet,
  member: { owner_id: string },
  email: string,
  action: string,
  input: Input,
) {
  const operation = field(input.operation, "request ID");
  if (!uuid.test(operation)) throw new RequestError("Invalid request ID.");
  const owner = member.owner_id;
  const lock = crypto.randomUUID();
  if (
    !await change("rpc/acquire_employee_write_lock", "POST", {
      workspace_owner: owner,
      operation: lock,
    })
  ) {
    throw new RequestError(
      "Another employee change is being saved. Try again shortly.",
      429,
    );
  }
  const audit = query("workspace_employee_activity", {
    owner_id: owner,
    operation_id: operation,
  });
  try {
    const details: Input = {};
    for (
      const name of [
        "tenant",
        "payment",
        "month",
        "amount",
        "date",
        "name",
        "phone",
        "bed",
        "booking",
        "reason",
      ]
    ) {
      if (input[name] !== undefined) {
        if (typeof input[name] === "number") details[name] = input[name];
        else details[name] = field(input[name], name, 400);
      }
    }
    const [previous] = await database(audit);
    if (previous) {
      if (
        previous.employee_email !== email || previous.action !== action ||
        Object.keys(details).length !==
          Object.keys(previous.details).filter((key) => key !== "original")
            .length ||
        Object.entries(details).some(([name, value]) =>
          previous.details[name] !== value
        )
      ) {
        throw new RequestError(
          "This request ID has already been used. Refresh before trying again.",
          409,
        );
      }
      if (previous.completed_at) {
        return action === "collect" ? { receipt: operation } : {};
      }
    } else {
      await change("workspace_employee_activity", "POST", {
        owner_id: owner,
        operation_id: operation,
        employee_email: email,
        action,
        details,
      });
    }
    if (action === "collect") {
      const amount = Number(details.amount);
      if (
        !Number.isFinite(amount) || amount <= 0 || amount > 1000000 ||
        Math.abs(amount * 100 - Math.round(amount * 100)) > 0.000001
      ) {
        throw new RequestError(
          "Enter a valid payment amount with up to two decimal places.",
        );
      }
      const month = validateDate(details.month, monthPattern);
      const date = validateDate(details.date, datePattern);
      if (date > dubaiDay()) {
        throw new RequestError("Payment date cannot be in the future.");
      }
      const [tenants, payments] = await sheet.read(
        "Tenants!A2:L",
        "Payments!A2:E",
      );
      if (find(payments, operation) < 0) {
        const tenant = tenants[find(tenants, details.tenant)];
        if (!tenant || !active(tenant)) {
          throw new RequestError("This tenant is no longer active.", 409);
        }
        await sheet.append("Payments!A:E", [
          operation,
          tenant[0],
          amount,
          month,
          date,
        ]);
      }
    } else if (action === "void_payment") {
      field(details.reason, "reason for voiding", 400);
      const paymentId = field(details.payment, "payment ID");
      const [payments] = await sheet.read("Payments!A2:E");
      const index = find(payments, paymentId);
      if (index < 0 && !previous?.details?.original) {
        throw new RequestError("This payment is no longer in Sheets.", 404);
      }
      if (index >= 0) {
        const [id, tenant, amount, month, date] = payments[index];
        await change(audit, "PATCH", {
          details: {
            ...details,
            original: { id, tenant, amount, month, date },
          },
        });
        await sheet.request(
          `/values/Payments!A${index + 2}:E${index + 2}:clear`,
          "POST",
          {},
        );
      }
    } else {
      await updateOccupancy(sheet, action, operation, details);
    }
    await change(audit, "PATCH", { completed_at: new Date().toISOString() });
    return action === "collect" ? { receipt: operation } : {};
  } finally {
    await change(
      query("workspace_employee_write_locks", {
        owner_id: owner,
        operation_id: lock,
      }),
      "DELETE",
    );
  }
}

async function updateOccupancy(
  sheet: Sheet,
  action: string,
  operation: string,
  details: Input,
) {
  const [rooms, beds, tenants, bookings] = await sheet.read(
    "Rooms!A2:N",
    "Beds!A2:D",
    "Tenants!A2:L",
    "Bookings!A2:N",
  );
  const bookingIndex = find(bookings, details.booking);
  const booking = bookings[bookingIndex];
  const tenantIndex = find(tenants, details.tenant);
  const tenant = tenants[tenantIndex];

  function vacantBed(id: unknown, bookingId?: unknown, tenantId?: unknown) {
    const index = find(beds, id);
    const bed = beds[index];
    const room = bed && rooms[find(rooms, bed[1])];
    const parent = room?.[10] ? rooms[find(rooms, room[10])] : undefined;
    const unavailable = (row: Row) =>
      ["false", "0"].includes(String(row[11]).toLowerCase());
    if (
      !bed || !room || unavailable(room) ||
      (room[10] && (!parent || unavailable(parent))) ||
      bookings.some((row) =>
        row[0] !== bookingId && row[5] === bed[0] && row[12] === "reserved"
      ) ||
      tenants.some((row) =>
        row[0] && row[0] !== tenantId && active(row) && row[5] === bed[0]
      ) ||
      (String(bed[3]).toUpperCase() === "OCCUPIED" &&
        !tenants.some((row) =>
          row[0] === tenantId && active(row) && row[5] === bed[0]
        ))
    ) {
      throw new RequestError("That bed is no longer available.", 409);
    }
    return { index, bed, room };
  }
  if (action === "book") {
    if (find(bookings, operation) >= 0) return;
    const { bed, room } = vacantBed(details.bed);
    const name = field(details.name, "tenant name", 150);
    const phone = field(details.phone, "phone number", 40);
    const date = validateDate(details.date, datePattern);
    if (date < dubaiDay()) {
      throw new RequestError("Choose a move-in date from today onward.");
    }
    const rent =
      Number(String(bed[2]).toUpperCase() === "UPPER" ? room[7] : room[6]) ||
      Number(room[9]);
    if (!Number.isFinite(rent) || rent <= 0) {
      throw new RequestError("The owner needs to set the rent for this bed.");
    }
    await sheet.append("Bookings!A:N", [
      operation,
      name,
      phone,
      room[1],
      room[0],
      bed[0],
      date,
      rent,
      0,
      0,
      dubaiDay(),
      1,
      "reserved",
      0,
    ]);
  } else if (action === "check_in") {
    if (
      !booking || (booking[12] !== "reserved" && booking[12] !== "checkedIn")
    ) {
      throw new RequestError("This booking is no longer reserved.", 409);
    }
    if (booking[12] === "checkedIn") return;
    if (String(booking[6]) > dubaiDay()) {
      throw new RequestError("Check-in is available from the move-in date.");
    }
    const { index } = vacantBed(booking[5], booking[0], booking[0]);
    if (find(tenants, booking[0]) < 0) {
      await sheet.addCheckedInTenant(
        [
          ...booking.slice(0, 6),
          booking[7],
          booking[8],
          booking[6],
          booking[11],
          "TRUE",
          "",
        ],
        index,
        bookingIndex,
      );
      return;
    }
    await sheet.update([
      { range: `Beds!D${index + 2}`, values: [["OCCUPIED"]] },
      { range: `Bookings!M${bookingIndex + 2}`, values: [["checkedIn"]] },
    ]);
  } else if (action === "check_out") {
    if (!tenant) throw new RequestError("This tenant could not be found.", 404);
    if (!active(tenant)) return;
    const checkout = details.date === undefined
      ? dubaiDay()
      : validateDate(details.date, datePattern);
    if (checkout > dubaiDay()) {
      throw new RequestError("Check-out date cannot be in the future.");
    }
    const index = find(beds, tenant[5]);
    const stillOccupied = tenants.some((row) =>
      row[0] && row[0] !== tenant[0] && row[5] === tenant[5] && active(row)
    );
    await sheet.update([
      {
        range: `Tenants!K${tenantIndex + 2}:L${tenantIndex + 2}`,
        values: [["FALSE", checkout]],
      },
      ...(index >= 0 && !stillOccupied
        ? [{ range: `Beds!D${index + 2}`, values: [["VACANT"]] }]
        : []),
    ]);
  } else if (action === "assign_bed") {
    if (!tenant || !active(tenant)) {
      throw new RequestError("This tenant is no longer active.", 409);
    }
    if (tenant[5] === details.bed) return;
    const { index, bed, room } = vacantBed(details.bed);
    const oldIndex = find(beds, tenant[5]);
    const stillOccupied = tenants.some((row) =>
      row[0] && row[0] !== tenant[0] && row[5] === tenant[5] && active(row)
    );
    await sheet.update([
      {
        range: `Tenants!D${tenantIndex + 2}:F${tenantIndex + 2}`,
        values: [[room[1], room[0], bed[0]]],
      },
      { range: `Beds!D${index + 2}`, values: [["OCCUPIED"]] },
      ...(oldIndex >= 0 && !stillOccupied
        ? [{ range: `Beds!D${oldIndex + 2}`, values: [["VACANT"]] }]
        : []),
    ]);
  }
}
