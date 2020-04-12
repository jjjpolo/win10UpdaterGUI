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

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '400,179'
$Form.text                       = "Form"
$Form.TopMost                    = $false

$download_ProgressBar                    = New-Object system.Windows.Forms.ProgressBar
$download_ProgressBar.width              = 303
$download_ProgressBar.height             = 60
$download_ProgressBar.location           = New-Object System.Drawing.Point(40,23)

$Button1                         = New-Object system.Windows.Forms.Button
$Button1.text                    = "button"
$Button1.width                   = 60
$Button1.height                  = 30
$Button1.location                = New-Object System.Drawing.Point(149,125)
$Button1.Font                    = 'Microsoft Sans Serif,10'
$Button1.Add_Click(
    {
        $path = "c:\Intel_Log"
        #$url =  "http://download.windowsupdate.com/d/msdownload/update/software/updt/2020/03/windows10.0-kb4554364-x86_f863a4d7845e249f3b0d087839b62da60262af62.msu"
        #$name = "test.msu"
        $url =  "https://download.teamviewer.com/download/version_9x/TeamViewer_Setup.exe"
        $name = "test.exe"
        
        Start-DownloadFile -URL $url -Path $path -Name $name

        Write-Host "Finished..."
    }
)

$Form.controls.AddRange(@($download_ProgressBar,$Button1))
$Form.showDialog()

