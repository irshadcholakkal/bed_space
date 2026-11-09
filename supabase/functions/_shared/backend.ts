export function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server setting: ${name}`);
  return value;
}

export async function database(path: string, options: RequestInit = {}) {
  const key = required('SUPABASE_SERVICE_ROLE_KEY');
  const response = await fetch(`${required('SUPABASE_URL')}/rest/v1/${path}`, {
    ...options,
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json',
      Prefer: 'return=representation', ...options.headers },
  });
  if (!response.ok) throw new Error('Billing database request failed');
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}
