<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    Untitled
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '480,380'
$Form.text                       = "DOWNLOAD LATEST CUMULATIVE UPDATE"
$Form.TopMost                    = $false

# row 1:
$windows_lable                   = New-Object system.Windows.Forms.Label
$windows_lable.text              = "Windows 10:"
$windows_lable.AutoSize          = $true
$windows_lable.width             = 25
$windows_lable.height            = 10
$windows_lable.location          = New-Object System.Drawing.Point(34,15)
$windows_lable.Font              = 'Microsoft Sans Serif,10'

$ComboBox1architecture_combobox   = New-Object system.Windows.Forms.ComboBox
$ComboBox1architecture_combobox.text  = "x86"
$ComboBox1architecture_combobox.width  = 100
$ComboBox1architecture_combobox.height  = 20
$ComboBox1architecture_combobox.location  = New-Object System.Drawing.Point(145,15)
$ComboBox1architecture_combobox.Font  = 'Microsoft Sans Serif,10'

$build_label                     = New-Object system.Windows.Forms.Label
$build_label.text                = "Build:"
$build_label.AutoSize            = $true
$build_label.width               = 25
$build_label.height              = 10
$build_label.location            = New-Object System.Drawing.Point(301,15)
$build_label.Font                = 'Microsoft Sans Serif,10'

$build_combobox                  = New-Object system.Windows.Forms.ComboBox
$build_combobox.text             = "1903"
$build_combobox.width            = 100
$build_combobox.height           = 20
$build_combobox.location         = New-Object System.Drawing.Point(355,15)
$build_combobox.Font             = 'Microsoft Sans Serif,10'

# row 2:
$target_label                    = New-Object system.Windows.Forms.Label
$target_label.text               = "Target Location"
$target_label.AutoSize           = $true
$target_label.width              = 25
$target_label.height             = 10
$target_label.location           = New-Object System.Drawing.Point(18,65)
$target_label.Font               = 'Microsoft Sans Serif,10'

$path_textbox                    = New-Object system.Windows.Forms.TextBox
$path_textbox.multiline          = $false
$path_textbox.width              = 250
$path_textbox.height             = 15
$path_textbox.location           = New-Object System.Drawing.Point(124,65)
$path_textbox.Font               = 'Microsoft Sans Serif,10'

$setPath_btn                     = New-Object system.Windows.Forms.Button
$setPath_btn.text                = "..."
$setPath_btn.width               = 60
$setPath_btn.height              = 30
$setPath_btn.location            = New-Object System.Drawing.Point(380,65)
$setPath_btn.Font                = 'Microsoft Sans Serif,10'

# row 3:
$show_btn                        = New-Object system.Windows.Forms.Button
$show_btn.text                   = "Show"
$show_btn.width                  = 100
$show_btn.height                 = 30
$show_btn.location               = New-Object System.Drawing.Point(58,115)
$show_btn.Font                   = 'Microsoft Sans Serif,10'

$download_btn                    = New-Object system.Windows.Forms.Button
$download_btn.text               = "Download"
$download_btn.width              = 100
$download_btn.height             = 30
$download_btn.location           = New-Object System.Drawing.Point(300,115)
$download_btn.Font               = 'Microsoft Sans Serif,10'

#row 4:
$output_textbox                  = New-Object system.Windows.Forms.TextBox
$output_textbox.multiline        = $true
$output_textbox.width            = 429
$output_textbox.height           = 206
$output_textbox.location         = New-Object System.Drawing.Point(27,160)
$output_textbox.Font             = 'Microsoft Sans Serif,10'



$Form.controls.AddRange(@($path_textbox,$show_btn,$download_btn,$setPath_btn,$target_label,$build_label,$ComboBox1architecture_combobox,$build_combobox,$output_textbox,$windows_lable))


$Form.ShowDialog()