#!/bin/bash

# Safe rm replacement - moves files to ~/.Trash instead of deleting
# Usage: safe-rm [options] file1 [file2 ...]

# Create ~/.Trash directory if it doesn't exist
TRASH_DIR="$HOME/.Trash"
mkdir -p "$TRASH_DIR"

# Function to show usage
show_usage() {
    echo "Usage: safe-rm [-f | -i] [-dIPRrvWxe] file ..."
    echo "       safe-rm [--help]"
    echo ""
    echo "Safe rm replacement - moves files to ~/.Trash instead of permanently deleting them."
    echo ""
    echo "Options:"
    echo "  -d             Remove empty directories"
    echo "  -e             Empty the trash (permanently delete all files in ~/.Trash)"
    echo "  -f             Force removal without confirmation, ignore nonexistent files"
    echo "  -i             Prompt before every removal"
    echo "  -I             Prompt once before removing more than three files"
    echo "  -P             Overwrite files before removal (ignored - files moved to trash)"
    echo "  -R, -r         Remove directories and their contents recursively"
    echo "  -v             Verbose mode - show what files are being moved"
    echo "  -W             Attempt to undelete whiteouts (ignored)"
    echo "  -x             Don't cross filesystem boundaries (ignored)"
    echo "  --help         Show this help message"
    echo ""
    echo "Note: Files are moved to ~/.Trash and can be manually restored."
}

# Initialize flags
VERBOSE=false
FORCE=false
INTERACTIVE=false
INTERACTIVE_ONCE=false
RECURSIVE=false
REMOVE_DIRS=false
EMPTY_TRASH=false
FILES=()

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_usage
            exit 0
            ;;
        -f)
            FORCE=true
            INTERACTIVE=false
            shift
            ;;
        -i)
            INTERACTIVE=true
            FORCE=false
            shift
            ;;
        -I)
            INTERACTIVE_ONCE=true
            shift
            ;;
        -v)
            VERBOSE=true
            shift
            ;;
        -r|-R)
            RECURSIVE=true
            shift
            ;;
        -d)
            REMOVE_DIRS=true
            shift
            ;;
        -e)
            EMPTY_TRASH=true
            shift
            ;;
        -P|-W|-x)
            # These flags are ignored but accepted for compatibility
            shift
            ;;
        -*)
            # Handle combined flags like -rf, -iv, etc.
            flags="${1#-}"
            shift
            for (( i=0; i<${#flags}; i++ )); do
                flag="${flags:$i:1}"
                case $flag in
                    f) FORCE=true; INTERACTIVE=false ;;
                    i) INTERACTIVE=true; FORCE=false ;;
                    I) INTERACTIVE_ONCE=true ;;
                    v) VERBOSE=true ;;
                    r|R) RECURSIVE=true ;;
                    d) REMOVE_DIRS=true ;;
                    e) EMPTY_TRASH=true ;;
                    P|W|x) ;; # Ignored for compatibility
                    *)
                        echo "rm: invalid option -- '$flag'"
                        echo "Try 'safe-rm --help' for more information."
                        exit 1
                        ;;
                esac
            done
            ;;
        --)
            shift
            FILES+=("$@")
            break
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Function to empty trash
empty_trash() {
    if [ ! -d "$TRASH_DIR" ] || [ -z "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        echo "Trash is already empty."
        return 0
    fi
    
    echo "Contents of ~/.Trash to be permanently deleted:"
    echo "================================================"
    
    # Count files and directories
    local file_count=0
    local dir_count=0
    local total_size=0
    
    # Show summary of what's in trash
    for item in "$TRASH_DIR"/*; do
        if [ -e "$item" ]; then
            local basename=$(basename "$item")
            local size=""
            
            if [ -f "$item" ]; then
                file_count=$((file_count + 1))
                size=$(du -h "$item" 2>/dev/null | cut -f1)
                total_size=$((total_size + $(du -k "$item" 2>/dev/null | cut -f1)))
                echo "  FILE: $basename ($size)"
            elif [ -d "$item" ]; then
                dir_count=$((dir_count + 1))
                size=$(du -sh "$item" 2>/dev/null | cut -f1)
                local item_size=$(du -sk "$item" 2>/dev/null | cut -f1)
                total_size=$((total_size + item_size))
                echo "  DIR:  $basename/ ($size)"
            fi
        fi
    done
    
    echo "================================================"
    echo "Summary: $file_count files, $dir_count directories"
    
    # Convert total size to human readable
    if [ $total_size -gt 1048576 ]; then
        local size_gb=$((total_size / 1048576))
        echo "Total size: ${size_gb}GB"
    elif [ $total_size -gt 1024 ]; then
        local size_mb=$((total_size / 1024))
        echo "Total size: ${size_mb}MB"
    else
        echo "Total size: ${total_size}KB"
    fi
    
    echo ""
    
    # Confirmation unless force flag is used
    if [ "$FORCE" = false ]; then
        echo -n "Are you sure you want to permanently delete all items in trash? [y/N]: "
        read -r response
        case $response in
            [Yy]|[Yy][Ee][Ss]) ;;
            *) 
                echo "Trash emptying cancelled."
                return 0 
                ;;
        esac
    fi
    
    # Actually delete everything using real rm
    if [ "$VERBOSE" = true ]; then
        echo "Permanently deleting trash contents..."
    fi
    
    # Use the real rm command to permanently delete
    if /bin/rm -rf "$TRASH_DIR"/* 2>/dev/null; then
        echo "Trash emptied successfully. $file_count files and $dir_count directories permanently deleted."
        return 0
    else
        echo "Error: Failed to empty trash completely. Some files may remain."
        return 1
    fi
}

# Handle empty trash flag
if [ "$EMPTY_TRASH" = true ]; then
    empty_trash
    exit $?
fi

# Check if any files were specified
if [ ${#FILES[@]} -eq 0 ]; then
    echo "rm: missing operand"
    echo "Try 'safe-rm --help' for more information."
    exit 1
fi

# Interactive once check - prompt if removing more than 3 files
if [ "$INTERACTIVE_ONCE" = true ] && [ ${#FILES[@]} -gt 3 ]; then
    echo -n "rm: remove ${#FILES[@]} arguments? "
    read -r response
    case $response in
        [Yy]|[Yy][Ee][Ss]) ;;
        *) exit 0 ;;
    esac
fi

# Function to ask for confirmation
confirm_removal() {
    local file="$1"
    local file_type=""
    
    if [ -d "$file" ]; then
        if [ "$RECURSIVE" = true ]; then
            file_type="directory"
        else
            echo "rm: $file: is a directory"
            return 1
        fi
    elif [ -f "$file" ]; then
        file_type="regular file"
    else
        file_type="file"
    fi
    
    echo -n "remove $file_type '$file'? "
    read -r response
    case $response in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to generate unique filename with timestamp
generate_unique_name() {
    local file="$1"
    local basename=$(basename "$file")
    local target="$TRASH_DIR/$basename"
    
    # If file doesn't exist in trash, use original name
    if [ ! -e "$target" ]; then
        echo "$target"
        return
    fi
    
    # Generate timestamp-based unique name
    local timestamp=$(date +"%Y%m%d_%H%M%S_%N" | cut -c1-18)  # Include nanoseconds for uniqueness
    local extension="${basename##*.}"
    local name="${basename%.*}"
    
    # Handle files without extensions
    if [ "$extension" = "$basename" ]; then
        echo "$TRASH_DIR/${name}_${timestamp}"
    else
        echo "$TRASH_DIR/${name}_${timestamp}.${extension}"
    fi
}

# Function to safely move a file or directory
safe_move() {
    local file="$1"
    
    # Check if file exists
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        if [ "$FORCE" = false ]; then
            echo "rm: $file: No such file or directory"
            return 1
        else
            return 0  # -f flag ignores nonexistent files
        fi
    fi
    
    # Handle directories
    if [ -d "$file" ] && [ ! -L "$file" ]; then
        if [ "$RECURSIVE" = false ] && [ "$REMOVE_DIRS" = false ]; then
            echo "rm: $file: is a directory"
            return 1
        fi
        
        if [ "$REMOVE_DIRS" = true ]; then
            # Check if directory is empty
            if [ "$(ls -A "$file" 2>/dev/null)" ]; then
                echo "rm: $file: Directory not empty"
                return 1
            fi
        fi
    fi
    
    # Interactive confirmation
    if [ "$INTERACTIVE" = true ]; then
        if ! confirm_removal "$file"; then
            return 0
        fi
    fi
    
    # Generate unique target name
    local target=$(generate_unique_name "$file")
    
    # Show what we're doing if verbose
    if [ "$VERBOSE" = true ]; then
        echo "Moving '$file' to '$target'"
    fi
    
    # Move the file/directory
    if mv "$file" "$target" 2>/dev/null; then
        if [ "$VERBOSE" = true ]; then
            echo "Successfully moved '$file' to trash"
        fi
        return 0
    else
        echo "rm: $file: Permission denied"
        return 1
    fi
}

# Process each file
exit_code=0
for file in "${FILES[@]}"; do
    if ! safe_move "$file"; then
        exit_code=1
    fi
done

if [ "$VERBOSE" = true ] && [ $exit_code -eq 0 ]; then
    echo "Files moved to ~/.Trash (you can restore them manually if needed)"
fi

exit $exit_code