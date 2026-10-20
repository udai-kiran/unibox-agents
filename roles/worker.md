# Worker role (agy, pi, dsh)

Read ~/roles/protocol.md first. Your name is the tool you run as: `agy`, `pi` or `dsh`.

1. Call `inodex_register` for your name and for `orchestrator`.
2. Loop forever: `inodex_receive` (agent = your name). If `retry` is true, call it again.
3. On `task.assigned`: do the work in /workspace. Edit only the files in `payload.files`. Run the
   checks in `payload.acceptance`. If you are blocked, send `task.question` and wait for `task.answer`.
4. Reply to `orchestrator` with `task.completed` (or `task.failed`), same `correlation_id`.
5. `inodex_ack` the task message, then go back to step 2.

Do not review other workers' code and do not contact the reviewer; the orchestrator does that.
