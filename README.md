# MaaTools

Standalone version of the MAA plugin for PlayCover, based on [hguandl/PlayTools](https://github.com/hguandl/PlayTools).

## Requirements

- PlayCover 3.0 or later
- PlayTools must already be injected into the target application

## Usage

### Install

```bash
sh maatools.sh install <Bundle ID>
```

### Uninstall

```bash
sh maatools.sh uninstall <Bundle ID>
```

### List Installation Status

```bash
sh maatools.sh list
```

## Q&A

### 1. Will this conflict with a PlayCover version with embedded MaaTools?

No. If the **MaaTools** option is enabled in PlayCover's **Bypass** settings, the embedded version will take priority, and the standalone version won't run.

### 2. Do I need to reinstall MaaTools after reinstalling the IPA?

Yes.

### 3. How do I upgrade MaaTools?

Simply run the `install` command again for any application, or you can manually copy `MaaTools.framework` to `~/Library/Frameworks`.
