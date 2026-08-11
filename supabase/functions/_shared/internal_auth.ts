const internalSecretHeader = "x-ophir-internal-secret";
const internalSecretEnvName = "OPHIR_INTERNAL_WORKER_SECRET";

function constantTimeEquals(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const maxLength = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < maxLength; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return difference === 0;
}

export function authorizeInternalRequest(
  request: Request,
  getEnv: (name: string) => string | undefined,
): "authorized" | "unauthorized" | "config_missing" {
  const expectedSecret = getEnv(internalSecretEnvName);
  if (typeof expectedSecret !== "string" || expectedSecret.length === 0) {
    return "config_missing";
  }

  const receivedSecret = request.headers.get(internalSecretHeader);
  if (
    receivedSecret === null ||
    !constantTimeEquals(receivedSecret, expectedSecret)
  ) {
    return "unauthorized";
  }

  return "authorized";
}
