#!/usr/bin/env bash
#
# Generate your plugin data and tweaks with a simple execution!
#

# shellcheck disable=SC2207

DATA=""
MODULE_NAME=""
ANNOTATION_PREFIX=""
LINE_SIZE=""

# Print all args to `stderr`
error() {
    local TXT=("$@")
    printf "%s\n" "${TXT[@]}" >&2
    return 0
}

die() {
    local EC=1

    if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        EC="$1"
        shift
    fi

    if [[ $# -ge 1 ]]; then
        local TXT=("$@")
        if [[ $EC -eq 0 ]]; then
            printf "%s\n" "${TXT[@]}"
        else
            error "${TXT[@]}"
        fi
    fi

    exit "$EC"
}

# Check whether a given console command exists
_cmd_exists() {
    if [[ $# -eq 0 ]]; then
        error "What command?"
        return 127
    fi

    local OPTS=":v"
    local VERBOSE=0
    local CMDS=()
    local EXES=()
    local ARG
    while getopts "$OPTS" ARG; do
        case "$ARG" in
            v) VERBOSE=$((VERBOSE + 1)) ;;
            *)
                command -v "$ARG" &> /dev/null || return 1
                CMDS+=("$ARG")
                EXES+=("$(command -v "$ARG" 2> /dev/null)")
                ;;
        esac
        shift
    done

    if [[ $VERBOSE -eq 1 ]]; then
        printf "%s\n" "${CMDS[@]}"
    elif [[ $VERBOSE -eq 2 ]]; then
        printf "\`%s\` ==> OK\n" "${CMDS[@]}"
    elif [[ $VERBOSE -ge 3 ]]; then
        for I in $(seq 1 ${#CMDS[@]}); do
            I=$((I - 1))
            printf "\`%s\` ==> \`%s\` ==> OK\n" "${CMDS[I]}" "${EXES[I]}"
        done
        unset I
    fi
    return 0
}

_cmd_exists 'find' || die 127 "\`find\` is not in PATH!"

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

_rename_module() {
    if [[ -d ./lua/my-plugin ]] && _file_readable_writeable "./lua/my-plugin.lua"; then
        while true; do
            _prompt_data "Rename your plugin module (previously: \`my-plugin\`): " 0

            if [[ $DATA =~ ^[a-zA-Z_][a-zA-Z0-9_\-]*[a-zA-Z0-9_]$ ]]; then
                break
            fi

            error "Invalid module name!" "Use a parseable Lua module name"
        done

        MODULE_NAME="${DATA}"

        mv ./lua/my-plugin "./lua/${MODULE_NAME}" || return 1
        mv ./lua/my-plugin.lua "./lua/${MODULE_NAME}.lua" || return 1
        mv ./rplugin/python3/my-plugin.py "./rplugin/python3/${MODULE_NAME}.py" || return 1
    fi

    return 0
}

_rename_annotations() {
    local IFS

    while true; do
        _prompt_data "Rename your module class annotations (previously: \`MyPlugin\`): " 0

        if [[ $DATA =~ ^[a-zA-Z][a-zA-Z0-9_\.]*[a-zA-Z0-9_]$ ]]; then
            break
        fi

        error "Invalid module name: \`${DATA}\`" "Try again..."
    done

    ANNOTATION_PREFIX="${DATA}"

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)
    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find rplugin -type f -regex '.*\.py$' -print0)

    return 0
}

_select_indentation() {
    local IFS
    local ET=""
    DATA=""

    while true; do
        _prompt_data "Use tabs or spaces? [Spaces/tabs]: " 1
        if [[ -n "$DATA" ]]; then
            case "$DATA" in
                [Ss][Pp][Aa][Cc][Ee][Ss])
                    DATA="Spaces"
                    ET="et"
                    break
                    ;;
                [Tt][Aa][Bb][Ss])
                    DATA="Tabs"
                    ET="noet"
                    break
                    ;;
                *)
                    error "Invalid indentation style!" "Try again..."
                    continue
                    ;;
            esac
        else
            DATA="Spaces"
            break
        fi
    done

    while IFS= read -r -d '' file; do
        sed -i "s/\\set\\s/ ${ET} /g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^indent_type\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^indent_type\\s\\+=\\s.*$/indent_type = \"${DATA}\"/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))

            printf "%s\n" "indent_type = \"${DATA}\"" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi

    while true; do
        _prompt_data "Select your indentation level (default: 2): " 1
        if [[ -n "$DATA" ]]; then
            if ! [[ $DATA =~ ^[1-9]+[0-9]*$ ]]; then
                error "Invalid indentation level!" "Try again..."
                continue
            fi
        else
            DATA="2"
        fi

        break
    done

    while IFS= read -r -d '' file; do
        sed -i "s/^--\\svim:\\sset\\sts=[1-9]\\+[0-9]*\\ssts=[1-9]\\+[0-9]*\\ssw=[1-9]\\+[0-9]*/-- vim: set ts=${DATA} sts=${DATA} sw=${DATA}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^indent_width\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^indent_width\\s\\+=\\s.*$/indent_width = ${DATA}/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))

            printf "%s\n" "indent_width = ${DATA}" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi

    return 0
}

_select_line_size() {
    local IFS
    DATA=""

    while true; do
        _prompt_data "Select your line size (default: 100): " 1

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

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^column_width\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^column_width\\s\\+=\\s.*$/column_width = ${LINE_SIZE}/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))

            printf "%s\n" "column_width = ${LINE_SIZE}" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi

    return 0
}

_remove_health_file() {
    if ! _yn "Remove the checkhealth file? [y/N]: " 1 "N"; then
        return 0
    fi

    if _file_readable_writeable "./lua/${MODULE_NAME}/health.lua"; then
        rm "./lua/${MODULE_NAME}/health.lua"
        return $?
    fi

    return 1
}

_remove_python_component() {
    if ! _yn "Remove the Python component? [Y/n]: " 1 "Y"; then
        return 0
    fi

    if _file_readable_writeable "./rplugin/python3/${MODULE_NAME}.py"; then
        rm -rf ./rplugin
        return $?
    fi

    return 1
}

_remove_script() {
    if ! _file_readable_writeable ./generate.sh; then
        return 1
    fi

    if ! _yn "Self-destruct this script? [Y/n]: " 1 "Y"; then
        return 0
    fi

    rm ./generate.sh
    return $?
}

_main() {
    _rename_module || die 1 "Couldn't rename module file structure!"
    _rename_annotations || die 1 "Couldn't rename module annotations!"

    _select_indentation || die 1 "Unable to set indentation!"
    _select_line_size || die 1 "Unable to set StyLua line size!"

    _remove_health_file || die 1 "Unable to (not) remove health file!"
    _remove_python_component || die 1 "Unable to (not) remove Python component!"

    _remove_script || die 1

    die 0
}

_main

# vim: set ts=4 sts=4 sw=4 et ai si sta:
