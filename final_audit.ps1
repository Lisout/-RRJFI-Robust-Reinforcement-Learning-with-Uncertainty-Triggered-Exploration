param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()
$passes = [System.Collections.Generic.List[string]]::new()

function Check {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:passes.Add($Message)
    } else {
        $script:failures.Add($Message)
    }
}

function Number {
    param([object]$Value)
    return [double]::Parse(
        [string]$Value,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Check-Near {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )
    Check ([math]::Abs($Actual - $Expected) -le $Tolerance) (
        '{0} (actual={1:G12}, expected={2:G12})' -f $Message, $Actual, $Expected
    )
}

function Metric-Row {
    param(
        [object[]]$Rows,
        [hashtable]$Keys
    )
    $selected = @($Rows | Where-Object {
        $row = $_
        foreach ($key in $Keys.Keys) {
            if ([string]$row.$key -ne [string]$Keys[$key]) {
                return $false
            }
        }
        return $true
    })
    Check ($selected.Count -eq 1) ('Unique metric row: ' + (($Keys.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))
    if ($selected.Count -ne 1) {
        throw 'Metric row was not unique.'
    }
    return $selected[0]
}

function Audit-DisplayMath {
    param([string]$Path)
    $lines = [System.IO.File]::ReadAllLines($Path)
    $open = $false
    $start = 0
    $content = @()
    $blockCount = 0
    $punctuation = [System.Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s*(?:>\s*)?\$\$\s*$') {
            if (-not $open) {
                $open = $true
                $start = $index + 1
                $content = @()
            } else {
                $blockCount++
                $meaningful = @(
                    $content |
                        ForEach-Object { $_ -replace '^\s*>\s?', '' } |
                        Where-Object { $_.Trim().Length -gt 0 -and $_ -notmatch '^\\(?:tag|label)\{' }
                )
                if ($meaningful.Count -gt 0) {
                    $last = $meaningful[-1].Trim()
                    if ($last -match '[,.;:，。；：]\s*$') {
                        $punctuation.Add("line $start ends with '$last'")
                    }
                }
                $open = $false
            }
            continue
        }
        if ($open) {
            $content += $line
        }
    }

    return [pscustomobject]@{
        Blocks = $blockCount
        Balanced = -not $open
        TerminalPunctuation = $punctuation
    }
}

$resultsRoot = Join-Path $ProjectRoot '05_results'
$manuscriptRoot = Join-Path $ProjectRoot '08_manuscript_stage'
$responseRoot = Join-Path $ProjectRoot '09_response_stage'
$manuscript = Join-Path $manuscriptRoot 'clean_manuscript.md'

# E1 observer results.
$e1 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E1_observer_summary.csv')
Check-Near (Number (Metric-Row $e1 @{Metric='containmentRate'}).Mean) 1 1e-12 'E1 state containment'
Check-Near (Number (Metric-Row $e1 @{Metric='delayRetentionRate'}).Mean) 1 1e-12 'E1 true-delay retention'
Check-Near (Number (Metric-Row $e1 @{Metric='rewardWidthReduction'}).Mean) 0.491937123852557 1e-12 'E1 reward-width reduction'
Check-Near (Number (Metric-Row $e1 @{Metric='meanHullExcess'}).Mean) 0.000119811063584888 1e-15 'E1 mean hull excess'

# E2 paired controller comparison.
$e2 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E2_control_summary.csv')
$e2Tests = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E2_control_paired_tests.csv')
Check-Near (Number (Metric-Row $e2 @{task='tracking';method='proposed';metric='trackingRmse'}).mean) 0.137253481421193 1e-12 'E2 proposed tracking RMSE'
Check-Near (Number (Metric-Row $e2 @{task='tracking';method='maddpg';metric='trackingRmse'}).mean) 0.149254065758005 1e-12 'E2 MADDPG tracking RMSE'
Check-Near (Number (Metric-Row $e2 @{task='stabilization';method='pid';metric='trackingRmse'}).mean) 0.12500303547474 1e-12 'E2 PID stabilization RMSE'
Check ((Number (Metric-Row $e2Tests @{task='tracking';competitor='maddpg';metric='trackingRmse'}).signrankP) -lt 0.01) 'E2 paired tracking comparison is significant versus MADDPG'

# E3 selective exploration.
$e3 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E3_iebpu_summary.csv')
Check-Near (Number (Metric-Row $e3 @{variant='full';metric='activationRatio'}).mean) 0.3055 1e-12 'E3 full-gate activation ratio'
Check-Near (Number (Metric-Row $e3 @{variant='full';metric='explorationEnergy'}).mean) 57.2250903485806 1e-10 'E3 full-gate energy'
Check-Near (Number (Metric-Row $e3 @{variant='continuous';metric='explorationEnergy'}).mean) 187.470657091566 1e-10 'E3 continuous-exploration energy'
Check-Near (Number (Metric-Row $e3 @{variant='full';metric='minimumInterOnsetTime'}).minimum) 0.8 1e-12 'E3 observed minimum inter-onset time'

# E4 recovery and certificate withdrawal.
$e4 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E4_recovery_raw_metrics.csv')
foreach ($expectation in @(
    @{variant='certifiedRecovery';violations=0},
    @{variant='robustOnly';violations=18},
    @{variant='pointOnly';violations=11}
)) {
    $rows = @($e4 | Where-Object variant -eq $expectation.variant)
    $violations = @($rows | Where-Object { (Number $_.anySafetyViolation) -gt 0 }).Count
    Check ($rows.Count -eq 20 -and $violations -eq $expectation.violations) (
        "E4 $($expectation.variant) violations=$violations/20"
    )
}
$withdrawal = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E4_domain_withdrawal.csv')
Check ($withdrawal.Count -eq 12) 'E4 out-of-domain diagnostic has 12 runs'
Check-Near (($withdrawal | ForEach-Object { Number $_.withdrawalTime } | Measure-Object -Minimum).Minimum) 0.2 1e-12 'E4 minimum withdrawal time'
Check-Near (($withdrawal | ForEach-Object { Number $_.withdrawalTime } | Measure-Object -Maximum).Maximum) 1.9 1e-12 'E4 maximum withdrawal time'

# E5--E7 scaling and frozen-policy certificate.
$e5 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E5_representation_ablation.csv')
Check-Near (Number (Metric-Row $e5 @{dimension='48'}).onlineHeldOutMse) 0.0168581022166611 1e-14 'E5 dimension-48 online held-out MSE'
$e6 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E6_scalability_summary.csv')
$e6n200 = Metric-Row $e6 @{numAgents='200'}
Check-Near (Number $e6n200.meanEndToEndMicroseconds) 5318.68188235294 1e-8 'E6 N=200 complete-step time'
Check-Near (Number $e6n200.minimumContainmentRate) 1 1e-12 'E6 minimum containment at N=200'
$e7 = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E7_certificate_summary.csv')
$e7Audit = Import-Csv -LiteralPath (Join-Path $resultsRoot 'E7_certificate_constraint_generation.csv')
Check ((Number $e7.totalEnumeratedModes) -eq 110592) 'E7 enumerates 110,592 endpoint-delay modes'
Check-Near (Number $e7Audit.fullBoxContraction) 0.991233929476804 1e-12 'E7 worst common-P contraction'
Check ((Number $e7Audit.fullBoxContraction) -lt 1) 'E7 common-P contraction is below one'

# Manuscript claims and formatting.
$manuscriptText = [System.IO.File]::ReadAllText($manuscript)
foreach ($claim in @('49.19%', '69.5%', '110,592', '0.9912339', '5.319 ms', '0.8 s', '18 and 11 runs', '[0.024,0.024]^{\mathsf T}', 'dynamic internal-state trigger')) {
    Check ($manuscriptText.Contains($claim)) "Manuscript contains audited claim '$claim'"
}
Check (-not [regex]::IsMatch($manuscriptText, '(?i)\bprop(?:o|s)sition\b')) 'Manuscript contains no proposition/propsition construct'
Check (-not [regex]::IsMatch($manuscriptText, '(?<!\\)qquad')) 'No missing backslash before qquad'
Check (-not [regex]::IsMatch($manuscriptText, '\bA[1-5]\b')) 'Assumptions are not abbreviated as A1--A5'
Check ([regex]::Matches($manuscriptText, '(?m)^### 4\.').Count -eq 3) 'Simulation has exactly three numbered subsections'

$figureRoot = Join-Path $ProjectRoot '06_figures'
$requiredFigures = @(
    'workflow_complete_algorithm.fig', 'training_curves.fig',
    'E1_observer_and_hull.fig', 'E2_controller_comparison.fig',
    'E3_iebpu_trigger.fig', 'E3_iebpu_variants.fig',
    'E4_recovery_and_withdrawal.fig', 'E5_representation_ablation.fig',
    'E6_scalability.fig', 'E7_common_lyapunov_certificate.fig'
)
foreach ($figureName in $requiredFigures) {
    Check (Test-Path -LiteralPath (Join-Path $figureRoot $figureName)) "Editable figure exists: $figureName"
}

$highlightTex = [System.IO.File]::ReadAllText((Join-Path $manuscriptRoot 'highlight_manuscript.tex'))
Check ($highlightTex.Contains('\sethlcolor{yellow}')) 'Highlight LaTeX explicitly selects yellow'
Check ([regex]::Matches($highlightTex, '\\hl\{').Count -gt 1000) 'Highlight LaTeX contains extensive real hl commands'

$documentFiles = @(
    $manuscript,
    (Join-Path $manuscriptRoot 'highlight_manuscript.md'),
    (Join-Path $responseRoot 'Response_All_English.md'),
    (Join-Path $responseRoot 'Response_All_Chinese.md'),
    (Join-Path $responseRoot 'Response_CN_With_EN_Manuscript.md')
)
foreach ($document in $documentFiles) {
    $mathAudit = Audit-DisplayMath $document
    Check $mathAudit.Balanced "$([System.IO.Path]::GetFileName($document)) has balanced display-math delimiters"
    Check ($mathAudit.TerminalPunctuation.Count -eq 0) "$([System.IO.Path]::GetFileName($document)) has no display equation ending in punctuation"

    $text = [System.IO.File]::ReadAllText($document)
    $imageMatches = [regex]::Matches($text, '!\[[^\]]*\]\(([^)]+)\)')
    $missingImages = @()
    foreach ($match in $imageMatches) {
        $imagePath = $match.Groups[1].Value
        if ($imagePath -notmatch '^(?:https?://|[A-Za-z]:\\)') {
            $imagePath = Join-Path ([System.IO.Path]::GetDirectoryName($document)) $imagePath
        }
        if (-not (Test-Path -LiteralPath $imagePath)) {
            $missingImages += $imagePath
        }
    }
    Check ($missingImages.Count -eq 0) "$([System.IO.Path]::GetFileName($document)) has no missing image"
}

# The three requested Typora response structures.
foreach ($name in @('Response_All_English.md','Response_All_Chinese.md','Response_CN_With_EN_Manuscript.md')) {
    $path = Join-Path $responseRoot $name
    $text = [System.IO.File]::ReadAllText($path)
    $caution = [regex]::Matches($text, '(?m)^> \[!CAUTION\]\r?$').Count
    $note = [regex]::Matches($text, '(?m)^> \[!NOTE\]\r?$').Count
    $response = [regex]::Matches($text, '(?m)^\*\*(?:Response to the comment|对审稿意见的回复)\*\*\r?$').Count
    Check ($caution -eq 38 -and $response -eq 38 -and $note -eq 38) "$name contains 38 Caution/plain-response/Note triplets"
}

$manifest = Import-Csv -LiteralPath (Join-Path $responseRoot 'response_item_manifest.csv')
$expectedCounts = @{1=5;2=5;4=6;5=6;7=10;9=6}
Check ($manifest.Count -eq 38) 'Response manifest contains 38 unique comments'
foreach ($reviewer in $expectedCounts.Keys) {
    Check (@($manifest | Where-Object reviewer -eq ([string]$reviewer)).Count -eq $expectedCounts[$reviewer]) "Reviewer $reviewer response count"
}
Check (@($manifest | Group-Object pid | Where-Object Count -ne 1).Count -eq 0) 'Every source comment paragraph is used exactly once'

$responseTex = [System.IO.File]::ReadAllText((Join-Path $responseRoot 'review_response.tex'))
Check ([regex]::Matches($responseTex, '\\begin\{revcomment\}').Count -eq 38) 'Response LaTeX contains 38 reviewer-comment boxes'
Check ([regex]::Matches($responseTex, '\\begin\{revresponse\}').Count -eq 38) 'Response LaTeX contains 38 response boxes'
Check ([regex]::Matches($responseTex, '\\begin\{changes\}').Count -eq 38) 'Response LaTeX contains 38 manuscript-change boxes'

$byReviewerRoot = Join-Path $responseRoot 'ByReviewer'
foreach ($reviewer in $expectedCounts.Keys) {
    $reviewerRoot = Join-Path $byReviewerRoot "R$reviewer"
    $reviewerFiles = @(Get-ChildItem -LiteralPath $reviewerRoot -Filter '*.md' -File)
    $valid = $reviewerFiles.Count -eq 3
    foreach ($file in $reviewerFiles) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $caution = [regex]::Matches($text, '(?m)^> \[!CAUTION\]\r?$').Count
        $note = [regex]::Matches($text, '(?m)^> \[!NOTE\]\r?$').Count
        $valid = $valid -and $caution -eq $expectedCounts[$reviewer] -and $note -eq $expectedCounts[$reviewer]
    }
    Check $valid "Reviewer $reviewer has three complete standalone language variants"
}

# Compiled deliverables and critical log scan.
$compiled = @(
    (Join-Path $manuscriptRoot 'revised_manuscript.pdf'),
    (Join-Path $manuscriptRoot 'highlight_manuscript.pdf'),
    (Join-Path $responseRoot 'review_response.pdf')
)
foreach ($path in $compiled) {
    Check ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -gt 10000) "$([System.IO.Path]::GetFileName($path)) exists and is nonempty"
}
foreach ($log in @(
    (Join-Path $manuscriptRoot 'revised_manuscript.log'),
    (Join-Path $manuscriptRoot 'highlight_manuscript.log'),
    (Join-Path $responseRoot 'review_response.log')
)) {
    $critical = Select-String -LiteralPath $log -Pattern 'LaTeX Error|Undefined control sequence|Fatal error|multiply defined|destination with the same identifier|There were undefined references|Citation.*undefined'
    Check (@($critical).Count -eq 0) "$([System.IO.Path]::GetFileName($log)) has no critical compilation warning"
}

Write-Output ('AUDIT_PASSED={0}' -f $passes.Count)
Write-Output ('AUDIT_FAILED={0}' -f $failures.Count)
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output ('FAIL: ' + $_) }
    exit 1
}
Write-Output 'FINAL_AUDIT_OK'
