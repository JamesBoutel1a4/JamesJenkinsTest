#!/bin/bash

#************************************************************************************************
# author:       Aaron Allport
# date:         08-12-20
# description:  Tokenise metadata files
#
# Revisions:    Aaron Allport   08-12-20    Initial revision
#
#*************************************************************************************************/

# Usage:
# 
# -------------------------------------
# The tokens will be replaced for all
# files in the reference metadata type
# directories
#
# --------------------------------------
#
# For CSV files, the following format is required, each seperated by a carriage return:
# metadatFolderName,tokenToFind,valueToReplaceWith
# metadatFolderName,tokenToFind,valueToReplaceWith
#
# --------------------------------------
# 
# For example:
# 
# objects/Account/listViews,__Account_MyListView__,<filterScope>Mine</filterScope>
# workflows,__Case_OwnerUpdate__,aaron.allport@slalom.com
# 

INPUT=$1
OLDIFS=$IFS
IFS=','
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read metadataName tokenToFind valueToSubstitute
do
    # Strip the trailing carriage return/new-line character
    valueToSubstitute="$(echo $valueToSubstitute | sed 's/$//')"

    echo Metadata name $metadataName
    echo Token to find $tokenToFind
    echo Replacing with $valueToSubstitute

    for file in ./force-app/main/default/$metadataName/*
    do
        sed -i "s|$tokenToFind|$valueToSubstitute|g" "$file"
    done
done < $INPUT
IFS=$OLDIFS