---
name: windows-cleanup
description: Inspect Windows disk usage and reclaim space from verified disposable caches, completed installers, and superseded components. Use for Windows disk cleanup requests, including explicitly requested driver cleanup; not for generic performance tuning or non-Windows systems.
metadata:
  version: "0.3.0"
---

# Windows Cleanup

Reclaim disk space from evidence collected on the current Windows computer, while preserving useful data, installed applications outside the requested scope, active drivers, and recovery features.

## Select the scope

- Default to inspection without changes when the user asks for an audit, findings, or simply invokes this skill without a cleanup request. Do not delete files, uninstall software, stop services, or run cleanup commands in this mode.
- A clear cleanup request authorizes verified disposable data within the user's stated scope. Explain the concrete targets before acting, then proceed without repeatedly requesting the same permission. Inspection is always required first.
- Uninstall driver updater tools and remove obsolete driver packages only when the user explicitly includes the respective operation. General disk cleanup does not include either operation.
- Preserve narrower limits across follow-up requests unless the user explicitly changes them. Installing or invoking the skill does not itself authorize cleanup. Creating or testing this skill does not authorize cleaning the author's computer.

## Inspect and identify candidates

Read [inspection-and-reporting.md](references/inspection-and-reporting.md) before inspecting or changing the computer. It contains the complete preservation rules, path and permission checks, measurement requirements, and final report format.

1. Confirm Windows and discover the actual system volume, Windows directory, user profile, and Downloads location. Do not apply host Windows commands to WSL/Linux or infer the target from another computer's report.
2. Record total, used, and free disk space, plus relevant running work and device status. Respect the user's requested drives and categories.
3. Read [data-cleanup.md](references/data-cleanup.md) when evaluating temporary files, browser/update caches, installers, or application leftovers. Classify each candidate by evidence: disposable, in use, useful/protected, or unresolved. Unknown size or purpose is not evidence of junk.
4. For Windows component-store analysis or cleanup, read [windows-components.md](references/windows-components.md). Analysis can be part of an inspection; cleanup requires a cleanup request covering that category.
5. Read [drivers.md](references/drivers.md) when inspecting driver-related candidates or performing the explicitly requested driver operations. Use a fresh local inventory, including non-present devices where available.

In inspection mode, finish with findings and proposed actions. Do not run a cleanup operation merely to estimate its result. Report when a protected read-only inspection needs elevation and cannot be completed in the current environment.

## Execute authorized work

Apply the detailed procedure in the relevant reference before each category of cleanup. Verify command support on the target Windows version and consult the linked Microsoft or application documentation when needed.

- Resolve each exact target and check for junctions, symlinks, and reparse points leading elsewhere before recursive deletion. Keep enumeration and deletion in one shell, using literal paths.
- Use terminating errors and bounded traversal with a progress check for filesystem loops. For parent traversal use `System.IO.Directory.GetParent`; do not combine `Split-Path -LiteralPath` with `-Parent`. Stop on an error or unchanged parent instead of repeating it indefinitely.
- Skip active downloads, updates, installers, builds, open files, and unresolved targets. Do not terminate the user's applications to reclaim cache space.
- Keep personal files, source projects, AI models, application settings, browser sessions/site storage, recovery data, restore points, and virtual environments unless the user separately requests a specific operation on them.
- Never blanket-empty Temp or Downloads. Do not delete Driver Store, WinSxS, Windows Installer, or shared package-cache files manually; use the documented supported mechanism for the specific authorized operation.
- Do not disable updates, security, hibernation, Fast Startup, paging, or services to manufacture free space. Restore temporarily stopped update services to their recorded states in `finally`; do not change startup types.
- Follow the current environment's permissions and permitted elevation process. Prepare concrete administrator actions for review when the environment requires it. Do not bypass a rejected operation or broaden ownership/ACL changes to clear protected leftovers.
- For driver removal, require the verified newer active counterpart and all checks in the driver reference. Never use `pnputil` with `/force`, `/uninstall`, or `/reboot` for this cleanup.
- For component cleanup, analyze first and use standard supported cleanup only when recommended. Never use `/ResetBase` or `/SPSuperseded`; do not run concurrent DISM operations or interrupt a progressing operation merely because its percentage appears stuck.

## Verify and report

Measure the same volumes again through the OS. Report actual before/after readings and net change with consistent units; item sizes are estimates, not measured space recovered. Account accurately for partial success and background disk activity.

Use the report format in the inspection reference, adapted to the requested scope:

- In inspection mode, show candidate sizes, evidence, proposed actions, exclusions, and uncertainties; state that no cleanup was performed. Before/after cleanup results do not apply.
- In cleanup mode, list what was actually removed, skipped items and reasons, failed or incomplete operations, and any restart requested by Windows. Never restart automatically.
- If drivers were inspected or changed, report the observed device status and verify active driver versions after changes. Otherwise mark driver checks as not performed.

Stop when no further large, clearly disposable items remain within scope. Keep protected, uncertain, and in-use leftovers; report them instead of escalating or repeating cleanup indefinitely.
