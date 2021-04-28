param($Packages)

<#
# R Code that is ran within the container to download image specific packages and dependencies
# also shows their URL for later processing
getDependencies <- function(packs){
  dependencyNames <- unlist(
    tools::package_dependencies(packages = packs, db = available.packages(), 
                                which = c("Depends", "Imports"),
                                recursive = TRUE))
  packageNames <- union(packs, dependencyNames)
  packageNames
}
# Calculate dependencies
packages <- getDependencies(c('tidyverse', 'shiny', 'plotly', 'shinydashboard', 'DT', 'rmarkdown', 'flexdashboard'), dependencies = c("Depends", "Imports", "LinkingTo"))
setwd(".")
pkgInfo <- download.packages(pkgs = packages, destdir = getwd())
#>
$output = "resources:"
$Packages | foreach { 
        if ($_ -match 'trying URL'){
            $URL = $($_.trimstart("trying URL '").trimend("'"))
            $Name = $URL | Split-Path -Leaf
            Invoke-WebRequest -Uri "$URL" -OutFile "$Name"
            $Hash = (Get-FileHash -Algorithm SHA256 -Path $Name).Hash.ToLower()
            $output += @"
`n- filename: $Name
  url: $URL
  validation:
    type: sha256
    value: $Hash
"@
        }
    }
$output
$output | Set-Content ./R_Package_Details.txt
