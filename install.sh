#!/bin/bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash_config_source="${repo_root}/bash/config.bash"
starship_config_source="${repo_root}/starship/starship.toml"
bashrc_path="${HOME}/.bashrc"
bash_config_block="$(cat <<EOF
if [ -r "${bash_config_source}" ]; then
    . "${bash_config_source}"
fi
EOF
)"
fnm_install_dir="${HOME}/.local/share/fnm"
starship_config_dir="${HOME}/.config"
blesh_source_dir="${HOME}/.local/src/blesh"
blesh_install_dir="${HOME}/.local/share/blesh"
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

ensure_bash_default_shell() {
    local current_shell
    local bash_path

    current_shell="$(getent passwd "${USER}" | cut -d: -f7)"
    bash_path="$(command -v bash)"

    if [ "${current_shell}" = "${bash_path}" ]; then
        echo "bash is already the default shell"
        return
    fi

    if ! grep -Fqx "${bash_path}" /etc/shells; then
        echo "Adding ${bash_path} to /etc/shells"
        echo "${bash_path}" | sudo tee -a /etc/shells >/dev/null
    fi

    chsh -s "${bash_path}"
    echo "Set default shell to ${bash_path}"
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

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        echo "starship is already installed"
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "Unable to install starship automatically: curl is not available" >&2
        exit 1
    fi

    mkdir -p "${HOME}/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "${HOME}/.local/bin"
    echo "Installed starship to ${HOME}/.local/bin"
}

install_blesh() {
    if [ -r "${blesh_install_dir}/ble.sh" ]; then
        echo "ble.sh is already installed at ${blesh_install_dir}/ble.sh"
        return
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "Unable to install ble.sh automatically: git is not available" >&2
        exit 1
    fi

    if ! command -v make >/dev/null 2>&1; then
        echo "Unable to install ble.sh automatically: make is not available" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${blesh_source_dir}")"

    if [ -d "${blesh_source_dir}/.git" ]; then
        git -C "${blesh_source_dir}" pull --ff-only
        git -C "${blesh_source_dir}" submodule update --init --recursive
    else
        git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "${blesh_source_dir}"
    fi

    make -C "${blesh_source_dir}" install PREFIX="${HOME}/.local"
    echo "Installed ble.sh to ${blesh_install_dir}"
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

install_configured_packages
configure_keyboard
install_fnm
install_node_and_pnpm
install_starship
install_blesh

ensure_managed_block "${bashrc_path}" "system-config bash config" "${bash_config_block}"
echo "Installed Bash shell setup in ~/.bashrc"

mkdir -p "${starship_config_dir}"
link_repo_file "${starship_config_source}" "${starship_config_dir}/starship.toml"

ensure_bash_default_shell
