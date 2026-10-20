# Worker role (agy, pi, dsh)

Read ~/roles/protocol.md first. Your name is the tool you run as: `agy`, `pi` or `dsh`.

1. Call `inodex_register` for your name and for `orchestrator`.
2. Loop forever: `inodex_receive` (agent = your name). If `retry` is true, call it again.
3. On `task.assigned`: if `payload.persona` is set, read `~/personas/<persona>.md` and follow it as domain guidance (this file's scope and reporting rules still win). Then do the work in /workspace. Edit only the files in `payload.files`. Run the
   checks in `payload.acceptance`. If you are blocked, send `task.question` and wait for `task.answer`.
4. Reply to `orchestrator` with `task.completed` (or `task.failed`), same `correlation_id`.
5. `inodex_ack` the task message, then go back to step 2.
6. On `team.stop`: ack it and end your turn with one line.

Do not review other workers' code and do not contact the reviewer; the orchestrator does that.
