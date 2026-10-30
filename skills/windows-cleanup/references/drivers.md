# Driver updater tools and obsolete driver packages

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
