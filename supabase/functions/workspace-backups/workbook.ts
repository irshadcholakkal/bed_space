const drive = "https://www.googleapis.com/drive/v3/files";
const sheets = "https://sheets.googleapis.com/v4/spreadsheets";
const spreadsheetMime = "application/vnd.google-apps.spreadsheet";

const headers = {
  Buildings: "building_id building_name address total_rooms",
  Rooms:
    "room_id building_id room_number total_capacity lower_beds_count upper_beds_count lower_bed_rent upper_bed_rent utility_cost_monthly monthly_rent parent_room_id available media_json room_type",
  Beds: "bed_id room_id bed_type status",
  Tenants:
    "tenant_id tenant_name phone building_id room_id bed_id rent_amount advance_amount joining_date rent_due_day active checkout_date",
  Payments: "payment_id tenant_id amount payment_month paid_date",
  Expenses: "id room_id expense_type amount date description tenant_id",
  Bookings:
    "booking_id tenant_name phone building_id room_id bed_id move_in_date rent_amount advance_amount rent_paid payment_date rent_due_day status refund_amount",
};
type Tab = keyof typeof headers;
type Cell = string | number | boolean;
type Tabs = Record<Tab, Cell[][]>;
type Grid = { rowCount: number; columnCount: number };
type Sheet = {
  sheetId: number;
  title: string;
  sheetType: string;
  gridProperties?: Grid;
};

const tabNames = Object.keys(headers) as Tab[];
const firstHeader = (tab: Tab) => headers[tab].split(" ")[0];

export class RecoveryError extends Error {}

async function google<T>(url: string, token: string, body?: object) {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "Cache-Control": "no-cache",
    },
    ...(body && { method: "POST", body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) {
    throw new Error(`Google request failed (${response.status})`);
  }
  return await response.json() as T;
}

async function sheetMetadata(id: string, token: string) {
  const query = new URLSearchParams({
    fields:
      "sheets(properties(sheetId,title,sheetType,gridProperties(rowCount,columnCount))",
  });
  const workbook = await google<{ sheets: { properties: Sheet }[] }>(
    `${sheets}/${encodeURIComponent(id)}?${query}`,
    token,
  );
  return workbook.sheets.map((sheet) => sheet.properties);
}

export async function readTabs(id: string, token: string): Promise<Tabs> {
  const metadata = await sheetMetadata(id, token);
  const titles = tabNames.filter((tab) =>
    metadata.some((sheet) => sheet.title === tab && sheet.sheetType === "GRID")
  );
  if (tabNames.some((tab) => tab !== "Bookings" && !titles.includes(tab))) {
    throw new RecoveryError("A required workspace tab is missing.");
  }
  const query = new URLSearchParams({ valueRenderOption: "UNFORMATTED_VALUE" });
  for (const tab of titles) query.append("ranges", `'${tab}'`);
  const result = await google<{ valueRanges: { values?: Cell[][] }[] }>(
    `${sheets}/${encodeURIComponent(id)}/values:batchGet?${query}`,
    token,
  );
  const tabs = Object.fromEntries(titles.map((tab, index) => [
    tab,
    result.valueRanges[index]?.values,
  ]));
  // Workspaces created before bookings had six tabs.
  if (!titles.includes("Bookings")) {
    tabs.Bookings = [headers.Bookings.split(" ")];
  }
  return validateTabs(tabs);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateTabs(input: unknown): Tabs {
  if (!isRecord(input) || Object.keys(input).length !== tabNames.length) {
    throw new RecoveryError(
      "The recovery data must include every workspace tab.",
    );
  }
  for (const tab of tabNames) {
    const rows = input[tab];
    if (
      !Array.isArray(rows) || !Array.isArray(rows[0]) ||
      rows[0][0] !== firstHeader(tab) ||
      !rows.every((row) =>
        Array.isArray(row) &&
        row.every((cell) =>
          typeof cell === "string" || typeof cell === "boolean" ||
          (typeof cell === "number" && Number.isFinite(cell))
        )
      )
    ) {
      throw new RecoveryError(`Invalid workspace data in the ${tab} tab.`);
    }
  }
  return input as Tabs;
}

export function recoveryFile(owner: string, tabs: Tabs) {
  return { format: "bed-space-recovery", version: 1, owner, tabs };
}

export function readRecoveryFile(owner: string, file: unknown) {
  if (
    !isRecord(file) || file.format !== "bed-space-recovery" ||
    file.version !== 1
  ) {
    throw new RecoveryError("Choose a Bed Space recovery JSON file.");
  }
  if (file.owner !== owner) {
    throw new RecoveryError(
      "This recovery file belongs to a different account.",
    );
  }
  return validateTabs(file.tabs);
}

export function counts(tabs: Tabs) {
  return Object.fromEntries(
    tabNames.map((
      tab,
    ) => [
      tab,
      tabs[tab].slice(1).filter((row) => row[0] !== "" && row[0] != null)
        .length,
    ]),
  );
}

function cellValue(cell: Cell) {
  if (typeof cell === "number") return { numberValue: cell };
  if (typeof cell === "boolean") return { boolValue: cell };
  return { stringValue: cell };
}

export async function replaceTabs(
  id: string,
  token: string,
  tabs: Tabs,
  isBackup = false,
) {
  const metadata = await sheetMetadata(id, token);
  let nextId = 1;
  const usedIds = new Set(metadata.map((sheet) => sheet.sheetId));
  const requests: object[] = [];
  const hasWorkspaceTabs = metadata.some((sheet) =>
    tabNames.includes(sheet.title as Tab)
  );

  for (const tab of tabNames) {
    const rows = tabs[tab];
    const existing = metadata.find((sheet) => sheet.title === tab);
    if (existing && !existing.gridProperties) {
      throw new RecoveryError(`The ${tab} tab must be a grid.`);
    }

    while (usedIds.has(nextId)) nextId++;
    const sheetId = existing?.sheetId ?? nextId++;
    const grid = existing?.gridProperties;
    const rowCount = Math.max(grid?.rowCount ?? 1000, rows.length);
    const columnCount = rows.reduce(
      (width, row) => Math.max(width, row.length),
      Math.max(grid?.columnCount ?? 0, headers[tab].split(" ").length),
    );
    const gridProperties = { rowCount, columnCount };
    if (!existing) {
      requests.push({
        addSheet: { properties: { sheetId, title: tab, gridProperties } },
      });
    } else if (
      grid?.rowCount !== rowCount || grid.columnCount !== columnCount
    ) {
      requests.push({
        updateSheetProperties: {
          properties: { sheetId, gridProperties },
          fields: "gridProperties(rowCount,columnCount)",
        },
      });
    }

    // An explicit grid range clears stale values past the incoming rows.
    requests.push({
      updateCells: {
        range: {
          sheetId,
          startRowIndex: 0,
          endRowIndex: rowCount,
          startColumnIndex: 0,
          endColumnIndex: columnCount,
        },
        rows: rows.map((row) => ({
          values: row.map((cell) => ({ userEnteredValue: cellValue(cell) })),
        })),
        fields: "userEnteredValue",
      },
    });
  }
  if (isBackup) {
    requests.push({
      updateSpreadsheetProperties: {
        properties: { title: "Backup" },
        fields: "title",
      },
    });
    if (!hasWorkspaceTabs && metadata.length === 1) {
      requests.push({ deleteSheet: { sheetId: metadata[0].sheetId } });
    }
  }
  await google(`${sheets}/${encodeURIComponent(id)}:batchUpdate`, token, {
    requests,
  });
}

export async function findBackup(owner: string, token: string) {
  const query = new URLSearchParams({
    q: `trashed = false and mimeType = '${spreadsheetMime}' and 'me' in owners and appProperties has { key='bedSpaceBackupOwner' and value='${owner}' }`,
    fields: "files(id)",
    pageSize: "1",
    orderBy: "createdTime",
  });
  const result = await google<{ files: { id: string }[] }>(
    `${drive}?${query}`,
    token,
  );
  return result.files[0]?.id;
}

export async function refreshBackup(
  owner: string,
  source: string,
  token: string,
) {
  const tabs = await readTabs(source, token);
  const existing = await findBackup(owner, token);
  const destination = existing ?? (await google<{ id: string }>(
    `${drive}?fields=id&ignoreDefaultVisibility=true`,
    token,
    {
      name: "Backup",
      mimeType: spreadsheetMime,
      parents: ["root"],
      appProperties: { bedSpaceBackupOwner: owner },
    },
  )).id;
  if (destination === source) {
    throw new RecoveryError("The backup cannot be the live workspace.");
  }
  await replaceTabs(destination, token, tabs, true);
  return destination;
}
