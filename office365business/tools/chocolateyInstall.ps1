$configFile = (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'configuration.xml')
$packageName = 'Office365Business'
$installerType = 'EXE'
$url = 'https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_7614-3602.exe'
$checksum = 'CB9B41ABF4C3D67D082BA534F757A0C84F7CA4AF89D77590CC58290B7C875F5E'

$silentArgs = "/extract:$env:temp\office /log:$env:temp\officeInstall.log /quiet /norestart"
$validExitCodes = @(0)

$architecture = Get-ProcessorBits

$Installofficesixtyfourbit = $False
$OfficeProdIDsToExclude = @()
$OverrideConfigFileFullPath = $null

$arguments = @{};
$packageParameters = $env:chocolateyPackageParameters;

# Now parse the packageParameters using good old regular expression
if ($packageParameters) {
    $match_pattern = "\/(?<option>([a-zA-Z0-9_]+)):(?<value>([`"'])?([a-zA-Z0-9- ;,_\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z0-9_]+))"
    #$match_pattern = "\/(?<option>([a-zA-Z    ]+)):(?<value>([`"'])?([a-zA-Z0-9- _\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z]+))"
    $option_name = 'option'
    $value_name = 'value'

    if ($packageParameters -match $match_pattern ){
        $results = $packageParameters | Select-String $match_pattern -AllMatches
        $results.matches | % {
          $arguments.Add(
              $_.Groups[$option_name].Value.Trim(),
              $_.Groups[$value_name].Value.Trim())
      }
    }
    else
    {
      throw "Package Parameters were found but were invalid (REGEX Failure)"
    }

    if ($arguments.ContainsKey("OverrideConfigFileFullPath")) {
        $OverrideConfigFileFullPath = $arguments.Get_Item("OverrideConfigFileFullPath")
        If (!(Test-Path "$OverrideConfigFileFullPath"))
        {
            Throw "/OverrideConfigFileFullPath points to $OverrideConfigFileFullPath, but the file does not exist."
        }
        else
        {
          Write-Output "Overriding built in configuration file with '$OverrideConfigFileFullPath'"
          Write-Warning "Parameters that modify the configuration file will be ignored."
        }
    }

    If (!$OverrideConfigFileFullPath)
    {
      if ($arguments.ContainsKey("officesixtyfourbit")) {
          If ($architecture -ne 64)
          {
            Write-Warning "You are running on 32-bit Windows, but asked for 64-bit Office - 32-bit Office will be installed instead."
          }
          else
          {
            Write-Warning "32-bit Office is usually installed on 64-bit Windows to maximize plug-in compatibility."
            $Installofficesixtyfourbit = $True
          }
      }
      if ($arguments.ContainsKey("OfficeProdIDsToExclude")) {
          [array]$OfficeProdIDsToExclude = $arguments.Get_Item("OfficeProdIDsToExclude") -split (",")
          Write-Output "You have asked to exclude the product ids: $OfficeProdIDsToExclude"
      }
    }

} else {
    Write-Debug "No Package Parameters Passed in";
}

$ConfigContents = [io.file]::readalltext("$configfile")

If ($Installofficesixtyfourbit) {
  $ConfigContents = [regex]::replace($ConfigContents,"OfficeClientEdition=`"32`"","OfficeClientEdition=`"64`"")
  $ConfigFileChanged = $True
}

If ($OfficeProdIDsToExclude.count -gt 0)
{

  $ConfigFragment = "        <Language ID=`"en-us`" />`r`n"

  ForEach ($ProdIDToExclude in $OfficeProdIDsToExclude)
    {
	    $ConfigFragment += "        <ExcludeApp ID=`"$ProdIDToExclude`" />`r`n"
	  }

  $ConfigContents = [regex]::replace($ConfigContents,"<Language ID=`"en-us`" />",$ConfigFragment)
  $ConfigFileChanged = $True
}

If ($ConfigFileChanged)
{
  $ConfigContents | Out-File -Encoding ASCII $configfile -Force
  Write-output "Wrote `"$configfile`""
}

Write-Host "Extracting to $silentArgs"
Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$url" -validExitCodes $validExitCodes -Checksum $checksum -ChecksumType "sha256"
Install-ChocolateyInstallPackage "$packageName" "$installerType" "/download $configFile" "$env:temp\office\setup.exe"
Install-ChocolateyInstallPackage "$packageName" "$installerType" "/configure $configFile" "$env:temp\office\setup.exe"
