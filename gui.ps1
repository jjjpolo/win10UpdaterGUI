function Start-DownloadFile()
{
    param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$URL,
        
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$Path,
        
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$Name
            )
    $targetFile = $Path + "\\" + $Name
    $uri = New-Object "System.Uri" "$URL"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count

    while ($count -gt 0)
    {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        $currentPercentDownload = [int] ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
        Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete $currentPercentDownload
        Write-Host -NoNewline $currentPercentDownload `r
        $download_ProgressBar.value = $currentPercentDownload
        Start-Sleep -s 0.1
    }

    Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()
}

function MSLatestUpdate()
{
    param(
        [parameter(Mandatory=$false, HelpMessage="Specify the update type to download, either Cumulative, ServiceStack and/or AdobeFlash.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("CumulativeUpdate", "ServicingStackUpdate", "AdobeFlashUpdate")]
        [string[]]$UpdateType = "CumulativeUpdate",
    
        [parameter(Mandatory=$false, HelpMessage="Specify the path where the updates will be downloaded.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[A-Za-z]{1}:\\\w+")]
        [ValidateScript({
            # Check if path contains any invalid characters
            if ((Split-Path -Path $_ -Leaf).IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
                Write-Warning -Message "$(Split-Path -Path $_ -Leaf) contains invalid characters"
            }
            else {
                # Check if the whole path exists
                if (Test-Path -Path $_ -PathType Container) {
                    return $true
                }
                else {
                    Write-Warning -Message "Unable to locate part of or the whole specified path, specify a valid path"
                }
            }
        })]
        [string]$Path = (Get-Location),
    
        [parameter(Mandatory=$false, HelpMessage="Specify a single or multiple operating system build versions, e.g. 1803, 1809 or 1903.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^(1[789]|2[01])0(3|9)$")]
        [string[]]$OSBuild = "1909",
    
        [parameter(Mandatory=$false, HelpMessage="Specify the operating system architecture, either x64-based or x86-based.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("x64-based", "x86-based")]
        [string]$OSArchitecture = "x64-based",
    
        [parameter(Mandatory=$false, HelpMessage="Show only the updates and skip downloading them.")]
        [boolean]$List
    )
    Process {
        # Functions
        
        
        function Get-MSUpdateXML {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$FeedURL
            )
            # Construct a temporary file to store the XML content
            $XMLTempFile = Join-Path -Path $env:TEMP -ChildPath "UpdateFeed.xml"
            
            try {
                # Download update feed url and output content to temporary file
                Invoke-WebRequest -Uri $FeedURL -ContentType "application/atom+xml; charset=utf-8" -OutFile $XMLTempFile -UseBasicParsing -ErrorAction Stop -Verbose:$false
                
                if (Test-Path -Path $XMLTempFile) {
                    try {
                        # Read XML file content and return data from function
                        [xml]$XMLData = Get-Content -Path $XMLTempFile -ErrorAction Stop -Encoding UTF8 -Force
        
                        try {
                            # Remove temporary XML file
                            Remove-Item -Path $XMLTempFile -Force -ErrorAction Stop
        
                            return $XMLData
                        }
                        catch [System.Exception] {
                            Write-Warning -Message "Failed to remove temporary XML file '$($XMLTempFile)'. Error message: $($_.Exception.Message)"
                        }
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to read XML data from '$($XMLTempFile)'. Error message: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Warning -Message "Unable to locate temporary update XML file"
                }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to download update feed XML content to temporary file. Error message: $($_.Exception.Message)"
            }
        }
        
        function Get-MSDownloadInfo {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$UpdateID
            )
        
            try {
                # Retrieve the KB page from update catalog
                $UpdateCatalogRequest = Invoke-WebRequest -Uri "http://www.catalog.update.microsoft.com/Search.aspx?q=$($UpdateID)" -UseBasicParsing -ErrorAction Stop -Verbose:$false
                if ($UpdateCatalogRequest -ne $null) {
                    # Determine link id's and update description
                    $UpdateCatalogItems = ($UpdateCatalogRequest.Links | Where-Object { $_.Id -match "_link" })
                    foreach ($UpdateCatalogItem in $UpdateCatalogItems) {
                        if (($UpdateCatalogItem.outerHTML -match $OSArchitecture) -and ($UpdateCatalogItem.outerHTML -match "Windows 10")) {
                            $CurrentUpdateDescription = ($UpdateCatalogItem.outerHTML -replace "<a[^>]*>([^<]+)<\/a>", '$1').TrimStart().TrimEnd()
                            $CurrentUpdateLinkID = $UpdateCatalogItem.id.Replace("_link", "")
                        }
                    }
                    
                    # Construct update catalog object that will be used to call update catalog download API
                    $UpdateCatalogData = [PSCustomObject]@{
                        KB = $CurrentUpdate.ID
                        LinkID = $CurrentUpdateLinkID
                        Description = $CurrentUpdateDescription
                    }
        
                    # Construct an ordered hashtable containing the update ID data and convert to JSON
                    $UpdateCatalogTable = [ordered]@{
                        Size = 0
                        Languages = ""
                        UidInfo = $UpdateCatalogData.LinkID
                        UpdateID = $UpdateCatalogData.LinkID
                    }
                    $UpdateCatalogJSON = $UpdateCatalogTable | ConvertTo-Json -Compress
        
                    # Construct body object for web request call
                    $Body = @{
                        UpdateIDs = "[$($UpdateCatalogJSON)]"
                    }
        
                    # Call update catalog download dialog using a rest call
                    $DownloadDialogURL = "http://www.catalog.update.microsoft.com/DownloadDialog.aspx"
                    $CurrentUpdateDownloadURL = Invoke-WebRequest -Uri $DownloadDialogURL -Body $Body -Method Post -UseBasicParsing -ErrorAction Stop -Verbose:$false | Select-Object -ExpandProperty Content | Select-String -AllMatches -Pattern "(http[s]?\://download\.windowsupdate\.com\/[^\'\""]*)" | ForEach-Object { $_.Matches.Value }
                    
                    $UpdateCatalogDownloadItem = [PSCustomObject]@{
                        KB = $UpdateCatalogData.KB
                        Description = $CurrentUpdateDescription
                        DownloadURL = $CurrentUpdateDownloadURL
                    }
                    return $UpdateCatalogDownloadItem
                }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to invoke web request and search update catalog for specific KB article '$($CurrentUpdate.ID)'. Error message: $($_.Exception.Message)"
            }
        }
        
        function Get-MSCumulativeUpdate {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidatePattern("^(1[789]|2[01])0(3|9)$")]
                [string]$OSBuild,
        
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidateSet("x64-based", "x86-based")]
                [string]$OSArchitecture
            )
            # Construct OS build and version table
            $OSVersionTable = @{
                "1607" = 14393
                "1703" = 15063
                "1709" = 16299
                "1803" = 17134
                "1809" = 17763
                "1903" = 18362
                "1909" = 18363
            }
    
            # Filter object matching desired update type
            $OSBuildPattern = "$($OSVersionTable[$OSBuild]).(\d+)"
            $UpdateEntryList = New-Object -TypeName System.Collections.ArrayList
            foreach ($UpdateEntry in $UpdateFeedXML.feed.entry) {
                if ($UpdateEntry.title -match $OSBuildPattern) {
                    $BuildVersion = [regex]::Match($UpdateEntry.title, $OSBuildPattern).Value
                    $PSObject = [PSCustomObject]@{
                        Title = $UpdateEntry.title
                        ID = $UpdateEntry.id
                        Build = $BuildVersion
                        Updated = $UpdateEntry.updated
                    }
                    $UpdateEntryList.Add($PSObject) | Out-Null
                }
            }
        
            if ($UpdateEntryList.Count -ge 1) {
                # Filter and select the most current update
                $UpdateList = New-Object -TypeName System.Collections.ArrayList
                foreach ($Update in $UpdateEntryList) {
                    $PSObject = [PSCustomObject]@{
                        Title = $Update.title
                        ID = "KB{0}" -f ($Update.id).Split(":")[2]
                        Build = $Update.Build.Split(".")[0]
                        Revision = [int]($Update.Build.Split(".")[1])
                        Updated = ([DateTime]::Parse($Update.updated))
                    }
                    $UpdateList.Add($PSObject) | Out-Null
                }
                $CurrentUpdate = $UpdateList | Sort-Object -Property Revision -Descending | Select-Object -First 1
            }
        
            # Retrieve download data from update catalog
            if ($CurrentUpdate -ne $null) {
                return Get-MSDownloadInfo -UpdateID $CurrentUpdate.ID
            }
        }
        
        function Get-MSServicingStackUpdate {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidatePattern("^(1[789]|2[01])0(3|9)$")]
                [string]$OSBuild,
        
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidateSet("x64-based", "x86-based")]
                [string]$OSArchitecture
            )
            # Filter object matching desired update type
            $UpdateEntryList = New-Object -TypeName System.Collections.ArrayList
            foreach ($UpdateEntry in $UpdateFeedXML.feed.entry) {
                if (($UpdateEntry.title -match "Servicing stack update.*") -and ($UpdateEntry.title -match ".*$($OSBuild).*")) {
                    $PSObject = [PSCustomObject]@{
                        Title = $UpdateEntry.title
                        ID = $UpdateEntry.id
                        Updated = $UpdateEntry.updated
                    }
                    $UpdateEntryList.Add($PSObject) | Out-Null
                }
            }
        
            if ($UpdateEntryList.Count -ge 1) {
                # Filter and select the most current update
                $UpdateList = New-Object -TypeName System.Collections.ArrayList
                foreach ($Update in $UpdateEntryList) {
                    $PSObject = [PSCustomObject]@{
                        Title = $Update.title
                        ID = "KB{0}" -f ($Update.id).Split(":")[2]
                        Updated = ([DateTime]::Parse($Update.updated))
                    }
                    $UpdateList.Add($PSObject) | Out-Null
                }
                $CurrentUpdate = $UpdateList | Sort-Object -Property Updated -Descending | Select-Object -First 1
        
                # Retrieve download data from update catalog
                if ($CurrentUpdate -ne $null) {
                    return Get-MSDownloadInfo -UpdateID $CurrentUpdate.ID
                }
            }
        }
    
        function Get-MSAdobeFlashUpdate {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidatePattern("^(1[789]|2[01])0(3|9)$")]
                [string]$OSBuild,
        
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidateSet("x64-based", "x86-based")]
                [string]$OSArchitecture
            )       
            # Filter object matching desired update type
            $UpdateEntryList = New-Object -TypeName System.Collections.ArrayList
            foreach ($UpdateEntry in $UpdateFeedXML.feed.entry) {
                if ($UpdateEntry.title -match ".*Adobe Flash Player.*") {
                    $PSObject = [PSCustomObject]@{
                        Title = $UpdateEntry.title
                        ID = $UpdateEntry.id
                        Updated = $UpdateEntry.updated
                    }
                    $UpdateEntryList.Add($PSObject) | Out-Null
                }
            }
        
            if ($UpdateEntryList.Count -ge 1) {
                # Filter and select the most current update
                $UpdateList = New-Object -TypeName System.Collections.ArrayList
                foreach ($Update in $UpdateEntryList) {
                    $PSObject = [PSCustomObject]@{
                        Title = $Update.title
                        ID = "KB{0}" -f ($Update.id).Split(":")[2]
                        Updated = ([DateTime]::Parse($Update.updated))
                    }
                    $UpdateList.Add($PSObject) | Out-Null
                }
                $CurrentUpdate = $UpdateList | Sort-Object -Property Updated -Descending | Select-Object -First 1
        
                # Retrieve download data from update catalog
                if ($CurrentUpdate -ne $null) {
                    return Get-MSDownloadInfo -UpdateID $CurrentUpdate.ID
                }
            }
        }
    
        # Retrieve the update feed XML document
        $UpdateFeedXML = Get-MSUpdateXML -FeedURL "https://support.microsoft.com/app/content/api/content/feeds/sap/en-us/6ae59d69-36fc-8e4d-23dd-631d98bf74a9/atom"        
        
        # Process each update type and retrieve update and download information
        $UpdateList = New-Object -TypeName System.Collections.ArrayList
        foreach ($UpdateItem in $UpdateType) {
            switch ($UpdateItem) {
                "CumulativeUpdate" {
                    foreach ($OSBuildItem in $OSBuild) {
                        $Update = Get-MSCumulativeUpdate -OSBuild $OSBuildItem -OSArchitecture $OSArchitecture
                        $Update | Add-Member -MemberType NoteProperty -Name "Type" -Value $UpdateItem
                        $Update | Add-Member -MemberType NoteProperty -Name "OSBuild" -Value $OSBuildItem
                        $UpdateList.Add($Update) | Out-Null
                    }
                }
                "ServicingStackUpdate" {
                    foreach ($OSBuildItem in $OSBuild) {
                        $Update = Get-MSServicingStackUpdate -OSBuild $OSBuildItem -OSArchitecture $OSArchitecture
                        $Update | Add-Member -MemberType NoteProperty -Name "Type" -Value $UpdateItem
                        $Update | Add-Member -MemberType NoteProperty -Name "OSBuild" -Value $OSBuildItem
                        $UpdateList.Add($Update) | Out-Null
                    }
                }
                "AdobeFlashUpdate" {
                    foreach ($OSBuildItem in $OSBuild) {
                        $Update = Get-MSAdobeFlashUpdate -OSBuild $OSBuildItem -OSArchitecture $OSArchitecture
                        $Update | Add-Member -MemberType NoteProperty -Name "Type" -Value $UpdateItem
                        $Update | Add-Member -MemberType NoteProperty -Name "OSBuild" -Value $OSBuildItem
                        $UpdateList.Add($Update) | Out-Null
                    }
                }
            }
        }
        
        # Download updates or list them only
        if ($UpdateList.Count -ge 1) {
            if ($List -eq $true) {
                Write-Host $UpdateList
                return $UpdateList
            }
            else {
                foreach ($UpdateItem in $UpdateList) {
                    $UpdateList
                    Write-Verbose -Message "Starting download of '$($UpdateItem.Description)' from: $($UpdateItem.DownloadURL)"
                    Start-DownloadFile -URL $UpdateItem.DownloadURL -Path $Path -Name ("Windows10.0-$($UpdateItem.OSBuild)-$($UpdateItem.KB)-$($UpdateItem.Type).msu")
                    return $UpdateList
                }
            }
        }
    }
}


Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '1000,500'
$Form.text                       = "DOWNLOAD LATEST CUMULATIVE UPDATE"
$Form.TopMost                    = $false

# _____________________________________________________________________________row 1:
$windows_lable                   = New-Object system.Windows.Forms.Label
$windows_lable.text              = "Windows 10:"
$windows_lable.AutoSize          = $true
$windows_lable.width             = 25
$windows_lable.height            = 10
$windows_lable.location          = New-Object System.Drawing.Point(25,15)
$windows_lable.Font              = 'Microsoft Sans Serif,10'

$architectures = "x86", "x64"
$architecture_combobox   = New-Object system.Windows.Forms.ComboBox
foreach ($architecture in $architectures){ $architecture_combobox.Items.Add($architecture) }
$architecture_combobox.text = "x86"
$architecture_combobox.width  = 100
$architecture_combobox.height  = 20
$architecture_combobox.location  = New-Object System.Drawing.Point(110,15)
$architecture_combobox.Font  = 'Microsoft Sans Serif,10'

$build_label                     = New-Object system.Windows.Forms.Label
$build_label.text                = "Build:"
$build_label.AutoSize            = $true
$build_label.width               = 25
$build_label.height              = 10
$build_label.location            = New-Object System.Drawing.Point(300,15)
$build_label.Font                = 'Microsoft Sans Serif,10'

$buildings = "1909", "1903", "1809"
$build_combobox                  = New-Object system.Windows.Forms.ComboBox
foreach ($building in $buildings){ $build_combobox.Items.Add($building) }
$build_combobox.text = "1909"
$build_combobox.width            = 100
$build_combobox.height           = 20
$build_combobox.location         = New-Object System.Drawing.Point(345,15)
$build_combobox.Font             = 'Microsoft Sans Serif,10'

# _____________________________________________________________________________row 2:
$target_label                    = New-Object system.Windows.Forms.Label
$target_label.text               = "Target Location"
$target_label.AutoSize           = $true
$target_label.width              = 25
$target_label.height             = 10
$target_label.location           = New-Object System.Drawing.Point(25,70)
$target_label.Font               = 'Microsoft Sans Serif,10'

$path_textbox                    = New-Object system.Windows.Forms.TextBox
$path_textbox.multiline          = $false
$path_textbox.width              = 250
$path_textbox.height             = 15
$path_textbox.location           = New-Object System.Drawing.Point(124,65)
$path_textbox.text = "C:\"
$path_textbox.Font               = 'Microsoft Sans Serif,10'

$setPath_btn                     = New-Object system.Windows.Forms.Button
$setPath_btn.text                = "..."
$setPath_btn.width               = 65
$setPath_btn.height              = 30
$setPath_btn.location            = New-Object System.Drawing.Point(380,60)
$setPath_btn.Font                = 'Microsoft Sans Serif,10'
$setPath_btn.Add_Click(
    {
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

        $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
        $foldername.Description = "Select a folder"
        $foldername.rootfolder = "MyComputer"
        $foldername.SelectedPath = $initialDirectory
    
        if($foldername.ShowDialog() -eq "OK")
        {
            $folder += $foldername.SelectedPath
        }
        $path_textbox.Text = $folder
    }
)

# _____________________________________________________________________________row 3:
$show_btn                        = New-Object system.Windows.Forms.Button
$show_btn.text                   = "Show"
$show_btn.width                  = 100
$show_btn.height                 = 30
$show_btn.location               = New-Object System.Drawing.Point(90,115)
$show_btn.Font                   = 'Microsoft Sans Serif,10'
$show_btn.Add_Click(
    {    
        Write-Host "Showing..."
        $output_textbox.Text = "Showing... `r`n"
        $UpdateType = "CumulativeUpdate"
        $Path = $path_textbox.Text
        $OSBuild = $build_combobox.Text
        $OSArchitecture = $architecture_combobox.Text+"-based"
        $List = $True
        $response = MSLatestUpdate $UpdateType $Path $OSBuild $OSArchitecture $List
        foreach($item in ($response-split ";"))
        {
            $output_textbox.AppendText("`r`n")
            Write-Host $item
            $output_textbox.AppendText($item)
            $output_textbox.AppendText("`r`n")
        }
        [System.Windows.Forms.MessageBox]::Show("Showing..." , "Show dialog box")
    }
)

$download_btn                    = New-Object system.Windows.Forms.Button
$download_btn.text               = "Download"
$download_btn.width              = 100
$download_btn.height             = 30
$download_btn.location           = New-Object System.Drawing.Point(290,115)
$download_btn.Font               = 'Microsoft Sans Serif,10'
$download_btn.Add_Click(
    {    
        Write-Host "Downloading..."
        $output_textbox.Text = "Downloading... `r`n"
        $UpdateType = "CumulativeUpdate"
        $Path = $path_textbox.Text
        $OSBuild = $build_combobox.Text
        $OSArchitecture = $architecture_combobox.Text+"-based"
        $List = $False
        $response = MSLatestUpdate $UpdateType $Path $OSBuild $OSArchitecture $List
        foreach($item in ($response-split ";"))
        {
            $output_textbox.AppendText("`r`n")
            Write-Host $item
            $output_textbox.AppendText($item)
            $output_textbox.AppendText("`r`n")
        }
        [System.Windows.Forms.MessageBox]::Show("Downloading..." , "Show dialog box")
    }
)

# _____________________________________________________________________________row 4:
$output_textbox                  = New-Object system.Windows.Forms.TextBox
$output_textbox.multiline        = $true
$output_textbox.width            = 950
$output_textbox.height           = 206
$output_textbox.location         = New-Object System.Drawing.Point(25,160)
$output_textbox.Font             = 'Microsoft Sans Serif,10'


$download_ProgressBar                    = New-Object system.Windows.Forms.ProgressBar
$download_ProgressBar.width              = 950
$download_ProgressBar.height             = 30
$download_ProgressBar.location           = New-Object System.Drawing.Point(25,400)

$Form.controls.AddRange(@($path_textbox,$show_btn,$download_btn,$setPath_btn,$target_label,$build_label,$architecture_combobox,$build_combobox,$output_textbox,$windows_lable, $download_ProgressBar))
$Form.ShowDialog()