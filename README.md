# Safe RM - A Safer Alternative to `rm`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue.svg)](https://github.com/masberta/safe-rm)

**Safe RM** is a drop-in replacement for the dangerous `rm` command that moves files to trash instead of permanently deleting them. Never lose important files to accidental deletions again!

![Trust me!](/img/trustme.png "Trust me!")

## 🚀 Features

- **🛡️ Safe by Default**: Moves files to `~/.Trash` instead of permanent deletion
- **🔄 Full `rm` Compatibility**: Supports all standard `rm` flags (`-r`, `-f`, `-i`, etc.)
- **♻️ Easy Recovery**: Deleted files can be manually restored from trash
- **🗑️ Trash Management**: Built-in trash emptying with `-e` flag
- **⚡ Zero Learning Curve**: Works exactly like `rm` - no new commands to learn
- **🔒 Integrity Verification**: SHA256 hash verification ensures authentic installation
- **🌐 Cross-Platform**: Works on Linux, macOS, and other Unix-like systems

# ⚠️ WARNING ⚠️ #

It's strongly suggested you test this repository on a disposable cloud instance or virtual machine. If you really would like to try this on your main machine **avoid** *Install Option 3 - System Wide*.* 

Antying you do **is reversable** and the script has an un-installation option, despite this, be extra careful and use at your own risk! 

-- YOU HAVE BEEN WARNED! --

## 📦 Installation

### Prerequisites

Before installation, ensure you have both required files:
- `safe-rm.sh` - The main safe rm script
- `install.sh` - The interactive installer

### Manual Download

1. Download both files manually:
   - [safe-rm.sh](https://gitlab.aws.dev/masberta/safe_rm_kiro/-/raw/main/safe-rm.sh)
   - [install.sh](https://gitlab.aws.dev/masberta/safe_rm_kiro/-/raw/main/install.sh)

    Or clone this repository:
    ```bash
    git clone git@ssh.gitlab.aws.dev:masberta/safe_rm_kiro.git
    cd safe_rm_kiro
    ```

2. Make the installer executable and run it:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   **Note**: Do not source the installer (`source install.sh`) - run it directly as shown above.


## 🛠️ Installation Options

The installer provides three installation methods:

### 1. User-level (Alias Method) - **Recommended**
- Creates a shell alias for the current user only
- Safest option, easy to remove
- Use `\rm` to access original `rm` when needed

### 2. User-level (Binary Method)
- Installs binary to `~/bin/rm`
- Works with scripts and non-interactive shells
- Use `rm.real` to access original `rm` when needed

### 3. System-wide
- Installs to `/usr/local/bin/rm` for all users
- Requires administrator privileges (sudo)
- Use `rm.real` to access original `rm` when needed

## 📋 Usage

Safe RM works exactly like the standard `rm` command:

```bash
# Remove files (moves to trash)
rm file1.txt file2.txt

# Remove directories recursively
rm -r directory/

# Force removal without confirmation
rm -f file.txt

# Interactive removal
rm -i important-file.txt

# Verbose output
rm -v file.txt

# Empty the trash permanently
rm -e
```

### 🗑️ Trash Management

```bash
# Empty trash with confirmation
rm -e

# Force empty trash without confirmation
rm -ef

# View trash contents
ls ~/.Trash/
```

### 🔓 Accessing Original `rm`

When you need the original `rm` command:

**Alias Method:**
```bash
\rm file.txt  # Bypass alias with backslash
```

**Binary Method:**
```bash
rm.real file.txt  # Use rm.real command
```

## ⚙️ Advanced Installation

### Force Installation (Skip Hash Verification)
```bash
./install.sh -f
```
⚠️ **Warning**: Only use `-f` flag if you trust the source and understand the security implications.

### Installation Help
```bash
./install.sh -h
```

## 🔍 How It Works

1. **File Detection**: Checks if files/directories exist
2. **Trash Directory**: Creates `~/.Trash` if it doesn't exist
3. **Conflict Resolution**: Adds timestamps to filenames if conflicts occur
4. **Safe Move**: Uses `mv` to move files to trash instead of deleting
5. **Permissions**: Preserves original file permissions and ownership

### Filename Conflict Resolution
If a file with the same name exists in trash, Safe RM automatically adds a timestamp:
```
original-file.txt → original-file_20231230_143022.txt
```

## 🚨 Safety Features

- **Hash Verification**: SHA256 verification ensures you're installing the correct script
- **SSH-Safe**: Won't terminate SSH sessions during installation
- **Line Ending Normalization**: Automatically fixes copy-paste formatting issues
- **Error Handling**: Graceful error handling with informative messages
- **Backup Access**: Always provides access to original `rm` command

## 🗂️ File Structure

```
safe-rm/
├── safe-rm.sh      # Main safe rm script
├── install.sh      # Interactive installer
└── README.md       # This file
```

## 🔧 Supported Flags

Safe RM supports all standard `rm` flags:

| Flag | Description |
|------|-------------|
| `-f` | Force removal, ignore nonexistent files |
| `-i` | Interactive mode, prompt before removal |
| `-I` | Prompt once before removing more than 3 files |
| `-r, -R` | Remove directories recursively |
| `-d` | Remove empty directories |
| `-v` | Verbose mode |
| `-e` | **Safe RM Extension**: Empty trash permanently |

## 🔄 Uninstallation

To remove Safe RM:

```bash
chmod +x install.sh
./install.sh
# Choose option 5: "Uninstall safe-rm"
```

Or manually:
```bash
# Remove alias (check your shell rc file)
nano ~/.zshrc  # or ~/.bashrc

# Remove binary
rm ~/bin/rm ~/bin/rm.real
```

## ❓ FAQ

### Q: What happens to my deleted files?
**A**: Files are moved to `~/.Trash/` and can be manually restored by moving them back.

### Q: How do I permanently delete files?
**A**: Use `rm -e` to empty the trash, or `\rm` / `rm.real` to access the original rm command.

### Q: Does this work with scripts?
**A**: Yes! Use the binary installation method for full script compatibility.

### Q: Can I use this on servers?
**A**: Yes, but consider the disk space implications of accumulating trash files.

### Q: Is this compatible with my shell?
**A**: Works with bash, zsh, and most POSIX-compatible shells.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

While Safe RM significantly reduces the risk of accidental file deletion, it's not a substitute for proper backups. Always maintain regular backups of important data.

## 🙏 Acknowledgments

- Inspired by the need for safer file deletion in Unix-like systems
- Thanks to the open-source community for feedback and contributions

---

**Made with ❤️ for safer computing**

*Remember: The best backup is the one you never need, but the second-best backup is the one that saves you when you do.*