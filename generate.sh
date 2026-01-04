#!/usr/bin/env bash
#
# Generate your plugin data and tweaks with a simple execution!
#

DATA=""

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

_rename_annotations() {
    local IFS

    _prompt_data "Rename your module class annotations (default: \`MyPlugin\`): " 0

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${DATA}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    return 0
}

_rename_modules() {
    if [[ -d ./lua/my-plugin ]] && _file_readable_writeable "./lua/my-plugin.lua"; then
        _prompt_data "Rename your Lua module (default: \`my-plugin\`): " 0

        while ! [[ $DATA =~ ^[a-zA-Z_][a-zA-Z0-9_\-]+$ ]]; do
            error "Invalid module name!" "Use a parseable Lua module name"
            _prompt_data "Rename your Lua module (default: \`my-plugin\`): " 0
        done

        mv ./lua/my-plugin "./lua/${DATA}" || return 1
        mv ./lua/my-plugin.lua "./lua/${DATA}.lua" || return 1
    fi

    return 0
}

_select_indentation() {
    local IFS
    local EC=0
    DATA=""

    while true; do
        _prompt_data "Use tabs or spaces? [Spaces/tabs]: " 1
        if [[ -n "$DATA" ]]; then
            case "$DATA" in
                [Ss][Pp][Aa][Cc][Ee][Ss])
                    DATA="Spaces"
                    break
                    ;;
                [Tt][Aa][Bb][Ss])
                    DATA="Tabs"
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
        if [[ "$DATA" == "Tabs" ]]; then
            sed -i "s/\\set\\s/ noet /g" "${file}" || return 1
        else
            sed -i "s/\\snoet\\s/ et /g" "${file}" || return 1
        fi
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
        if [[ -n "$DATA" ]] && ! [[ $DATA =~ ^[1-9]+[0-9]*$ ]]; then
            error "Invalid indentation level!" "Try again..."
            continue
        elif [[ -n "$DATA" ]] && [[ $DATA =~ ^[1-9]+[0-9]*$ ]]; then
            break
        elif [[ -z "$DATA" ]]; then
            DATA="2"
            break
        fi
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

_rename_modules || die 1 "Couldn't rename module file structure!"
_rename_annotations || die 1 "Couldn't rename module annotations!"
_select_indentation || die 1 "Unable to set indentation!"

exit 0
# vim: set ts=4 sts=4 sw=4 et ai si sta:
