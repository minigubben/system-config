# Package lists for install.sh.
# Add packages to COMMON_PACKAGES to install them on every supported system.
# Add packages to the manager-specific arrays when package names differ.

COMMON_PACKAGES=(
    "git"
    "curl"
    "vim"
    "screen"
)

DNF_PACKAGES=(
    # "ripgrep"
)

APT_GET_PACKAGES=(
    # "ripgrep"
)

PACMAN_PACKAGES=(
    # "ripgrep"
)

ZYPPER_PACKAGES=(
    # "ripgrep"
)
