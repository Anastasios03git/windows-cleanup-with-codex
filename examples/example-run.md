# Historical cleanup example

This is the owner-reported run from the original guide, before the skill was packaged. It is not a test result for this skill or a promise of recoverable space.

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
