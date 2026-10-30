# Windows component store

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
