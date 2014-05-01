#! /bin/bash

#function to print help/usage
help() {
#Our underline open/close tags/vars
ul=`tput smul`
nl=`tput rmul`
#Printing out the usage
echo "Usage:"
echo ""$0" [ -t ${ul}Time to run${nl} ] [ -f ${ul}File to dump traffic to${nl} ] [ -i ${ul}Interface to snoop on${nl} ] OPTIONS [-gh]"
echo "Defaults:"
echo "Time: 5 seconds		Dump File: capture.txt		Interface: any"
echo "Options:"
echo "-g	Capture google searches"
echo "-h	Display Help"
}

#Function to capture google searches from the network traffic
google() {
sudo tcpdump -i $iface -X > $file & #This will dump all the traffic in hex/ascii format in the file

#Starting a different instance for binary data to capture searches easily
sudo tcpdump -i $iface -n -s 0 -w - > gcap &

#Main program loop
i=0
while [ true ]
do
#Filtering network traffic to get the required info (gogle searches).
#Currently limited to queries >= 4 to filter out nonsense.
capture=`cat gcap | grep -a -E -o  "GET.*search.*q=[^&]{4,}" | grep -a -E -o "q=[^&]*&?" | head -n 1 | awk '{print $1}'`
#From that filtering out the nonsensical info.
capture=${capture:2}
if [ -z $capture ]
then
	echo "" > gcap
else
	len=`expr length $capture`
	if [ "${capture:$len-1:1}" == "&" ]
	then
		capture=${capture:0:$len-1}	#Remove the ampersand from the end
	fi
	capture=`echo $capture | sed 's/\+/ /g'`   #Final filter to purify the output (change the pluses to spaces)
	echo "" > gcap
	echo $capture >> searches.txt #Append the caught searches
fi

sleep 1
i=$((i+1))
if (( i>=$t ))	#Making sure it only runs up to the upper time limit imposed by the user.
then
	if (( $i < 60 ))
	then
	echo "$i seconds up. Closing down..."
	else
	echo "`expr $i / 60` minutes up. Closing down..."
	fi
	#Kill everything, clean up the mess.
	rm -rf gcap
	killall tcpdump
	kill -9 $$
fi
done
}


#Specifying defaults
file="capture.txt"
iface="any"
t="5"
g="0"

#Prints help if no argument is supplied
if (( $# == 0 ))
then
	help
fi

#Checking for user's input arguments
while getopts "ghf:i:t:" OPTION
do
    case $OPTION in
        f)
            file=$OPTARG
            ;;
        i)
            iface=$OPTARG
            ;;
        t)
            t=$OPTARG
	    leng=${#t}
	    #Allow time arguments like 1m or 2h for easier usage     
	    [[ "$t" =~ "m" ]] && t=$(expr `echo ${t:0:$leng-1}` \* 60)
	    [[ "$t" =~ "h" ]] && t=$(expr `echo ${t:0:$leng-1}` \* 3600)
            ;;
        g)
            g=1
            google
            ;;
	h)
	    help
	    exit
	    ;;
        esac
done

#Time to start tcpdump
#Create a traffic dump to analyze later IF google's capture script is not supposed to run
if [ "$g" == "0" ]
then
sudo tcpdump -i $iface -X > $file & #This will dump all the traffic in hex/ascii format in the file
sleep $t
killall tcpdump
kill -9 $$
fi