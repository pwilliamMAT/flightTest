[CmdletBinding()]
param(
    [string]$OutputPath = '',
    [string]$PreviewPath = ''
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName office

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptRoot 'coordinatedCaptureAnalysisFlowchart.pptx'
}

if ([string]::IsNullOrWhiteSpace($PreviewPath)) {
    $PreviewPath = Join-Path $scriptRoot 'coordinatedCaptureAnalysisFlowchart.png'
}

function Get-RgbValue {
    param(
        [int]$Red,
        [int]$Green,
        [int]$Blue
    )

    return $Red + ($Green -shl 8) + ($Blue -shl 16)
}

function Add-FlowchartShape {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Slide,

        [Parameter(Mandatory = $true)]
        [Microsoft.Office.Core.MsoAutoShapeType]$ShapeType,

        [Parameter(Mandatory = $true)]
        [double]$Left,

        [Parameter(Mandatory = $true)]
        [double]$Top,

        [Parameter(Mandatory = $true)]
        [double]$Width,

        [Parameter(Mandatory = $true)]
        [double]$Height,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$FillColor,

        [Parameter(Mandatory = $true)]
        [int]$LineColor,

        [Parameter(Mandatory = $true)]
        [int]$FontColor,

        [double]$FontSize = 14
    )

    $shape = $Slide.Shapes.AddShape($ShapeType, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.Fill.Solid()
    $shape.Fill.ForeColor.RGB = $FillColor
    $shape.Line.ForeColor.RGB = $LineColor
    $shape.Line.Weight = 1.5

    $shape.TextFrame2.TextRange.Text = $Text
    $shape.TextFrame2.TextRange.Font.Name = 'Aptos'
    $shape.TextFrame2.TextRange.Font.Size = $FontSize
    $shape.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $FontColor
    $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = [Microsoft.Office.Core.MsoParagraphAlignment]::msoAlignCenter
    $shape.TextFrame2.VerticalAnchor = [Microsoft.Office.Core.MsoVerticalAnchor]::msoAnchorMiddle
    $shape.TextFrame2.WordWrap = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.TextFrame.MarginLeft = 8
    $shape.TextFrame.MarginRight = 8
    $shape.TextFrame.MarginTop = 6
    $shape.TextFrame.MarginBottom = 6

    return $shape
}

function Add-LabelBox {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Slide,

        [Parameter(Mandatory = $true)]
        [double]$Left,

        [Parameter(Mandatory = $true)]
        [double]$Top,

        [Parameter(Mandatory = $true)]
        [double]$Width,

        [Parameter(Mandatory = $true)]
        [double]$Height,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$FontColor,

        [double]$FontSize = 11
    )

    $textBox = $Slide.Shapes.AddTextbox(
        [Microsoft.Office.Core.MsoTextOrientation]::msoTextOrientationHorizontal,
        $Left,
        $Top,
        $Width,
        $Height
    )

    $textBox.TextFrame2.TextRange.Text = $Text
    $textBox.TextFrame2.TextRange.Font.Name = 'Aptos'
    $textBox.TextFrame2.TextRange.Font.Size = $FontSize
    $textBox.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $textBox.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $FontColor
    $textBox.TextFrame2.TextRange.ParagraphFormat.Alignment = [Microsoft.Office.Core.MsoParagraphAlignment]::msoAlignCenter
    $textBox.TextFrame2.VerticalAnchor = [Microsoft.Office.Core.MsoVerticalAnchor]::msoAnchorMiddle
    $textBox.Line.Visible = [Microsoft.Office.Core.MsoTriState]::msoFalse
    $textBox.Fill.Visible = [Microsoft.Office.Core.MsoTriState]::msoFalse

    return $textBox
}

function Add-ArrowLine {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Slide,

        [Parameter(Mandatory = $true)]
        [double]$X1,

        [Parameter(Mandatory = $true)]
        [double]$Y1,

        [Parameter(Mandatory = $true)]
        [double]$X2,

        [Parameter(Mandatory = $true)]
        [double]$Y2,

        [Parameter(Mandatory = $true)]
        [int]$Color,

        [double]$Weight = 2.25
    )

    $line = $Slide.Shapes.AddLine($X1, $Y1, $X2, $Y2)
    $line.Line.ForeColor.RGB = $Color
    $line.Line.Weight = $Weight
    $line.Line.EndArrowheadStyle = [Microsoft.Office.Core.MsoArrowheadStyle]::msoArrowheadTriangle
    $line.Line.BeginArrowheadStyle = [Microsoft.Office.Core.MsoArrowheadStyle]::msoArrowheadNone

    return $line
}

function Ensure-ParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parentPath = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parentPath) -and -not (Test-Path -LiteralPath $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath | Out-Null
    }
}

$powerPoint = $null
$presentation = $null
$slide = $null

try {
    Ensure-ParentDirectory -Path $OutputPath
    Ensure-ParentDirectory -Path $PreviewPath

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    if (Test-Path -LiteralPath $PreviewPath) {
        Remove-Item -LiteralPath $PreviewPath -Force
    }

    $backgroundColor = Get-RgbValue -Red 250 -Green 251 -Blue 252
    $titleColor = Get-RgbValue -Red 31 -Green 41 -Blue 55
    $borderColor = Get-RgbValue -Red 71 -Green 85 -Blue 105
    $connectorColor = Get-RgbValue -Red 107 -Green 114 -Blue 128
    $testingMachineColor = Get-RgbValue -Red 31 -Green 78 -Blue 121
    $raspberryPiColor = Get-RgbValue -Red 178 -Green 58 -Blue 72
    $usrpColor = Get-RgbValue -Red 92 -Green 103 -Blue 112
    $developmentComputerColor = Get-RgbValue -Red 15 -Green 118 -Blue 110
    $matlabAnalysisColor = Get-RgbValue -Red 217 -Green 119 -Blue 6
    $decisionColor = Get-RgbValue -Red 242 -Green 193 -Blue 78
    $successColor = Get-RgbValue -Red 46 -Green 139 -Blue 87
    $retryColor = Get-RgbValue -Red 196 -Green 69 -Blue 54
    $whiteColor = Get-RgbValue -Red 255 -Green 255 -Blue 255
    $decisionTextColor = Get-RgbValue -Red 69 -Green 45 -Blue 13

    $powerPoint = New-Object -ComObject PowerPoint.Application
    $presentation = $powerPoint.Presentations.Add()
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540

    while ($presentation.Slides.Count -gt 0) {
        $presentation.Slides.Item(1).Delete()
    }

    $slide = $presentation.Slides.Add(1, 12)
    $slide.FollowMasterBackground = [Microsoft.Office.Core.MsoTriState]::msoFalse
    $slide.Background.Fill.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $slide.Background.Fill.Solid()
    $slide.Background.Fill.ForeColor.RGB = $backgroundColor

    $titleBox = Add-LabelBox `
        -Slide $slide `
        -Left 36 `
        -Top 18 `
        -Width 888 `
        -Height 32 `
        -Text 'Coordinated Capture to MATLAB Analysis' `
        -FontColor $titleColor `
        -FontSize 24

    $titleBox.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue

    $shapeTop = 122
    $shapeHeight = 86
    $boxOneLeft = 34
    $boxOneWidth = 120
    $boxTwoLeft = 170
    $boxTwoWidth = 120
    $boxThreeLeft = 306
    $boxThreeWidth = 96
    $boxFourLeft = 418
    $boxFourWidth = 132
    $boxFiveLeft = 566
    $boxFiveWidth = 120
    $decisionLeft = 702
    $decisionSize = 100
    $successLeft = 818
    $successWidth = 120

    $testingMachine = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $boxOneLeft `
        -Top $shapeTop `
        -Width $boxOneWidth `
        -Height $shapeHeight `
        -Text "Testing Machine`nPC`nStart capture" `
        -FillColor $testingMachineColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $raspberryPi = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $boxTwoLeft `
        -Top $shapeTop `
        -Width $boxTwoWidth `
        -Height $shapeHeight `
        -Text "Raspberry Pi`nLog ADS-B`n+ GPS" `
        -FillColor $raspberryPiColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $usrp = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $boxThreeLeft `
        -Top $shapeTop `
        -Width $boxThreeWidth `
        -Height $shapeHeight `
        -Text "USRP`nRecord IQ" `
        -FillColor $usrpColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $developmentComputer = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $boxFourLeft `
        -Top $shapeTop `
        -Width $boxFourWidth `
        -Height $shapeHeight `
        -Text "Development`nComputer`nSync session" `
        -FillColor $developmentComputerColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $matlabAnalysis = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $boxFiveLeft `
        -Top $shapeTop `
        -Width $boxFiveWidth `
        -Height $shapeHeight `
        -Text "MATLAB Analysis`nRun precheck" `
        -FillColor $matlabAnalysisColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $decision = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartDecision) `
        -Left $decisionLeft `
        -Top $shapeTop `
        -Width $decisionSize `
        -Height $decisionSize `
        -Text 'Pass' `
        -FillColor $decisionColor `
        -LineColor $borderColor `
        -FontColor $decisionTextColor `
        -FontSize 13

    $fullAnalysis = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left $successLeft `
        -Top $shapeTop `
        -Width $successWidth `
        -Height $shapeHeight `
        -Text "Run full`nanalysis" `
        -FillColor $successColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $retryBox = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType ([Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess) `
        -Left 676 `
        -Top 306 `
        -Width 152 `
        -Height 72 `
        -Text "Retune or`nrecollect" `
        -FillColor $retryColor `
        -LineColor $borderColor `
        -FontColor $whiteColor `
        -FontSize 13

    $centerY = $shapeTop + ($shapeHeight / 2)
    $decisionCenterY = $shapeTop + ($decisionSize / 2)
    $decisionCenterX = $decisionLeft + ($decisionSize / 2)

    Add-ArrowLine -Slide $slide -X1 ($boxOneLeft + $boxOneWidth) -Y1 $centerY -X2 $boxTwoLeft -Y2 $centerY -Color $connectorColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 ($boxTwoLeft + $boxTwoWidth) -Y1 $centerY -X2 $boxThreeLeft -Y2 $centerY -Color $connectorColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 ($boxThreeLeft + $boxThreeWidth) -Y1 $centerY -X2 $boxFourLeft -Y2 $centerY -Color $connectorColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 ($boxFourLeft + $boxFourWidth) -Y1 $centerY -X2 $boxFiveLeft -Y2 $centerY -Color $connectorColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 ($boxFiveLeft + $boxFiveWidth) -Y1 $centerY -X2 $decisionLeft -Y2 $decisionCenterY -Color $connectorColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 ($decisionLeft + $decisionSize) -Y1 $decisionCenterY -X2 $successLeft -Y2 $centerY -Color $successColor | Out-Null
    Add-ArrowLine -Slide $slide -X1 $decisionCenterX -Y1 ($shapeTop + $decisionSize) -X2 $decisionCenterX -Y2 306 -Color $retryColor | Out-Null

    Add-LabelBox -Slide $slide -Left 784 -Top 102 -Width 40 -Height 18 -Text 'Yes' -FontColor $successColor -FontSize 11 | Out-Null
    Add-LabelBox -Slide $slide -Left 770 -Top 246 -Width 36 -Height 18 -Text 'No' -FontColor $retryColor -FontSize 11 | Out-Null

    $footer = Add-LabelBox `
        -Slide $slide `
        -Left 36 `
        -Top 492 `
        -Width 888 `
        -Height 20 `
        -Text 'Source: coordinated capture, session sync, and direct-path precheck workflow' `
        -FontColor $connectorColor `
        -FontSize 9

    $footer.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoFalse

    $presentation.SaveAs($OutputPath)
    $slide.Export($PreviewPath, 'PNG', 1920, 1080)

    Write-Output "Created PowerPoint: $OutputPath"
    Write-Output "Created Preview: $PreviewPath"
}
finally {
    if ($presentation -ne $null) {
        $presentation.Close()
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation) | Out-Null
    }

    if ($slide -ne $null) {
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($slide) | Out-Null
    }

    if ($powerPoint -ne $null) {
        $powerPoint.Quit()
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($powerPoint) | Out-Null
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
