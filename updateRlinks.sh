#!/bin/bash
clear

# This should be ran from the same dir as the hardening_manifest.yaml

### INPUT EXAMPLE ###
#
# - filename: RJDBC_0.2-8.tar.gz
#   url: https://packagemanager.rstudio.com/all/latest/src/contrib/RJDBC_0.2-8.tar.gz
#   validation:
#     type: sha256
#     value: f5e495da7a84abd347755f909bf21d91bd75f1e942a541176f4bc8357b8394e7
#
### OUTPUT EXAMPLE ###
# - filename: RJDBC_0.2-8.tar.gz
#   url: https://packagemanager.rstudio.com/all/latest/src/contrib/Archive/RJDBC/RJDBC_0.2-8.tar.gz
#   validation:
#     type: sha256
#     value: 4caa35f040e920564ddae4d1ee16886f7cea4cf878460ac77c54d15ce21ea104
#


# Converts command line arguments (the images) into a list/array
hm=( "$@" )

# Parses hardening_manifest.yaml and changes the url
hardening_manifest=$(cat ./$hm | grep ' filename:' -A 4)

echo '' > Updated_hardening_manifest.yaml

IFS=; while read -r line; do 
    #echo "$line"
    if echo $line | grep -q "url: "; then
        ## Cuts out just the package url
        OriginalURL=$(echo "$line" | grep ' url:' | tr -s ' ' | cut -d ' ' -f 3)
        #echo "$OriginalURL"

        ## Cuts out just the package namd and version
        PackageNameAndVersion=$(echo "$OriginalURL" | rev | cut -f -1 -d '/' | rev)
        #echo "$PackageNameAndVersion"

        ## Cuts out just the package name
        PackageName=$(echo $PackageNameAndVersion | cut -f -1 -d '_')
        #echo "$PackageName"

        if echo $line | grep -q "packagemanager.rstudio.com"; then
            ## Creates the new url by replacing part of it
            NewUrl=$(echo "$OriginalURL" | sed "s/contrib/contrib\/Archive\/$PackageName/g")
            #echo "$NewUrl"

            ## Downloads new file
            curl --location --url $NewUrl --output $PackageNameAndVersion --silent

            ## Hashes the new url file
            PackageFileHash=$(sha256sum $PackageNameAndVersion | cut -d ' ' -f 1)
            #PackageFileHash=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX     #testing
            #echo "$PackageFileHash"

            ReplaceFileHash=true

            echo "  url: $NewUrl"
            echo "  url: $NewUrl" >> Updated_hardening_manifest.yaml
        else
            ## Downloads original url file
            curl --location --url $OriginalURL --output $PackageNameAndVersion --silent            

            ## Hashes the original url file
            PackageFileHash=$(sha256sum $PackageNameAndVersion | cut -d ' ' -f 1)
            #PackageFileHash=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX     #testing
            #echo "$PackageFileHash"

            ReplaceFileHash=false
            echo "  url: $OriginalURL"
            echo "  url: $OriginalURL" >> Updated_hardening_manifest.yaml

        fi
    elif echo $line | grep -q "value: "; then
        if [ "$ReplaceFileHash" == true ]; then
            ## Outputs hash of new url file
            NewFileHashLine=$(echo "$line" | sed "s/value\:.*/value: $PackageFileHash/g")
            echo "$NewFileHashLine"
            echo "$NewFileHashLine" >> Updated_hardening_manifest.yaml
        else
            ## Outputs hash of original url file
            OriginalFileHashLine=$(echo "$line" | sed "s/value\:.*/value: $PackageFileHash/g")
            echo "$OriginalFileHashLine"
            echo "$OriginalFileHashLine" >> Updated_hardening_manifest.yaml
        fi
    else
        ## Outputs all other lines
        echo "$line"
        echo "$line" >> Updated_hardening_manifest.yaml        
    fi

done <<< $hardening_manifest


	

# DIFFERENT HASH ISSUE
# INFO: File saved as 'nlme_3.1-152.tar.gz'
# INFO: ===== ARTIFACT: https://packagemanager.rstudio.com/all/latest/src/contrib/Archive/nnet/nnet_7.3-16.tar.gz
# INFO: Downloading from https://packagemanager.rstudio.com/all/latest/src/contrib/Archive/nnet/nnet_7.3-16.tar.gz
# INFO: Checking file verification type
# INFO: Generating checksum
# INFO: comparing checksum values: 4f938427df6cd75adb8f51b1da3ee5839b6e401d539ad11614b83a7ae9853dbd vs af92ca656ca4ada7f63603ecf6c324b7a292b6e09fbee1416100c715a5f05ed6

