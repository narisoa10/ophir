import { createPlaidSandboxTransactionsRefreshHandler } from "./handler.ts";

Deno.serve(createPlaidSandboxTransactionsRefreshHandler());
