import { createPlaidProcessTransactionSyncJobsHandler } from "./handler.ts";

Deno.serve(createPlaidProcessTransactionSyncJobsHandler());
