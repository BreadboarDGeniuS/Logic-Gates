Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to find the next available packdata file
function Get-NextPackdataFile {
    $index = 1
    while (Test-Path "packdata$index.txt") {
        $index++
    }
    return "packdata$index.txt"
}

# Reset all relevant parameters and variables
$global:logFileName = Get-NextPackdataFile
$global:COM_PORT = $null
$global:currentTimer = $null

# Ensure the XML file path is set
$xmlFilePath = Join-Path -Path (Get-Location) -ChildPath "BreadboarDGeniuSLogicProgrammer.xml"
$global:progPyPath = ""
$global:hexFilesStandard = @{
    "and-nand" = ""
    "or-nor" = ""
    "xor-xnor" = ""
    "dual-not" = ""
    "majority-minority" = ""
}

$global:counterhexFilesStandard = @{
    "LS163-Counter" = ""
    "Decimal-Generator" = ""
    "10Bit-binary-output" = ""
    "7-Segment-Contoller" = ""
    "SomeOthertypeofthing" = ""
}

$global:hexFilesCustom = @()
$global:counterhexFilesCustom = @()
$global:statusLabels = @{}

# Load the configuration from XML
function Load-Configuration {
    if (Test-Path $xmlFilePath) {
        $xml = [xml](Get-Content $xmlFilePath)
        $global:progPyPath = $xml.Configuration.progPyPath

        # Load standard hex file paths
        foreach ($file in $xml.Configuration.StandardHexFiles.File) {
            $global:hexFilesStandard[$file.Name] = $file.InnerText
        }

        # Load custom hex file paths into an array
        $global:hexFilesCustom = @()
        foreach ($file in $xml.Configuration.CustomHexFiles.File) {
            $global:hexFilesCustom += @{ Name = $file.Name; Path = $file.InnerText }
        }
		
		# Load counter standard hex file paths
        foreach ($file in $xml.Configuration.counterStandardHexFiles.File) {
            $global:counterhexFilesStandard[$file.Name] = $file.InnerText
        }

        # Load counter custom hex file paths into an array
        $global:counterhexFilesCustom = @()
        foreach ($file in $xml.Configuration.counterCustomHexFiles.File) {
            $global:counterhexFilesCustom += @{ Name = $file.Name; Path = $file.InnerText }
        }
		
    } else {
        $global:progPyPath = ""
    }
}

# Save the configuration to XML
function Save-Configuration {
    $xml = New-Object xml
    $configuration = $xml.CreateElement("Configuration")
    $xml.AppendChild($configuration) | Out-Null

    $progPyPathElement = $xml.CreateElement("progPyPath")
    $progPyPathElement.InnerText = $global:progPyPath
    $configuration.AppendChild($progPyPathElement) | Out-Null

    $standardHexFilesElement = $xml.CreateElement("StandardHexFiles")
    foreach ($name in $global:hexFilesStandard.Keys) {
        $fileElement = $xml.CreateElement("File")
        $fileElement.SetAttribute("Name", $name)
        $fileElement.InnerText = $global:hexFilesStandard[$name]
        $standardHexFilesElement.AppendChild($fileElement) | Out-Null
    }
    $configuration.AppendChild($standardHexFilesElement) | Out-Null

    $customHexFilesElement = $xml.CreateElement("CustomHexFiles")
    foreach ($file in $global:hexFilesCustom) {
        $fileElement = $xml.CreateElement("File")
        $fileElement.SetAttribute("Name", $file.Name)
        $fileElement.InnerText = $file.Path
        $customHexFilesElement.AppendChild($fileElement) | Out-Null
    }
    $configuration.AppendChild($customHexFilesElement) | Out-Null

	$counterstandardHexFilesElement = $xml.CreateElement("counterStandardHexFiles")
    foreach ($name in $global:counterhexFilesStandard.Keys) {
        $fileElement = $xml.CreateElement("File")
        $fileElement.SetAttribute("Name", $name)
        $fileElement.InnerText = $global:counterhexFilesStandard[$name]
        $counterstandardHexFilesElement.AppendChild($fileElement) | Out-Null
    }
    $configuration.AppendChild($counterstandardHexFilesElement) | Out-Null

    $countercustomHexFilesElement = $xml.CreateElement("counterCustomHexFiles")
    foreach ($file in $global:counterhexFilesCustom) {
        $fileElement = $xml.CreateElement("File")
        $fileElement.SetAttribute("Name", $file.Name)
        $fileElement.InnerText = $file.Path
        $countercustomHexFilesElement.AppendChild($fileElement) | Out-Null
    }
    $configuration.AppendChild($countercustomHexFilesElement) | Out-Null

    $xml.Save($xmlFilePath)
}

# Function to locate Arduino installation and megaTinyCore
function Find-ArduinoMegaTinyCore {
    $arduinoDirs = @(
        "$env:ProgramFiles\Arduino",
        "$env:ProgramFiles(x86)\Arduino",
        "$env:LOCALAPPDATA\Arduino15\packages",
        "$env:APPDATA\Arduino15\packages"
    )

    foreach ($dir in $arduinoDirs) {
        if (Test-Path $dir) {
            $megaTinyCorePath = Get-ChildItem -Path $dir -Recurse -Filter "prog.py" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($megaTinyCorePath) {
                return $megaTinyCorePath.FullName
            }
        }
    }

    return $null
}

# Check if prog.py exists, and if not, prompt the user to locate it
function Find-ProgPy {
    if (-not $global:progPyPath) {
        # First, check if megaTinyCore is installed and locate prog.py
        $global:progPyPath = Find-ArduinoMegaTinyCore
        if ($global:progPyPath) {
            Write-Host "Found prog.py via Arduino installation: $global:progPyPath"
            Save-Configuration  # Save to XML
        }
    }

    if (-not $global:progPyPath) {
        $global:progPyPath = Join-Path -Path (Get-Location) -ChildPath "prog.py"
    }

    if (-not (Test-Path $global:progPyPath)) {
        # If not found in current directory, check in the XML file
        Load-Configuration

        if (-not $global:progPyPath -or -not (Test-Path $global:progPyPath)) {
            # If still not found, ask the user to locate it
            $progPyFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $progPyFileDialog.Filter = "Python Files (*.py)|*.py"
            $progPyFileDialog.Title = "Locate prog.py"

            if ($progPyFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $global:progPyPath = $progPyFileDialog.FileName
                Save-Configuration  # Save the new path to the XML file
            } else {
                [System.Windows.Forms.MessageBox]::Show("prog.py not found. The application will now exit.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                exit
            }
        }
    }
}

# Check if Python3 is installed
if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    [System.Windows.Forms.MessageBox]::Show("Python3 is not installed. Please install Python3 to continue.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Load configuration and find prog.py
Load-Configuration
Find-ProgPy

# Function to detect the COM port of the CH340 device
function Get-CH340Port {
    $ch340Ports = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Name -like '*CH340*' } | Select-Object -ExpandProperty Name
    if ($ch340Ports.Count -eq 0) {
        return $null
    } elseif ($ch340Ports.Count -eq 1 -and $ch340Ports -match '\((COM\d+)\)') {
        return $matches[1]
    } else {
        # Multiple CH340 devices found, create a dropdown for selection
        return $ch340Ports
    }
}

# Function to update the COM port label and rescan button
function Update-COMPortLabel {
    $ch340Ports = Get-CH340Port
    
    if (-not $ch340Ports) {
        $comPortLabel.Text = "No BreadboarD GeniuS Programmer found"
        $comPortLabel.ForeColor = [System.Drawing.Color]::Red
        $comPortLabel.Location = New-Object System.Drawing.Point(10, 600)
        $rescanButton.Visible = $true
    } elseif ($ch340Ports -is [System.String]) {
        # Single port found
        $global:COM_PORT = $ch340Ports
        $comPortLabel.Text = "BreadboarD GeniuS Programmer found on $global:COM_PORT"
        $comPortLabel.ForeColor = [System.Drawing.Color]::Green
        $comPortLabel.Location = New-Object System.Drawing.Point(10, 600)
        $rescanButton.Visible = $false
    } elseif ($ch340Ports -is [System.Object[]]) {
        # Multiple ports found, present a dropdown selection
        $comPortLabel.Text = "Multiple BreadboarD GeniuS Programmer devices found, select one:"
        $comPortLabel.ForeColor = [System.Drawing.Color]::Blue
        $comPortLabel.Location = New-Object System.Drawing.Point(10, 600)

        # Create dropdown if it doesn't exist
        if (-not $global:comPortDropdown) {
            $global:comPortDropdown = New-Object System.Windows.Forms.ComboBox
            $global:comPortDropdown.Location = New-Object System.Drawing.Point(10, 630)
            $global:comPortDropdown.Size = New-Object System.Drawing.Size(240, 30)
            $form.Controls.Add($global:comPortDropdown)
        }

        # Populate the dropdown
        $global:comPortDropdown.Items.Clear()
        foreach ($port in $ch340Ports) {
            if ($port -match '\((COM\d+)\)') {
                $global:comPortDropdown.Items.Add($matches[1])
            }
        }

        # Handle dropdown selection
        $global:comPortDropdown.Add_SelectedIndexChanged({
            $global:COM_PORT = $global:comPortDropdown.SelectedItem
            $comPortLabel.Text = "Selected BreadboarD GeniuS Programmer on $global:COM_PORT"
            $comPortLabel.ForeColor = [System.Drawing.Color]::Green
        })

        $rescanButton.Visible = $true
        $global:comPortDropdown.Visible = $true
    }
}

# Function to handle standard button clicks
function Handle-StandardButtonClick {
    param (
        [string]$buttonName,
        [string]$labelKey,  # Key to fetch label from the global dictionary
        [string]$hexFile,
		[string]$MCU
    )

    if (-not $hexFile -or -not (Test-Path $hexFile)) {
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Hex Files (*.hex)|*.hex"
        $fileDialog.Title = "Locate $buttonName HEX File"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $global:hexFilesStandard[$buttonName] = $fileDialog.FileName
            Save-Configuration
            Run-Command $fileDialog.FileName $labelKey $buttonName
        }
    } else {
        Run-Command $hexFile $labelKey $buttonName $MCU
    }
}

function Handle-counterStandardButtonClick {
    param (
        [string]$buttonName,
        [string]$labelKey,  # Key to fetch label from the global dictionary
        [string]$hexFile,
		[string]$MCU
    )

    if (-not $hexFile -or -not (Test-Path $hexFile)) {
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Hex Files (*.hex)|*.hex"
        $fileDialog.Title = "Locate $buttonName HEX File"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $global:counterhexFilesStandard[$buttonName] = $fileDialog.FileName
            Save-Configuration
            Run-Command $fileDialog.FileName $labelKey $buttonName
        }
    } else {
        Run-Command $hexFile $labelKey $buttonName $MCU
    }
}

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "BreadboarD GeniuS logic gate programmer"
$form.Size = New-Object System.Drawing.Size(1350, 800)
$form.StartPosition = "CenterScreen"
$form.AutoScroll = $true  # Add scroll bars if content overflows

# Create a split panel for command and output console
$consolePanel = New-Object System.Windows.Forms.Panel
$consolePanel.Size = New-Object System.Drawing.Size(400, 700)
$consolePanel.Location = New-Object System.Drawing.Point(450, 10)
$form.Controls.Add($consolePanel)

# Create the top box for showing the command
$commandTextBox = New-Object System.Windows.Forms.TextBox
$commandTextBox.Location = New-Object System.Drawing.Point(0, 0)
$commandTextBox.Size = New-Object System.Drawing.Size(400, 150)
$commandTextBox.Multiline = $true
$commandTextBox.ScrollBars = 'Vertical'
$commandTextBox.ReadOnly = $true
$consolePanel.Controls.Add($commandTextBox)

# Create the bottom box for showing the output
$outputTextBox = New-Object System.Windows.Forms.TextBox
$outputTextBox.Location = New-Object System.Drawing.Point(0, 160)
$outputTextBox.Size = New-Object System.Drawing.Size(400, 520)
$outputTextBox.Multiline = $true
$outputTextBox.ScrollBars = 'Vertical'
$outputTextBox.ReadOnly = $true
$consolePanel.Controls.Add($outputTextBox)

# Function to update the command textbox and append previous commands with a separator
function Update-CommandText {
    param (
        [string]$command
    )

    # Append the separator and the command to the text box without clearing previous content
    $separator = "***************************************************" + [Environment]::NewLine + "$(Get-Date)" + [Environment]::NewLine + [Environment]::NewLine + "***************************************************" + [Environment]::NewLine
    $commandTextBox.AppendText($separator)
    $commandTextBox.AppendText($command + [Environment]::NewLine)
}

# Function to append output to the output textbox with a separator
function Append-ConsoleOutput {
    param (
        [string]$text
    )

    # Append the separator and the output to the text box without clearing previous content
    $separator = "***************************************************" + [Environment]::NewLine + "$(Get-Date)" + [Environment]::NewLine + [Environment]::NewLine + "***************************************************" + [Environment]::NewLine
    $outputTextBox.AppendText($separator)
    $outputTextBox.AppendText($text + [Environment]::NewLine)
}

# Function to create a status label (checkmark or red X)
function Create-StatusLabel {
    param (
        [System.Drawing.Point]$location,
        [System.Windows.Forms.Control]$parentControl
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Location = $location
    $label.Size = New-Object System.Drawing.Size(145, 50)
    $label.Visible = $false
    $parentControl.Controls.Add($label)
    return $label
}

# Function to show status
function Show-Status {
    param (
        [string]$labelKey,  # Key to fetch the label
        [bool]$success
    )

    $statusLabel = $global:statusLabels[$labelKey]

    if ($statusLabel -is [System.Windows.Forms.Label]) {
        if ($success) {
            $statusLabel.Text = "[OK] Success"
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $statusLabel.Text = "[FAIL] Failed"
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
        }
        $statusLabel.Visible = $true
    } else {
        Append-ConsoleOutput "Error: The label provided is not a valid System.Windows.Forms.Label object."
    }
}

# Function to clear status
function Clear-Status {
    param (
        [string]$labelKey  # Key to fetch the label
    )

    $statusLabel = $global:statusLabels[$labelKey]

    if ($statusLabel -is [System.Windows.Forms.Label]) {
        $statusLabel.Visible = $false
    } else {
        Append-ConsoleOutput "Error: The label provided is not a valid System.Windows.Forms.Label object."
    }
}

# Function to clear all status labels
function Clear-AllStatuses {
    foreach ($labelKey in $global:statusLabels.Keys) {
        Clear-Status $labelKey
    }
}

# Create the group boxes for Standard and Custom buttons
$standardGroupBox = New-Object System.Windows.Forms.GroupBox
$standardGroupBox.Text = "Logic Gate Standard"
$standardGroupBox.Location = New-Object System.Drawing.Point(10, 10)
$standardGroupBox.Size = New-Object System.Drawing.Size(400, 270)
$form.Controls.Add($standardGroupBox)

$customGroupBox = New-Object System.Windows.Forms.GroupBox
$customGroupBox.Text = "Logic Gate Custom"
$customGroupBox.Location = New-Object System.Drawing.Point(10, 290)
$customGroupBox.Size = New-Object System.Drawing.Size(400, 300)
$form.Controls.Add($customGroupBox)

# Create a scrollable panel for custom buttons
$customPanel = New-Object System.Windows.Forms.Panel
$customPanel.AutoScroll = $true
$customPanel.Dock = 'Fill'
$customGroupBox.Controls.Add($customPanel)

# Create the group boxes for Standard and Custom buttons
$counterstandardGroupBox = New-Object System.Windows.Forms.GroupBox
$counterstandardGroupBox.Text = "Binary Counter Standard"
$counterstandardGroupBox.Location = New-Object System.Drawing.Point(890, 10)
$counterstandardGroupBox.Size = New-Object System.Drawing.Size(400, 270)
$form.Controls.Add($counterstandardGroupBox)

$countercustomGroupBox = New-Object System.Windows.Forms.GroupBox
$countercustomGroupBox.Text = "Binary Counter Custom"
$countercustomGroupBox.Location = New-Object System.Drawing.Point(890, 290)
$countercustomGroupBox.Size = New-Object System.Drawing.Size(400, 300)
$form.Controls.Add($countercustomGroupBox)

# Create a scrollable panel for custom buttons
$countercustomPanel = New-Object System.Windows.Forms.Panel
$countercustomPanel.AutoScroll = $true
$countercustomPanel.Dock = 'Fill'
$countercustomGroupBox.Controls.Add($countercustomPanel)


# Variables for standard buttons and status labels
$xOffset = 10
$yOffsetStandard = 25
$yOffsetCustom = 0
#$ycounterOffsetStandard = 25

# Create Counter standard buttons
$counterbuttonA = New-Object System.Windows.Forms.Button
$counterbuttonA.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$counterbuttonA.Size = New-Object System.Drawing.Size(240, 30)
$counterbuttonA.Text = "Program Binary Counter"
$counterbuttonA.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "counterstatusA"
    Handle-StandardButtonClick -buttonName "LS163-Counter" -labelKey "counterstatusA" -hexFile $global:counterhexFilesStandard["LS163-Counter"] -MCU "atmega4809"
})
$counterstandardGroupBox.Controls.Add($counterbuttonA)
$global:statusLabels["counterstatusA"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $counterstandardGroupBox
$yOffsetStandard += 40

$counterbuttonE = New-Object System.Windows.Forms.Button
$counterbuttonE.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$counterbuttonE.Size = New-Object System.Drawing.Size(240, 30)
$counterbuttonE.Text = "Erase and Reset"
$counterbuttonE.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "counterstatusE"
    counterErase-Device "counterstatusE"
})
$counterstandardGroupBox.Controls.Add($counterbuttonE)
$global:statusLabels["counterstatusE"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $counterstandardGroupBox


$yOffsetStandard = 25
# Create standard buttons
$buttonA = New-Object System.Windows.Forms.Button
$buttonA.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonA.Size = New-Object System.Drawing.Size(240, 30)
$buttonA.Text = "Program AND/NAND Gate"
$buttonA.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusA"
    Handle-StandardButtonClick -buttonName "and-nand" -labelKey "statusA" -hexFile $global:hexFilesStandard["and-nand"] -MCU "attiny1616"
})
$standardGroupBox.Controls.Add($buttonA)
$global:statusLabels["statusA"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox
$yOffsetStandard += 40

$buttonO = New-Object System.Windows.Forms.Button
$buttonO.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonO.Size = New-Object System.Drawing.Size(240, 30)
$buttonO.Text = "Program OR/NOR Gate"
$buttonO.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusO"
    Handle-StandardButtonClick -buttonName "or-nor" -labelKey "statusO" -hexFile $global:hexFilesStandard["or-nor"] -MCU "attiny1616"
})
$standardGroupBox.Controls.Add($buttonO)
$global:statusLabels["statusO"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox
$yOffsetStandard += 40

$buttonX = New-Object System.Windows.Forms.Button
$buttonX.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonX.Size = New-Object System.Drawing.Size(240, 30)
$buttonX.Text = "Program XOR/XNOR Gate"
$buttonX.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusX"
    Handle-StandardButtonClick -buttonName "xor-xnor" -labelKey "statusX" -hexFile $global:hexFilesStandard["xor-xnor"] -MCU "attiny1616"
})
$standardGroupBox.Controls.Add($buttonX)
$global:statusLabels["statusX"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox
$yOffsetStandard += 40

$buttonN = New-Object System.Windows.Forms.Button
$buttonN.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonN.Size = New-Object System.Drawing.Size(240, 30)
$buttonN.Text = "Program Dual NOT Gate"
$buttonN.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusN"
    Handle-StandardButtonClick -buttonName "dual-not" -labelKey "statusN" -hexFile $global:hexFilesStandard["dual-not"] -MCU "attiny1616"
})
$standardGroupBox.Controls.Add($buttonN)
$global:statusLabels["statusN"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox
$yOffsetStandard += 40

$buttonM = New-Object System.Windows.Forms.Button
$buttonM.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonM.Size = New-Object System.Drawing.Size(240, 30)
$buttonM.Text = "Program Majority/Minority Gate"
$buttonM.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusM"
    Handle-StandardButtonClick -buttonName "majority-minority" -labelKey "statusM" -hexFile $global:hexFilesStandard["majority-minority"] -MCU "attiny1616"
})
$standardGroupBox.Controls.Add($buttonM)
$global:statusLabels["statusM"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox
$yOffsetStandard += 40

$buttonE = New-Object System.Windows.Forms.Button
$buttonE.Location = New-Object System.Drawing.Point($xOffset, $yOffsetStandard)
$buttonE.Size = New-Object System.Drawing.Size(240, 30)
$buttonE.Text = "Erase and Reset"
$buttonE.Add_Click({
    Clear-AllStatuses
    Show-RunningStatus "statusE"
    Erase-Device "statusE"
})
$standardGroupBox.Controls.Add($buttonE)
$global:statusLabels["statusE"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetStandard)) -parentControl $standardGroupBox

# Function to configure and display custom buttons
function Configure-CustomButtons {
    # Custom Buttons (Static Configuration)
    # Button 1
    $button1 = New-Object System.Windows.Forms.Button
    $button1.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button1.Size = New-Object System.Drawing.Size(200, 30)
    $button1.Visible = $false
    $customPanel.Controls.Add($button1)

    $deleteButton1 = New-Object System.Windows.Forms.Button
    $deleteButton1.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton1.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton1.Text = "X"
    $deleteButton1.ForeColor = [System.Drawing.Color]::Red
    $deleteButton1.Visible = $false
    $customPanel.Controls.Add($deleteButton1)

    $global:statusLabels["status1"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 2
    $button2 = New-Object System.Windows.Forms.Button
    $button2.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button2.Size = New-Object System.Drawing.Size(200, 30)
    $button2.Visible = $false
    $customPanel.Controls.Add($button2)

    $deleteButton2 = New-Object System.Windows.Forms.Button
    $deleteButton2.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton2.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton2.Text = "X"
    $deleteButton2.ForeColor = [System.Drawing.Color]::Red
    $deleteButton2.Visible = $false
    $customPanel.Controls.Add($deleteButton2)

    $global:statusLabels["status2"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 3
    $button3 = New-Object System.Windows.Forms.Button
    $button3.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button3.Size = New-Object System.Drawing.Size(200, 30)
    $button3.Visible = $false
    $customPanel.Controls.Add($button3)

    $deleteButton3 = New-Object System.Windows.Forms.Button
    $deleteButton3.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton3.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton3.Text = "X"
    $deleteButton3.ForeColor = [System.Drawing.Color]::Red
    $deleteButton3.Visible = $false
    $customPanel.Controls.Add($deleteButton3)

    $global:statusLabels["status3"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 4
    $button4 = New-Object System.Windows.Forms.Button
    $button4.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button4.Size = New-Object System.Drawing.Size(200, 30)
    $button4.Visible = $false
    $customPanel.Controls.Add($button4)

    $deleteButton4 = New-Object System.Windows.Forms.Button
    $deleteButton4.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton4.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton4.Text = "X"
    $deleteButton4.ForeColor = [System.Drawing.Color]::Red
    $deleteButton4.Visible = $false
    $customPanel.Controls.Add($deleteButton4)

    $global:statusLabels["status4"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 5
    $button5 = New-Object System.Windows.Forms.Button
    $button5.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button5.Size = New-Object System.Drawing.Size(200, 30)
    $button5.Visible = $false
    $customPanel.Controls.Add($button5)

    $deleteButton5 = New-Object System.Windows.Forms.Button
    $deleteButton5.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton5.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton5.Text = "X"
    $deleteButton5.ForeColor = [System.Drawing.Color]::Red
    $deleteButton5.Visible = $false
    $customPanel.Controls.Add($deleteButton5)

    $global:statusLabels["status5"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 6
    $button6 = New-Object System.Windows.Forms.Button
    $button6.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button6.Size = New-Object System.Drawing.Size(200, 30)
    $button6.Visible = $false
    $customPanel.Controls.Add($button6)

    $deleteButton6 = New-Object System.Windows.Forms.Button
    $deleteButton6.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton6.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton6.Text = "X"
    $deleteButton6.ForeColor = [System.Drawing.Color]::Red
    $deleteButton6.Visible = $false
    $customPanel.Controls.Add($deleteButton6)

    $global:statusLabels["status6"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 7
    $button7 = New-Object System.Windows.Forms.Button
    $button7.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button7.Size = New-Object System.Drawing.Size(200, 30)
    $button7.Visible = $false
    $customPanel.Controls.Add($button7)

    $deleteButton7 = New-Object System.Windows.Forms.Button
    $deleteButton7.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton7.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton7.Text = "X"
    $deleteButton7.ForeColor = [System.Drawing.Color]::Red
    $deleteButton7.Visible = $false
    $customPanel.Controls.Add($deleteButton7)

    $global:statusLabels["status7"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 8
    $button8 = New-Object System.Windows.Forms.Button
    $button8.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button8.Size = New-Object System.Drawing.Size(200, 30)
    $button8.Visible = $false
    $customPanel.Controls.Add($button8)

    $deleteButton8 = New-Object System.Windows.Forms.Button
    $deleteButton8.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton8.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton8.Text = "X"
    $deleteButton8.ForeColor = [System.Drawing.Color]::Red
    $deleteButton8.Visible = $false
    $customPanel.Controls.Add($deleteButton8)

    $global:statusLabels["status8"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 9
    $button9 = New-Object System.Windows.Forms.Button
    $button9.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button9.Size = New-Object System.Drawing.Size(200, 30)
    $button9.Visible = $false
    $customPanel.Controls.Add($button9)

    $deleteButton9 = New-Object System.Windows.Forms.Button
    $deleteButton9.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton9.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton9.Text = "X"
    $deleteButton9.ForeColor = [System.Drawing.Color]::Red
    $deleteButton9.Visible = $false
    $customPanel.Controls.Add($deleteButton9)

    $global:statusLabels["status9"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Button 10
    $button10 = New-Object System.Windows.Forms.Button
    $button10.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $button10.Size = New-Object System.Drawing.Size(200, 30)
    $button10.Visible = $false
    $customPanel.Controls.Add($button10)

    $deleteButton10 = New-Object System.Windows.Forms.Button
    $deleteButton10.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $deleteButton10.Size = New-Object System.Drawing.Size(30, 30)
    $deleteButton10.Text = "X"
    $deleteButton10.ForeColor = [System.Drawing.Color]::Red
    $deleteButton10.Visible = $false
    $customPanel.Controls.Add($deleteButton10)

    $global:statusLabels["status10"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $customPanel
    $yOffsetCustom += 40

    # Configure each button based on the XML data
    if ($global:hexFilesCustom.Count -ge 1) {
        $button1.Text = $global:hexFilesCustom[0].Name
        $button1.Visible = $true
        $button1.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status1"
            Run-Command $global:hexFilesCustom[0].Path "status1" $button1.Text "attiny1616"
        })
        $deleteButton1.Visible = $true
        $deleteButton1.Add_Click({
            Remove-CustomHexFile 1
        })
    }

    if ($global:hexFilesCustom.Count -ge 2) {
        $button2.Text = $global:hexFilesCustom[1].Name
        $button2.Visible = $true
        $button2.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status2"
            Run-Command $global:hexFilesCustom[1].Path "status2" $button2.Text "attiny1616"
        })
        $deleteButton2.Visible = $true
        $deleteButton2.Add_Click({
            Remove-CustomHexFile 2
        })
    }

    if ($global:hexFilesCustom.Count -ge 3) {
        $button3.Text = $global:hexFilesCustom[2].Name
        $button3.Visible = $true
        $button3.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status3"
            Run-Command $global:hexFilesCustom[2].Path "status3" $button3.Text "attiny1616"
        })
        $deleteButton3.Visible = $true
        $deleteButton3.Add_Click({
            Remove-CustomHexFile 3
        })
    }

    if ($global:hexFilesCustom.Count -ge 4) {
        $button4.Text = $global:hexFilesCustom[3].Name
        $button4.Visible = $true
        $button4.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status4"
            Run-Command $global:hexFilesCustom[3].Path "status4" $button4.Text "attiny1616"
        })
        $deleteButton4.Visible = $true
        $deleteButton4.Add_Click({
            Remove-CustomHexFile 4
        })
    }

    if ($global:hexFilesCustom.Count -ge 5) {
        $button5.Text = $global:hexFilesCustom[4].Name
        $button5.Visible = $true
        $button5.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status5"
            Run-Command $global:hexFilesCustom[4].Path "status5" $button5.Text "attiny1616"
        })
        $deleteButton5.Visible = $true
        $deleteButton5.Add_Click({
            Remove-CustomHexFile 5
        })
    }

    if ($global:hexFilesCustom.Count -ge 6) {
        $button6.Text = $global:hexFilesCustom[5].Name
        $button6.Visible = $true
        $button6.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status6"
            Run-Command $global:hexFilesCustom[5].Path "status6" $button6.Text "attiny1616"
        })
        $deleteButton6.Visible = $true
        $deleteButton6.Add_Click({
            Remove-CustomHexFile 6
        })
    }

    if ($global:hexFilesCustom.Count -ge 7) {
        $button7.Text = $global:hexFilesCustom[6].Name
        $button7.Visible = $true
        $button7.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status7"
            Run-Command $global:hexFilesCustom[6].Path "status7" $button7.Text "attiny1616"
        })
        $deleteButton7.Visible = $true
        $deleteButton7.Add_Click({
            Remove-CustomHexFile 7
        })
    }

    if ($global:hexFilesCustom.Count -ge 8) {
        $button8.Text = $global:hexFilesCustom[7].Name
        $button8.Visible = $true
        $button8.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status8"
            Run-Command $global:hexFilesCustom[7].Path "status8" $button8.Text "attiny1616"
        })
        $deleteButton8.Visible = $true
        $deleteButton8.Add_Click({
            Remove-CustomHexFile 8
        })
    }

    if ($global:hexFilesCustom.Count -ge 9) {
        $button9.Text = $global:hexFilesCustom[8].Name
        $button9.Visible = $true
        $button9.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status9"
            Run-Command $global:hexFilesCustom[8].Path "status9" $button9.Text "attiny1616"
        })
        $deleteButton9.Visible = $true
        $deleteButton9.Add_Click({
            Remove-CustomHexFile 9
        })
    }

    if ($global:hexFilesCustom.Count -ge 10) {
        $button10.Text = $global:hexFilesCustom[9].Name
        $button10.Visible = $true
        $button10.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "status10"
            Run-Command $global:hexFilesCustom[9].Path "status10" $button10.Text "attiny1616"
        })
        $deleteButton10.Visible = $true
        $deleteButton10.Add_Click({
            Remove-CustomHexFile 10
        })
    }

    # Add "Add .hex" button if there is room for more custom buttons
    if ($global:hexFilesCustom.Count -lt 10) {
        $addButton = New-Object System.Windows.Forms.Button
        $addButton.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
        $addButton.Size = New-Object System.Drawing.Size(200, 30)
        $addButton.Text = "Add Binary .hex"
        $addButton.Add_Click({
            Add-CustomHexFile
        })
        $customPanel.Controls.Add($addButton)
    }
}

function Configure-counterCustomButtons {
    # Custom Buttons (Static Configuration)
    # Button 1
    $counterbutton1 = New-Object System.Windows.Forms.Button
    $counterbutton1.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton1.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton1.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton1)

    $counterdeleteButton1 = New-Object System.Windows.Forms.Button
    $counterdeleteButton1.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton1.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton1.Text = "X"
    $counterdeleteButton1.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton1.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton1)

    $global:statusLabels["counterstatus1"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 2
    $counterbutton2 = New-Object System.Windows.Forms.Button
    $counterbutton2.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton2.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton2.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton2)

    $counterdeleteButton2 = New-Object System.Windows.Forms.Button
    $counterdeleteButton2.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton2.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton2.Text = "X"
    $counterdeleteButton2.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton2.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton2)

    $global:statusLabels["counterstatus2"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 3
    $counterbutton3 = New-Object System.Windows.Forms.Button
    $counterbutton3.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton3.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton3.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton3)

    $counterdeleteButton3 = New-Object System.Windows.Forms.Button
    $counterdeleteButton3.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton3.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton3.Text = "X"
    $counterdeleteButton3.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton3.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton3)

    $global:statusLabels["counterstatus3"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 4
    $counterbutton4 = New-Object System.Windows.Forms.Button
    $counterbutton4.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton4.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton4.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton4)

    $counterdeleteButton4 = New-Object System.Windows.Forms.Button
    $counterdeleteButton4.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton4.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton4.Text = "X"
    $counterdeleteButton4.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton4.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton4)

    $global:statusLabels["counterstatus4"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 5
    $counterbutton5 = New-Object System.Windows.Forms.Button
    $counterbutton5.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton5.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton5.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton5)

    $counterdeleteButton5 = New-Object System.Windows.Forms.Button
    $counterdeleteButton5.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton5.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton5.Text = "X"
    $counterdeleteButton5.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton5.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton5)

    $global:statusLabels["counterstatus5"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 6
    $counterbutton6 = New-Object System.Windows.Forms.Button
    $counterbutton6.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton6.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton6.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton6)

    $counterdeleteButton6 = New-Object System.Windows.Forms.Button
    $counterdeleteButton6.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton6.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton6.Text = "X"
    $counterdeleteButton6.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton6.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton6)

    $global:statusLabels["counterstatus6"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 7
    $counterbutton7 = New-Object System.Windows.Forms.Button
    $counterbutton7.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton7.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton7.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton7)

    $counterdeleteButton7 = New-Object System.Windows.Forms.Button
    $counterdeleteButton7.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton7.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton7.Text = "X"
    $counterdeleteButton7.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton7.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton7)

    $global:statusLabels["counterstatus7"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 8
    $counterbutton8 = New-Object System.Windows.Forms.Button
    $counterbutton8.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton8.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton8.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton8)

    $counterdeleteButton8 = New-Object System.Windows.Forms.Button
    $counterdeleteButton8.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton8.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton8.Text = "X"
    $counterdeleteButton8.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton8.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton8)

    $global:statusLabels["counterstatus8"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 9
    $counterbutton9 = New-Object System.Windows.Forms.Button
    $counterbutton9.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton9.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton9.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton9)

    $counterdeleteButton9 = New-Object System.Windows.Forms.Button
    $counterdeleteButton9.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton9.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton9.Text = "X"
    $counterdeleteButton9.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton9.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton9)

    $global:statusLabels["counterstatus9"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Button 10
    $counterbutton10 = New-Object System.Windows.Forms.Button
    $counterbutton10.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
    $counterbutton10.Size = New-Object System.Drawing.Size(200, 30)
    $counterbutton10.Visible = $false
    $countercustomPanel.Controls.Add($counterbutton10)

    $counterdeleteButton10 = New-Object System.Windows.Forms.Button
    $counterdeleteButton10.Location = New-Object System.Drawing.Point(([int]$xOffset + 210), [int]$yOffsetCustom)
    $counterdeleteButton10.Size = New-Object System.Drawing.Size(30, 30)
    $counterdeleteButton10.Text = "X"
    $counterdeleteButton10.ForeColor = [System.Drawing.Color]::Red
    $counterdeleteButton10.Visible = $false
    $countercustomPanel.Controls.Add($counterdeleteButton10)

    $global:statusLabels["counterstatus10"] = Create-StatusLabel -location (New-Object System.Drawing.Point(250, $yOffsetCustom)) -parentControl $countercustomPanel
    $yOffsetCustom += 40

    # Configure each button based on the XML data
    if ($global:counterhexFilesCustom.Count -ge 1) {
        $counterbutton1.Text = $global:counterhexFilesCustom[0].Name
        $counterbutton1.Visible = $true
        $counterbutton1.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus1"
            Run-Command $global:counterhexFilesCustom[0].Path "counterstatus1" $counterbutton1.Text "atmega4809"
        })
        $counterdeleteButton1.Visible = $true
        $counterdeleteButton1.Add_Click({
            Remove-counterCustomHexFile 1
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 2) {
        $counterbutton2.Text = $global:counterhexFilesCustom[1].Name
        $counterbutton2.Visible = $true
        $counterbutton2.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus2"
            Run-Command $global:counterhexFilesCustom[1].Path "counterstatus2" $counterbutton2.Text "atmega4809"
        })
        $counterdeleteButton2.Visible = $true
        $counterdeleteButton2.Add_Click({
            Remove-counterCustomHexFile 2
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 3) {
        $counterbutton3.Text = $global:counterhexFilesCustom[2].Name
        $counterbutton3.Visible = $true
        $counterbutton3.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus3"
            Run-Command $global:counterhexFilesCustom[2].Path "counterstatus3" $counterbutton3.Text "atmega4809"
        })
        $counterdeleteButton3.Visible = $true
        $counterdeleteButton3.Add_Click({
            Remove-counterCustomHexFile 3
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 4) {
        $counterbutton4.Text = $global:counterhexFilesCustom[3].Name
        $counterbutton4.Visible = $true
        $counterbutton4.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus4"
            Run-Command $global:counterhexFilesCustom[3].Path "counterstatus4" $counterbutton4.Text "atmega4809"
        })
        $counterdeleteButton4.Visible = $true
        $counterdeleteButton4.Add_Click({
            Remove-counterCustomHexFile 4
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 5) {
        $counterbutton5.Text = $global:counterhexFilesCustom[4].Name
        $counterbutton5.Visible = $true
        $counterbutton5.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus5"
            Run-Command $global:counterhexFilesCustom[4].Path "counterstatus5" $counterbutton5.Text "atmega4809"
        })
        $counterdeleteButton5.Visible = $true
        $counterdeleteButton5.Add_Click({
            Remove-counterCustomHexFile 5
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 6) {
        $counterbutton6.Text = $global:counterhexFilesCustom[5].Name
        $counterbutton6.Visible = $true
        $counterbutton6.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus6"
            Run-Command $global:counterhexFilesCustom[5].Path "counterstatus6" $counterbutton6.Text "atmega4809"
        })
        $counterdeleteButton6.Visible = $true
        $counterdeleteButton6.Add_Click({
            Remove-counterCustomHexFile 6
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 7) {
        $counterbutton7.Text = $global:counterhexFilesCustom[6].Name
        $counterbutton7.Visible = $true
        $counterbutton7.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus7"
            Run-Command $global:counterhexFilesCustom[6].Path "counterstatus7" $counterbutton7.Text "atmega4809"
        })
        $deleteButton7.Visible = $true
        $deleteButton7.Add_Click({
            Remove-counterCustomHexFile 7
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 8) {
        $counterbutton8.Text = $global:counterhexFilesCustom[7].Name
        $counterbutton8.Visible = $true
        $counterbutton8.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus8"
            Run-Command $global:counterhexFilesCustom[7].Path "counterstatus8" $counterbutton8.Text "atmega4809"
        })
        $counterdeleteButton8.Visible = $true
        $counterdeleteButton8.Add_Click({
            Remove-counterCustomHexFile 8
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 9) {
        $counterbutton9.Text = $global:counterhexFilesCustom[8].Name
        $counterbutton9.Visible = $true
        $counterbutton9.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus9"
            Run-Command $global:counterhexFilesCustom[8].Path "counterstatus9" $counterbutton9.Text "atmega4809"
        })
        $counterdeleteButton9.Visible = $true
        $counterdeleteButton9.Add_Click({
            Remove-counterCustomHexFile 9
        })
    }

    if ($global:counterhexFilesCustom.Count -ge 10) {
        $counterbutton10.Text = $global:counterhexFilesCustom[9].Name
        $counterbutton10.Visible = $true
        $counterbutton10.Add_Click({
            Clear-AllStatuses
            Show-RunningStatus "counterstatus10"
            Run-Command $global:counterhexFilesCustom[9].Path "counterstatus10" $counterbutton10.Text "atmega4809"
			})
        $deleteButton10.Visible = $true
        $deleteButton10.Add_Click({
            Remove-CustomHexFile 10
        })
    }

    # Add "Add .hex" button if there is room for more custom buttons
    if ($global:counterhexFilesCustom.Count -lt 10) {
        $counteraddButton = New-Object System.Windows.Forms.Button
        $counteraddButton.Location = New-Object System.Drawing.Point([int]$xOffset, [int]$yOffsetCustom)
        $counteraddButton.Size = New-Object System.Drawing.Size(200, 30)
        $counteraddButton.Text = "Add Binary .hex"
        $counteraddButton.Add_Click({
            Add-counterCustomHexFile
        })
        $countercustomPanel.Controls.Add($counteraddButton)
    }
}

# Function to add custom buttons and update them
function Add-CustomHexFile {
    if ($global:hexFilesCustom.Count -lt 10) {
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Hex Files (*.hex)|*.hex"
        $fileDialog.Title = "Select a Custom HEX File"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension($fileDialog.FileName)
            $global:hexFilesCustom += @{ Name = $fileName; Path = $fileDialog.FileName }
            Save-Configuration
            $customPanel.Controls.Clear()  # Clear existing buttons
            Configure-CustomButtons  # Reconfigure all buttons
			Configure-counterCustomButtons  # Reconfigure all buttons
        }
    }
}

function Add-counterCustomHexFile {
    if ($global:counterhexFilesCustom.Count -lt 10) {
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Hex Files (*.hex)|*.hex"
        $fileDialog.Title = "Select a Custom HEX File"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension($fileDialog.FileName)
            $global:counterhexFilesCustom += @{ Name = $fileName; Path = $fileDialog.FileName }
            Save-Configuration
            $countercustomPanel.Controls.Clear()  # Clear existing buttons
			Configure-CustomButtons  # Reconfigure all buttons
            Configure-counterCustomButtons  # Reconfigure all buttons
        }
    }
}

# Function to remove a specific custom hex file
function Remove-CustomHexFile {
    param (
        [int]$index
    )

    $global:hexFilesCustom = $global:hexFilesCustom | Where-Object { $_ -ne $global:hexFilesCustom[$index - 1] }
    Save-Configuration
    $customPanel.Controls.Clear()  # Clear existing buttons
    Configure-CustomButtons  # Reconfigure all buttons
	Configure-counterCustomButtons
}

function Remove-counterCustomHexFile {
    param (
        [int]$index
    )

    $global:counterhexFilesCustom = $global:counterhexFilesCustom | Where-Object { $_ -ne $global:counterhexFilesCustom[$index - 1] }
    Save-Configuration
    $countercustomPanel.Controls.Clear()  # Clear existing buttons
	Configure-CustomButtons  # Reconfigure all buttons
    Configure-counterCustomButtons  # Reconfigure all buttons
}

# Create the rescan button
$rescanButton = New-Object System.Windows.Forms.Button
$rescanButton.Location = New-Object System.Drawing.Point(300, 590)
$rescanButton.Size = New-Object System.Drawing.Size(75, 30)
$rescanButton.Text = "Rescan"
$rescanButton.Visible = $false
$rescanButton.Add_Click({
    Update-COMPortLabel
})
$form.Controls.Add($rescanButton)

# Create a label to display the COM port status
$comPortLabel = New-Object System.Windows.Forms.Label
$comPortLabel.Location = New-Object System.Drawing.Point(10, 630)
$comPortLabel.Size = New-Object System.Drawing.Size(250, 30)
$form.Controls.Add($comPortLabel)

# Add new "Start New Log File" button
$buttonLog = New-Object System.Windows.Forms.Button
$buttonLog.Location = New-Object System.Drawing.Point(50, 670)
$buttonLog.Size = New-Object System.Drawing.Size(180, 30)
$buttonLog.Text = "Start New Log File"
$buttonLog.Add_Click({
    $global:logFileName = Get-NextPackdataFile
    [System.Windows.Forms.MessageBox]::Show("New log file created: $global:logFileName", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$form.Controls.Add($buttonLog)

# Add "Quit" button
$buttonQ = New-Object System.Windows.Forms.Button
$buttonQ.Location = New-Object System.Drawing.Point(50, 710)
$buttonQ.Size = New-Object System.Drawing.Size(180, 30)
$buttonQ.Text = "Quit"
$buttonQ.Add_Click({ $form.Close() })
$form.Controls.Add($buttonQ)

# Initial COM port detection
Update-COMPortLabel
# Initial Custom Button Configuration
Configure-CustomButtons
Configure-counterCustomButtons

# Function to show running status
function Show-RunningStatus {
    param (
        [string]$labelKey  # Key to fetch the label
    )

    $statusLabel = $global:statusLabels[$labelKey]

    if ($statusLabel -is [System.Windows.Forms.Label]) {
        $statusLabel.Text = "Running..."
        $statusLabel.ForeColor = [System.Drawing.Color]::Blue
        $statusLabel.Visible = $true
    } else {
        Append-ConsoleOutput "Error: The label provided is not a valid System.Windows.Forms.Label object."
    }
}

# Function to log details into the packdata file
function Log-RunDetails {
    param (
        [string]$optionName,
        [string[]]$output
    )

    # Initialize variables
    $deviceSerial = "Not found"      # Default value
    $deviceID = "Not found"          # Default value
    $deviceRevision = "Not found"    # Default value
    $deviceFamilyID = "Not found"    # Default value

    # Extract the relevant information from the output
    foreach ($line in $output) {
        if ($line -match "Device serial number:\s*(.+)") {
            $deviceSerial = $matches[1].Trim()
        }
        if ($line -match "Device ID:\s*'(\S+)'") {
            $deviceID = $matches[1].Trim()
        }
        if ($line -match "Device revision:\s*'(\S+)'") {
            $deviceRevision = $matches[1].Trim()
        }
        if ($line -match "Device family ID:\s*'(\S+)'") {
            $deviceFamilyID = $matches[1].Trim()
        }
    }

    # Create log entry
    $logEntry = "Device family ID: $deviceFamilyID, Device ID: $deviceID, Device serial number: $deviceSerial, Device revision: $deviceRevision, $optionName "
    
    # Log to the file
    Add-Content -Path $global:logFileName -Value $logEntry
}

# Function to run the Python command with the selected hex file
function Run-Command {
    param (
        [string]$hexFile,
        [string]$labelKey,  # Key to fetch the label
        [string]$optionName,
		[string]$MCU
    )
	
	if ($MCU -match "attiny1616") {
		$Logicdevicetype = "BreadboarD GeniuS Logic Gate"
	}
    if ($MCU -match "atmega4809") {
		$Logicdevicetype = "BreadboarD GeniuS Counter Unit"
	}
	
	$statusLabel = $global:statusLabels[$labelKey]

    # Escape the hex file path by enclosing it in double quotes
    $hexFileEscaped = "`"$hexFile`""

    # Prepare the command to program the device using the specified hex file
    $command = "python3 -u $global:progPyPath -t uart -u $global:COM_PORT -b 57600 -d $MCU --fuses 0:0b00000000 2:0x01 6:0x04 7:0x00 8:0x00 -f $hexFileEscaped -a write -v"


    # Update the command textbox
    Update-CommandText $command
    
	if ($MCU -match "atmega4809") {
		$clearfusescommand = "python3 -u $global:progPyPath -a write -d atmega4809 -t uart -u $global:COM_PORT --fuses fuse5=0xC1"
	}
	
    # Run the command and capture the output
    $output = Invoke-Expression $command 2>&1 | Out-String -Stream

    # Display the output of the command to the console
    Append-ConsoleOutput "Command Output: $output"

    # Check for specific errors, like UPDI initialization failure
    if ($output -match "UPDI init failed") {
        $statusLabel.Text = "[FAIL] UPDI Failed, please reseat the device in the programmer"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    } 
    if ($output -match "Device ID mismatch") {
        $statusLabel.Text = "[FAIL] Incorrect Logic Unit, insert $Logicdevicetype"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    }

    # Check if the command ran successfully
    if ($LASTEXITCODE -eq 0 -and $output -notmatch "error") {
        Show-Status $labelKey $true
        Log-RunDetails $optionName $output
    } else {
        Show-Status $labelKey $false
    }
}

# Function to erase the device and reset it to default
function Erase-Device {
    param (
        [string]$labelKey  # Key to fetch the label
    )

    $statusLabel = $global:statusLabels[$labelKey]

    # Prepare the erase command
    $eraseCommand = "python3 -u $global:progPyPath -a erase -d attiny1616 -t uart -u $global:COM_PORT"

    # Update the command textbox
    Update-CommandText $eraseCommand

    # Run the erase command and capture the output
    $eraseOutput = Invoke-Expression $eraseCommand 2>&1 | Out-String -Stream
    Append-ConsoleOutput "Erase Command Output: $eraseOutput"

    # Escape the path to the hex file used in the reset command
    $hexFileEscaped = "`"LEDflash.hex`""

    # Prepare the reset command
    $resetCommand = "python3 -u $global:progPyPath -t uart -u $global:COM_PORT -b 57600 -d attiny1616 --fuses 0:0b00000000 2:0x01 6:0x04 7:0x00 8:0x00 -f $hexFileEscaped -a write -v"

    # Update the command textbox
    Update-CommandText $resetCommand

    # Run the reset command and capture the output
    $resetOutput = Invoke-Expression $resetCommand 2>&1 | Out-String -Stream
    Append-ConsoleOutput "Reset Command Output: $resetOutput"
# Check for specific errors, like UPDI initialization failure
    if ($output -match "UPDI init failed") {
        $statusLabel.Text = "[FAIL] UPDI Failed, please reseat the device in the programmer"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    } 
    if ($output -match "Device ID mismatch") {
        $statusLabel.Text = "[FAIL] Incorrect Logic Unit, insert $Logicdevicetype"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    }
    if ($LASTEXITCODE -eq 0 -and $resetOutput -notmatch "error") {
        Show-Status $labelKey $true
        Log-RunDetails "Erase and Reset" $resetOutput
    } else {
        Show-Status $labelKey $false
    }
}

function counterErase-Device {
    param (
        [string]$labelKey  # Key to fetch the label
    )

    $statusLabel = $global:statusLabels[$labelKey]

    # Prepare the erase command
    $eraseCommand = "python3 -u $global:progPyPath -a write -d atmega4809 -t uart -u $global:COM_PORT --fuses fuse5=0xC1"

    # Update the command textbox
    Update-CommandText $eraseCommand

    # Run the erase command and capture the output
    $eraseOutput = Invoke-Expression $eraseCommand 2>&1 | Out-String -Stream
    Append-ConsoleOutput "Erase Command Output: $eraseOutput"

    # Escape the path to the hex file used in the reset command
    $counterhexFileEscaped = "`"counterLEDflash.hex`""

    # Prepare the reset command
    $resetCommand = "python3 -u $global:progPyPath -t uart -u $global:COM_PORT -b 57600 -d atmega4809 --fuses 0:0b00000000 2:0x01 6:0x04 7:0x00 8:0x00 -f $counterhexFileEscaped -a write -v"

    # Update the command textbox
    Update-CommandText $resetCommand

    # Run the reset command and capture the output
    $resetOutput = Invoke-Expression $resetCommand 2>&1 | Out-String -Stream
    Append-ConsoleOutput "Reset Command Output: $resetOutput"
# Check for specific errors, like UPDI initialization failure
    if ($output -match "UPDI init failed") {
        $statusLabel.Text = "[FAIL] UPDI Failed, please reseat the device in the programmer"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    } 
    if ($output -match "Device ID mismatch") {
        $statusLabel.Text = "[FAIL] Incorrect Logic Unit, insert $Logicdevicetype"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $statusLabel.Visible = $true
        return
    }
    if ($LASTEXITCODE -eq 0 -and $resetOutput -notmatch "error") {
        Show-Status $labelKey $true
        Log-RunDetails "Erase and Reset" $resetOutput
    } else {
        Show-Status $labelKey $false
    }
}

# Show the form
$form.ShowDialog()
