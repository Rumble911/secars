<#
SecARS - M2 functional checks (API part of docs/M2/M2_FunctionalTests.md)

Before running:
  1. Oracle is running and the backend is up on http://localhost:8080.
  2. Run scripts\m2_db_checks.sql section 1 first (objects must be VALID).
  3. Use a fresh seed for a clean run. Test T04 locks student1 for 15 minutes;
     unlock it with section 6 of scripts\m2_db_checks.sql before running again.

Run from the secars folder:
  powershell -ExecutionPolicy Bypass -File .\scripts\m2_api_checks.ps1

Passwords: taken from the DEMO_*_PW environment variables if they are set,
otherwise typed at the prompt. They are never written to disk.

Output: docs\M2\results\m2_run_<date_time>.csv
Rows marked MANUAL need the browser and are listed at the end of the run.
#>
param(
  [string]$Base = 'http://localhost:8080',
  [string]$Tester = 'SR14'
)

$ErrorActionPreference = 'Continue'
$rows = New-Object System.Collections.Generic.List[object]

# ---------------------------------------------------------------- helpers
function Pass([string]$d) { return @{ Ok = $true;  Detail = $d } }
function Fail([string]$d) { return @{ Ok = $false; Detail = $d } }
function Skip([string]$d) { return @{ Ok = $null;  Detail = $d } }

function Record([string]$id, [string]$title, [string]$result, [string]$detail) {
  $rows.Add([pscustomobject]@{
    ID = $id; Test = $title; Result = $result; Detail = $detail
    Date = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Tester = $Tester
  })
  $color = 'Yellow'
  if ($result -eq 'PASS') { $color = 'Green' }
  if ($result -eq 'FAIL') { $color = 'Red' }
  Write-Host ('{0,-4} {1,-7} {2}' -f $id, $result, $detail) -ForegroundColor $color
}

function Check([string]$id, [string]$title, [scriptblock]$test) {
  try {
    $r = & $test
    if ($r.Ok -eq $true)      { Record $id $title 'PASS' $r.Detail }
    elseif ($r.Ok -eq $false) { Record $id $title 'FAIL' $r.Detail }
    else                      { Record $id $title 'SKIP' $r.Detail }
  } catch {
    Record $id $title 'FAIL' ('exception: ' + $_.Exception.Message)
  }
}

function Manual([string]$id, [string]$title, [string]$how) {
  Record $id $title 'MANUAL' $how
}

function New-Client {
  return [pscustomobject]@{
    Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    Header  = $null
    Token   = $null
  }
}

function Invoke-Api {
  param($Client, [string]$Method, [string]$Path, $Body = $null, [switch]$NoCsrf)
  $p = @{
    Uri = ($Base + $Path); Method = $Method; WebSession = $Client.Session
    UseBasicParsing = $true; Headers = @{}
  }
  if ($Method -ne 'GET' -and -not $NoCsrf -and $Client.Header) {
    $p.Headers[$Client.Header] = $Client.Token
  }
  if ($null -ne $Body) {
    $p.Body = ($Body | ConvertTo-Json -Compress)
    $p.ContentType = 'application/json'
  }
  try {
    $resp = Invoke-WebRequest @p
    $json = $null
    if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ Status = [int]$resp.StatusCode; Json = $json }
  } catch {
    $status = 0
    $raw = $null
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    if ($_.ErrorDetails) { $raw = $_.ErrorDetails.Message }
    if (-not $raw -and $_.Exception.Response -and ($_.Exception.Response | Get-Member -Name GetResponseStream)) {
      $raw = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
    }
    $json = $null
    if ($raw) { try { $json = $raw | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ Status = $status; Json = $json }
  }
}

function Login-As($Client, [string]$User, [string]$Password) {
  $r = Invoke-Api $Client 'POST' '/api/auth/login' @{ username = $User; password = $Password }
  if ($r.Status -ne 200) { return $false }
  $c = Invoke-Api $Client 'GET' '/api/auth/csrf'
  $Client.Header = $c.Json.headerName
  $Client.Token  = $c.Json.token
  return $true
}

function Get-Secret([string]$User, [string]$EnvName) {
  $v = [Environment]::GetEnvironmentVariable($EnvName)
  if ($v) { return $v }
  $s = Read-Host ('Password for ' + $User) -AsSecureString
  return [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

function Status-Ok($r, [int]$code) { return ($r.Status -eq $code) }

# ---------------------------------------------------------------- setup
Write-Host "Backend: $Base" -ForegroundColor Cyan
$pw = @{
  student1   = Get-Secret 'student1'   'DEMO_STUDENT_PW'
  lecturer1  = Get-Secret 'lecturer1'  'DEMO_LECTURER_PW'
  registrar1 = Get-Secret 'registrar1' 'DEMO_REGISTRAR_PW'
  registrar2 = Get-Secret 'registrar2' 'DEMO_REGISTRAR2_PW'
  auditor1   = Get-Secret 'auditor1'   'DEMO_AUDITOR_PW'
}

$anon    = New-Client
$anon2   = New-Client
$student = New-Client
$lect    = New-Client
$reg1    = New-Client
$reg2    = New-Client
$aud     = New-Client

# ================================================================ A. AUTH
Write-Host "`n== A. Authentication ==" -ForegroundColor Cyan

Check 'T01' 'Database health' {
  $r = Invoke-Api $anon 'GET' '/api/health/db'
  if ($r.Status -eq 200 -and $r.Json.database -eq 'UP') { return (Pass 'HTTP 200, database UP') }
  return (Fail "HTTP $($r.Status)")
}

Check 'T03' 'Wrong password gives the generic message' {
  $r = Invoke-Api $anon 'POST' '/api/auth/login' @{ username = 'student1'; password = 'WrongPass123' }
  if ($r.Status -eq 401 -and $r.Json.error -eq 'Invalid username or password') {
    return (Pass 'HTTP 401, message "Invalid username or password"')
  }
  return (Fail "HTTP $($r.Status), error '$($r.Json.error)'")
}

Check 'T02' 'Login as student1 returns ROLE_STUDENT' {
  if (-not (Login-As $student 'student1' $pw.student1)) { return (Fail 'login refused (check the password)') }
  $me = Invoke-Api $student 'GET' '/api/auth/me'
  if ($me.Json.role -eq 'ROLE_STUDENT') {
    return (Pass '/api/auth/me = ROLE_STUDENT (redirect to /student: check in the browser)')
  }
  return (Fail "role was '$($me.Json.role)'")
}

Check 'T10' 'Student cannot call a lecturer endpoint' {
  $r = Invoke-Api $student 'GET' '/api/lecturer/offerings'
  if ($r.Status -eq 403) { return (Pass 'HTTP 403') }
  return (Fail "HTTP $($r.Status)")
}

# ---- setup other roles (logins reset the failure counter)
$lectOk = Login-As $lect 'lecturer1'  $pw.lecturer1
$reg1Ok = Login-As $reg1 'registrar1' $pw.registrar1
$reg2Ok = Login-As $reg2 'registrar2' $pw.registrar2
$audOk  = Login-As $aud  'auditor1'   $pw.auditor1
Write-Host ("Logins: lecturer1={0} registrar1={1} registrar2={2} auditor1={3}" -f $lectOk, $reg1Ok, $reg2Ok, $audOk) -ForegroundColor Gray

# ================================================================ B. LECTURER
Write-Host "`n== B. Lecturer ==" -ForegroundColor Cyan

$ownList = @()
$own     = $null
$row     = $null
$otherId = $null
try {
  $ownList = @((Invoke-Api $lect 'GET' '/api/lecturer/offerings').Json)
  $own = $ownList | Where-Object { $_.status -eq 'OPEN' } | Select-Object -First 1
  if ($own) {
    $row = @((Invoke-Api $lect 'GET' "/api/lecturer/offerings/$($own.offering_id)/grades").Json) | Select-Object -First 1
  }
  $ownIds = @($ownList | ForEach-Object { $_.offering_id })
  $regAll = @((Invoke-Api $reg1 'GET' '/api/registrar/offerings').Json)
  $otherId = ($regAll | Where-Object { $ownIds -notcontains $_.offering_id } | Select-Object -First 1).offering_id
} catch {
  Write-Host ('setup (lecturer): ' + $_.Exception.Message) -ForegroundColor Yellow
}

Manual 'T11' 'Lecturer sees only own sections' `
  "Open /lecturer as lecturer1 and confirm every row is a section you teach (API returned $($ownList.Count) rows)"

Check 'T06' 'Changing a grade without CSRF header is refused' {
  if (-not $row) { return (Fail 'no OPEN section with students for lecturer1') }
  $r = Invoke-Api $lect 'PUT' "/api/lecturer/enrollments/$($row.enrollment_id)/grade" @{ grade = 50 } -NoCsrf
  if ($r.Status -eq 403) { return (Pass 'HTTP 403 without CSRF header') }
  return (Fail "HTTP $($r.Status)")
}

Check 'T13' 'Lecturer enters a grade in an OPEN section' {
  if (-not $row) { return (Fail 'no OPEN section with students for lecturer1') }
  $r = Invoke-Api $lect 'PUT' "/api/lecturer/enrollments/$($row.enrollment_id)/grade" @{ grade = 88 }
  if ($r.Status -ge 200 -and $r.Status -lt 300) {
    return (Pass "HTTP $($r.Status), grade set to 88 (check the Save message and grade_audit in T15/T26)")
  }
  return (Fail "HTTP $($r.Status) $($r.Json.error)")
}

Check 'T14' 'Grade out of range is refused' {
  if (-not $row) { return (Fail 'no row') }
  $r = Invoke-Api $lect 'PUT' "/api/lecturer/enrollments/$($row.enrollment_id)/grade" @{ grade = 101 }
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'between 0 and 100') { return (Pass 'HTTP 400, range message') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T12' 'Another lecturer''s section is refused' {
  if (-not $otherId) { return (Fail 'no section outside lecturer1 found') }
  $r = Invoke-Api $lect 'GET' "/api/lecturer/offerings/$otherId/grades"
  if ($r.Status -eq 403 -and $r.Json.error -eq 'Not allowed') {
    return (Pass 'HTTP 403 "Not allowed" (ACCESS_DENIED is checked in T27)')
  }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T17' 'Submit moves forward only' {
  if (-not $own) { return (Fail 'no OPEN section for lecturer1') }
  $first  = Invoke-Api $lect 'POST' "/api/lecturer/offerings/$($own.offering_id)/submit"
  $second = Invoke-Api $lect 'POST' "/api/lecturer/offerings/$($own.offering_id)/submit"
  if ($first.Status -ge 200 -and $first.Status -lt 300 -and $second.Status -eq 400 -and "$($second.Json.error)" -match 'open') {
    return (Pass "first HTTP $($first.Status), second HTTP 400 '$($second.Json.error)'")
  }
  return (Fail "first HTTP $($first.Status), second HTTP $($second.Status) '$($second.Json.error)'")
}

Check 'T16' 'Grade is locked after submit' {
  if (-not $row) { return (Fail 'no row') }
  $r = Invoke-Api $lect 'PUT' "/api/lecturer/enrollments/$($row.enrollment_id)/grade" @{ grade = 90 }
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'closed') { return (Pass 'HTTP 400, section closed') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

# ================================================================ C. REGISTRAR
Write-Host "`n== C. Registrar ==" -ForegroundColor Cyan

$openOne = $null
$csc     = $null
$jana    = $null
$script:reqId = $null
try {
  $regAll = @((Invoke-Api $reg1 'GET' '/api/registrar/offerings').Json)
  $openOne = $regAll | Where-Object { $_.status -eq 'OPEN' } | Select-Object -First 1
  $csc     = $regAll | Where-Object { $_.code -eq 'CSC122' -and $_.status -eq 'SUBMITTED' } | Select-Object -First 1
  if ($csc) {
    $cscRows = @((Invoke-Api $reg1 'GET' "/api/registrar/offerings/$($csc.offering_id)/enrollments").Json)
    $jana = $cscRows | Where-Object { $_.full_name -like '*Jana Rashid*' } | Select-Object -First 1
    if (-not $jana) { $jana = $cscRows | Where-Object { [decimal]$_.grade -eq [decimal]60.32 } | Select-Object -First 1 }
  }
} catch {
  Write-Host ('setup (registrar): ' + $_.Exception.Message) -ForegroundColor Yellow
}

Check 'T18' 'Publish is refused for an OPEN section' {
  if (-not $openOne) { return (Fail 'no OPEN section found') }
  $r = Invoke-Api $reg1 'POST' "/api/registrar/offerings/$($openOne.offering_id)/publish"
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'submitted') { return (Pass 'HTTP 400, only submitted sections') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T19' 'Publish a SUBMITTED section (CSC122)' {
  if (-not $csc) { return (Fail 'CSC122 is not SUBMITTED in this seed') }
  $r = Invoke-Api $reg1 'POST' "/api/registrar/offerings/$($csc.offering_id)/publish"
  $after = $null
  $after = @((Invoke-Api $reg1 'GET' '/api/registrar/offerings').Json) | Where-Object { $_.offering_id -eq $csc.offering_id }
  if ($r.Status -ge 200 -and $r.Status -lt 300 -and $after.status -eq 'PUBLISHED') {
    return (Pass "HTTP $($r.Status), status PUBLISHED")
  }
  return (Fail "HTTP $($r.Status), status now '$($after.status)'")
}

Check 'T21' 'Change request refused for an OPEN section' {
  if (-not $openOne) { return (Fail 'no OPEN section') }
  $en = @((Invoke-Api $reg1 'GET' "/api/registrar/offerings/$($openOne.offering_id)/enrollments").Json) | Select-Object -First 1
  if (-not $en) { return (Fail 'the OPEN section has no students') }
  $r = Invoke-Api $reg1 'POST' '/api/registrar/change-requests' @{ enrollmentId = $en.enrollment_id; newGrade = 70; reason = 'Testing post-close rule' }
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'still open') { return (Pass 'HTTP 400, section still open') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T20' 'Reason shorter than 10 characters is refused' {
  if (-not $jana) { return (Fail 'Jana Rashid row not found in CSC122') }
  $r = Invoke-Api $reg1 'POST' '/api/registrar/change-requests' @{ enrollmentId = $jana.enrollment_id; newGrade = 70; reason = 'short' }
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'at least 10') { return (Pass 'HTTP 400, reason message') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T22' 'Registrar1 files a valid change request (60.32 to 70)' {
  if (-not $jana) { return (Fail 'Jana Rashid row not found in CSC122') }
  $r = Invoke-Api $reg1 'POST' '/api/registrar/change-requests' @{ enrollmentId = $jana.enrollment_id; newGrade = 70; reason = 'Final exam score re-check' }
  if ($r.Status -lt 200 -or $r.Status -ge 300) { return (Fail "HTTP $($r.Status) '$($r.Json.error)'") }
  $pending = @((Invoke-Api $reg1 'GET' '/api/registrar/change-requests/pending').Json)
  $item = $pending | Where-Object { $_.full_name -eq $jana.full_name -and [decimal]$_.new_grade -eq 70 } | Select-Object -First 1
  if (-not $item) { return (Fail 'request not in the pending list') }
  $script:reqId = $item.request_id
  $now = @((Invoke-Api $reg1 'GET' "/api/registrar/offerings/$($csc.offering_id)/enrollments").Json) | Where-Object { $_.enrollment_id -eq $jana.enrollment_id }
  return (Pass "request $($script:reqId) pending; grade still $($now.grade)")
}

Check 'T23' 'Registrar cannot approve their own request' {
  if (-not $script:reqId) { return (Fail 'no request from T22') }
  $r = Invoke-Api $reg1 'POST' "/api/registrar/change-requests/$($script:reqId)/decision" @{ approve = $true; note = 'self' }
  if ($r.Status -eq 403 -and $r.Json.error -eq 'Not allowed') { return (Pass 'HTTP 403 "Not allowed"') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

Check 'T24' 'Registrar2 approves: grade becomes 70' {
  if (-not $script:reqId) { return (Fail 'no request from T22') }
  $r = Invoke-Api $reg2 'POST' "/api/registrar/change-requests/$($script:reqId)/decision" @{ approve = $true; note = 'Verified' }
  if ($r.Status -lt 200 -or $r.Status -ge 300) { return (Fail "HTTP $($r.Status) '$($r.Json.error)'") }
  $now = @((Invoke-Api $reg1 'GET' "/api/registrar/offerings/$($csc.offering_id)/enrollments").Json) | Where-Object { $_.enrollment_id -eq $jana.enrollment_id }
  if ([decimal]$now.grade -eq [decimal]70) { return (Pass 'grade is 70; POST_CLOSE row checked in T26') }
  return (Fail "grade is '$($now.grade)'")
}

Check 'T25' 'A decided request cannot be decided again' {
  if (-not $script:reqId) { return (Fail 'no request from T22') }
  $r = Invoke-Api $reg2 'POST' "/api/registrar/change-requests/$($script:reqId)/decision" @{ approve = $true; note = 'again' }
  if ($r.Status -eq 400 -and "$($r.Json.error)" -match 'already decided') { return (Pass 'HTTP 400, already decided') }
  return (Fail "HTTP $($r.Status) '$($r.Json.error)'")
}

# ================================================================ D. AUDITOR
Write-Host "`n== D. Auditor ==" -ForegroundColor Cyan

Check 'T26' 'Grade history shows ENTRY/EDIT and POST_CLOSE' {
  $log = @((Invoke-Api $aud 'GET' '/api/auditor/grade-audit').Json)
  $types = @($log | ForEach-Object { $_.change_type } | Sort-Object -Unique)
  $hasEdit = ($types -contains 'ENTRY') -or ($types -contains 'EDIT')
  if ($hasEdit -and ($types -contains 'POST_CLOSE')) { return (Pass "types present: $($types -join ', ')") }
  return (Fail "types present: $($types -join ', ')")
}

Check 'T15' 'Edit history row keeps old and new value' {
  if (-not $row) { return (Fail 'no row') }
  $log = @((Invoke-Api $aud 'GET' '/api/auditor/grade-audit').Json)
  $hit = $log | Where-Object { $_.enrollment_id -eq $row.enrollment_id -and $_.change_type -in @('ENTRY', 'EDIT') -and [decimal]$_.new_grade -eq 88 } | Select-Object -First 1
  if ($hit) { return (Pass "old $($hit.old_grade), new $($hit.new_grade), actor $($hit.actor)") }
  return (Fail 'no ENTRY/EDIT row with new grade 88 for that enrolment')
}

Check 'T28' 'Auditor cannot file a change request (read only)' {
  if (-not $row) { return (Fail 'no row') }
  $r = Invoke-Api $aud 'POST' '/api/registrar/change-requests' @{ enrollmentId = $row.enrollment_id; newGrade = 70; reason = 'Auditor attempt test' }
  if ($r.Status -eq 403) { return (Pass 'HTTP 403') }
  return (Fail "HTTP $($r.Status)")
}

Check 'T29' 'Auditor cannot read student data' {
  $r = Invoke-Api $aud 'GET' '/api/student/enrollments'
  if ($r.Status -eq 403) { return (Pass 'HTTP 403') }
  return (Fail "HTTP $($r.Status)")
}

# ================================================================ E. STUDENT (after publish)
Write-Host "`n== E. Student after publish ==" -ForegroundColor Cyan

Manual 'T07' 'Student sees only own enrolments' 'In /student as student1, confirm no other student data is shown'
Manual 'T08' 'Grades of non-published sections show "Not published"' 'In /student, rows of OPEN/SUBMITTED sections show "Not published"'

Check 'T09' 'Grade shown after publishing (CSC122)' {
  $mine = @((Invoke-Api $student 'GET' '/api/student/enrollments').Json)
  $c = $mine | Where-Object { $_.courseCode -eq 'CSC122' } | Select-Object -First 1
  if (-not $c) { return (Skip 'student1 is not enrolled in CSC122: check with a student who is') }
  if ($null -ne $c.grade) { return (Pass "grade shown: $($c.grade)") }
  return (Fail 'CSC122 is published but the grade is empty')
}

Check 'T05' 'Logout returns 204 and /me then returns 401' {
  $out = Invoke-Api $student 'POST' '/api/auth/logout'
  $me  = Invoke-Api $student 'GET' '/api/auth/me'
  if ($out.Status -ge 200 -and $out.Status -lt 300 -and $me.Status -eq 401) {
    return (Pass "logout HTTP $($out.Status), then /me HTTP 401")
  }
  return (Fail "logout HTTP $($out.Status), /me HTTP $($me.Status)")
}

# ================================================================ F. LOCK-OUT (last: it locks student1)
Write-Host "`n== F. Lock-out (runs last) ==" -ForegroundColor Cyan

Check 'T04' 'Account locks after 5 failures' {
  $statuses = @()
  for ($i = 1; $i -le 5; $i++) {
    $statuses += (Invoke-Api $anon2 'POST' '/api/auth/login' @{ username = 'student1'; password = "WrongPass$i" }).Status
  }
  $six = Invoke-Api $anon2 'POST' '/api/auth/login' @{ username = 'student1'; password = $pw.student1 }
  if (($statuses | Where-Object { $_ -ne 401 }).Count -eq 0 -and $six.Status -eq 401) {
    return (Pass "failures: $($statuses -join ','); correct password after lock: HTTP $($six.Status)")
  }
  return (Fail "failures: $($statuses -join ','); correct password: HTTP $($six.Status)")
}

Check 'T27' 'Security events show failures, lock and denials' {
  $ev = @((Invoke-Api $aud 'GET' '/api/auditor/security-events').Json)
  $types = @($ev | ForEach-Object { $_.event_type } | Sort-Object -Unique)
  $need = @('LOGIN_FAILED', 'ACCOUNT_LOCKED', 'ACCESS_DENIED')
  $missing = @($need | Where-Object { $types -notcontains $_ })
  if ($missing.Count -eq 0) { return (Pass "types present: $($types -join ', ')") }
  return (Fail "missing: $($missing -join ', '); types present: $($types -join ', ')")
}

Manual 'T30' 'Errors do not reveal Oracle details' `
  'Stop the Oracle listener, call any data endpoint, check the body only has "Something went wrong" and a correlationId; restart the listener'

# ---------------------------------------------------------------- save and summary
$outDir = Join-Path $PSScriptRoot '..\docs\M2\results'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$file = Join-Path $outDir ('m2_run_' + (Get-Date -Format 'yyyyMMdd_HHmm') + '.csv')
$rows | Sort-Object ID | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8

Write-Host "`n== Summary ==" -ForegroundColor Cyan
$rows | Group-Object Result | ForEach-Object { Write-Host ("{0,-8} {1}" -f $_.Name, $_.Count) }
Write-Host "`nSaved: $((Resolve-Path $file).Path)" -ForegroundColor Cyan
Write-Host "student1 is now locked for 15 minutes (T04). Unlock with section 6 of scripts\m2_db_checks.sql if you run again." -ForegroundColor Yellow
