#!/bin/sh

db_file="db.sn"

function rdom () { local IFS=\> ; read -d \< E C ;}

curl -k --connect-timeout 5 --basic --user telecomixsyria:'password' https://status.telecomix.org/api/statuses/home_timeline.xml 2>/dev/null | \
    while rdom;
do 
    if [ "$E" == "screen_name" ]; then
	echo $C >tmp_screen_name
    elif [ "$E" == "text" ]; then
	echo $C >tmp_text
    elif [ "$E" == "error" ]; then
	touch snt_error
    elif [ "$E" == "id" -a ! -r tmp_id ]; then
	echo -n $C >tmp_id
    fi

    if [ -r tmp_screen_name -a -r tmp_text -a -r tmp_id ]; then
	egrep "^$(cat tmp_id)\$" $db_file >/dev/null 2>&1 || (echo `cat tmp_screen_name tmp_text` | sed "s/ /: /" && echo $(cat tmp_id) >>$db_file)
	rm -f tmp_screen_name tmp_text tmp_id
    fi
done

[ -f snt_error ] && rm -f snt_error && exit 1

exit 0