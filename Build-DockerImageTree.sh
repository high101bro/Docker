
# Usage: 
# The image names will be the same as its directory name
# The version specified below is the same throughout the Dockerfiles


# The image/directory names in the images array below are in parent-child order
#images=( python36-ai jlab-eda jlab-dl jlab-cv )
images=$@
version='latest'


# Creates directory if it does not exist
ReportDir='docker_build_errors'
if [ ! -d "$ReportDir" ]; then
    echo "[!] Creating Directory... $ReportDir"
    mkdir ./$ReportDir
fi


# iterates through list and builds images
# reports are saved to the above directory 
for image in "${images[@]}"; do

    # Parses hardening_manifest.yaml and download packages to the image's docker directory
    echo "[!] Checking hardening_manifest for packages"
    hardening_manifest=$(cat ./$image/hardening_manifest.yaml | grep 'url:' | cut -f 4 -d ' ')
    while IFS= read -r PackageURL; do 
        PackageName=$(echo "$PackageURL" | rev | cut -f -1 -d '/' | rev)
        if [[ $(ls ./$image/$PackageName) ]]; then 
            echo "    - Package already exists... $PackageName"
            continue
        else
            echo "    - Downloading package... $PackageURL"; 
            curl --url $PackageURL --output ./$image/$PackageName
            continue
        fi 2> /dev/null
    done <<< ./$image/$hardening_manifest


    # Removes any existing test builds; helps keep docker image listing clean
    echo "[!] Checking for any removing previous test builds"
    if docker images | grep "^$image\b" | grep "$version"; then
        echo "    - Removing previous test build... $image:$version"
        docker images | grep "^$image\b" | grep "$version" && docker rmi "$image:$version"
    fi


    # Builds the image(s)
    echo "[!] Attempting to build image... $image:$version"
    docker build -t "$image:$version" ./"$image" #2>&1 ./$ReportDir/errors_$image.txt


    # Checkes if image is built or not and provides message
    if [[ $(docker images | grep "^$image\b" | grep "$version") ]]; then 
        echo "[!] Image was successfully built!"
    else 
        echo "[!] Image failed to build - view error report in: $ReportDir"
    fi
done

# Lists the docker images created
for image in "${images[@]}"; do
    docker images | grep "^$image\b" | grep "$version"
done


