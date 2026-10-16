# Disposable local PostgreSQL only. No managed connection string is accepted.
param([Parameter(Mandatory=$true)][string]$PostgresBin)
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$bin=(Resolve-Path -LiteralPath $PostgresBin).Path
foreach($exe in @('initdb.exe','pg_ctl.exe','psql.exe','createdb.exe')){if(-not(Test-Path -LiteralPath (Join-Path $bin $exe))){throw "Missing portable PostgreSQL executable: $exe"}}
$work=Join-Path ([IO.Path]::GetTempPath()) ('ssm-feasibility-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$data=Join-Path $work 'data'
$passwordFile=Join-Path $work 'password.txt'
$password=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($passwordFile,$password)
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start();$port=$listener.LocalEndpoint.Port;$listener.Stop()
$started=$false
$oldPassword=$env:PGPASSWORD
$oldService=$env:PGSERVICE
$oldOptions=$env:PGOPTIONS
try {
 $env:PGPASSWORD=$password;$env:PGSERVICE=$null;$env:PGOPTIONS=$null
 & (Join-Path $bin 'initdb.exe') -D $data -U ssm_fixture --encoding=UTF8 --no-locale --auth-host=scram-sha-256 --auth-local=scram-sha-256 --pwfile=$passwordFile *> (Join-Path $work 'initdb.log')
 if($LASTEXITCODE -ne 0){throw "initdb failed; inspect $work/initdb.log"}
  $startup=Start-Process -FilePath (Join-Path $bin 'pg_ctl.exe') -ArgumentList @('-D',('"'+$data+'"'),'-l',('"'+(Join-Path $work 'server.log')+'"'),'-o',('"-h 127.0.0.1 -p '+$port+'"'),'-w','start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'startup.log') -RedirectStandardError (Join-Path $work 'startup-error.log')
 $startup.WaitForExit()
 if($startup.ExitCode -ne 0){throw "Local server startup failed; inspect $work/startup.log"}
 $started=$true
 $connection=@('--host=127.0.0.1',"--port=$port",'--username=ssm_fixture')
 & (Join-Path $bin 'createdb.exe') @connection ssm_feasibility_fixture
 if($LASTEXITCODE -ne 0){throw 'Disposable database creation failed'}
 $files=@('supabase/pending/tests/client_requirement_intake_local_fixture.sql','supabase/pending/20261005_client_requirement_intake.sql','supabase/pending/20261013_sales_feasibility_handover.sql','supabase/pending/tests/requirement_feasibility_original_target_compatibility_local_acceptance.sql')
 foreach($file in $files){
  $source=Join-Path $repoRoot $file
  $log=Join-Path $work ((Split-Path $file -Leaf)+'.log')
  & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -f $source *> $log
  if($LASTEXITCODE -ne 0){throw "Fixture failed: $file; inspect $log"}
 }
 # Rebuild only this disposable fixture to match the handover harness schema.
 # The intake-provenance migration imposes stronger pins than the replay-tamper cases model.
 foreach($file in @('supabase/pending/tests/client_requirement_intake_local_fixture.sql','supabase/pending/20261013_sales_feasibility_handover.sql')){
  & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -f (Join-Path $repoRoot $file) *> (Join-Path $work ((Split-Path $file -Leaf)+'.handover-setup.log'))
  if($LASTEXITCODE -ne 0){throw "Handover fixture setup failed: $file"}
 }
 # Fixture-only grant, never applied to a managed target.
 & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -c 'GRANT EXECUTE ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) TO authenticated;' *> (Join-Path $work 'fixture-execute-grant.log')
 if($LASTEXITCODE -ne 0){throw 'Fixture-only execution grant failed'}
 foreach($name in @('sales_feasibility_handover_local_acceptance.sql','sales_feasibility_handover_graph_lock_local_acceptance.sql','sales_feasibility_handover_root_serialization_local_acceptance.sql')){
  & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot $name) *> (Join-Path $work ($name+'.log'))
  if($LASTEXITCODE -ne 0){throw "Local handover acceptance failed: $name; inspect $work"}
 }
 $holderPath=Join-Path $PSScriptRoot 'sales_feasibility_windows_root_holder.sql'
 $holder=Start-Process -FilePath (Join-Path $bin 'psql.exe') -ArgumentList ($connection+@('--dbname=ssm_feasibility_fixture','--set=ON_ERROR_STOP=1','-f',('"'+$holderPath+'"'))) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'root-holder.log') -RedirectStandardError (Join-Path $work 'root-holder-error.log')
 $ready=$false
 for($attempt=0;$attempt -lt 30;$attempt++){
  $marker=& (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture -Atqc "SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND classid=20261016 AND objid=36 AND granted"
  if($LASTEXITCODE -ne 0){throw 'Root readiness query failed'}
  if($marker -eq '1'){$ready=$true;break}
  if($holder.HasExited){break}
  Start-Sleep -Milliseconds 100
 }
 if(-not $ready){throw 'Concurrent root holder readiness not observed'}
 & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot 'sales_feasibility_windows_root_probe.sql') *> (Join-Path $work 'root-probe.log')
 if($LASTEXITCODE -ne 0){throw 'Concurrent replay probe failed'}
 $holder.WaitForExit()
 if($holder.ExitCode -ne 0){throw 'Concurrent holder failed'}
 foreach($file in @('supabase/pending/20261016_requirement_internal_notes.sql','supabase/pending/tests/requirement_internal_notes_local_acceptance.sql','supabase/pending/tests/requirement_internal_notes_caller_rollback_local_acceptance.sql','supabase/pending/tests/requirement_internal_notes_repin_local_acceptance.sql')){
  & (Join-Path $bin 'psql.exe') @connection --dbname=ssm_feasibility_fixture --set=ON_ERROR_STOP=1 -f (Join-Path $repoRoot $file) *> (Join-Path $work ((Split-Path $file -Leaf)+'.log'))
  if($LASTEXITCODE -ne 0){throw "Internal note local acceptance failed: $file"}
 }
 Write-Output "LOCAL_INTERNAL_NOTE_SQL_PASS logs=$work"
 Write-Output "LOCAL_ROOT_CONTENTION_SQL_PASS logs=$work"
 Write-Output "LOCAL_HANDOVER_SEQUENTIAL_SQL_PASS logs=$work"
 Write-Output "LOCAL_COMPATIBILITY_SQL_PASS logs=$work"
 Write-Output 'Synthetic local evidence only; no target JWT, live deployment or managed restore acceptance.'
} finally {
 if($started){& (Join-Path $bin 'pg_ctl.exe') -D $data -m fast -w stop *> (Join-Path $work 'shutdown.log')}
 $env:PGPASSWORD=$oldPassword;$env:PGSERVICE=$oldService;$env:PGOPTIONS=$oldOptions
 # Retain stopped disposable data/logs for diagnosis; no recursive deletion.
 if(Test-Path -LiteralPath $passwordFile){Remove-Item -LiteralPath $passwordFile}
 Write-Output "LOCAL_FIXTURE_STOPPED_OR_NOT_STARTED work=$work"
}
