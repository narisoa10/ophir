import { createPlaidWebhookHandler } from "./handler.ts";

Deno.serve(createPlaidWebhookHandler());
