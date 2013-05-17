#!/bin/bash

[ -p "in" -a -r out ] || exit 1

function check_tweets {
    app_mentions="./twmentions.py"
    app_timeline="./twtimeline.py"
    app_sn_timeline="./sntimeline.sh"

    $app_timeline >in
    $app_mentions >in
    $app_sn_timeline >in
}

function tweet_check_loop {
    interval=600
    while [ 1 ]; do check_tweets; sleep $interval; done
}

function handle_join {
    nick=$1
    ln=$((1 + $RANDOM % `wc -l greetmsg | awk {'print $1'}`))
    greet=`head -n $ln greetmsg | tail -n 1`
    now=`date +%s`
    previous=`grep "^$nick " greet_history | cut -d " " -f 2 2>/dev/null`
    
    interval=$((24*3*3600))

    sleep $(($RANDOM%5)).$(($RANDOM%10))

    if [ -z "$previous" ]; then
	echo "$nick: $greet" >in
	echo $nick $now >>greet_history
    elif [ $(($now - $previous)) -gt $interval ]; then
	echo "$nick: $greet" >in
	sed -i "s/^$nick $previous\$/$nick $now/" greet_history
    else
	sed -i "s/^$nick $previous\$/$nick $now/" greet_history
    fi
}

function publish_news {
    dt=`date "+%Y-%m-%d %H:%M:%S %z"`
    md5sum=`md5sum <<<$dt | awk {'print $1'}`
    rest=$1

    local status="fail"

    touch publication && cat - publication <<<"$dt|$rest" >pub && mv -f pub publication
    if [ "$dt|$rest" == "`head -n 1 publication`" ]; then
        cp publication /path/to/news.txt && stat -c %s /path/to/news.txt >/path/to/news.size
        if [ $? == 0 ]; then status="ok"; fi
    fi

    echo news:$status
}

function publish_tweet {
    rest=$1
    twitapp="./tweet.py"

    status_twitter="fail"
    status_statusnet="fail"

    if [ `wc -m <<<"$rest"` -le 140 ]; then
        twitmsg=$rest
    
	[ -n "`curl -k --connect-timeout 5 --basic --user user:'password' -d status=\"$twitmsg\" https://status.telecomix.org/api/statuses/update.xml | grep statusnet:html`" ] && status_statusnet="ok"
    
	if [ -x "$twitapp" ]; then
            "$twitapp" "$twitmsg"
            retcode=$?
	    [ $retcode == 0 ] && status_twitter="ok"
	fi

    else

	echo Too long.
	
    fi

    echo statusnet:$status_statusnet twitter:$status_twitter
}

function enqueue
{
    rest=$1
    how=$2
    id=$RANDOM
    while [ -r queue_$id ]; do id=$RANDOM; done
    echo -e "$rest"'\n'$how >queue_$id && echo $id || echo 0
}

function cont_msg
{
    rest=$2
    id=$1

    if [ ! -w queue_$id -o ! -r queue_$id ]; then
	echo "I can't find this post ID, sorry :/"
    else
	md5before=$(md5sum queue_$id)
	sed -i "1c$(head -n 1 queue_$id) $rest" queue_$id
	md5after=$(md5sum queue_$id)
	if [ "$md5before" == "$md5after" ]; then
	    echo "failed lol I haz an internal error :D"
	else
	    len=$(head -n 1 queue_$id | wc -m)
	    echo "Continuation saved [now: $len characters] <3"
	fi
    fi    
}

function publish_video {
    arg=$1
    date_str=$(cut -d " " -f 1 <<<$arg | egrep '^([0-9]{4}-[01][0-9]-[0-3][0-9]|today|unknown)$' | sed s/today/$(date +%Y-%m-%d)/ | sed s/unknown/0000-00-00/)
    place=$(cut -d " " -f 2 <<<$arg | tr '[A-Z]' '[a-z]')
    url=$(cut -d " " -f 3 <<<$arg | egrep '^(http://|https://)')
    description=$(cut -d " " -f 4- <<<$arg)

    [ -z "$date_str" ] && echo date not valid && exit;
    [ -z "$url" ] && echo URL not valid && exit;

    dbfile="$materialdir/videos.txt"

    echo "$date_str $place $url $description" >>$dbfile && echo ok || echo fail
}

function publish_pic {
    arg=$1
    date_str=$(cut -d " " -f 1 <<<$arg | egrep '^([0-9]{4}-[01][0-9]-[0-3][0-9]|today|unknown)$' | sed s/today/$(date +%Y-%m-%d)/ | sed s/unknown/0000-00-00/)
    place=$(cut -d " " -f 2 <<<$arg | tr '[A-Z]' '[a-z]')
    url=$(cut -d " " -f 3 <<<$arg | egrep '^(http://|https://)')
    description=$(cut -d " " -f 4- <<<$arg)

    [ -z "$date_str" ] && echo date not valid && exit;
    [ -z "$url" ] && echo URL not valid && exit;
    
    dbfile="$materialdir/pictures.txt"

    echo "$date_str $place $url $description" >>$dbfile && echo ok || echo fail
}

function handle_message {
    nick=$1
    msg=$2

    cmdch="+"

    acl='some|nick|names'


    if [ "`cut -b 1 <<<$msg`" == "$cmdch" ]; then
	cmd=`cut -d " " -f 1 <<<$msg | cut -b 2-`
	rest=`cut -d " " -f 2- <<<$msg`
	control=`egrep \("$acl"\) <<<$nick`

	case $cmd in
	    "help")
		echo "Cmds: +news +tweet +yarly +stfu +mode +mode? +cheezburger +cont +echo +echo? +video" >in
		;;

	    news|tweet)
		if [ -n "$control" ]; then
		    if [ $echomode == on ]; then
			echo "$rest" >in
		    fi
		    
		    if [ $publishmode == "direct" ]; then
			echo $(publish_$cmd "$rest") >in
		    elif [ $publishmode == "queue" ]; then
			ret=$(enqueue "$rest" $cmd)
			if [ $ret == "0" ]; then
			    echo "fail?!?" >in
			else
			    len=$(head -n 1 queue_$ret | wc -m)
			    echo "$nick:" \[$len chars\] - More text: \"${cmdch}cont $ret\" - Publish: \"${cmdch}yarly $ret\" - Cancel: \"${cmdch}stfu $ret\" >in
			fi
		    fi
		else
		    echo "noez :)" >in
		fi
		;;

	    mode)
		if [ -n "$control" ]; then
		    egrep '^(direct|queue)$' <<<"$rest" >/dev/null && publishmode=$rest && echo Yup >in || echo "What?" >in
		else
		    echo "noez :p" >in
		fi
		;;

	    "echo")
		if [ -n "$control" ]; then
		    egrep '^(on|off)$' <<<"$rest" >/dev/null && echomode=$rest && echo "okey ;)" >in || echo "on or off ??" >in
		else
		    echo "hahaha no no no noez :D" >in
		fi
		;;

	    "mode?")
		echo $publishmode >in
		;;
	    
	    "echo?")
		echo $echomode >in
		;;

	    yarly)
                if [ -n "$control" ]; then
		    id="`egrep '^[0-9]*$' <<<\"$rest\"`"
		    if [ -r queue_$id ]; then
			topub="`head -n 1 queue_$id`"
			how="`head -n 2 queue_$id | tail -n 1`"
			echo $(publish_$how "$topub") >in
			rm -f queue_$id
		    else
			echo Dunno this post O_o >in
		    fi
		else
		    echo "dont think so" >in
		fi
		;;

	    cont)
		id="`cut -d ' ' -f 1 <<<\"$rest\" | egrep '^[0-9]*$'`"
		msg="`cut -d ' ' -f 2- <<<\"$rest\"`"

		if [ -n "$control" ]; then
		    if [ $echomode == on -a -r queue_$id ]; then
			echo "$msg" >in
		    fi
		    echo $(cont_msg "$id" "$msg") >in
		else
		    echo "I'm kinda disappoint, it seems you do not have my trust to do that at the moment :/" >in
		fi
		;;

	    stfu)
		if [ -n "$control" ]; then
		    id="`egrep '^[0-9]*$' <<<\"$rest\"`"
		    if [ -f queue_$id ]; then
			echo Message $id dropped >in
			rm -f queue_$id
		    else
			echo Unknown ID
		    fi
		fi
		;;

	    video|pic)
		if [ -n "$control" ]; then
		    echo $nick: $cmd: $(publish_$cmd "$rest") >in
		else
		    echo "You cannot :/" >in
		fi
		;;
	    
	    cheezburger)
		echo nomnomnomnnom >in
		;;

	    cookie)
		echo nomnomcrunch :D >in
		;;

	    *)
		echo 'mmmh?' >in
		;;
	esac
    fi    
}

publishmode="queue"
echomode="on"
dtpattern="^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}"
materialdir="/some/path/to/vidsandpics"

tweet_check_loop &


tail -f -n 0 out | while read line;
do
    isjoin=`egrep "$dtpattern -!-.*has joined.*" <<<$line`
    ismsg=`egrep "$dtpattern <" <<<$line`

    if [ -n "$isjoin" ]; then
	nick=`sed -r "s/$dtpattern"' -!- ([^ \\(\\)]*).*/\1/' <<<$isjoin`
	handle_join "$nick"
    elif [ -n "$ismsg" ]; then
	nick=`sed -r "s/$dtpattern"' <([^ ]*)>.*/\1/' <<<$line`
	msg=`sed -r "s/$dtpattern"' <[^ ]*> (.*)/\1/' <<<$line` 
	handle_message $nick "$msg"
    fi
done