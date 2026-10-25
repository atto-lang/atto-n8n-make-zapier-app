import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema
namespace Ores.Workflows;

@minLength(1) @maxLength(128)
scalar BoundedId extends string;

@format("uuid")
scalar Uuid extends string;

@minValue(1) @maxValue(2147483647)
scalar PositiveRevision extends int32;

@minLength(1) @maxLength(65536)
scalar PayloadJson extends string;

model RunRequest {
  workflowId: Uuid;
  versionId: Uuid;
  idempotencyKey: BoundedId;
  inputJson: PayloadJson;
}

enum RunStatus { queued, running, waiting, succeeded, failed, cancelled }

model RunView {
  id: Uuid;
  workflowId: Uuid;
  versionId: Uuid;
  status: RunStatus;
}

model ApprovalDecision {
  approvalId: Uuid;
  decision: "approved" | "rejected";
  expectedRevision: PositiveRevision;
}

model SubscribeRun {
  runId: Uuid;
  @pattern("^(0|[1-9][0-9]{0,18})$")
  afterSequence: string;
}
