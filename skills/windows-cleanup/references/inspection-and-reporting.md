# Inspection, preservation, and reporting

### 1. Inspect this computer first

- Confirm that the operating system is Windows. Do not apply these Windows commands to another operating system.
- Resolve the actual user profile, system drive, Windows directory, and Downloads folder. Downloads may have been relocated to another drive.
- Do not reuse another user's paths, hardware model, uninstall product codes, or `oem*.inf` identifiers.
- Record total, used, and free space before making changes.
- If driver cleanup is authorized, inventory the devices and drivers actually present, including device name, version, and INF. Record any device errors.
- Check for running installers, updates, downloads, builds, or other work using the candidate locations.
- Give a short explanation of the verified cleanup targets before acting. Proceed within the authorized scope without repeatedly asking for the same approval.

A file's age, a folder named `cache`, an `.old` suffix, or the absence of an application from one inventory is not enough to establish that an item is disposable.

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
