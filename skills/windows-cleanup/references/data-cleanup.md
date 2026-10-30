# Temporary data, installers, and application leftovers

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
