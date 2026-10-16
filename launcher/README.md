# Tanki Era launcher source and review

This is the exact C# source used for the 2.0.0.0 launcher. The companion runtime archive is the same embedded archive in the published executable; its hash is listed in ../SHA256SUMS.txt. The icon is included for rebuilding.

The launcher checks only RebarFw/Tanki-Era- on GitHub, selects the allowed game assets at one immutable commit, verifies downloads, prepares a complete release in the user's local AppData folder, and starts the captive AIR game executable. It does not need administrator privileges or antivirus exclusions.

Build with the Windows .NET Framework C# compiler using Build.ps1. A local build can differ in compiler timestamps and module identifiers, so a rebuild is not guaranteed to produce an identical whole-file hash.

## Current scan status

The published launcher is currently unsigned. On October 16, 2026, VirusTotal reported 7/71 detections for the executable, including after reanalysis; the outer ZIP report showed 2/67. These detections have not been cleared by their vendors.

An updated local Microsoft Defender custom scan of the exact ZIP, executable and bundled runtime found no threats using definitions 1.461.55.0. A source comparison matched all 52 managed method bodies and all embedded resources against a diagnostic rebuild. The main bundled AIR DLL has a valid Adobe Inc. signature. The captive AIR entry executable is unsigned and has an older Arctic Wolf detection of its own.

These checks support requesting vendor review; they do not establish universal safety or override another vendor's verdict. No antivirus exclusions, disabled protections, obfuscation, encryption of the payload, or cosmetic binary modifications are used to hide the file from scanners. The published executable and ZIP have not been changed to obtain a different hash.

Reports:

- Executable: https://www.virustotal.com/gui/file/29eefcd4e2aa317aa67e82e13824238ddd61a8ac6bdcf25693e6d430e96a9471/detection
- ZIP: https://www.virustotal.com/gui/file/995e0a1f8979c0cc35e4e4e357345e9e9af980c9a0a62729c50208b449acbbda/detection

Vendor review is pending. A trusted code-signing certificate is required for a signed release; the build script can use an existing trusted signing certificate. It does not create certificates or alter certificate trust. Signing identifies the publisher and does not guarantee a zero-detection scan.
