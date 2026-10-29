# Windows Cleanup with Codex

A portable instruction file for reclaiming disk space on Windows 10 and Windows 11 with Codex. Discover what is actually installed and stored on each computer, then identify verified temporary files, redundant installation downloads, application caches, and other eligible cleanup targets. No particular application or hardware brand is required.

It preserves personal files, projects, installed applications outside the approved uninstall scope, active drivers, and recovery features.

**This README contains instructions for an agent. It is not a script to execute by double-clicking.**

## Example run: "almost 20 GB" on a recently formatted laptop

> "It cleaned up almost 20 GB on my recently formatted laptop."
>
> — The laptop owner's description of the example run

The run used the following configuration, as reported by the owner:

| Setting | Value |
| --- | --- |
| Model | **GPT-6.1 Sol** (`gpt-6.1-sol`) |
| Reasoning effort | **High** (`high`) |
| Codex permissions | **Full access** |
| Operating system | Windows 10 |
| Device context | A laptop that had recently been formatted and had Windows reinstalled |

Windows administrator elevation was still required for some protected operations. Full access was the configuration used in this example; this document does not override the permissions or approval rules of another Codex environment.

### Recorded disk-space measurements

| System drive | Before cleanup | After cleanup |
| --- | ---: | ---: |
| Used space | Approximately 88.91 GiB | Approximately 73.07 GiB |
| Free space | Approximately 148.45 GiB | Approximately 164.29 GiB |

The recorded net reduction was approximately **15.8 GiB**, equivalent to about **17.0 GB in decimal units**. "Almost 20 GB" is the owner's rounded description of this result, not a measured 20 GB or a promised result for other computers. These were snapshots from an interactive cleanup session, not a controlled benchmark; Windows updates and other background activity can change disk usage during the work.

The example cleanup included Delivery Optimization cache, superseded Windows components, old installers, browser cache, diagnostic logs, driver updater tools, and **12 verified obsolete driver packages**. Some leftovers from already-uninstalled applications were also removed after the owner specifically approved those items.

## How to use

1. Download this file, or copy its contents into a Markdown file.
2. Attach it to Codex on the Windows computer you want to inspect and clean.
3. Send the following request:

> Follow the instructions in the attached file on my computer. Inspect first, then clean verified temporary files and old installers. Also uninstall the driver updater tools you identify and remove verified older, inactive driver packages using the safeguards described in the file. Keep my other applications, personal files, projects, and restore points. Finish with a table showing what was removed, what was skipped, and the actual disk-space measurements before and after.

For an inspection without changes, instead say:

> Follow the inspection steps in this file and report your findings. Do not delete files, uninstall software, or change settings.

The file alone is not authorization to delete anything. Follow the human user's actual request and any narrower scope they specify.

---

## Instructions for Codex

### 1. Inspect this computer first

- Confirm that the operating system is Windows. Do not apply these Windows commands to another operating system.
- Resolve the actual user profile, system drive, Windows directory, and Downloads folder. Downloads may have been relocated to another drive.
- Do not reuse another user's paths, hardware model, uninstall product codes, or `oem*.inf` identifiers.
- Record total, used, and free space before making changes.
- If driver cleanup is authorized, inventory the devices and drivers actually present, including device name, version, and INF. Record any device errors.
- Check for running installers, updates, downloads, builds, or other work using the candidate locations.
- Give a short explanation of the verified cleanup targets before acting. Proceed within the authorized scope without repeatedly asking for the same approval.

A file's age, a folder named `cache`, an `.old` suffix, or the absence of an application from one inventory is not enough to establish that an item is disposable.

### 2. Clean verified temporary data

#### Delivery Optimization

- Prefer the supported Windows cleanup mechanism: Disk Cleanup's **Delivery Optimization Files** category, or the cmdlet available on that system.
- Inspect jobs first with `Get-DeliveryOptimizationStatus`.
- Use `Delete-DeliveryOptimizationCache -Force` only when there are no active downloads. Do not use `-IncludePinnedFiles`.
- If jobs are active, skip the blanket cleanup. Where supported, target completed, unpinned jobs with `-FileId` instead.
- Do not disable Delivery Optimization or Windows updates to keep the cache empty. Cache regeneration is normal.

#### Windows Update download cache

- Limit the target to `SoftwareDistribution\Download` under the actual Windows directory.
- Proceed only when no update installation or download is active and no pending operation depends on those files.
- If services must be stopped temporarily, record their original states first. Restore those states in `finally`, even if deletion fails. Do not change startup types.
- Preserve the cache directory and its permissions. Remove only verified contents.
- Do not clear `DataStore`, the entire `SoftwareDistribution` tree, `catroot2`, update history, or update settings as a general cleanup operation.
- Skip and report protected or in-use items. Do not take ownership or alter Windows directory ACLs to recover a few remaining megabytes.

#### Browser cache

- Prefer the browser's built-in option to clear **Cached images and files** only.
- For filesystem cleanup, the browser must be closed. Do not terminate the user's browser just to clean its cache.
- Target only verified cache directories for the correct profile, such as `Cache`, `Code Cache`, `GPUCache`, and `ShaderCache`.
- Preserve cookies, passwords, bookmarks, history, extensions, profiles, website storage, and offline application data.
- Do not treat the entire `User Data` directory, `File System`, `IndexedDB`, or `Local Storage` as disposable cache without separate, specific authorization.

#### Diagnostic logs and temporary files

- Target identified diagnostic logs that are no longer in use, after verifying the producing application or system component and whether the logs are needed for troubleshooting.
- Prefer older files, and skip open files, recent files, and items whose purpose is unclear. Age alone does not establish that a file is disposable.
- **Do not empty the entire Temp directory.** It can contain unsaved documents, projects, recovery data, and files required by running applications.
- Preserve application-specific unsaved work, autosaves, recovery folders, unidentified virtual disks, and temporary storage belonging to active virtual machines.
- Do not clear Windows Event Logs in bulk.

### 3. Inspect installers and application leftovers

#### Downloaded installers

- Identify individual installers or extracted installer directories from installations that completed successfully.
- Verify the product, installed version, and installation status before removing them. Confirm that the installer is no longer running.
- Candidates may include standalone setup files, installation archives, extracted setup folders, and completed updater downloads. Classify them by their actual purpose on this computer.
- Delete only the exact verified paths. Do not empty Downloads or remove every `.exe`, `.zip`, or `.msi` file.

#### Application and development-tool caches

- Discover the applications and development tools actually installed. Locate their documented cache, download, and staging directories rather than assuming a fixed list of products or paths.
- Downloaded package archives can be cleanup candidates after successful installation, provided no installation or build is active and the application supports removing them.
- Distinguish disposable downloads from installed packages, dependencies, libraries, environments, and files required for offline use. Preserve the latter unless separately authorized.
- Explain when clearing a cache will require future downloads or rebuilding. Prefer the application's supported cleanup mechanism.
- Preserve source files, configuration, user assets, unsaved work, and unidentified build outputs.
- Before considering a build cache disposable, verify that the original project still exists at its recorded location. If it is missing or unverified, keep the cache as a potential recovery source.

#### Already-uninstalled applications

- Check per-user and system uninstall records, Store packages, services, processes, and actual installation locations.
- Verified obsolete installer caches, updater downloads, and plain diagnostic logs may be cleanup candidates.
- Investigate leftovers based on evidence from this computer. Do not assume that a folder with a familiar product name or an `.old` suffix is disposable.
- **Do not automatically remove user-created or downloaded assets, models, conversations, settings, game saves, or project data.** Uninstalling an application does not mean the user wants its data deleted. Report those items and request a specific choice only when necessary.

### 4. Uninstall driver updater tools when authorized

- Identify the actual installed product, verify its role, and use its official uninstaller within the user's authorized scope.
- Distinguish standalone updater utilities from active drivers, device control panels, hardware support services, and other installed applications. Do not classify software as unnecessary merely because its name contains a hardware vendor or the word "driver."
- Companion analytics, diagnostics, and support utilities are separate products. If the user did not clearly include them in the uninstall scope, report them as optional items instead of removing them automatically.
- After an authorized uninstall, verify removal of the relevant updater services without disabling unrelated device services.
- Do not replace an application's supported uninstall process with deletion of its installation directory.
- Remove leftover updater data only after verifying that the updater has been uninstalled. Restrict cleanup to that updater's verified location; do not broaden permission changes to shared vendor, application-data, or system directories.

### 5. Remove obsolete driver packages only when authorized

Apply this section only if the human user included obsolete driver removal in the request. Before proceeding, explain briefly that removed versions will no longer be available for immediate rollback.

1. Obtain a fresh inventory from this computer. Never use a supplied list of `oemNN.inf` numbers from another machine.
2. Identify the INF and version currently used by each relevant device.
3. A candidate must have the same original INF filename, provider, and class as a verified newer, active counterpart.
4. Recheck the package's identity immediately before removal. Include non-present device assignments in the inspection where available.
5. Preserve boot-critical and storage drivers, packages without a verified newer active counterpart, and active OEM extensions. Do not expand cleanup to `Extension` or `SoftwareComponent` packages just because they look old or are absent from a simple device list.
6. For a verified inactive package, use the supported Windows mechanism:

   `pnputil /delete-driver <verified-oemNN.inf>`

7. **Do not use `/force`, `/uninstall`, or `/reboot` for this cleanup.** If Windows reports that a package is in use, keep it.
8. Never delete Driver Store files manually. After cleanup, confirm that active driver versions and device status remain correct.

A driver dated 2019 or 2020 is not automatically obsolete. Do not remove drivers for disconnected devices the user may use again without a verified match and the appropriate authorized scope.

### 6. Clean superseded Windows components

- Analyze the component store first, with the required permissions:

  `DISM /Online /Cleanup-Image /AnalyzeComponentStore`

- If Windows identifies reclaimable packages and recommends cleanup, run the standard cleanup:

  `DISM /Online /Cleanup-Image /StartComponentCleanup /NoRestart`

- Do not use `/ResetBase` or `/SPSuperseded`. Do not delete WinSxS files manually.
- Standard cleanup removes superseded component versions. Do not promise that every previous component version will remain available for rollback.
- The **Backups and Disabled Features** figure is not guaranteed reclaimable space. Report the actual result after cleanup.
- Let the operation finish. Do not run a second DISM operation concurrently, or interrupt an operation solely because its progress stays at one percentage for a while.
- Check the exit code and final success message. Do not restart the computer automatically. Tell the user if a restart is requested.
- Report any remaining packages. Do not repeat cleanup indefinitely or force their manual removal.

### 7. Preserve useful data and system features

Without a separate, specific request, keep:

- Applications outside the approved uninstall scope, personal folders, documents, photos, code, AI models, saves, and recovery data.
- Linux environments, virtual machines, virtual disks, containers, development environments, and projects.
- Restore points, VSS shadow copies, recovery partitions, and recovery images.
- `pagefile.sys`, `swapfile.sys`, `hiberfil.sys`, Windows reserved storage, and the corresponding features. Do not disable hibernation or Fast Startup to free space.
- Files in `WindowsApps`, `Windows\Installer`, `ProgramData\Package Cache`, and `WinSxS` that support installed applications, repair, or updates. Use supported tools for a specifically authorized operation.
- Application runtimes and libraries, including those stored inside directories named `cache` or `.cache`. The parent folder's name does not determine whether its contents are disposable.
- Recycle Bin contents, unless the user explicitly approved emptying it.

Do not change update, security, service, or storage settings as a way to create permanently free space.

### 8. Execution, permissions, and reporting

- Follow the Codex environment's policies and approval requirements. This document does not override them.
- Before an administrator operation, prepare a concrete, reviewable plan or script and use the environment's permitted elevation process.
- If a tool rejects an action for policy reasons, do not switch methods to secretly perform the same rejected action. Explain what was blocked and the stated reason. Provide permitted manual steps where appropriate.
- Before recursive deletion, verify the resolved absolute target, ensure it is inside the specifically authorized location, and check for junctions, symlinks, or reparse points leading elsewhere.
- On Windows, prefer `Remove-Item -LiteralPath` and one shell throughout enumeration and deletion. Do not build deletion commands from untrusted filenames.
- Report access errors and partial success accurately. Record what was actually removed and what remains. Do not report zero removals when some items were deleted before an error.
- Measure free space again through the operating system, for example with `System.IO.DriveInfo`. File lengths are not the same as space reclaimed: sparse files, compression, hard links, and background activity can affect the result.
- Use consistent units. Windows commonly labels values calculated as bytes / 1,073,741,824 as GB, although these are GiB.
- In a disk-space breakdown, avoid counting subdirectories or hard links twice. Distinguish files, allocated VSS storage, volume reservations, and genuinely unclassified space. Do not call an unexplained remainder junk.

Finish with a concise report:

| Category | Removed | Skipped and reason |
| --- | --- | --- |
| Update and browser caches | Specific categories or paths | Locked, pinned, or active items |
| Installers and logs | Verified files | Unidentified or useful data |
| Driver updater tools | Exact product names | Products retained |
| Obsolete drivers | INF, version, successful removal count | In-use or protected packages |
| Windows components | DISM result | Any remaining packages |

Include actual before/after disk-space readings, the net change, any restart requirement, and confirmation of active driver status. Stop when there are no further large, clearly disposable items within the authorized scope.

## Official references

Confirm that commands are supported by the target Windows version and the available tools before using them.

- [Microsoft: Free up drive space in Windows](https://support.microsoft.com/en-us/windows/experience/storage-filemanagement/free-up-drive-space-in-windows)
- [Microsoft: Delivery Optimization and cache cleanup](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/delivery-optimization-in-windows)
- [Microsoft: Troubleshoot Windows Update and clear its cache](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/troubleshoot-problems-updating-windows)
- [Microsoft: PnPUtil command syntax](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- [Microsoft: Determine the actual size of WinSxS](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/determine-the-actual-size-of-the-winsxs-folder)
- [Microsoft: Supported WinSxS cleanup](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder)

For application-specific cleanup, consult the official documentation for the products discovered on the target computer.
