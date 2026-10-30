# Windows Cleanup 0.3.0

## Before extracting a downloaded ZIP

**Every new ZIP you download may be blocked again by Windows.** Before extracting it, right-click **the ZIP file > Properties > Unblock > Apply**, if Unblock is shown. Repeat this for each new download, after reviewing and trusting it.

This release is not digitally signed. Windows can mark files downloaded from GitHub as Internet files and block its PowerShell scripts. After reviewing and trusting the release, right-click **Windows-Cleanup-v0.3.0.zip**, choose **Properties**, check **Unblock** if shown, and select **Apply**. Then extract the whole ZIP into a new folder. If you already extracted it, extract again from the unblocked ZIP; keep any old reports you need in the original folder.

If startup fails, the CMD window now stays open so you can read the actual error. A security warning on the CMD file does not itself unblock the PowerShell files inside the package. Do not disable Windows security or system execution policy. Organization-enforced restrictions may require your administrator.

## Open the app

1. Extract the entire ZIP to a writable folder. Keep its files together. If Windows marks the downloaded ZIP as blocked, review and trust the download before using Properties > Unblock on the ZIP and extracting it again. Do not disable system execution policy.
2. Double-click **Open-WindowsCleanup.cmd**, or run that file from CMD.
3. The setup guide checks **PowerShell 7**, **Codex CLI**, and **Codex sign-in**. Install guide buttons open the official instructions. Complete any missing installation, then select **Check again**.
4. Select **Sign in** if needed, and complete Codex's browser login with your own account. You need Internet access and an account with Codex access. The guide does not install anything automatically or collect your password.
5. When all checks pass, select **Open app**, then **New inspection**. Opening the app does not start cleanup.
6. Read the inspection report. To continue, check the review box, type **CLEAN**, and select **Continue to Clean**. Review each requested action with **Approve / Reject**. Read the final report for actual removals, skips, and errors. Windows may separately request administrator approval.

During Clean, **Stop Clean** requests interruption and retains the logs. It does not undo actions already completed. Recognized active Windows servicing commands are allowed to finish before interruption. Repeated path-check errors automatically request the same guarded interruption. An interrupted run requires a fresh inspection before another cleanup attempt.

The runtime uses your own Codex installation, account, settings, and enabled tools. Additional plugin capabilities depend on your local Codex environment. This ZIP is a portable PowerShell/WPF app, not a standalone executable installer. Full validation details are in **VALIDATION.md**; tests are kept in the GitHub source rather than this runtime ZIP.
