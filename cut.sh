#!/bin/bash
#
# CUT - Copy Upload Tool
#  
# Author: Giovani Paseto
#
# Sync and upload files to Copy using Bash

CUT_VERSION="0.1.1"
CUT_CONFIG=~/.cut
CUT_CONSUMER_CONFIG=~/cut_consumer
CUT_LOG_FILE="logfile"

###########
# COPY API
###########
#Request
URL_RT="https://api.copy.com/oauth/request"
#Access
URL_ACCESS="https://api.copy.com/oauth/access"
#Authorize
URL_AUTH="https://www.copy.com/applications/authorize"
#API Root
URL_API_CALLS="https://api.copy.com/rest/"
#Read Root Directory
URL_META="https://api.copy.com/rest/meta"
#File handler
URL_HANDLER="https://api.copy.com/rest/files/"
#Copy Developer URL
URL_DEV="https://developers.copy.com/console"
#Copy login URL
URL_LOGIN="https://www.copy.com/auth/login"
#Copy create account URL
URL_CREATE="https://www.copy.com/signup"

#Get Verifier code from thrird party URL

CK_URL="http://egxdev.com/copyVerifier.php"

#PARAMS
TIMESTAMP=`date +%s`
#NONCE=`date +%s%T555555555 | openssl base64 | sed -e s'/[+=/]//g'`

function nonce (){
  echo `date +%s%T555555555 | openssl base64 | sed -e s'/[+=/]//g'`
}

# Configure CUT

if [[ -e $CUT_CONFIG ]]; then
    source "$CUT_CONFIG" 2>/dev/null || {
        sed -i'' 's/:/=/' "$CUT_CONFIG" && source "$CUT_CONFIG" 2>/dev/null
    }
    if [[ $CONSUMER_KEY == "" || $CONSUMER_SECRET == "" || $OAUTH_ACCESS_TOKEN_SECRET == "" || $OAUTH_ACCESS_TOKEN == "" || $COPY_DEFAULT_FOLDER == "" ]]; then
        echo -e "Ops, there's something wrong with you config file, please run CUT again."
        unlink $CUT_CONFIG
        exit 1
    fi
else    
    while (true); do
        #USER AUTH
        echo -ne "\n ----- CUT - Copy Upload Tool v$CUT_VERSION - [SETUP] ----- \n"
        echo -ne "\n Please follow instructions above:\n"
        echo -ne " 1 - Login (${URL_LOGIN}) or Create account(${URL_CREATE}) at Copy \n" 
        echo -ne " 2 - Open the following URL in your browser and click Create Application or\n"
        echo -ne "\n\n ${URL_DEV}\n\n"        
        echo -ne " 3 - Browse Application and fill the required information above."        
	
	#Check if is the same key
	if [[ -e $CUT_CONSUMER_CONFIG ]]; then
	    source "$CUT_CONSUMER_CONFIG" 2>/dev/null || {
        	sed -i'' 's/:/=/' "$CUT_CONSUMER_CONFIG" && source "$CUT_CONSUMER_CONFIG" 2>/dev/null
	    }
	fi

        echo -n " Please enter Consumer Key: (${TEMP_KEY})"
        read CONSUMER_KEY
	if [[ $CONSUMER_KEY == "" ]]; then 
            CONSUMER_KEY=${TEMP_KEY}
        fi
        echo -n " Please enter Consumer Secret (${TEMP_SECRET}): "
        read CONSUMER_SECRET
	if [[ $CONSUMER_SECRET == "" ]]; then 
            CONSUMER_SECRET=${TEMP_SECRET}
        fi
        echo -n " Default Copy folder where your files will be placed [CUT]: "
        read COPY_DEFAULT_FOLDER
        if [[ $COPY_DEFAULT_FOLDER == "" ]]; then 
            COPY_DEFAULT_FOLDER="CUT"
        fi

	#Save keys
	echo "TEMP_KEY=$CONSUMER_KEY" > "$CUT_CONSUMER_CONFIG"
        echo "TEMP_SECRET=$CONSUMER_SECRET" >> "$CUT_CONSUMER_CONFIG" 
        
	echo -ne "\n Requesting token--- "
	oauth_ck="oauth_consumer_key=$CONSUMER_KEY" #consumer key
	oauth_sm="oauth_signature_method=PLAINTEXT" #signature method
	oauth_sg="oauth_signature=$CONSUMER_SECRET%26" #signature
	oauth_timestamp="oauth_timestamp=$TIMESTAMP"
	QUERY_STRING="oauth_callback=$CK_URL&$oauth_ck&$oauth_sm&$oauth_sg&$oauth_timestamp&oauth_nonce=$RANDOM"     	

	curl -k -s --show-error --globoff -i -o "$CUT_LOG_FILE" --data "$QUERY_STRING" "$URL_RT" 2> /dev/null    
	OAUTH_TOKEN_SECRET=$(sed -n 's/.*oauth_token_secret=\([a-z A-Z 0-9]*\).*/\1/p' "$CUT_LOG_FILE")
	OAUTH_TOKEN=$(sed -n 's/.*oauth_token=\([a-z A-Z 0-9]*\).*/\1/p' "$CUT_LOG_FILE")
	
	echo -ne "\n TOKEN = ${OAUTH_TOKEN} SECRET ${OAUTH_TOKEN_SECRET}"

	if [[ $OAUTH_TOKEN == "" ]]; then	
	        echo -ne " FAILED\n\n Please, run cut again...\n\n"
		E_MSG=$(sed -n 's/.*oauth_error_message=\([^\n\r]*\).*/\1/p' "$CUT_LOG_FILE")
		echo -ne "\n Error message: $E_MSG \n"
		unlink $CUT_LOG_FILE
		exit 1
	fi

        echo -ne "\n 4 - Now open the following URL in your browser to allow CUT to access your Copy folder \n"
        echo -ne "\n ${URL_AUTH}?oauth_token=$OAUTH_TOKEN\n"
        echo -ne "\n 5 - Please paste Verification Code: "
        read VCODE
        

        #API_ACCESS_TOKEN_URL
        echo -ne "\n Requesting token... vcode: $VCODE"
	unlink $CUT_LOG_FILE

	#Token secret needed
	oauth_sg="oauth_signature=$CONSUMER_SECRET%26$OAUTH_TOKEN_SECRET" #signature

	QUERY_STRING="$oauth_ck&oauth_token=$OAUTH_TOKEN&$oauth_sm&$oauth_sg&$oauth_timestamp&oauth_nonce=$RANDOM&oauth_version=1.0&oauth_verifier=$VCODE"    
        curl -k -s --show-error --globoff -i -o "$CUT_LOG_FILE" --data "$QUERY_STRING" "$URL_ACCESS" 2> /dev/null        
        OAUTH_ACCESS_TOKEN_SECRET=$(sed -n 's/.*oauth_token_secret=\([a-z A-Z 0-9]*\).*/\1/p' "$CUT_LOG_FILE")
        OAUTH_ACCESS_TOKEN=$(sed -n 's/.*oauth_token=\([a-z A-Z 0-9]*\)&.*/\1/p' "$CUT_LOG_FILE")   

	#Save data to file
        if [[ $OAUTH_ACCESS_TOKEN != "" && $OAUTH_ACCESS_TOKEN_SECRET != "" ]]; then
            echo -ne "OK\n"            
            echo "CONSUMER_KEY=$CONSUMER_KEY" > "$CUT_CONFIG"
            echo "CONSUMER_SECRET=$CONSUMER_SECRET" >> "$CUT_CONFIG"        
            echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" >> "$CUT_CONFIG"
            echo "OAUTH_ACCESS_TOKEN_SECRET=$OAUTH_ACCESS_TOKEN_SECRET" >> "$CUT_CONFIG"
            echo "COPY_DEFAULT_FOLDER=$COPY_DEFAULT_FOLDER" >> "$CUT_CONFIG"

            echo -ne "\n Done!\n"
            break
        else
            echo -ne " FAILED \n"            
            echo " Please check if you entered the right information. \n"                        
        fi

    done;
fi


#init upload

if [[ -e $CUT_CONFIG ]]; then
    source "$CUT_CONFIG" 2>/dev/null || {
       	sed -i'' 's/:/=/' "$CUT_CONSUMER_CONFIG" && source "$CUT_CONSUMER_CONFIG" 2>/dev/null
    }
fi
oauth_ck="oauth_consumer_key=$CONSUMER_KEY" #consumer key
oauth_sm="oauth_signature_method=PLAINTEXT" #signature method
oauth_sg="oauth_signature=$CONSUMER_SECRET%26" #signature
oauth_timestamp="oauth_timestamp=$TIMESTAMP"

QUERY_STRING="$oauth_ck&oauth_token=$OAUTH_ACCESS_TOKEN&$oauth_sm&${oauth_timestamp}&oauth_nonce=$RANDOM&$oauth_sg$OAUTH_ACCESS_TOKEN_SECRET"

function copyUpload {
  SOURCE=$1
  DESTINATION=$2  
  
  if [[ -d $SOURCE ]] #Check if is dir
  then        
    echo -e "Uploading DIRECTORY $SOURCE to $DESTINATION... \c"
    curl -k -s --show-error --globoff -i -o "$CUT_LOG_FILE" -X POST "${URL_HANDLER}${COPY_DEFAULT_FOLDER}/${DESTINATION}?${QUERY_STRING}" -H "X-Api-Version: 1" 2> /dev/null #create folder
    echo "done"
  else
    if [ -f $SOURCE ] #Check if file exists
    then                  
        echo -e "Uploading FILE $SOURCE to $DESTINATION... \c"
        curl -i --globoff -o "$CUT_LOG_FILE" --upload-file "$SOURCE" -X POST "${URL_HANDLER}${COPY_DEFAULT_FOLDER}/$DESTINATION?${QUERY_STRING}" -H "X-Api-Version: 2;" 2> /dev/null #create file
        echo "done"
    else
        echo "File not found at $SOURCE"
    fi
  fi
}

function usage {
    echo -e "\n ----- CUT - Copy Upload Tool v$CUT_VERSION - [USAGE] -----"    
    echo -e "\n Usage: \n cut.sh [-option] [local file or folder] [remote file or folder]"
    echo -e "\n Options:"
    echo -e " -s \tSingle file or folder upload"
    echo -e " -r \tRecursive folder upload"   
    echo -e ""
}

#Argument count
if [ "$#" -ne 3 ]; then
    #echo "Illegal number of parameters"
    usage
    exit 1
fi

while getopts ":s:r:" opt; do    
    shift $((OPTIND-1))
    FDEST=$1
    FSOUR=${OPTARG}    
    case "${opt}" in
        s)            
            copyUpload "${FSOUR}" "${FDEST}"
            ;;
        r)
            for filex in $( find $FSOUR* | sed 's/\.\.\///g' )
            do                          
                copyUpload "$filex" "${filex/${FSOUR}/$FDEST}"
            done        
            ;;
        \?)        
            echo "Invalid option : -$OPTARG" >&2
            usage
            ;;
    esac
done

