import { createPlaidSandboxFireTransactionWebhookHandler } from "./handler.ts";

Deno.serve(createPlaidSandboxFireTransactionWebhookHandler());
