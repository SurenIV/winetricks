#!/bin/sh

list_comp=./list_comp
tries=0

get_file_sha()
{
    local file_name="$1"
    gotsha256sum=$(sha256sum "$file_name" | sed 's/(stdin)= //;s/ .*//')
}

if [ -z "$list_comp" ]; then
    echo "Список компонентов не найден."
    exit 1
fi

if [ ! -x "$(command -v epm 2>/dev/null)" ] ; then
    echo "Не удалось найти epm."
    exit 1
fi

while read -r comp_dir url sha comp_name; do
    tries=0
    skip_sha_check=0
    url="$(echo $url | sed 's|"||g')"
    echo "Попытка загрузить компонент $comp_dir."
    while test $tries -lt 2 ; do
        tries=$((tries + 1))

        if [ -z "$comp_name" ]; then
            comp_name="$(echo $url | sed -e 's|^.*/||g' -e 's|"||g')"
        else
            comp_name="$(echo $comp_name | sed 's|"||g')"
        fi

        if [ -d ./winetricks/"$comp_dir" ]; then
            cd ./winetricks/"$comp_dir"
        else
            echo "Будет создан каталог ./winetricks/$comp_dir"
            mkdir -p ./winetricks/"$comp_dir"
            cd ./winetricks/"$comp_dir"
        fi

        if [ -s "$comp_name" ]; then
            if [ -z "$sha" ]; then
                echo "В списке у компонента не указана контрольная сумма."
                echo "Проверка контрольной суммы будет пропущена."
                cd - > /dev/null
                break
            fi

            get_file_sha "$comp_name"
            if [ "$gotsha256sum"x = "$sha"x ]; then
                echo "Контрольная сумма существуюего файла совпадает с указанной в списке."
                echo "Загрузка выполнена не будет."
                cd - > /dev/null
                break
            else
                echo "Контрольная сумма существуюего файла не совпадает с указанной в списке."
                echo "Загрузка будет выполнена повторная загрузка."
                test -f "$comp_name" && rm "$comp_name"
            fi
        fi

        #if [ "$checksum_ok" = "0" ]; then
            epm tool eget -P ./winetricks/"$comp_dir" -O "$comp_name" -nd -c --read-timeout 300 --retry-connrefused --tries "3" --header "Accept: */*" "$url"
        #fi

        if test $? = 0; then
            echo "Загрузка $comp_name выполнена успешно."
            cd - > /dev/null
            break
        elif test $tries = 2; then
            echo "Загрузить $comp_name с web.archive.org не удалось."
            skip_sha_check=1
            test -f "$comp_name" && rm "$comp_name"
            break
        fi

        echo "Не удалось загрузить $comp_name из источника, попытка загрузить с web.archive.org"
        url="https://web.archive.org/web/2000/$url"
        cd - &> /dev/null
    done

    # Проверка контролькой суммы загруженного файла, если он был загружен.
    # И выход если контрольная сумма не совпала.
    get_file_sha ./winetricks/"$comp_dir"/"$comp_name"
    if [ -n "$sha" ] || [ "$skip_sha_check" = "1" ]; then
        if [ "$gotsha256sum"x != "$sha"x ]; then
            echo "Контрольная сумма существуюего файла не совпадает после выполненой загрузки!"
            echo "Выполнение скрипта будет остановленно!"
            exit 1
        fi
    fi
    echo "#-------------------------------------------------------#"
done < $list_comp

echo "Создание архива winetricks-all.tar.gz"
tar -czvf winetricks-all.tar.gz ./winetricks || { echo "Ошибка создания архива!" ; exit 1; }
echo "Выполнения скрипта загрузки успешно завершена"
