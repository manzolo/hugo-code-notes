---
title: "GPG Bash Playground"
date: 2025-09-28T00:00:00+02:00
lastmod: 2025-09-28T00:00:00+02:00
draft: false
author: "Manzolo"
tags: ["gpg", "encryption", "security", "pgp", "keys"]
categories: ["Networking & Security"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# GPG Bash Playground Guide

## Introduction

The GPG Bash Playground is an educational Bash script that demonstrates the practical use of GPG (GNU Privacy Guard) for key generation, public key exchange, encryption, and decryption. The script simulates a secure communication scenario by creating three users (Alice, Bob, and Carol), generating their GPG keys, exchanging public keys, and performing encrypted message exchanges. It includes comprehensive logging, error handling, and a debug mode for detailed output. This guide explains how to set up, run, and understand the script's functionality.

The script is particularly useful for learning GPG concepts in a controlled environment, showcasing how asymmetric encryption works in practice—where only intended recipients can decrypt messages, while unauthorized parties (like Carol trying to decrypt Bob's message to Alice) fail.

## What is the GPG Bash Playground?

This script automates a complete GPG workflow:
1. **User Creation**: Creates three system users (Alice, Bob, Carol) to simulate different parties.
2. **Key Generation**: Generates RSA 2048-bit GPG keys for each user.
3. **Key Exchange**: Exports and imports public keys between users, setting trust levels.
4. **Encryption/Decryption Demo**: Encrypts messages between pairs (e.g., Bob to Alice) and tests decryption by intended and unauthorized recipients.
5. **Cleanup**: Removes users, temporary files, and GPG agents after execution.

It logs all actions to a file (e.g., `gpg.sh.log`) and supports a debug mode (`-d`) for verbose output. The script requires root privileges due to user creation and system modifications.

## Prerequisites

- **Bash**: Compatible with most Unix-like systems (Linux/macOS).
- **GPG**: GNU Privacy Guard (installed automatically if missing on Debian/Ubuntu).
- **Root Access**: Run with `sudo` for user management.
- **Git**: For cloning the repository.
- **Docker** (Optional): For running in an isolated container.

Install dependencies on Debian/Ubuntu:
```bash
sudo apt update
sudo apt install git gnupg docker.io  # Docker optional
```

## How to Use the Script

### 1. Clone and Prepare
Clone the repository from GitHub:
```bash
git clone https://github.com/manzolo/gpg-bash-playground.git
cd gpg-bash-playground
chmod +x gpg.sh
```

### 2. Run the Script
Execute as root:
```bash
sudo ./gpg.sh
```

- **Standard Mode**: Runs the full demo with logging.
- **Debug Mode**: Add `-d` for detailed command outputs:
  ```bash
  sudo ./gpg.sh -d
  ```

The script will:
- Install GPG if needed.
- Create users and generate keys.
- Perform key exchanges and message encryptions/decryptions.
- Output logs to `gpg.sh.log` and display them on the console.

### 3. Run in Docker (Recommended for Testing)
For an isolated environment without affecting your host system:

```bash
git clone https://github.com/manzolo/gpg-bash-playground.git
cd gpg-bash-playground
docker build -t manzolo/gpg-playground .
mkdir -p tmp
chmod 777 -R tmp

# Standard mode
docker run --rm -it -v $(pwd)/tmp:/workspace/tmp manzolo/gpg-playground

# Debug mode
docker run --rm -it -v $(pwd)/tmp:/workspace/tmp manzolo/gpg-playground -d
```

- **Explanation**:
  - Builds a Docker image with the script and dependencies.
  - Mounts `./tmp` as `/workspace/tmp` for exporting keys and logs.
  - Runs the script inside the container, preserving outputs in `./tmp`.

### 4. View Logs
After execution, check the log file:
```bash
cat gpg.sh.log
```

## Examples

### Example 1: Standard Run
Running `sudo ./gpg.sh` produces output like:
```
2025-03-11 20:32:24 - [INFO] - Log file is ready.
2025-03-11 20:32:24 - [INFO] - GPG is already installed.
2025-03-11 20:32:24 - [INFO] - Creating user alice...
2025-03-11 20:32:24 - [INFO] - User alice created successfully.
...
2025-03-11 20:32:26 - [INFO] - bob is attempting to decrypt the message from alice...
2025-03-11 20:32:26 - [INFO] - Message from alice successfully decrypted by bob: Secret message from alice to bob
2025-03-11 20:32:26 - [ERROR] - carol failed to decrypt the message from bob.
2025-03-11 20:32:26 - [ERROR] - Decryption by Carol failed (expected).
...
2025-03-11 20:32:26 - [INFO] - Script completed.
```

- **Key Observations**:
  - Successful decryptions confirm GPG's asymmetric encryption.
  - Expected failures (e.g., Carol decrypting Bob's message to Alice) demonstrate security.

### Example 2: Debug Mode
With `-d`, you'll see verbose command outputs:
```
2025-03-11 20:32:26 - [DEBUG] - gpg (GnuPG) 2.2.40
2025-03-11 20:32:26 - [DEBUG] - ...
2025-03-11 20:32:26 - [INFO] - Public key of alice imported successfully for user bob.
```

Useful for troubleshooting GPG commands.

### Example 3: Inspect Exported Keys
After running, check exported public keys in `/tmp` (or `./tmp` in Docker):
```bash
ls /tmp/*_public.gpg
gpg --import /tmp/alice_public.gpg  # Import to your keyring for inspection
```

## Script Breakdown

The script (`gpg.sh`) is structured with modular functions:

- **Logging Functions**: `log_message`, `log_error`, `log_command_output` for colored, timestamped outputs.
- **User Management**: `create_user`, `setup_gpg` (cleans `.gnupg` dir).
- **GPG Operations**:
  - `generate_gpg_key`: Uses `--quick-generate-key` with empty passphrase for demo.
  - `export_public_key`: Exports to `/tmp/${user}_public.gpg`.
  - `import_public_key`: Imports and sets "ultimate" trust.
  - `encrypt_message`: Encrypts a shared message file for a recipient.
  - `decrypt_message`: Attempts decryption, logs success/failure.
- **Cleanup**: `kill_gpg_agent`, removes users and files.
- **Main Flow**: Parses args, initializes, runs demos, cleans up.

Key GPG Commands Demonstrated:
- `gpg --quick-generate-key`: Key generation.
- `gpg --export/--import`: Public key exchange.
- `gpg --encrypt --recipient`: Asymmetric encryption.
- `gpg --decrypt`: Decryption with private key.

## Use Cases
- **Learning GPG**: Hands-on demo of key management and encryption workflows.
- **Testing Environments**: Use Docker to experiment without root on host.
- **Scripting Education**: Example of Bash error handling, sudo usage, and logging.
- **Security Workshops**: Simulate multi-user encrypted communication.

## Pro Tips
- **Customize Users/Messages**: Edit variables like `ALICE="yourname"` or message content in `encrypt_message`.
- **Persistent Keys**: Remove cleanup section to keep users/keys for further testing.
- **Advanced GPG**: Extend with subkeys, signing (`--sign`), or revocation.
- **Log Analysis**: Pipe logs to `grep ERROR` for quick issue spotting.

{{< callout type="tip" >}}
**Tip**: Run in Docker first to avoid creating real users on your system—ideal for quick tests!
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: The script uses empty passphrases for demo purposes. In production, always use strong passphrases and consider hardware tokens.
{{< /callout >}}

## Troubleshooting
- **"This script must be run as root"**: Use `sudo`.
- **GPG Installation Fails**: Ensure internet access for `apt-get`.
- **User Creation Errors**: Check `/etc/passwd` for conflicts; script skips existing users.
- **Decryption Always Fails**: Verify trust levels with `gpg --edit-key` in debug mode.
- **Docker Volume Issues**: Ensure `./tmp` has 777 permissions for writes.
- **gpg-agent Lingers**: Manual `pkill gpg-agent` if cleanup fails.

## Next Steps

In future tutorials, we'll explore:
- Advanced GPG scripting with signing and revocation.
- Integrating GPG with email (e.g., Thunderbird/Enigmail).
- Secure file sharing with GPG in Bash pipelines.

## Resources
- [GPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [Docker Documentation](https://docs.docker.com/)

---

*Run the GPG Bash Playground to experiment with encryption—perfect for mastering secure communication in Bash!*