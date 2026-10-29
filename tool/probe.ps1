$base = 'http://127.0.0.1:8088'
function Probe($method, $path, $body) {
  $u = "$base$path"
  try {
    if ($body) { $r = Invoke-WebRequest $u -Method $method -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 8 }
    else { $r = Invoke-WebRequest $u -Method $method -UseBasicParsing -TimeoutSec 8 }
    Write-Output ("[{0,-4}] {1,-24} {2}  {3}" -f $method, $path, $r.StatusCode, $r.Content)
  } catch {
    $sc = $_.Exception.Response.StatusCode.value__
    $msg = $_.ErrorDetails.Message
    Write-Output ("[{0,-4}] {1,-24} {2}  {3}" -f $method, $path, $sc, $msg)
  }
}
Write-Output '===== DISCOVERY ====='
Probe GET  '/api/routes'
Write-Output '===== CORE ====='
Probe GET  '/api/health'
Probe GET  '/api/info'
Probe GET  '/api/status'
Write-Output '===== NEW: METRICS / STATS / SESSIONS / ECHO ====='
Probe GET  '/api/metrics'
Probe POST '/api/query' '{"sql":"CREATE TABLE emp(id INTEGER, name TEXT, dept TEXT); CREATE VIEW mgrs AS SELECT id,name FROM emp;"}'
Probe POST '/api/query' '{"sql":"INSERT INTO emp VALUES (1,''Ann'',''Eng''),(2,''Bob'',''Eng''),(3,''Cy'',''Ops'');"}'
Probe GET  '/api/stats'
Probe GET  '/api/sessions'
Probe POST '/api/echo' '{"hello":"world","n":42}'
Probe GET  '/api/metrics'
Write-Output '===== SCHEMA ====='
Probe GET  '/api/tables'
Probe GET  '/api/tables/emp'
Probe GET  '/api/views'
Write-Output '===== ERROR CASES ====='
Probe POST '/api/query' '{"sql":"SELECT * FROM nope;"}'
Probe POST '/api/query' '{"sql":"   "}'
Probe GET  '/api/tables/1bad'
Probe GET  '/api/missing'
