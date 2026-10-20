# Team protocol (shared by every agent)

Agents talk only through the inodex MCP tools. inodex cannot interrupt a busy agent: it
only wakes one that is blocked in `inodex_receive`. So every non-orchestrator agent
spends its idle time in a receive loop.

## Agents (inbox names)

| Name           | Tool   | Role                                          |
| -------------- | ------ | --------------------------------------------- |
| `orchestrator` | claude | Plans, assigns tasks, decides, talks to user  |
| `reviewer`     | codex  | Reviews worker output, read-only              |
| `agy`          | agy    | Worker                                        |
| `pi`           | pi     | Worker                                        |
| `dsh`          | dsh    | Worker                                        |

Start by calling `inodex_register` for your own name and for every name you will send to
(registering twice is harmless; sending to an unregistered name fails).

## Messages

`correlation_id` is the task id (`T-1`, `T-2`, ...). Use the same one for every message about
that task. `payload` is JSON.

| type               | from -> to                | payload                                                    |
| ------------------ | ------------------------- | ---------------------------------------------------------- |
| `task.assigned`    | orchestrator -> worker    | `goal`, `files` (the only files the worker may edit), `acceptance`, `notes`, optional `persona` (file in `~/personas/`, e.g. `python-pro`) |
| `task.completed`   | worker -> orchestrator    | `summary`, `files_changed`, `checks_run`                   |
| `task.failed`      | worker -> orchestrator    | `reason`, `what_was_tried`                                 |
| `task.question`    | worker -> orchestrator    | `question` (then wait for `task.answer`)                   |
| `task.answer`      | orchestrator -> worker    | `answer`                                                   |
| `review.requested` | orchestrator -> reviewer  | `task_id`, `worker`, `files_changed`, `acceptance`, `round`, `kind` (`correctness` or `adversarial`) |
| `review.result`    | reviewer -> orchestrator  | `verdict` (`approve` or `changes_requested`), `findings` (each with a `quote`), `round` (echoed), `evidence` (on approve) |
| `team.stop`        | orchestrator -> everyone  | `{}` - ack it, reply with one line of text, and end your turn |

Flow: orchestrator assigns -> worker finishes (`task.completed`) -> orchestrator sends
`review.requested` -> reviewer answers -> on `changes_requested` the orchestrator sends a new
`task.assigned` to the same worker with the findings in `notes`.

## Evidence

Every finding in a `review.result` needs a `quote`: the line from the file, as you read it, that
shows the problem (`{"file": "a.py", "line": 7, "problem": "...", "quote": "return x"}`). An
`approve` needs `evidence`: one quoted line for each acceptance criterion, showing it is met. A
finding whose quote does not show the problem, or a verdict without quotes, is treated as not reviewed.
Do not raise a finding about something the file already does.

## Rules

- Delivery is at-least-once. If you see a `correlation_id` + `type` you already handled, just ack it.
- Ack a message only after you have sent your reply.
- Work longer than a minute: call `inodex_extend` on the message id every minute.
- `inodex_receive` returning `retry: true` means nothing arrived: call it again.
- Everyone shares one checkout at /workspace. Edit only the files your task lists.
- Never ask another agent to delegate further; only the orchestrator assigns work.
- Stay in your receive loop until `team.stop` arrives. After acking it, end your turn.
- Send messages only as yourself (`from` is your own name). Never send as another agent.
