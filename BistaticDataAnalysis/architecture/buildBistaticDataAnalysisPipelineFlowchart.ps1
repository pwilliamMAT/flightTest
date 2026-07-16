[CmdletBinding()]
param(
    [string]$OutputPath = '',
    [string]$PreviewPath = ''
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName office

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptRoot 'bistaticDataAnalysisPipelineFlowchart.pptx'
}

if ([string]::IsNullOrWhiteSpace($PreviewPath)) {
    $PreviewPath = Join-Path $scriptRoot 'bistaticDataAnalysisPipelineFlowchart.png'
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

        [double]$FontSize = 12
    )

    $shape = $Slide.Shapes.AddShape($ShapeType, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.Fill.Solid()
    $shape.Fill.ForeColor.RGB = $FillColor
    $shape.Line.ForeColor.RGB = $LineColor
    $shape.Line.Weight = 1.4

    $shape.TextFrame2.TextRange.Text = $Text
    $shape.TextFrame2.TextRange.Font.Name = 'Aptos'
    $shape.TextFrame2.TextRange.Font.Size = $FontSize
    $shape.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $FontColor
    $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = [Microsoft.Office.Core.MsoParagraphAlignment]::msoAlignCenter
    $shape.TextFrame2.VerticalAnchor = [Microsoft.Office.Core.MsoVerticalAnchor]::msoAnchorMiddle
    $shape.TextFrame2.WordWrap = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $shape.TextFrame.MarginLeft = 6
    $shape.TextFrame.MarginRight = 6
    $shape.TextFrame.MarginTop = 4
    $shape.TextFrame.MarginBottom = 4

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

        [double]$FontSize = 11,

        [bool]$Bold = $true
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
    if ($Bold) {
        $textBox.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue
    }
    else {
        $textBox.TextFrame2.TextRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoFalse
    }
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

        [double]$Weight = 2.0,

        [bool]$Dashed = $false
    )

    $line = $Slide.Shapes.AddLine($X1, $Y1, $X2, $Y2)
    $line.Line.ForeColor.RGB = $Color
    $line.Line.Weight = $Weight
    $line.Line.EndArrowheadStyle = [Microsoft.Office.Core.MsoArrowheadStyle]::msoArrowheadTriangle
    $line.Line.BeginArrowheadStyle = [Microsoft.Office.Core.MsoArrowheadStyle]::msoArrowheadNone

    if ($Dashed) {
        $line.Line.DashStyle = [Microsoft.Office.Core.MsoLineDashStyle]::msoLineDash
    }

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

    $backgroundColor = Get-RgbValue -Red 249 -Green 250 -Blue 252
    $titleColor = Get-RgbValue -Red 31 -Green 41 -Blue 55
    $subtitleColor = Get-RgbValue -Red 71 -Green 85 -Blue 105
    $borderColor = Get-RgbValue -Red 71 -Green 85 -Blue 105
    $connectorColor = Get-RgbValue -Red 107 -Green 114 -Blue 128
    $truthConnectorColor = Get-RgbValue -Red 124 -Green 58 -Blue 237
    $inputColor = Get-RgbValue -Red 32 -Green 78 -Blue 121
    $wrapperColor = Get-RgbValue -Red 11 -Green 94 -Blue 157
    $orchestratorColor = Get-RgbValue -Red 8 -Green 126 -Blue 139
    $processingColorA = Get-RgbValue -Red 72 -Green 92 -Blue 118
    $processingColorB = Get-RgbValue -Red 84 -Green 105 -Blue 127
    $processingColorC = Get-RgbValue -Red 100 -Green 116 -Blue 139
    $processingColorD = Get-RgbValue -Red 114 -Green 127 -Blue 149
    $detectionColor = Get-RgbValue -Red 217 -Green 119 -Blue 6
    $aggregateColor = Get-RgbValue -Red 180 -Green 83 -Blue 9
    $trackerColor = Get-RgbValue -Red 21 -Green 128 -Blue 61
    $outputColor = Get-RgbValue -Red 4 -Green 120 -Blue 87
    $truthInputColor = Get-RgbValue -Red 91 -Green 33 -Blue 182
    $truthColorA = Get-RgbValue -Red 109 -Green 40 -Blue 217
    $truthColorB = Get-RgbValue -Red 126 -Green 58 -Blue 242
    $truthColorC = Get-RgbValue -Red 139 -Green 92 -Blue 246
    $truthColorD = Get-RgbValue -Red 147 -Green 112 -Blue 219
    $whiteColor = Get-RgbValue -Red 255 -Green 255 -Blue 255

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

    Add-LabelBox `
        -Slide $slide `
        -Left 36 `
        -Top 16 `
        -Width 888 `
        -Height 32 `
        -Text 'BistaticDataAnalysis Active Pipeline' `
        -FontColor $titleColor `
        -FontSize 24 | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left 72 `
        -Top 48 `
        -Width 816 `
        -Height 18 `
        -Text 'Top-level entrypoint inside folder: runBistaticAnalysisSession.m' `
        -FontColor $subtitleColor `
        -FontSize 10 `
        -Bold $false | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left 28 `
        -Top 68 `
        -Width 420 `
        -Height 18 `
        -Text 'Mainline: IQ to Range-Doppler tracks' `
        -FontColor $subtitleColor `
        -FontSize 11 | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left 302 `
        -Top 280 `
        -Width 400 `
        -Height 18 `
        -Text 'Truth branch: ADS-B evaluation of detector outputs' `
        -FontColor $truthConnectorColor `
        -FontSize 11 | Out-Null

    $mainTop = 96
    $mainHeight = 82
    $mainGap = 6
    $mainStages = @(
        [pscustomobject]@{
            Key = 'session'
            Width = 90
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartData
            Text = "Session`ninputs"
            Fill = $inputColor
            FontColor = $whiteColor
            FontSize = 11
        }
        [pscustomobject]@{
            Key = 'wrapper'
            Width = 86
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "runBistatic`nAnalysis`nSession"
            Fill = $wrapperColor
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'orchestrator'
            Width = 112
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "analyzeBistaticData`n+ processOnePart"
            Fill = $orchestratorColor
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'iq'
            Width = 80
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = 'loadIQData'
            Fill = $processingColorA
            FontColor = $whiteColor
            FontSize = 10.5
        }
        [pscustomobject]@{
            Key = 'lag'
            Width = 100
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "checkRefQuality`n+ DPI lag"
            Fill = $processingColorB
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'clutter'
            Width = 108
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "mitigateClutter`n+ createRDM"
            Fill = $processingColorC
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'detector'
            Width = 110
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "NCI + whitening`n+ detectTargets"
            Fill = $detectionColor
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'aggregate'
            Width = 86
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "Aggregate`ndetections"
            Fill = $aggregateColor
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'tracker'
            Width = 120
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "trackTargets + init KF`n+ RD viewers"
            Fill = $trackerColor
            FontColor = $whiteColor
            FontSize = 10
        }
    )

    $mainTotalWidth = (($mainStages | Measure-Object -Property Width -Sum).Sum) + ($mainGap * ($mainStages.Count - 1))
    $currentLeft = [math]::Round((960 - $mainTotalWidth) / 2, 1)
    $mainShapes = @{}
    $mainOrder = @()

    foreach ($stage in $mainStages) {
        $shape = Add-FlowchartShape `
            -Slide $slide `
            -ShapeType $stage.ShapeType `
            -Left $currentLeft `
            -Top $mainTop `
            -Width $stage.Width `
            -Height $mainHeight `
            -Text $stage.Text `
            -FillColor $stage.Fill `
            -LineColor $borderColor `
            -FontColor $stage.FontColor `
            -FontSize $stage.FontSize

        $mainShapes[$stage.Key] = $shape
        $mainOrder += $stage.Key
        $currentLeft += $stage.Width + $mainGap
    }

    for ($k = 0; $k -lt ($mainOrder.Count - 1); $k++) {
        $src = $mainShapes[$mainOrder[$k]]
        $dst = $mainShapes[$mainOrder[$k + 1]]
        $srcY = $src.Top + ($src.Height / 2)
        $dstY = $dst.Top + ($dst.Height / 2)
        Add-ArrowLine `
            -Slide $slide `
            -X1 ($src.Left + $src.Width) `
            -Y1 $srcY `
            -X2 $dst.Left `
            -Y2 $dstY `
            -Color $connectorColor `
            -Weight 2.0 | Out-Null
    }

    $truthTop = 306
    $truthHeight = 70
    $truthGap = 12
    $assessWidth = 88
    $aggregateShape = $mainShapes['aggregate']
    $aggregateCenterX = $aggregateShape.Left + ($aggregateShape.Width / 2)
    $assessLeft = [math]::Round($aggregateCenterX - ($assessWidth / 2), 1)

    $truthStages = @(
        [pscustomobject]@{
            Key = 'truthInput'
            Width = 82
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartData
            Text = "ADS-B`ntruth files"
            Fill = $truthInputColor
            FontColor = $whiteColor
            FontSize = 10.25
        }
        [pscustomobject]@{
            Key = 'loadTruth'
            Width = 92
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "loadADSBTruth`n+ getRadarEpoch"
            Fill = $truthColorA
            FontColor = $whiteColor
            FontSize = 9.5
        }
        [pscustomobject]@{
            Key = 'projectTruth'
            Width = 82
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = 'adsbToBistatic'
            Fill = $truthColorB
            FontColor = $whiteColor
            FontSize = 10
        }
        [pscustomobject]@{
            Key = 'alignTruth'
            Width = 82
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "alignTruthTo`nRadar"
            Fill = $truthColorC
            FontColor = $whiteColor
            FontSize = 9.75
        }
        [pscustomobject]@{
            Key = 'assessTruth'
            Width = 88
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "assessTruthVs`nDetections"
            Fill = $truthColorD
            FontColor = $whiteColor
            FontSize = 9.75
        }
        [pscustomobject]@{
            Key = 'truthDiag'
            Width = 96
            ShapeType = [Microsoft.Office.Core.MsoAutoShapeType]::msoShapeFlowchartProcess
            Text = "runDetectionTruth`nDiagnostics"
            Fill = $truthColorA
            FontColor = $whiteColor
            FontSize = 9.0
        }
    )

    $truthShapes = @{}

    $assessStage = $truthStages | Where-Object { $_.Key -eq 'assessTruth' }
    $truthShapes['assessTruth'] = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType $assessStage.ShapeType `
        -Left $assessLeft `
        -Top $truthTop `
        -Width $assessStage.Width `
        -Height $truthHeight `
        -Text $assessStage.Text `
        -FillColor $assessStage.Fill `
        -LineColor $borderColor `
        -FontColor $assessStage.FontColor `
        -FontSize $assessStage.FontSize

    $rightTruthStage = $truthStages | Where-Object { $_.Key -eq 'truthDiag' }
    $truthShapes['truthDiag'] = Add-FlowchartShape `
        -Slide $slide `
        -ShapeType $rightTruthStage.ShapeType `
        -Left ($assessLeft + $assessStage.Width + $truthGap) `
        -Top $truthTop `
        -Width $rightTruthStage.Width `
        -Height $truthHeight `
        -Text $rightTruthStage.Text `
        -FillColor $rightTruthStage.Fill `
        -LineColor $borderColor `
        -FontColor $rightTruthStage.FontColor `
        -FontSize $rightTruthStage.FontSize

    $precedingKeys = @('truthInput', 'loadTruth', 'projectTruth', 'alignTruth')
    $nextLeft = $assessLeft - $truthGap

    for ($k = $precedingKeys.Count - 1; $k -ge 0; $k--) {
        $stageKey = $precedingKeys[$k]
        $stage = $truthStages | Where-Object { $_.Key -eq $stageKey }
        $left = $nextLeft - $stage.Width
        $truthShapes[$stageKey] = Add-FlowchartShape `
            -Slide $slide `
            -ShapeType $stage.ShapeType `
            -Left $left `
            -Top $truthTop `
            -Width $stage.Width `
            -Height $truthHeight `
            -Text $stage.Text `
            -FillColor $stage.Fill `
            -LineColor $borderColor `
            -FontColor $stage.FontColor `
            -FontSize $stage.FontSize
        $nextLeft = $left - $truthGap
    }

    $truthOrder = @('truthInput', 'loadTruth', 'projectTruth', 'alignTruth', 'assessTruth', 'truthDiag')
    for ($k = 0; $k -lt ($truthOrder.Count - 1); $k++) {
        $src = $truthShapes[$truthOrder[$k]]
        $dst = $truthShapes[$truthOrder[$k + 1]]
        $srcY = $src.Top + ($src.Height / 2)
        $dstY = $dst.Top + ($dst.Height / 2)
        Add-ArrowLine `
            -Slide $slide `
            -X1 ($src.Left + $src.Width) `
            -Y1 $srcY `
            -X2 $dst.Left `
            -Y2 $dstY `
            -Color $truthConnectorColor `
            -Weight 2.0 | Out-Null
    }

    $assessTruthShape = $truthShapes['assessTruth']
    Add-ArrowLine `
        -Slide $slide `
        -X1 $aggregateCenterX `
        -Y1 ($aggregateShape.Top + $aggregateShape.Height) `
        -X2 ($assessTruthShape.Left + ($assessTruthShape.Width / 2)) `
        -Y2 $assessTruthShape.Top `
        -Color $truthConnectorColor `
        -Weight 2.0 `
        -Dashed $true | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left ($aggregateCenterX - 70) `
        -Top 232 `
        -Width 140 `
        -Height 24 `
        -Text "detections`nfor evaluation" `
        -FontColor $truthConnectorColor `
        -FontSize 9.5 | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left 168 `
        -Top 462 `
        -Width 624 `
        -Height 18 `
        -Text 'Truth branch evaluates detector outputs; it does not feed back into detection generation.' `
        -FontColor $subtitleColor `
        -FontSize 9 `
        -Bold $false | Out-Null

    Add-LabelBox `
        -Slide $slide `
        -Left 120 `
        -Top 494 `
        -Width 720 `
        -Height 18 `
        -Text 'Source: runBistaticAnalysisSession, analyzeBistaticData, processOnePart, trackTargets, and ADS-B truth evaluation helpers' `
        -FontColor $subtitleColor `
        -FontSize 8.5 `
        -Bold $false | Out-Null

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
