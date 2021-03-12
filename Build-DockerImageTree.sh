
# Usage: 
# The image names will be the same as its directory name
# The version specified below is the same throughout the Dockerfiles
#
# Example:
# ./Build-DockerImageTree.sh parent_image child_image grandchild_image ..etc
# ./Build-DockerImageTree.sh python36-ai jlab-eda jlab-dl jlab-cv
# The image/directory names in the images array below are in parent-child order

clear

# Terminal Colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

function helpmenu {
    echo -e "\n${red}Usage: ${reset}$0 parent_image child_image grandchild_image ..etc"
    echo -e "       -h   --help       Shows help"
    echo -e "       -v   --verbose    Verbose mode"
    echo ''
    exit 0
}
# Simple Help switches/arguments
if [ -z "$*" ]; then
    helpmenu
fi
for arg in $@; do
    if [[ ($arg == "-h") || ($arg == "--help") ]]; then
       helpmenu
fi
done


# Set the images in parent-child order
#images=( python36-ai jlab-eda jlab-dl jlab-cv )

# Converts command line arguments (the images) into a list/array
images=( "$@" )

version='latest'

# Creates directory if it does not exist
ReportDir='docker_build_reports'
if [ ! -d "$ReportDir" ]; then
    echo -e "${red}[!]${green} Creating Directory...  $ReportDir${reset}"
    mkdir ./$ReportDir
fi

echo -e "\n${yellow}================================================================================${reset}"

# iterates through list and builds images
# reports are saved to the above directory 
for image in "${images[@]}"; do
    # Parses hardening_manifest.yaml and download packages to the image's docker directory
    echo -e "\n${red}[!]${green} Checking hardening_manifest for packages${reset}"
    hardening_manifest=$(cat ./$image/hardening_manifest.yaml | grep 'url:' | cut -f 4 -d ' ')
    while IFS= read -r PackageURL; do 
        PackageName=$(echo "$PackageURL" | rev | cut -f -1 -d '/' | rev)
        if [[ $(ls ./$image/$PackageName) ]]; then 
            for arg in $@; do
                if [[ ($arg == "-v") || ($arg == "--verbose") ]]; then
                    echo "    - Package already exists...  $PackageName${reset}"                    
                fi
            done
        else
            echo "    - Downloading package...  ${yellow}$PackageURL${reset}"
            curl --location --url $PackageURL --output ./$image/$PackageName
        fi 2> /dev/null
    done <<< ./$image/$hardening_manifest


    # Removes any existing test builds; helps keep docker image listing clean
    echo -e "\n${red}[!]${green} Checking for any removing previous test builds${reset}"
    if docker images | grep "^$image\b" | grep "$version"; then
        echo "    - Removing previous test build...${yellow}  $image:$version${reset}"
        docker images | grep "^$image\b" | grep "$version" && docker rmi "$image:$version" -f
    fi


    # Builds the image(s) 
    echo -e "\n${red}[!]${green} Attempting to build image...${yellow}  $image:$version${reset}"
    docker build -t "$image:$version" ./"$image"


    # Checkes if image is built or not and provides message
    if [[ $(docker images | grep "^$image\b" | grep "$version") ]]; then 
        echo -e "\n${red}[!]${green} Image was successfully built!${reset}"
    else 
        echo -e "\n${red}[!]${green} Image failed to build - view error report in:${yellow} $ReportDir${reset}"
    fi

    echo -e "\n${yellow}================================================================================${reset}"

done

echo ' '
echo "${red}[!]${green} Images successfully created:${reset}"

# Lists the docker images created
for image in "${images[@]}"; do
    docker images | grep "^$image\b" | grep "$version"
done

echo -e "\n${yellow}================================================================================${reset}\n"


# Test commands against image
for image in "${images[@]}"; do
    # Removes existing error file
    rm -f ./$ReportDir/stderr_$image.txt
    rm -f ./$ReportDir/stderr_$image.txt

    test_cmd_file="./$image/test_cmds.txt"
    if test -f "$test_cmd_file"; then    
        image_id=$(docker images | grep "^$image\b" | grep "$version" | tr -s ' ' | cut -d ' ' -f 3)

        echo "${red}[!]${reset} Testing commands aginst image:${yellow}  $image${reset}"
        test_commands=$(cat $test_cmd_file)
        while IFS= read -r cmd; do

            # runs each command against the docker image and creates logs 
            test_cmd="docker run $image_id $cmd"
            eval "$test_cmd" 2>> ./$ReportDir/stderr_$image.txt 1>> ./$ReportDir/stdout_$image.txt
            
            # Set text color if eval code is successful or not (exit code 0)
            if [ "$?" == "0" ]; then
                echo -e "    - ${green}$cmd${reset}"
            else
                echo -e "    - ${red}$cmd  ${yellow}[View Error Log:  ./$ReportDir/stderr_$image.txt]${reset}"
            fi
        done <<< $test_commands
    fi
done

echo -e "\n${yellow}================================================================================${reset}\n"



