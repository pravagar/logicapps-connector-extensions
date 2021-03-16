﻿$extensionPath=Split-Path -parent $PSCommandPath
$extensionPath = (get-item $extensionPath).parent.parent.FullName

write-host "Nuget extension path is $extensionPath"
$extensionName = "CosmosDB"
$extensionNameServiceProvider = $extensionName+"ServiceProvider"

$userprofile = [environment]::GetFolderPath('USERPROFILE')
$dll =  Join-Path -Path $extensionPath -ChildPath "netcoreapp3.1"
$dll =  Join-Path -Path $dll -ChildPath "Microsoft.Azure.Workflows.ServiceProvider.Extensions.CosmosDB.dll"

$extensionModulePath = Join-Path -Path $userprofile -ChildPath ".azure-functions-core-tools"
$extensionModulePath = Join-Path -Path $extensionModulePath -ChildPath "Functions"
$extensionModulePath = Join-Path -Path $extensionModulePath -ChildPath "ExtensionBundles"
$extensionModulePath = Join-Path -Path $extensionModulePath -ChildPath "Microsoft.Azure.Functions.ExtensionBundle.Workflows"

$latest = Get-ChildItem -Path $extensionModulePath | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$latest.name
$extensionModulePath = Join-Path -Path $extensionModulePath  -ChildPath $latest.name 
$extensionModulePath = Join-Path -Path $extensionModulePath  -ChildPath "bin"
$extensionModulePath = Join-Path -Path $extensionModulePath  -ChildPath "extensions.json"
write-host "EXTENSION PATH is $extensionModulePath and dll Path is $dll"

$fullAssemlyName = [System.Reflection.AssemblyName]::GetAssemblyName($dll).FullName

try
{
# Kill all the existing func.exe else modeule extension cannot be modified. 
taskkill /IM "func.exe" /F
}
catch
{
  write-host "func.exe not found"
}

# 1. Add Nuget package to existing project 
dotnet add package "Microsoft.Azure.Workflows.ServiceProvider.Extensions.CosmosDB" --version 1.0.0  --source $extensionPath

#  2. Update extensions.json under extension module

$typeFullName =  "Microsoft.Azure.Workflows.ServiceProvider.Extensions.CosmosDB.CosmosDBStartup, $fullAssemlyName"

$newNode =  [pscustomobject] @{ 
  name = $extensionNameServiceProvider
  typeName = $typeFullName}


$jsonContent = Get-Content $extensionModulePath -raw | ConvertFrom-Json
if ( ![bool]($jsonContent.extensions.name -match $extensionNameServiceProvider))
{
	$jsonContent.extensions += $newNode
}
else
{
	$jsonContent.extensions | % {if($_.name -eq $extensionNameServiceProvider){$_.typeName=$typeFullName}}
}
$jsonContent | ConvertTo-Json -depth 32| set-content $extensionModulePath

# 3. update dll in extension module.
$spl = Split-Path $extensionModulePath
Copy-Item $dll  -Destination $spl

Write-host "Successfully added extension.. "