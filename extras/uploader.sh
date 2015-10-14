#!/bin/bash
# 
# File:   uploader.sh
#
# Author: Giovani Paseto
#
# Created on Nov 21, 2014, 8:36:24 AM
#
# Upload files using cloud services API apps
#
# Require: zip
#

# Config file
VERSION="0.1"
CONFIG_FILE=~/.uploader

echo "Init setup"
if [[ -e $CONFIG_FILE ]]; then
    source "$CONFIG_FILE" 2>/dev/null || {
        sed -i'' 's/:/=/' "$CONFIG_FILE" && source "$CONFIG_FILE" 2>/dev/null
    }
    if [[ $FOLDER_NAME == "" || $MYSQL_U == "" || $MYSQL_P == "" || $MYSQL_DB == "" || $APP_LOCATION == "" ]]; then
        echo -e "Ops, there's something wrong with you config file, please run again."
        unlink $CONFIG_FILE
        exit 1
    fi
else    
    while (true); do
	echo -ne "\n ----- Uploader v$VERSION - [SETUP] ----- \n"
        echo -ne "\n Please follow instructions above:\n"        	
        echo -n " Please choose a folder name [UPLOADER]:"
        read FOLDER_NAME
	if [[ $FOLDER_NAME == "" ]]; then 
            FOLDER_NAME="UPLOADER"
        fi
	echo -n " MySQL username:"
        read MYSQL_U
	echo -n " MySQL password:"
        read MYSQL_P
	echo -n " MySQL Database name:"
        read MYSQL_DB
	echo -n " Cloud API App location [/home/user/cut.sh]:"
        read APP_LOCATION

	# Save config file
	echo -ne "OK\n"            
        echo "FOLDER_NAME=$FOLDER_NAME" > "$CONFIG_FILE"
        echo "MYSQL_U=$MYSQL_U" >> "$CONFIG_FILE"        
        echo "MYSQL_P=$MYSQL_P" >> "$CONFIG_FILE"
        echo "MYSQL_DB=$MYSQL_DB" >> "$CONFIG_FILE"
        echo "APP_LOCATION=$APP_LOCATION" >> "$CONFIG_FILE"

        echo -ne "\n Done!\n"	
	break
    done;
fi

# Params
DATE=$(date +"%Y%m%d")
TIME=$(date +"%H%M")


#Config DB params
db1="$MYSQL_DB.sql"
COMPRENSSED_FILE="${DATE}${TIME}_${MYSQL_DB}_${FOLDER_NAME}"

#Config file/folder to upload params
SOURCE_FOLDER="$HOME/$FOLDER_NAME/SOURCE_UPLOAD_FOLDER/"
DESTINATION_FOLDER="$HOME/$FOLDER_NAME/DESTINATION_UPLOAD_FOLDER/"

#Optional params
DATABASE_FOLDER="$HOME/$FOLDER_NAME/DB/"
CLOUD_FOLDER_1="$FOLDER_NAME/FILES/"
ARGS="-r"


echo "START $DATE"
for file_1 in $( find $SOURCE_FOLDER* -type f | sed 's/\.\.\///g' )             # For each file in SOURCE_FOLDER
do
        file_2=$( echo $file_1 | sed "s $SOURCE_FOLDER $DESTINATION_FOLDER g" )              # Getting file path in DESTINATION_FOLDER
        dir_2=$( dirname $file_2 )


        if [ ! -d $dir_2 ]                                              # Checking if sub-dir exists in DESTINATION_FOLDER
        then
                echo -e "Dir: $dir_2 does not exist. Creating...\c"
                mkdir -p $dir_2                                         # Creating if sub-dir missing
                echo "Done"
        fi

        if [ -f $file_2 ]                                               # Checking if file exists in DESTINATION_FOLDER
        then
                cksum_file_1=$( cksum $file_1 | cut -f 1 -d " " )       # Get cksum of file in SOURCE_FOLDER
                cksum_file_2=$( cksum $file_2 | cut -f 1 -d " " )       # Get cksum of file in DESTINATION_FOLDER

                if [ $cksum_file_1 -ne $cksum_file_2 ]                  # Check if cksum matches
                then
                        echo -e "File: $file_1 is modified. Copying...\c\n"
                        cp $file_1 $file_2                              # Copy if cksum mismatch
			pathname=${file_2%/*}
			nome="${file_2##*/}"
			$APP_LOCATION $ARGS $file_2 "${CLOUD_FOLDER_1}${pathname}/$nome"
                        echo "Done"
                fi
        else
                echo -e "File: $file_2 does not exist. Copying...\c\n"
                cp $file_1 $file_2                                      # Copy if file does not exist.
		pathname=${file_2%/*}
		nome="${file_2##*/}"
		$APP_LOCATION $ARGS $file_2 "${CLOUD_FOLDER_1}${pathname}/$nome"
                echo "Done\n"                
        fi
	
done

echo -e "Read/Write permission...\c"
chmod -R 777 $DESTINATION_FOLDER
echo "Done"

echo -e "Delete .svn files at: ${HOME}/${FOLDER_NAME}... \c"
rm -rf `find "${HOME}/${FOLDER_NAME}" -type d -name .svn`
echo "Done"

#Create Database backup
echo -e "Generating database backup... \c"
mysqldump --password=$MYSQL_P -u $MYSQL_U $MYSQL_DB > "${DATABASE_FOLDER}$db1"
echo "Done"

echo -e "Compress backup... \c"

if [ ! -d $DATABASE_FOLDER ]                                              # Checking if sub-dir exists
        then
                echo -e "Dir: $DATABASE_FOLDER does not exist. Creating...\c"
                mkdir -p $DATABASE_FOLDER                                         # Creating if sub-dir missing
                echo "Done"
        fi

zip -r "${DATABASE_FOLDER}${COMPRENSSED_FILE}" "$DATABASE_FOLDER"

rm -f "${DATABASE_FOLDER}$db1"

#Cloud API
echo "Upload Database if exists"
if [ -f $APP_LOCATION ]
	then
		$APP_LOCATION $ARGS $DATABASE_FOLDER "${FOLDER_NAME}/DB/${DATE}/"
else
	unlink $CONFIG_FILE
	echo "App file not found at: $APP_LOCATION"
	exit 1
fi


echo "Cleaning cache..."
rm -f "${DATABASE_FOLDER}${COMPRENSSED_FILE}.zip"

echo "Done $DATE $TIME"

