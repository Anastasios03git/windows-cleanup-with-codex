# Windows Cleanup with Codex

Version: **0.2.0** — Windows Cleanup Agent launcher and bundled Codex skill.

A reusable Codex skill for inspecting disk usage and reclaiming space on Windows 10 and Windows 11. It discovers the computer's actual applications and paths, verifies cleanup candidates, and preserves useful data and system functionality.

**Inspection without changes is the default.** A cleanup request enables only its stated scope. Driver updater uninstalls and obsolete driver removal each require explicit authorization.

This is an instruction-based skill, not an executable cleaner or a double-click script. It uses the tools and permissions available in the local Codex environment. Administrator access may be needed for protected Windows operations; the skill does not change permission settings.

## Run the Windows Cleanup Agent

The launcher uses Codex as the agent runtime and the bundled skill as its workflow. Requirements: **Windows, PowerShell 7**, and **Codex CLI** on PATH, authenticated with `codex login`. Keep this repository's files together. You do not need to install the bundled skill separately for the launcher.

Open PowerShell 7 in this repository folder and start inspection:

```powershell
pwsh -File .\Start-WindowsCleanup.ps1
```

Inspection uses `codex exec` with a read-only sandbox. It saves `inspection.md` and a `run.json` manifest in a new `runs/` subfolder, then prints the exact command for the next step. Review the findings and proposed targets first.

### Optional system diagnostics

For system information that the agent's sandbox cannot inspect, enable the fixed diagnostic collector:

```powershell
pwsh -File .\Start-WindowsCleanup.ps1 -SystemDiagnostics
```

Start normally; Windows requests administrator approval for the separate helper. It reads OS/volume information, service states, active work, reboot markers, Delivery Optimization jobs, present-device status, and performs **DISM AnalyzeComponentStore only** when no conflicting servicing/install operation or restart marker is detected. Add `-IncludeDrivers` during inspection to include driver package and signed-driver inventories as well.

The helper performs no cleanup, uninstall, restart, service-configuration change, or execution-policy change. It writes `system-diagnostics.json` and an analysis log in the run folder; DISM also uses Windows servicing facilities for its analysis. Its command list is fixed in `scripts/Get-SystemDiagnostics.ps1` and does not come from model output. Existing output files and paths containing reparse points are rejected.

The launcher passes the timestamped snapshot to Codex as evidence while preserving the read-only agent sandbox. Declining UAC or a collector failure continues basic inspection with an explicit limitation. Individual failed/skipped checks remain visible in the snapshot. The snapshot is hashed alongside the plan, and modifying it requires a fresh inspection before Clean mode.

### Review and clean

Inspection runs Codex without a console window and drains its stdout/stderr concurrently into `inspection-console.log` and `inspection-errors.log`. Only short progress notices appear in the launcher terminal. This avoids streaming verbose native output through the Windows console host. Failed inspections record the error in `run.json`. To keep a newly launched PowerShell window open when the script finishes or fails, start it with `pwsh -NoExit -File .\Start-WindowsCleanup.ps1`. If Codex is interrupted, inspect the saved logs and create a fresh inspection rather than treating partial findings as an approved plan. An `inspecting` manifest alone is not evidence that its worker is still running.

To execute a reviewed plan, use the run directory printed by inspection:

```powershell
pwsh -File .\Start-WindowsCleanup.ps1 -Mode Clean -RunDirectory '.\runs\YOUR-RUN-DIRECTORY'
```

The launcher displays the report again and requires typing `CLEAN`. It then opens an **interactive Codex session**, starting with a read-only sandbox and human permission requests for actions outside it. Keep that terminal open, review requested actions, and allow only those you want. Windows administrator elevation remains separate when needed. The agent rechecks targets and saves `cleanup-report.md` with actual results. A completed CLI session is not itself proof that every target was removed; inspect the final report for skips and failures.

Plans expire after 24 hours. Modified reports, changed skill files, another computer/user, failed inspections, and previously started cleanup sessions require a fresh inspection. File hashes detect accidental plan changes; they are not a security boundary against someone who controls the local files.

Driver removal and application uninstalls are excluded by default. To explicitly include driver operations in the proposed scope, create an inspection with `-IncludeDrivers`, then review and approve that plan in Clean mode. No driver operation is authorized during inspection.

Use `-CodexPath 'C:\path\to\codex.exe'` if Codex CLI is not on PATH. The launcher preserves your configured model. Default run reports are excluded from Git because they contain machine-specific findings; review their contents before sharing them.

See [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode) for the inspection runtime. Clean mode deliberately uses the interactive CLI so permissions can be requested at action time.

## Install the skill locally

In Codex, ask the built-in skill installer:

```text
Use $skill-installer to install the skill from https://github.com/Anastasios03git/windows-cleanup-with-codex/tree/main/skills/windows-cleanup
```

For a local checkout, copy the complete `skills/windows-cleanup` folder into your Codex user skills directory (`$CODEX_HOME/skills`, or `%USERPROFILE%\.codex\skills` when `CODEX_HOME` is unset). Keep its `references` and `agents` subfolders together. Review an existing skill with the same name before replacing it.

If the skill does not appear after installation, restart Codex. See the [official skill documentation](https://learn.chatgpt.com/docs/build-skills) for supported discovery locations and other Codex clients.

## Use

Run the skill on the Windows computer you want to inspect, in a local environment with access to the relevant drives. A cloud sandbox cannot inspect your laptop's disk.

### Inspect without changes

```text
Use $windows-cleanup to inspect my Windows disk usage. Report verified cleanup candidates, estimated sizes, and items to preserve. Do not delete files, uninstall software, stop services, or change settings.
```

### Clean verified temporary data

```text
Use $windows-cleanup to inspect first, then clean verified disposable caches, temporary files, and completed installers. Include supported Windows component cleanup only if analysis recommends it. Preserve my applications, personal files, projects, browser data other than cache, and restore points. Do not uninstall driver updater tools or remove driver packages. Report actual disk space before and after, removals, and skipped items.
```

### Include driver operations explicitly

```text
Use $windows-cleanup to inspect and clean verified disposable data. Also uninstall the standalone driver updater tools you identify and remove verified older inactive driver packages using the skill's safeguards. Preserve active drivers, unrelated hardware utilities, my other applications, personal files, projects, and restore points. Report device status, removals, skipped items, and actual disk space before and after.
```

Do not copy INF identifiers, uninstall product codes, or file paths from another computer. The agent must discover and verify them locally.

## What it preserves

- Personal files, source projects, AI models, application settings, saves, and recovery data.
- Browser cookies, passwords, bookmarks, history, extensions, website storage, and offline data.
- Active drivers, boot/storage drivers, and packages without a verified newer active counterpart.
- Restore points, recovery partitions, paging, hibernation, Windows updates, and security settings.
- Useful runtimes, virtual machines, Linux/container environments, and unidentified data.
- Recycle Bin contents unless emptying it is specifically requested.

It does not blanket-empty Temp or Downloads, manually delete Driver Store or WinSxS files, force removal of in-use drivers, or promise a particular space saving.

## Example and validation

The [original owner-reported example](examples/example-run.md) records about **15.8 GiB** net reduction (about **17.0 GB** decimal). It predates this packaged skill and is not a controlled benchmark or a validation run for this version.

See [package validation](VALIDATION.md) for completed structural checks, independent desk simulations, a limited authorized Windows run, and remaining Windows/VM validation.

Version 0.2.0 has been exercised on the owner's Windows 10 laptop with real Inspect, administrator-approved diagnostics, and interactive Clean checks. Clean correctly retained active Edge caches and deferred component work when a pending updater operation was found. No deletion was performed in that launcher run; successful removal through the launcher remains to be validated.

Before recommending the skill for broader use, test inspection and a limited cleanup on another Windows computer or a disposable VM. Check that running applications, active updates, useful data, and paths outside the authorized target are preserved. Never use a production cleanup merely to test the package.

## Repository layout

```text
skills/windows-cleanup/
  SKILL.md
  agents/openai.yaml
  references/
    inspection-and-reporting.md
    data-cleanup.md
    drivers.md
    windows-components.md
examples/example-run.md
Start-WindowsCleanup.ps1
tests/Test-Launcher.ps1
scripts/Get-SystemDiagnostics.ps1
tests/Test-SystemDiagnostics.ps1
```

Detailed procedures and Microsoft source links live inside the skill so it remains self-contained after installation. The README and historical example are for repository readers.
