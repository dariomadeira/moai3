
$bytes = [System.IO.File]::ReadAllBytes('G:\moai_func\decomp\xuper4\unpacked\lib\arm64-v8a\libranger-jni.so')
$sb = New-Object System.Text.StringBuilder
$list = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $bytes.Length; $i++) {
    $b = $bytes[$i]
    if ($b -ge 32 -and $b -le 126) {
        [void]$sb.Append([char]$b)
    } else {
        if ($sb.Length -gt 4) {
            $s = $sb.ToString()
            if ($s -match "com/|Callback|JniHandler|NativeJni|PrepareProgram") {
                $list.Add($s)
            }
        }
        $sb.Clear()
    }
}

$list | Sort-Object -Unique | ForEach-Object { Write-Output $_ }
