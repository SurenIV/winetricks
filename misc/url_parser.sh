#!/bin/sh -e
#set -x

script_path="$(dirname "$0")"

if [ ! -r "${script_path}/winetricks-func" ]; then
    mkdir "${script_path}/winetricks-func"
fi

# todo: add or remove quiet feature
quiet="1"
# Копирование всех функций из winetricks, используется для того что бы знать откуда будут доставаться ссылки.
while IFS= read -r find_func ; do
    case ${find_func} in
        *#*"()") if [ "${quiet}" != "1" ]; then echo "skip \"${find_func}\" its not function, its comment"; fi;;
        *"()" | *"()"*"{") func_name="${find_func}"; if [ "${quiet}" != "1" ]; then echo "found function with name \"${func_name}\""; fi;;
        "}"*) end_func="1";;
        *) func_name=""; end_func="";;
    esac

    if [ -n "${func_name}" ]; then
        func_orig_name="$(echo "${func_name}" | sed 's/()//' | sed 's/ {//')"
        touch ./winetricks-func/"${func_orig_name}"
        latest_func="${func_orig_name}"
        echo "${find_func}" >> ./winetricks-func/"${latest_func}"
    elif [ -n "${end_func}" ] && [ -n "${latest_func}" ]; then
        echo "${find_func}" >> ./winetricks-func/"${latest_func}"
        latest_func=""
    elif [ -z "${latest_func}" ]; then
        if [ "${quiet}" != "1" ]; then
            echo "skip ${find_func}"
        fi
    else
        echo "${find_func}" >> ./winetricks-func/"${latest_func}"
    fi
done < "${script_path}/../src/winetricks"

{
    echo ""
    echo "w_metadata download_all_comp settings \\"
    echo '    title="download_all_comp"'
    echo ""
    echo "load_download_all_comp()"
    echo "{"
} >> "./download_all_comp"

for func_file in $(ls "${script_path}/winetricks-func"); do
    # Пропуская функцию загрузки обновленного winetricks.
    # Убрал загрузку, так как она выполняется во временный каталог и смысла загружать в cache нет.
    # todo: починить загрузку cnc_ddraw "${file1}"
    if [ "${func_file}" = "winetricks_selfupdate" ]; then
        continue
    elif [ "${func_file}" = "load_faudio" ]; then
        continue
    elif [ "${func_file}" = "load_cnc_ddraw" ]; then
        continue
    fi

    if [ -r "${script_path}/winetricks-func/${func_file}" ]; then
        # Поиск строк загрузки компонентов в функциях
        grep -E '(^ *w_download |^ *w_download_to)' "${script_path}/winetricks-func/${func_file}" | grep -E 'ftp|http' | grep -v "w_linkcheck_ignore=1" | sed 's/^ *//' | tr -d '\\' > url-winetricks.tmp
        # Получаем название компонента из названия функции
        func_name=$(echo "${func_file}" | sed -e 's|winetricks_||i' -e 's|helper_||i' -e 's|load_||i')

        while read -r download_string; do
            case "${download_string}" in
                # если w_download_to то пропускаем, строку менять не нужно
                *w_download_to*) continue;;
                # если w_download, то убераем из строки название функции что бы заменить на w_download_to
                *w_download*) download_func_type="1"; download_string=$(echo "${download_string}" | sed 's|w_download ||g');;
            esac

            if [ "${download_func_type}" = "1" ]; then
                echo "    w_download_to ${func_name} ${download_string}" >> "./download_all_comp"
            else
                echo "    ${download_string}" >> "./download_all_comp"
            fi

            download_func_type="0"
        done < url-winetricks.tmp
        rm -f url-winetricks.tmp
    else
        echo "cant find ${script_path}/winetricks-func/${func_file}"
    fi
done

echo "}" >> "./download_all_comp"
rm -rf "${script_path}/winetricks-func"
