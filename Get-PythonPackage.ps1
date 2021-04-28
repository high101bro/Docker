<#
    .SYNOPSIS
    This script searches https://pypi.python.org for packages to download, hash, and partially create a json file in support of secure Docker image creation.
    
    .DESCRIPTION
    This script searches https://pypi.python.org for packages to download, hash, and partially create a json file in support of secure Docker image creation.

    File Name      : Get-PythonPackageData.ps1
    Version        : v1.1
    Requires       : PowerShell v5

    Created        : 14 Jan 2021

    Author         : Daniel Komnick (high101bro)
    Email          : high101bro@gmail.com
    Website        : https://github.com/high101bro

    .PARAMETER PackageList
    This script accepts an array/list of packages to be passed into the script.
    This parameter should not be used in conjuction with -PackageName and -PackageVersion.

    .PARAMETER KeepDownloaded
    This script downloads the packages, hashes them, then immediately deletes them. Use this parameter switch to keep the downloaded files.

    .PARAMETER OutFile
    Saves the results to a file named '.\Package Urls and hashes.txt' in the same directory as the script.
    The results will also always be displayed on the command line.

    .EXAMPLE
    $PackageList = @(
        'Keras_Preprocessing-1.1.2-py2.py3-none-any.whl',
        'Markdown-3.3.3-py3-none-any.whl',
        'pandas-1.1.5-cp36-cp36m-manylinux1_x86_64.whl',
        'NONEXISTANT-PACKAGE.whl',
        'scikit_learn-0.23.2-cp36-cp36m-manylinux1_x86_64.whl',
        'numpy-1.19.4-cp36-cp36m-manylinux1_x86_64.whl',
        'scipy-1.5.4-cp36-cp36m-manylinux1_x86_64.whl',
        'Keras_Preprocessing-1.1.2-py2.py3-none-any.whl'
    )
    ./Get-PythonPackageData -PackageList $PackageList -KeepDownloaded -OutFile
    
    .EXAMPLE
    ./Get-PythonPackageData -PackageList (Get-Content './PackageList.txt')name -KeepDownloaded -OutFile

    .EXAMPLE
    ./Get-PythonPackageData -PackageList (Get-ChildItem ./dir).Name -KeepDownloaded -OutFile

    .INPUTS
    The expected inputs are either, 1) a single or multiple complete package names, or 2) a single package name and version.

    .OUTPUTS
    Data is output to the terminal and can be saved to file with the -OutFile parameter.

    .LINK
    https://github.com/high101bro/

    .NOTES
    None
#>
param(
    [string[]]$PackageList,
    [switch]$KeepDownloaded,
    [switch]$OutFile
)
$WarningPreference = 'SilentlyContinue'

$ScriptLocation = $($myinvocation.mycommand.definition) | Split-Path -Parent

$PackageList = $PackageList | Select-Object -Unique

$DetectedUri = @()
#Note: The empty space is required after resources.
$FormattedString = @"
resources:

"@

Clear-Host


$SiteToSearch = 'https://pypi.python.org'
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host "Repository:    " -NoNewline -ForegroundColor Blue
Write-Host $SiteToSearch -ForegroundColor Yellow
Write-Host "Help/Examples: " -NoNewline -ForegroundColor Blue
Write-Host "Get-Help ./$($myinvocation.mycommand.definition | Split-Path -Leaf) -Full" -ForegroundColor White
#Write-Host "$(Get-Command -Syntax $myinvocation.mycommand.definition)"
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host ''

if ( $PackageList )
{
    foreach ($Pkg in $PackageList)
    {
        $PkgName = $Pkg.split('-')[0]
        $Uri = "https://pypi.python.org/pypi/" + $PkgName + "/json"
        
        Write-Host "Searching:     " -NoNewLine -ForegroundColor Blue
        Write-Host $Pkg -ForegroundColor Gray

        try 
        {
            $WebReq = Invoke-WebRequest -Uri $Uri
            $obj = $WebReq.Content | ConvertFrom-Json
            $str = [string]($obj | ConvertTo-Json)  -split "\n"

            foreach ( $Line in $str.split(';') ) 
            {
                $line = $line | Where-Object {$_ -match 'url='}
                if ( $Line -match $Pkg )
                {
                    if ( $DetectedUri -notcontains $Line )
                    {
                        $URL = $Line.replace('url=','').trim()
                        $PkgName = $URL | Split-Path -Leaf
                        #$DetectedUri += $URL
                        Write-Host "Downloading:   " -NoNewLine -ForegroundColor Blue
                        Write-Host $URL -ForegroundColor White
                        Invoke-WebRequest -Uri $URL -OutFile "$ScriptLocation\$PkgName"

                        Write-Host "SHA256 Hash:   " -NoNewLine -ForegroundColor Blue
                        $SHA256Hash = (Get-FileHash -Algorithm SHA256 -Path "$ScriptLocation\$PkgName").Hash.ToLower()
                        Write-Host $SHA256Hash -ForegroundColor White

                        if (-not $KeepDownloaded) {
                            Remove-Item -Path "$ScriptLocation\$PkgName" -Force
                        }        
                    $FormattedString += @"
- filename: $PkgName
  url: $URL
  validation:
    type: sha256
    value: $SHA256Hash

"@   
                    }
                }
            }    
        }
        catch {
            Write-Host "NOT found:     " -NoNewLine -ForegroundColor Blue
            Write-Host "Unable to find $Pkg" -ForegroundColor Red
        }

        Write-Host ''
    }
}



Write-Host ''
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host '  JSON Formatted Data Below'
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host ''

Write-Host $FormattedString -ForegroundColor Cyan

Write-Host ''
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host '  JSON Formatted Data Above'
Write-Host "$('='*100)" -ForegroundColor Yellow
Write-Host ''

if ($OutFile){
    Write-Host "Opening File:  " -NoNewLine -ForegroundColor Blue
    Write-Host '.\Package Urls and hashes.txt' -ForegroundColor Red
    $FormattedString | Out-File '.\Package Urls and hashes.txt'
    Invoke-Item '.\Package Urls and hashes.txt'
}




