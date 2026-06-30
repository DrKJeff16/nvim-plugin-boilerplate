#!/usr/bin/env bash
#
# Generate your plugin data and tweaks with a simple execution!
#

# shellcheck disable=SC2207

DATA=""
MODULE_NAME=""
ANNOTATION_PREFIX=""
LINE_SIZE=""
PLUGIN_NAME=""
PLUGIN_DESCRIPTION=""
INDENTATION=""
TAB_SIZE=""

OPTIONS=":hvos:t:c:C:R:P:L:N:D:T:H:S:I:"
VERBOSE=0
ONLY_SELECTED=0
ASK_NAME=1
ASK_DESCRIPTION=1
SELECTED=()

REAL_ANS=2 # Intermediate variable, to store values when calling `_toggle_var_check`

# Toggle variables
# - `0`: Disabled
# - `1`: Enabled
# - `2`: Auto/Prompt (default)
CLEAN_SCRIPT=2
REPLACE_LICENSE=2
REWRITE_README=2
WITH_HEALTH=2
WITH_PYTHON=2
WITH_SELENE=2
WITH_STYLUA=2
WITH_TESTS=2
WITH_CI=2

# Print all args to `stderr`
_error() {
    local TXT=("$@")
    printf "%s\n" "${TXT[@]}" >&2
    return 0
}

# Only print text if verbose mode is On
_verbose_print() {
    [[ $VERBOSE -eq 0 ]] && return 0

    local TXT=("$@")
    printf "%s\n" "${TXT[@]}"
    return 0
}

# Remove with verbose flag if `-v` was passed to script
_verbose_rm() {
    if [[ $VERBOSE -eq 0 ]]; then
        rm -rf "$@" || return 1
        return 0
    fi

    rm -rfv "$@" || return 1
    return 0
}

# Kill the script execution with an exit status and optional messages
_die() {
    local EC=0
    if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        EC="$1"
        shift
    fi

    if [[ $# -ge 1 ]]; then
        local TXT=("$@")
        if [[ $EC -eq 0 ]]; then
            printf "%s\n" "${TXT[@]}"
        else
            _error "${TXT[@]}"
        fi
    fi

    exit "$EC"
}

# Check whether a given console command exists
_cmd_exists() {
    if [[ $# -eq 0 ]]; then
        _error "What command?"
        return 127
    fi

    local OPTS=":v"
    local VERB=0
    local CMDS=()
    local EXES=()
    local ARG
    while getopts "$OPTS" ARG; do
        case "$ARG" in
            v) VERB=$((VERB + 1)) ;;
            *)
                command -v "$ARG" &> /dev/null || return 1
                CMDS+=("$ARG")
                EXES+=("$(command -v "$ARG" 2> /dev/null)")
                ;;
        esac
        shift
    done

    if [[ $VERB -eq 1 ]]; then
        printf "%s\n" "${CMDS[@]}"
    elif [[ $VERB -eq 2 ]]; then
        printf "\`%s\` ==> OK\n" "${CMDS[@]}"
    elif [[ $VERB -ge 3 ]]; then
        for I in $(seq 1 ${#CMDS[@]}); do
            I=$((I - 1))
            printf "\`%s\` ==> \`%s\` ==> OK\n" "${CMDS[I]}" "${EXES[I]}"
        done
        unset I
    fi
    return 0
}

_usage() {
    local EC=0
    local TXT=()
    if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        EC="$1"
        shift
    fi
    if [[ $# -ge 1 ]]; then
        TXT+=("$@")
        TXT+=("")
    fi

    TXT+=(
        "generate.sh - Generator script for \`nvim-plugin-boilerplate\`"
        ""
        "Usage: generate.sh [-h] [-v]"
        ""
        "    -h             Print this help message with success exit code"
        "    -v             Enables verbose mode"
        ""
    )
    _die "$EC" "${TXT[@]}"
}

_cmd_exists 'find' 'sed' 'mv' 'rm' || _die 127 "\`find\` / \`sed\` / \`mv\` / \`rm\` not in PATH!"

# Check whether a given file exists, is readable and is writeable aswell
_file_readable_writeable() {
    [[ $# -eq 0 ]] && return 127
    [[ -f "$1" ]] || return 1
    [[ -r "$1" ]] || return 1
    [[ -w "$1" ]] || return 1
    return 0
}

# Check whether a given file exists, is readable and is writeable aswell, plus it is not empty
_file_rw_not_empty() {
    [[ $# -eq 0 ]] && return 127

    _file_readable_writeable "$1" || return 1
    [[ -s "$1" ]] || return 1
    return 0
}

# Generic prompt
_prompt_data() {
    local PROMPT_TXT="$1"
    local ALLOW_EMPTY="$2"
    while true; do
        read -p "$PROMPT_TXT" -r
        case $REPLY in
            "")
                if [[ $ALLOW_EMPTY -eq 1 ]]; then
                    DATA="$REPLY"
                    break
                fi
                ;;
            *)
                DATA="$REPLY"
                break
                ;;
        esac
    done
    return 0
}

# Yes/No prompt
_yn() {
    local PROMPT_TXT="$1"
    local ALLOW_EMPTY="$2"
    local DEFAULT_CHOICE="$3"
    if [[ $ALLOW_EMPTY -eq 1 ]]; then
        case $DEFAULT_CHOICE in
            [Yy] | [Yy][Ee][Ss] | "1") DEFAULT_CHOICE="Y" ;;
            [Nn] | [Nn][Oo] | "0") DEFAULT_CHOICE="N" ;;
            *) DEFAULT_CHOICE="Y" ;;
        esac
    fi

    while true; do
        _prompt_data "$PROMPT_TXT" "$ALLOW_EMPTY"
        if [[ -z "$DATA" ]]; then
            case $DEFAULT_CHOICE in
                "Y") return 0 ;;
                "N") return 1 ;;
            esac
            return 0
        fi
        case $DATA in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) continue ;;
        esac
    done
    return 1
}

# Prompt to rename this module's files
_rename_module() {
    if [[ -d ./lua/my-plugin ]] && _file_readable_writeable "./lua/my-plugin.lua"; then
        while true; do
            _prompt_data "Rename your plugin module (previously: \`my-plugin\`): " 0
            if [[ $DATA =~ ^[a-zA-Z_][a-zA-Z0-9_\-]*[a-zA-Z0-9_]$ ]]; then
                break
            fi
            _error "Invalid module name!" "Use a parseable Lua module name"
        done

        MODULE_NAME="${DATA}"
        mv ./lua/my-plugin "./lua/${MODULE_NAME}" || return 1
        mv ./lua/my-plugin.lua "./lua/${MODULE_NAME}.lua" || return 1
    fi
    if [[ -d ./rplugin/python3 ]] && _file_readable_writeable "./rplugin/python3/my-plugin.py"; then
        mv ./rplugin/python3/my-plugin.py "./rplugin/python3/${MODULE_NAME}.py" || return 1
    fi
    if [[ -d ./spec ]] && _file_readable_writeable "./spec/my-plugin_spec.lua"; then
        mv ./spec/my-plugin_spec.lua "./spec/${MODULE_NAME}_spec.lua" || return 1
    fi
    return 0
}

# Prompt to rename annotation classes
_rename_annotations() {
    local IFS
    while true; do
        _prompt_data "Rename your module class annotations (previously: \`MyPlugin\`): " 0
        if [[ $DATA =~ ^[a-zA-Z][a-zA-Z0-9_\.]*[a-zA-Z0-9_]$ ]]; then
            break
        fi
        _error "Invalid module name: \`${DATA}\`" "Try again..."
    done

    ANNOTATION_PREFIX="${DATA}"
    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)
    while IFS= read -r -d '' file; do
        sed -i "s/my-plugin/${MODULE_NAME}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find spec -type f -regex '.*\.lua$' -print0)
    while IFS= read -r -d '' file; do
        sed -i "s/my-plugin/${MODULE_NAME}/g" "${file}" || return 1
    done < <(find spec -type f -regex '.*_spec\.lua$' -print0)

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find rplugin -type f -regex '.*\.py$' -print0)

    return 0
}

# Prompt to select the indentation for Lua files
_select_indentation() {
    local IFS
    local ET=""
    DATA=""

    if [[ -n "$INDENTATION" ]]; then
        case "$INDENTATION" in
            [Ss] | [Ss][Pp][Aa][Cc][Ee][Ss])
                INDENTATION="Spaces"
                ET="et"
                ;;
            [Tt] | [Tt][Aa][Bb][Ss])
                INDENTATION="Tabs"
                ET="noet"
                ;;
            *) _usage 3 "Bad indentation!" ;;
        esac
    else
        while true; do
            _prompt_data "Use tabs or spaces? [S[paces]/t[abs]]: " 1
            if [[ -z "$DATA" ]]; then
                INDENTATION="Spaces"
                break
            fi
            case "$DATA" in
                [Ss] | [Ss][Pp][Aa][Cc][Ee][Ss])
                    INDENTATION="Spaces"
                    ET="et"
                    break
                    ;;
                [Tt] | [Tt][Aa][Bb][Ss])
                    INDENTATION="Tabs"
                    ET="noet"
                    break
                    ;;
                *) continue ;;
            esac
        done
    fi

    if [[ "$ET" == "noet" ]]; then
        while IFS= read -r -d '' file; do
            sed -i "s/\\set\\s/ ${ET} /g" "${file}" || return 1
        done < <(find lua -type f -regex '.*\.lua$' -print0)
    fi

    local TARGET_FILE=""
    if _file_rw_not_empty ./'.stylua.toml'; then
        TARGET_FILE=".stylua.toml"
    elif _file_rw_not_empty ./'stylua.toml'; then
        TARGET_FILE="stylua.toml"
    else
        _error "WARNING: Unable to find \`stylua.toml\` or \`.stylua.toml\`. Aborting indentation change for StyLua!"
        return 0
    fi

    if grep -qE '^indent_type\s+=\s+.*$' ./"${TARGET_FILE}"; then
        sed -i "s/^indent_type\\s\\+=\\s.*$/indent_type = \"${INDENTATION}\"/g" ./"${TARGET_FILE}" || return 1
    else
        local F_DATA=()
        IFS=$'\n' F_DATA=($(cat ./"${TARGET_FILE}"))
        printf "%s\n" "indent_type = \"${INDENTATION}\"" | tee ./"${TARGET_FILE}" &> /dev/null
        printf "%s\n" "${F_DATA[@]}" | tee -a ./"${TARGET_FILE}" &> /dev/null

        unset F_DATA
    fi

    if [[ -n "$TAB_SIZE" ]]; then
        ! [[ $TAB_SIZE =~ ^[1-9]+[0-9]*$ ]] && _usage 3 "Invalid indentation level \`${TAB_SIZE}\`"
    else
        while true; do
            _prompt_data "Select your indentation level (default: 2): " 1
            TAB_SIZE="${DATA}"
            if [[ -z "${TAB_SIZE}" ]]; then
                TAB_SIZE="2"
                break
            fi
            if ! [[ $TAB_SIZE =~ ^[1-9]+[0-9]*$ ]]; then
                _error "Invalid indentation level!" "Try again..."
                continue
            fi
            break
        done
    fi

    while IFS= read -r -d '' file; do
        sed -i "s/^--\\svim:\\sset\\sts=[1-9]\\+[0-9]*\\ssts=[1-9]\\+[0-9]*\\ssw=[1-9]\\+[0-9]*/-- vim: set ts=${TAB_SIZE} sts=${TAB_SIZE} sw=${TAB_SIZE}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    if grep -qE '^indent_width\s+=\s+.*$' ./"${TARGET_FILE}"; then
        sed -i "s/^indent_width\\s\\+=\\s.*$/indent_width = ${TAB_SIZE}/g" ./"${TARGET_FILE}" || return 1
    else
        local F_DATA=()
        IFS=$'\n' F_DATA=($(cat ./"${TARGET_FILE}"))
        printf "%s\n" "indent_width = ${TAB_SIZE}" | tee ./"${TARGET_FILE}" &> /dev/null
        printf "%s\n" "${F_DATA[@]}" | tee -a ./"${TARGET_FILE}" &> /dev/null

        unset F_DATA
    fi
    return 0
}

# Prompt to select the maximum line size for Lua files
_select_line_size() {
    local IFS
    DATA=""
    while true; do
        _prompt_data "Select your line size (default: 120): " 1
        if [[ -n "$DATA" ]]; then
            if [[ $DATA =~ ^[1-9][0-9]*$ ]]; then
                LINE_SIZE="${DATA}"
                break
            fi
            continue
        fi

        LINE_SIZE="100"
        break
    done

    local TARGET_FILE=""
    if _file_rw_not_empty ./'.stylua.toml'; then
        TARGET_FILE=".stylua.toml"
    elif _file_rw_not_empty ./'stylua.toml'; then
        TARGET_FILE="stylua.toml"
    else
        _error "WARNING: Unable to find \`stylua.toml\` or \`.stylua.toml\`. Aborting indentation change for StyLua!"
        return 0
    fi

    if grep -qE '^column_width\s+=\s+.*$' ./"${TARGET_FILE}"; then
        sed -i "s/^column_width\\s\\+=\\s.*$/column_width = ${LINE_SIZE}/g" ./"${TARGET_FILE}" || return 1
    else
        local F_DATA=()
        IFS=$'\n' F_DATA=($(cat ./"${TARGET_FILE}"))
        printf "%s\n" "column_width = ${LINE_SIZE}" | tee ./"${TARGET_FILE}" &> /dev/null
        printf "%s\n" "${F_DATA[@]}" | tee -a ./"${TARGET_FILE}" &> /dev/null

        unset F_DATA
    fi
    return 0
}

# Prompt to remove the StyLua config
_remove_stylua() {
    case "${WITH_STYLUA}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove StyLua config? [y/N]: " 1 "N" && return 0 ;;
    esac
    if _file_readable_writeable "./.stylua.toml"; then
        _verbose_print "Removing \`.stylua.toml\`..." ""
        _verbose_rm ./.stylua.toml || return 1
    elif _file_readable_writeable "./stylua.toml"; then
        _verbose_print "Removing \`stylua.toml\`..." ""
        _verbose_rm ./stylua.toml || return 1
    fi

    if _file_readable_writeable "./.github/workflows/stylua.yml"; then
        _verbose_print "Removing \`.github/workflows/stylua.yml\`..." ""
        _verbose_rm ./.github/workflows/stylua.yml || return 1
    fi
    return 0
}

# Prompt to remove the selene config
_remove_selene() {
    case "${WITH_SELENE}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove \`selene\` config? [Y/n]: " 1 "Y" && return 0 ;;
    esac
    if _file_readable_writeable "./selene.toml"; then
        _verbose_print "Removing \`selene.toml\`..." ""
        _verbose_rm ./selene.toml || return 1
    fi
    if _file_readable_writeable "./vim.yml"; then
        _verbose_print "Removing \`vim.yml\`..." ""
        _verbose_rm ./vim.yml || return 1
    fi
    if _file_readable_writeable "./.github/workflows/selene.yml"; then
        _verbose_print "Removing \`.github/workflows/selene.yml\`..." ""
        _verbose_rm ./.github/workflows/selene.yml || return 1
    fi
    return 0
}

# Prompt to remove the test components
_remove_tests() {
    case "${WITH_TESTS}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove tests? [Y/n]: " 1 "Y" &&  return 0 ;;
    esac

    if _file_readable_writeable "./.busted"; then
        _verbose_print "Removing busted config..."
        _verbose_rm ./.busted || return 1
    fi
    if _file_readable_writeable "./Makefile"; then
        _verbose_print "Removing Makefile..."
        _verbose_rm ./Makefile || return 1
    fi
    if [[ -d ./spec ]]; then
        _verbose_print "Removing tests..." ""
        _verbose_rm ./spec || return 1
    fi
    return 0
}

# Remove the `checkhealth` file
_remove_health_file() {
    case "${WITH_HEALTH}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove checkhealth file? [Y/n]: " 1 "Y" && return 0 ;;
    esac

    if _file_readable_writeable "./lua/${MODULE_NAME}/health.lua"; then
        _verbose_print "Removing \`health.lua\`..." ""
        _verbose_rm "./lua/${MODULE_NAME}/health.lua" || return 1
    fi
    return 0
}

# Remove the Python component
_remove_python_component() {
    case "${WITH_PYTHON}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove the Python component? [Y/n]: " 1 "Y" && return 0 ;;
    esac

    if ! _file_readable_writeable "./rplugin/python3/${MODULE_NAME}.py"; then
        _error "WARNING: Cannot find Python component. Unable to remove it!"
        return 0
    fi

    _verbose_print "Removimg Python component..." ""
    _verbose_rm ./rplugin || return 1
    return 0
}

# Prompt to remove this script
_remove_script() {
    if ! _file_readable_writeable ./generate.sh; then
        _error "WARNING: Cannot find this very script. Unable to remove it!"
        return 1
    fi

    case "${CLEAN_SCRIPT}" in
        "0")
            _error "This script will need to be deleted manually!"
            return 0
            ;;
        "1") : ;;
        "2")
            ! _yn "Self-destruct this script? [Y/n]: " 1 "Y" \
                && _error "" "This script will need to be deleted manually!" \
                && return 0

            ;;
    esac

    _verbose_print "Removing this script..." ""
    _verbose_rm ./generate.sh || return 1
    return 0
}

# Rewrite `README.md`
_rewrite_readme() {
    if ! _file_readable_writeable "./README.md"; then
        _error "WARNING: No \`README.md\` could be found!"
        return 0
    fi

    case "${REWRITE_README}" in
        "0") return 0 ;;
        "1") : ;;
        "2") ! _yn "Rewrite your \`README.md\`? [Y/n]: " 1 "Y" && return 0 ;;
    esac

    if [[ $ASK_NAME -eq 1 ]] && [[ -z "$PLUGIN_NAME" ]]; then
        _prompt_data "Input the plugin name: " 0
        PLUGIN_NAME="${DATA}"
    fi
    if [[ $ASK_DESCRIPTION -eq 1 ]] && [[ -z "$PLUGIN_DESCRIPTION" ]]; then
        _prompt_data "Input the plugin description in one line (markdown syntax): " 1
        PLUGIN_DESCRIPTION="${DATA}"
    fi

    local TXT=(
        "# ${PLUGIN_NAME}"
        ""
        "${PLUGIN_DESCRIPTION}"
        ""
        "<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->"
    )

    printf "%s\n" "${TXT[@]}" | tee ./README.md &> /dev/null
    return 0
}

_replace_license() {
    case "${REPLACE_LICENSE}" in
        "0") return 0 ;;
        "1") : ;;
        "2") ! _yn "Do you wish to use a different license? [y/N]: " 1 "N" && return 0 ;;
    esac
    if ! _cmd_exists 'gh'; then
        _error "\`gh\` is not installed. Aborting license replacing!"
        return 0
    fi

    printf "%s\n" "Changing license will use the GitHub CLI (\`gh\`). All operations will be verbose for transparency."
    read -rp "Press ENTER to continue..." _TRASH

    if ! gh extension list | grep -q "mislav/gh-license"; then
        ! _yn "This operation requires the \`gh\` extension \`mislav/gh-license\` to be installed.\nDo you wish to install it? [Y/n]: " 1 "Y" && return 0
        ! gh extension install "mislav/gh-license" && return 1
    fi

    while true; do
        printf "%s\n" \
            "" \
            "agpl-3.0" \
            "apache-2.0" \
            "bsd-2-clause" \
            "bsd-3-clause" \
            "bsl-1.0" \
            "cc0-1.0" \
            "epl-2.0" \
            "gpl-2.0" \
            "gpl-3.0" \
            "lgpl-2.1" \
            "mit" \
            "mpl-2.0" \
            "unlicense"

        _prompt_data "Choose one of the licenses listed above (case-sensitive): " 1
        case "${DATA}" in
            "agpl-3.0") LICENSE="agpl-3.0" ;;
            "apache-2.0") LICENSE="apache-2.0" ;;
            "bsd-2-clause") LICENSE="bsd-2-clause" ;;
            "bsd-3-clause") LICENSE="bsd-2-clause" ;;
            "bsl-1.0") LICENSE="bsl-1.0" ;;
            "cc0-1.0") LICENSE="cc0-1.0" ;;
            "epl-2.0") LICENSE="epl-2.0" ;;
            "gpl-2.0") LICENSE="gpl-2.0" ;;
            "gpl-3.0") LICENSE="gpl-3.0" ;;
            "lgpl-2.1") LICENSE="lgpl-2.1" ;;
            "mit") LICENSE="mit" ;;
            "mpl-2.0") LICENSE="mpl-2.0" ;;
            "unlicense") LICENSE="unlicense" ;;
            *) continue ;;
        esac
    done

    rm -f ./LICENSE
    gh license "${LICENSE}" || return 1
    return 0
}

_remove_ci() {
    if ! [[ -d ./.github ]]; then
        _error "No \`.github\` directory found. Aborting CI removal!"
        return 0
    fi

    _verbose_rm ./.github/FUNDING.yml

    case "${WITH_CI}" in
        "0") : ;;
        "1") return 0 ;;
        "2") ! _yn "Remove CI? [Y/n]: " 1 "Y" && return 0 ;;
    esac

    if [[ -f ./.github/CODEOWNERS ]]; then
        _yn "Remove CODEOWNERS file? [Y/n]: " 1 "Y" \
            && _verbose_rm ./.github/CODEOWNERS

    fi
    if [[ -f ./.github/workflows/vim-eof-comment.yml ]]; then
        _yn "Remove vim-eof-comment GitHub Action? [Y/n]: " 1 "Y" \
            && _verbose_rm ./.github/workflows/vim-eof-comment.yml

    fi

    return 0
}

_not_in_selected() {
    [[ ${#SELECTED[@]} -eq 0 ]] && return 0

    local ITEM="$1"
    for S in "${SELECTED[@]}"; do
        [[ "${S}" == "${ITEM}" ]] && return 1
    done
    return 0
}

# Execute the script
_main() {
    _rename_module || _die 1 "Couldn't rename module file structure!"
    _rename_annotations || _die 1 "Couldn't rename module annotations!"

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "indentation"; then
        _select_indentation || _die 1 "Unable to set indentation!"
        _select_line_size || _die 1 "Unable to set StyLua line size!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "tests"; then
        _remove_tests || _die 1 "Unable to (not) remove tests!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "health"; then
        _remove_health_file || _die 1 "Unable to (not) remove health file!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "python"; then
        _remove_python_component || _die 1 "Unable to (not) remove Python component!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "stylua"; then
        _remove_stylua || _die 1 "Unable to (not) remove StyLua config!"
    fi
    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "selene"; then
        _remove_selene || _die 1 "Unable to (not) remove selene config!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "license"; then
        _replace_license || _die 1 "Unable to replace license!"
    fi
    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "ci"; then
        _remove_ci || _die 1 "Unable to remove useless CI components!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "readme"; then
        _rewrite_readme || _die 1 "Unable to rewrite \`README.md\`!"
    fi

    if [[ $ONLY_SELECTED -eq 0 ]] || [[ $ONLY_SELECTED -eq 1 ]] && ! _not_in_selected "clear"; then
        _remove_script || _die 1 "Unable to (not) remove this script!"
    fi

    return 0
}

_toggle_var_check() {
    REAL_ANS=2
    local ANS="$1"
    case "$ANS" in
        "0" | [Nn] | [Nn][Oo]) REAL_ANS=0 ;;
        "1" | [Yy] | [Yy][Ee][Ss]) REAL_ANS=0 ;;
        "2" | [Aa][Uu][Tt][Oo] | [Pp][Rr][Oo][Mm][Pp][Tt]) REAL_ANS=2 ;;
        *) _usage 3 "Invalid argument: \`${ANS}\`" ;;
    esac
    return 0
}

while getopts "$OPTIONS" OPTION; do
    case "$OPTION" in
        C)
            _toggle_var_check "${OPTARG}"
            CLEAN_SCRIPT="${REAL_ANS}"
            _not_in_selected "clear" && SELECTED+=("clear")
            ;;
        P)
            _toggle_var_check "${OPTARG}"
            WITH_PYTHON="${REAL_ANS}"
            _not_in_selected "python" && SELECTED+=("python")
            ;;
        R)
            _toggle_var_check "${OPTARG}"
            REWRITE_README="${REAL_ANS}"
            _not_in_selected "readme" && SELECTED+=("readme")
            ;;
        L)
            _toggle_var_check "${OPTARG}"
            REPLACE_LICENSE="${REAL_ANS}"
            _not_in_selected "license" && SELECTED+=("license")
            ;;
        H)
            _toggle_var_check "${OPTARG}"
            WITH_HEALTH="${REAL_ANS}"
            _not_in_selected "health" && SELECTED+=("health")
            ;;
        s)
            _toggle_var_check "${OPTARG}"
            WITH_STYLUA="${REAL_ANS}"
            _not_in_selected "stylua" && SELECTED+=("stylua")
            ;;
        S)
            _toggle_var_check "${OPTARG}"
            WITH_SELENE="${REAL_ANS}"
            _not_in_selected "selene" && SELECTED+=("selene")
            ;;
        c)
            _toggle_var_check "${OPTARG}"
            WITH_CI="${REAL_ANS}"
            _not_in_selected "ci" && SELECTED+=("ci")
            ;;
        T)
            _toggle_var_check "${OPTARG}"
            WITH_TESTS="${REAL_ANS}"
            _not_in_selected "tests" && SELECTED+=("tests")
            ;;
        N)
            PLUGIN_NAME="${OPTARG}"
            ASK_NAME=0
            _not_in_selected "readme" && SELECTED+=("readme")
            ;;
        D)
            PLUGIN_DESCRIPTION="${OPTARG}"
            ASK_DESCRIPTION=0
            _not_in_selected "readme" && SELECTED+=("readme")
            ;;
        I)
            INDENTATION="${OPTARG}"
            _not_in_selected "indentation" && SELECTED+=("indentation")
            ;;
        t)
            TAB_SIZE="${OPTARG}"
            _not_in_selected "indentation" && SELECTED+=("indentation")
            ;;
        o) ONLY_SELECTED=1 ;;
        v) VERBOSE=1 ;;
        h) _usage 0 ;;
        :) _usage 1 "Missing argument for option \`${OPTION}\`" ;;
        ?) _usage 1 "Invalid option!" ;;
        *) _usage 1 "Invalid args!" ;;
    esac
done

[[ $ONLY_SELECTED -eq 0 ]] && SELECTED=()

_main || _die 1
_die 0

# vim: set ts=4 sts=4 sw=4 et ai si sta:
