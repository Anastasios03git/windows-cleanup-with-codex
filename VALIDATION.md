# Package validation

Consolidated version **0.2.0**, validated on 2026-10-30. The original guide remains in repository commit `4f7f79f`.

## Previous documented cleanup

Before packaging the workflow as a skill, the [original guide's recorded run](examples/example-run.md) reported approximately **15.8 GiB** net space recovery. It included browser cache, superseded Windows components, old installers, diagnostic logs, driver updater tools, and **12 verified obsolete driver packages**.

These procedures therefore have prior documented use. The distinction below is whether they were repeated after packaging as a skill; a missing repeat does not mean the procedure has never been used. The historical run remains an owner-reported interactive session, not a controlled benchmark.

## Completed checks

- The bundled `skill-creator` validator accepts the skill's name, YAML frontmatter, and instruction structure.
- All eight original instruction sections are preserved verbatim in the supporting references.
- Local Markdown links resolve, and skill references stay inside the installable folder.
- UI metadata parses as YAML, the summary meets its length constraint, and the default prompt invokes `$windows-cleanup` for inspection without changes.
- Automatic skill discovery remains enabled by default.
- The original owner-reported example is preserved separately and labeled as historical.
- `git diff --check` passes.

## Independent desk simulations

An independent agent read the skill and supporting references and applied them to three synthetic requests. No live system inspection, cleanup, service changes, uninstalls, or driver operations were performed.

| Request and evidence | Decision |
| --- | --- |
| Inspection request; running browser; update downloads with unknown status | Report findings; perform no cleanup or other mutation. |
| Cache and completed-installer cleanup only; one verified completed installer; open browser; build cache with missing source project; cache junction to photos; installed driver updater | Only the verified installer is eligible. Keep unresolved/useful data and paths outside the authorized target. Browser filesystem cleanup waits until closed; supported browser-only cache clearing still needs verification. Do not uninstall applications or remove drivers. |
| Explicit old-driver cleanup; one verified inactive display package with a newer active counterpart; storage driver; unmatched packages; package reported in use; unmatched package for a non-present device | Only the fully verified inactive display package is eligible after final checks. Preserve storage, unmatched, non-present-device, and in-use packages. Do not claim removal without execution results. |

The review found one scope wording ambiguity. The skill now states that narrower limits persist unless the user explicitly changes them.

## Limited authorized Windows run

After the synthetic checks, the owner separately requested a read-only inspection and then cleanup on Windows 10 Home, version 10.0.19045. The local skill was used for that authorized work.

- The inspection identified completed, unpinned Delivery Optimization cache entries and verified that no Delivery Optimization job was downloading.
- Targeted `Delete-DeliveryOptimizationCache -FileId ... -Force` operations succeeded for both verified entries. A fresh status query returned no remaining jobs.
- The observed net increase in free space was approximately **0.80 GiB**. Background Windows activity may affect the net measurement; this is not a controlled benchmark or a promised result.
- The browser was running. Browser filesystem cache deletion was skipped. An attempted built-in browser cleanup was stopped by the UI automation tool's URL-verification safeguard; browser cache was left intact and the limitation was reported.
- Windows servicing was active, so update-download files and servicing logs were retained. Arduino build data associated with missing or temporary source locations was also retained.
- No applications or driver packages were removed, no service settings were changed, and no restart was requested by the cleanup.

This run provides runtime evidence for targeted Delivery Optimization cleanup in one environment. It does not establish the behavior of the other cleanup categories or systems.

## Broader authorized workflow run

The owner subsequently requested the full workflow on the same Windows 10 computer. The browser was closed by the owner before filesystem cache cleanup. The inspection covered caches, installers/logs, Windows components, updater utilities, and driver packages; actions were limited to verified eligible targets.

| Category | Observed result |
| --- | --- |
| Microsoft Edge cache | Removed **3,469 files**, approximately **256.2 MiB**, from verified Cache, Code Cache, GPUCache, and shader-cache locations across the discovered profiles. No deletion errors. Lengths and modification timestamps of 16 protected browser files were unchanged; cookies, passwords, history, bookmarks, settings, and website storage were outside the deletion targets. |
| Delivery Optimization | Removed 5 completed, unpinned entries through the supported cmdlet, approximately **8.7 MiB**. No remaining jobs in the final query. |
| Historical Windows Setup logs | Removed 3 identified, unlocked logs from the completed installation, approximately **213.7 MiB**. Exact files were SetupAct.log.bak, SetupAct.log, and MigLog.xml in the actual Windows Panther directory. Each was more than 30 days old; no setup/deployment process was running. Configuration, recovery, and other Panther contents were preserved. |
| Windows components | Elevated DISM analysis recommended cleanup. Standard StartComponentCleanup with NoRestart returned **exit code 0** and a success message. Post-analysis also returned exit code 0. It still reported **1 reclaimable package** and recommended cleanup; no repeat cleanup or forced removal was attempted. |
| Completed installers | No eligible installer downloads were present. Arduino staging was empty. No installed package libraries or application repair caches were deleted. |
| Driver updater utilities | No installed standalone updater was identified for uninstall. Hardware drivers, control panels, and unrelated utilities were retained. |
| Obsolete driver packages | Inspected **122 third-party packages**, active signed drivers, and assignments including non-present devices. No package met all removal criteria. Same-version Bluetooth variants, hardware-specific audio packages, and unresolved extension/component dependencies were retained. No driver removal was attempted. |
| Other temporary/application data | Preserved Arduino build data with missing or temporary source locations, unsaved/recovery locations, WSL, application runtimes, and unresolved update-download contents. |

The OS reported free space increasing from **156.305 GiB** to **156.520 GiB**, a net **219.4 MiB**. These before/after readings cover this later run only. File lengths removed are not equivalent to physical space reclaimed, and background activity can affect the net measurement. No particular saving is promised.

The final device inspection found no device errors. All **29 active third-party signed driver assignments and versions** matched the initial snapshot. No restart was requested. Services, recovery features, security settings, execution policies, and installed applications were not changed.

## Scope of validation

### Launcher integration tests

The PowerShell 7 launcher was tested with a simulated Codex executable in an isolated directory, including paths containing spaces. Tests covered inspection output, cancellation before cleanup, explicit approval, interactive sandbox/approval arguments, report generation, replay rejection, modified/expired/foreign-computer plans, CLI failures, and missing final reports. No live model run or Windows cleanup was performed by these launcher tests.

To repeat the simulation, use PowerShell 7 with a new test directory outside the repository:

```powershell
pwsh -File .\tests\Test-Launcher.ps1 -TestRoot 'C:\path\to\new-test-folder'
```

CLI argument support was checked against the installed Codex CLI 0.165.0-alpha.1.2 help. The Windows cleanup runs recorded earlier in this document refer to the skill used directly. Launcher session completion is recorded separately from cleanup success, which must be assessed from its report.

### Console isolation and live inspection

Two initial live inspection attempts ended before a report was saved. Windows Application events from the second attempt recorded crashes of conhost.exe and PowerShell ConsoleHost. Keeping PowerShell open with NoExit did not prevent that crash.

The launcher starts the inspection worker without a console window and asynchronously copies stdout and stderr to separate log files. Only short progress notices are printed in the parent terminal. Integration tests passed with simultaneous large Unicode output on both streams, alongside the previous plan-validation and failure-handling scenarios.

A subsequent real-model inspection completed successfully: Codex exited with code 0, produced a nonempty inspection report, and the launcher saved a matching SHA-256 plan hash with status `review_required`. No further conhost/PowerShell crash was recorded during that run. The resulting report explicitly retained inaccessible and unresolved items; some volume, service, and device inspection queries were denied by the read-only sandbox. No cleanup or elevation was performed.

This validates the live inspection path in the tested environment. Interactive Clean mode also has the real guarded execution recorded below, in addition to simulated CLI integration tests. Console isolation should not be taken as proof that every possible console-host crash has been resolved.

### Optional system diagnostics

The optional `-SystemDiagnostics` step uses a separate fixed PowerShell helper with Windows administrator approval. The model receives its snapshot as evidence and remains in the read-only sandbox. The helper has no cleanup/uninstall/restart operation and never changes execution policy or service configuration.

Mock integration checks cover a completed snapshot, partial results, cancelled UAC, missing output, invalid request identity, preservation of the agent sandbox, and rejection of a modified snapshot before cleanup. The existing launcher tests also pass.

A real administrator-approved run of the helper completed all eight default diagnostic groups without recorded errors on the local Windows 10 computer. It collected OS/volume readings, service states, active-work information, reboot markers, Delivery Optimization status, and present-device status. DISM AnalyzeComponentStore completed with exit code 0. Only diagnostics were performed. The optional additional driver inventories were not repeated as part of this feature test. The combined live model run using the snapshot is recorded below.

### Final combined laptop inspection

A final run on the owner's Windows 10 laptop completed the complete Inspect pipeline: Windows administrator approval for the fixed diagnostics helper, all eight default diagnostic groups, and then a real Codex inspection inside the read-only sandbox using that snapshot. DISM analysis returned exit code 0, and the collector recorded no errors.

Codex produced a nonempty inspection report, and the launcher recorded status `review_required` with matching SHA-256 hashes for the report and diagnostic snapshot. The final report was reviewed to confirm that the collector's volume/system observations were available to the agent and that protected or unresolved items were retained. No cleanup was requested or performed in this final pipeline test.

The executable logic tested here is the logic in the consolidated package. The final packaging step unified version labels and documentation; it did not change that execution logic. Prior run manifests remain tied to the earlier skill digest, so start a fresh inspection before using Clean mode with the consolidated package.

### Real interactive Clean validation

On 2026-10-30, the owner launched Inspect with system diagnostics and then approved the resulting plan through the launcher's interactive Clean mode on the same Windows 10 laptop. The agent generated a cleanup report after fresh activity checks and a separately approved administrator preflight.

Both proposed categories were correctly retained under the preservation rules:

- Edge cache: approximately 171 MiB was measured, but Edge was still running. No cache-clearing operation or browser termination was performed.
- Superseded Windows components: the administrator preflight found a pending Edge updater file operation. Fresh component analysis and cleanup were deferred instead of relying on the earlier recommendation.

No files were deleted, no applications or drivers were removed, and no services were changed. Measured free space decreased by 6,381,568 bytes (about 6.09 MiB) during observation and report generation; this is not cleanup recovery. An initial non-elevated DISM analysis returned error 740; the subsequent administrator preflight correctly skipped component work because of the pending operation.

This is real validation of the interactive Clean entry path, permissions/preflight checks, preservation decisions, and factual report generation. It does not validate successful removal through the launcher: neither cleanup operation started. At report review, the manifest still recorded `session_started`, so a successful CLI exit and launcher finalization are not asserted. Successful removal through the launcher, the optional driver paths, and operation on another computer/VM still need their own evidence.

### Skill workflow evidence

The original workflow has the broader recorded use described above. After packaging, the skill has also completed structural checks, synthetic decision checks, Delivery Optimization cleanup, closed-browser cache cleanup, selected historical log cleanup, and elevated standard DISM cleanup in the local environment.

The later run exercised the inspection and preservation paths for driver packages and updater utilities, but did not repeat their removal/uninstall paths because no eligible targets existed. Those operations retain their historical evidence; they have not been repeated with the packaged skill. Operation on a different computer/VM also remains to be checked.

DISM command success should not be interpreted as removal of every reclaimable package: the remaining package is explicitly reported above. Further testing should use eligible targets in an authorized environment rather than force removals merely to exercise a branch.
