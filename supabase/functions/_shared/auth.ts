export type AuthenticatedUser = {
  id: string;
};

export async function authenticateRequest(
  request: Request,
): Promise<AuthenticatedUser | null> {
  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!authorization || !supabaseUrl || !anonKey) {
    return null;
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: anonKey,
    },
  });

  if (!response.ok) {
    return null;
  }

  const data = await response.json();
  const id = data?.id;

  if (typeof id !== "string" || id.length === 0) {
    return null;
  }

  return { id };
}
