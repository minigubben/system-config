#!/bin/bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bin_path="${repo_root}/bin"
fish_source_dir="${repo_root}/fish"
fish_config_dir="${HOME}/.config/fish"
bashrc_path="${HOME}/.bashrc"
bash_line="export PATH=\"\$PATH:${bin_path}\""
bash_node_tools_block="$(cat <<'EOF'
export FNM_DIR="$HOME/.local/share/fnm"
if [ -d "$FNM_DIR" ]; then
    export PATH="$FNM_DIR:$PATH"
fi
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac
EOF
)"
fnm_install_dir="${HOME}/.local/share/fnm"
fish_bin_path_file="${fish_config_dir}/conf.d/system-config-bin-path.fish"
package_list_file="${repo_root}/packages.sh"

COMMON_PACKAGES=()
DNF_PACKAGES=()
APT_GET_PACKAGES=()
PACMAN_PACKAGES=()
ZYPPER_PACKAGES=()

detect_package_manager() {
    local manager

    for manager in dnf apt-get pacman zypper; do
        if command -v "${manager}" >/dev/null 2>&1; then
            printf '%s\n' "${manager}"
            return 0
        fi
    done

    return 1
}

install_with_package_manager() {
    local manager="$1"
    shift
    local packages=("$@")

    if [ "${#packages[@]}" -eq 0 ]; then
        return
    fi

    case "${manager}" in
        dnf)
            sudo dnf install -y "${packages[@]}"
            ;;
        apt-get)
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "${packages[@]}"
            ;;
        zypper)
            sudo zypper --non-interactive install "${packages[@]}"
            ;;
        *)
            echo "Unable to install packages automatically: unsupported package manager ${manager}" >&2
            exit 1
            ;;
    esac
}

load_package_lists() {
    if [ ! -f "${package_list_file}" ]; then
        echo "Package list file not found at ${package_list_file}; skipping extra package installation"
        return
    fi

    # shellcheck disable=SC1090
    source "${package_list_file}"
}

ensure_fish_installed() {
    local package_manager

    if command -v fish >/dev/null 2>&1; then
        echo "fish is already installed"
        return
    fi

    if ! package_manager="$(detect_package_manager)"; then
        echo "Unable to install fish automatically: unsupported package manager" >&2
        exit 1
    fi

    install_with_package_manager "${package_manager}" fish
}

configure_keyboard() {
    if ! command -v localectl >/dev/null 2>&1; then
        echo "Skipping keyboard configuration: localectl is not available"
        return
    fi

    sudo localectl set-x11-keymap us microsoftpro altgr-intl terminate:ctrl_alt_bksp
    echo "Configured X11 keyboard layout to us altgr-intl"
}

install_configured_packages() {
    local package_manager
    local packages=("${COMMON_PACKAGES[@]}")

    if ! package_manager="$(detect_package_manager)"; then
        echo "Unable to install configured packages automatically: unsupported package manager" >&2
        exit 1
    fi

    case "${package_manager}" in
        dnf)
            packages+=("${DNF_PACKAGES[@]}")
            ;;
        apt-get)
            packages+=("${APT_GET_PACKAGES[@]}")
            ;;
        pacman)
            packages+=("${PACMAN_PACKAGES[@]}")
            ;;
        zypper)
            packages+=("${ZYPPER_PACKAGES[@]}")
            ;;
    esac

    if [ "${#packages[@]}" -eq 0 ]; then
        echo "No extra packages configured for ${package_manager}"
        return
    fi

    echo "Installing configured packages for ${package_manager}: ${packages[*]}"
    install_with_package_manager "${package_manager}" "${packages[@]}"
}

ensure_fish_default_shell() {
    local current_shell
    local fish_path

    current_shell="$(getent passwd "${USER}" | cut -d: -f7)"
    fish_path="$(command -v fish)"

    if [ "${current_shell}" = "${fish_path}" ]; then
        echo "fish is already the default shell"
        return
    fi

    if ! grep -Fqx "${fish_path}" /etc/shells; then
        echo "Adding ${fish_path} to /etc/shells"
        echo "${fish_path}" | sudo tee -a /etc/shells >/dev/null
    fi

    chsh -s "${fish_path}"
    echo "Set default shell to ${fish_path}"
}

link_repo_file() {
    local source_path="$1"
    local target_path="$2"

    if [ -L "${target_path}" ]; then
        local current_target
        current_target="$(readlink "${target_path}")"
        if [ "${current_target}" = "${source_path}" ]; then
            echo "Symlink already exists: ${target_path} -> ${source_path}"
            return
        fi
    elif [ -e "${target_path}" ]; then
        local backup_path="${target_path}.bak"
        mv "${target_path}" "${backup_path}"
        echo "Backed up existing ${target_path} to ${backup_path}"
    fi

    ln -sfn "${source_path}" "${target_path}"
    echo "Linked ${target_path} -> ${source_path}"
}

ensure_line_present() {
    local file_path="$1"
    local line="$2"

    mkdir -p "$(dirname "${file_path}")"
    touch "${file_path}"

    if grep -Fqx "${line}" "${file_path}"; then
        return
    fi

    printf '%s\n' "${line}" >> "${file_path}"
}

ensure_managed_block() {
    local file_path="$1"
    local block_name="$2"
    local block_content="$3"
    local start_marker="# >>> ${block_name} >>>"
    local end_marker="# <<< ${block_name} <<<"
    local tmp_file

    mkdir -p "$(dirname "${file_path}")"
    touch "${file_path}"
    tmp_file="$(mktemp)"

    awk -v start="${start_marker}" -v end="${end_marker}" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "${file_path}" > "${tmp_file}"

    printf '%s\n%s\n%s\n' "${start_marker}" "${block_content}" "${end_marker}" >> "${tmp_file}"
    mv "${tmp_file}" "${file_path}"
}

install_fnm() {
    local fnm_bin="${fnm_install_dir}/fnm"

    if [ -x "${fnm_bin}" ]; then
        echo "fnm is already installed at ${fnm_bin}"
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "Unable to install fnm automatically: curl is not available" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${fnm_install_dir}")"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "${fnm_install_dir}" --skip-shell
    echo "Installed fnm to ${fnm_install_dir}"
}

install_node_and_pnpm() {
    local fnm_bin="${fnm_install_dir}/fnm"
    local current_node

    if [ ! -x "${fnm_bin}" ]; then
        echo "Unable to install Node.js automatically: fnm is not available at ${fnm_bin}" >&2
        exit 1
    fi

    export PATH="${fnm_install_dir}:${PATH}"
    eval "$("${fnm_bin}" env --shell bash)"

    fnm install --lts
    fnm use lts-latest
    current_node="$(fnm current)"
    fnm default "${current_node}"
    fnm use default

    if ! command -v corepack >/dev/null 2>&1; then
        echo "Unable to install pnpm automatically: corepack is not available" >&2
        exit 1
    fi

    corepack enable
    corepack install --global pnpm@latest

    echo "Installed Node.js ${current_node} and configured pnpm via Corepack"
}

load_package_lists

ensure_fish_installed
install_configured_packages
configure_keyboard
install_fnm
install_node_and_pnpm

# Preserve the original bash setup for shells that still read ~/.bashrc.
if [ -f "${bashrc_path}" ] && grep -Fqx "${bash_line}" "${bashrc_path}"; then
    echo "${bin_path} is already in PATH in ~/.bashrc"
else
    ensure_line_present "${bashrc_path}" "${bash_line}"
    echo "Added ${bin_path} to PATH in ~/.bashrc"
fi

ensure_managed_block "${bashrc_path}" "system-config node tools" "${bash_node_tools_block}"
echo "Installed Node.js shell setup in ~/.bashrc"

mkdir -p "${fish_config_dir}" "${fish_config_dir}/conf.d" "${fish_config_dir}/functions"

link_repo_file "${fish_source_dir}/config.fish" "${fish_config_dir}/config.fish"
link_repo_file "${fish_source_dir}/functions/fish_prompt.fish" "${fish_config_dir}/functions/fish_prompt.fish"
printf 'fish_add_path -g %q\n' "${bin_path}" > "${fish_bin_path_file}"

echo "Linked fish config into ${fish_config_dir}"
echo "Installed ${bin_path} PATH hook to ${fish_bin_path_file}"

ensure_fish_default_shell
