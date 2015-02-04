#!/bin/bash

# uses wp-cli to setup WP for a list of users read from text file.
# Does the following for each line in text file (script assumes user list contains UW NetIDs).
# - creates user
# - creates WP DB
# - uses wp-cli to download, create config, and install WP
# - writes user name and password to text file

# If "-d" is passed the sites are destroyed and user deleted instead.
# Script uses root and root for user name and password to MySQL for DB and DB user creation.
# Hopefully that is not what your MySQL server is using.


HOME_PATH="/var/www/html"
SITE_URL="http://example.com"


#Set Script Name variable
SCRIPT=`basename ${BASH_SOURCE[0]}`

#Initialize variables to default values.
DELETE=0

#Help function
function HELP {
  echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
  echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
  echo "Command line switches are optional. The following switches are recognized."
  echo "${REV}-d${NORM}  --Deletes users, removing WP sites and DBs instead of creating them."
  echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
  exit 1
}

if [ $# -eq 0 ]
  then
    HELP
    exit 1
fi

while getopts :dh FLAG; do
  case $FLAG in
    d)  #set option "d"
      DELETE=1
      ;;
    h)  #show help
      HELP
      ;;
    \?) #unrecognized option - show help
      echo -e "Use ${BOLD}$SCRIPT -h${NORM} to see the help documentation."\\n
      exit 2
      ;;
  esac
done

shift $((OPTIND-1))  #This tells getopts to move on to the next argument.

### End getopts code ###

if [ $DELETE = 1 ]
then
	while read NAME                                                                         
	do
        	echo "removing user $NAME..."                                                   
        	passwd -l $NAME                                                                 
        	killall -KILL -u $NAME                                                          
        	userdel -r $NAME                                                                
        	echo "DROP database wp_$NAME;DROP USER 'wp_$NAME'@'localhost'" | mysql -u root --password=root
	done <$1
else
	while read NAME
	do
		PASSWORD=`makepasswd --chars=12`
		echo "creating $NAME..."
		useradd $NAME --create-home --home $HOME_PATH/$NAME --shell /bin/bash
		echo "setting $NAME's password..."
		echo "$NAME:$PASSWORD" | chpasswd
		echo "creating $NAME's DB..."
		echo "create database wp_$NAME;grant all on wp_$NAME.* to 'wp_$NAME'@'localhost' identified by '$PASSWORD'" | mysql -u root --password=root
		sudo -u $NAME -i -- wp core download --path=$HOME_PATH/$NAME
		sudo -u $NAME -i -- wp core config --dbname="wp_$NAME" --dbuser="wp_$NAME" --dbpass="$PASSWORD" --path=$HOME_PATH/$NAME
		sudo -u $NAME -i -- wp core install --url=$SITE_URL/$NAME --title="$NAME's Wordpress" --admin_user=$NAME --admin_password=$PASSWORD --admin_email="$NAME@wisc.edu" --path=$HOME_PATH/$NAME
		echo "$NAME : $PASSWORD" >> userlist.txt
	done <$1
fi
