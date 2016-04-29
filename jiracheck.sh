#!/bin/bash
#============================================================================
#title          :jiracheck
#description    :This script is used to check if tickets are in closed status
#author         :Roman Rakhmanin
#date           :20160428
#version        :0.1
#usage          :./jiracheck
#notes          :Slow version, makes api connection for each ticket
#bash_version   :GNU bash, version 4.3.11(1)-release (x86_64-pc-linux-gnu)
##===========================================================================
##    Usage
##  -h  Shows current message  
##  -r [filename]  Reads the file specified 
##
## [filename] should contain jira ticket keys, separated by newline 
## ex [filename]: 
## SUPTOS-23556
## MSTOS-2356  
## SOMETRACKER-2144124 
## Usage Ex:                                                            
## \$ ./${script} -r tickets.txt 
##
##===========================================================================
#============================================================================



JIRA_URL='testjira.lo' #put here your jira url

all_tickets=();
open_tickets=();
closed_tickets=();
older_closed_tickets=();
nonexisting_tickets=();

#Usage help
helpFunction () {
    script=$(basename "$0");
    head -n28 $PWD/${script} | grep "^##" | sed 's/^##/#/g';
}



#Login and check credentials
loginInfo () {
    echo -n "Your jira login?:"
    read USER;
    echo -n "Your password?:"
    read -rs PASSWORD;
    echo -e "\nChecking..."
    local result="$(curl --silent -k -D- -u "${USER}":"${PASSWORD}" -X GET -H "Content-Type: application/json" "${JIRA_URL}")";
    if ! grep -q "X-Seraph-LoginReason: OK" <<< "$result"
        then
           [ -z $result ] && echo "Jira \"${JIRA_URL}\" is not available!" || echo "Credentials are wrong!"
            loginInfo;
        else echo "Successful!"
    fi
}

# This function splits given tickets on different groups, depending on request result. Names are self-spoken 
spreadIssues () {
    local result="";
    result="$(curl --silent -k -D- -u "${USER}":"${PASSWORD}" -X GET -H "Content-Type: application/json" \
    "${JIRA_URL}"/rest/api/2/issue/"${1}"?fields=resolution%2Cresolutiondate);";
    if ! grep -q '"Issue Does Not Exist"' <<< $result;
        then 
            if grep -q '"resolution":null' <<< $result;
            then
                open_tickets+=("${1}");
            else
                local ticket_date=$(date --date=$( echo "$result" | grep -Po "\d{4}-\d{2}-\d{2}") "+%s");
                local current_date=$(date +"%s")
                if [[ $(( (current_date - ticket_date)/86400 ))  -gt 30 ]]; then
                    older_closed_tickets+=("${1}");
                else
                    closed_tickets+=("${1}");
                fi
            fi
    else
        nonexisting_tickets+=("${1}");
    fi;
}

#if no options specified, set options to -h
[ $# -eq 0 ] && set -- "-h"

#and main options check. If -a with filename specified, 
while getopts ":hr:" opt; do
  case $opt in
    h)
      helpFunction
      exit;
      ;;
    r)
      if [ ! -f "$OPTARG" ]; 
        then 
            echo "No such file!"; 
            exit; 
        else 
             all_tickets=($(
             egrep -oi "((sup|ms)(tos|tp))(-|_||\.)[0-9]+" "$OPTARG" |
             sed -r 's/(_|\.)/-/g; s/([a-zA-Z])([0-9])/\1-\2/g; s/.*/\U&/' |
             sort -iu |
             tr '\n' ' '
             ))
        fi;      
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      helpFunction
      exit;
      ;;
    :)
     echo "Option -$OPTARG requires an argument" >&2
      helpFunction
      exit;
      ;;     
    
  esac
done

#main part starts here
loginInfo; 
echo "Proceeding with tickets:";
counter=0; #used just to beautify output
tickets_amount=${#all_tickets[@]}; #If we don't create new variable, it'll be counted each iteration
for i in "${all_tickets[@]}"; 
do 
    ((counter+=1)); 
    echo -ne "\rProcessing ${counter} out of ${tickets_amount}: $i";
    spreadIssues $i; 
done

echo -e "\nOpen:"
echo "${open_tickets[@]}";
echo "Closed more than month ago:"
echo "${older_closed_tickets[@]}";
echo "Closed in a near past:"
echo "${closed_tickets[@]}";
echo "Don't even exist:"
echo "${nonexisting_tickets[@]}";