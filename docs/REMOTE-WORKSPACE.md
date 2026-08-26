# GitHub-backed Remote Workspace

GitHub is the canonical project control plane, but Git is not a POSIX block filesystem. NCOM's remote workspace will provide a filesystem-like developer experience using ordinary Git primitives plus a local cache.

## Design

```text
NCOM Workspace
  -> local working tree
  -> sparse checkout / partial clone
  -> content-addressed cache
  -> manifest + revision lock
  -> optional GitHub Actions dispatch
  -> release artifact cache
```

## What this enables

- Keep source, configuration, skills, manifests, and reproducible build definitions in GitHub.
- Pull only the workspace paths required by a device.
- Cache large model/tool artifacts locally instead of storing model weights in Git history.
- Use GitHub Releases/Packages for versioned native bundles and VM images.
- Use GitHub Actions for remote build/test/package jobs.
- Use a self-hosted GitHub Actions runner on the Surface when a job must execute on the physical machine.

## Client strategy

The Linux desktop and iOS app can synchronize project metadata and compatible artifacts. The browser client can run the UI and connect to a user's NCOM runtime, while browser-local inference is optional and capability-negotiated.

## Important boundary

This is not a promise that GitHub becomes an always-mounted network drive. GitHub remains a versioned control plane; `ncom-sync` supplies the filesystem-like abstraction and handles offline operation.
