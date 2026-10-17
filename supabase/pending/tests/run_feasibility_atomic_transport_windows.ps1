# Loopback-only disposable PostgreSQL verification; no managed connection accepted.
param([Parameter(Mandatory=$true)][string]$PostgresBin)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$bin=(Resolve-Path -LiteralPath $PostgresBin).Path
$work=Join-Path ([IO.Path]::GetTempPath()) ('ssm-atomic-transport-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$data=Join-Path $work 'data'; $passwordPath=Join-Path $work 'password.txt'
$secret=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($passwordPath,$secret)
$oldPassword=$env:PGPASSWORD; $oldAddress=$env:PGHOSTADDR; $oldService=$env:PGSERVICE; $oldOptions=$env:PGOPTIONS
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start(); $port=$listener.LocalEndpoint.Port; $listener.Stop()
$startupAttempted=$false
try {
 $env:PGPASSWORD=$secret; $env:PGHOSTADDR='127.0.0.1'; $env:PGSERVICE=$null; $env:PGOPTIONS=$null
 & (Join-Path $bin 'initdb.exe') -D $data -U ssm_fixture --encoding=UTF8 --no-locale --auth-host=scram-sha-256 --auth-local=scram-sha-256 --pwfile=$passwordPath *> (Join-Path $work 'initdb.log')
 if($LASTEXITCODE -ne 0){throw 'initdb failed'}
 $startupAttempted=$true
 $startup=Start-Process -FilePath (Join-Path $bin 'pg_ctl.exe') -ArgumentList @('-D',('"'+$data+'"'),'-l',('"'+(Join-Path $work 'server.log')+'"'),'-o',('"-h 127.0.0.1 -p '+$port+'"'),'-w','start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'startup.log') -RedirectStandardError (Join-Path $work 'startup-error.log')
 $startup.WaitForExit(); if($startup.ExitCode -ne 0){throw 'Local startup failed'}
 $connection=@('--host=127.0.0.1',"--port=$port",'--username=ssm_fixture','--dbname=postgres','--set=ON_ERROR_STOP=1')
 function Run-SqlFile([string]$path,[string]$name,[bool]$expectedFailure=$false){
  & (Join-Path $bin 'psql.exe') @connection -f $path *> (Join-Path $work ($name+'.log'))
  $failed=$LASTEXITCODE -ne 0
  if($failed -ne $expectedFailure){throw "Unexpected SQL result for $name; inspect $work"}
 }
 function Run-SqlText([string]$sql,[string]$name){
  $path=Join-Path $work ($name+'.sql'); [IO.File]::WriteAllText($path,$sql)
  Run-SqlFile $path $name
 }
 Run-SqlFile (Join-Path $repo 'supabase/pending/activation-review-20261017-corrected/fixture.sql') 'fixture'
 $transport=Join-Path $repo 'supabase/pending/transport-review-20261017'
 Run-SqlFile (Join-Path $transport '00_setup.sql') 'setup'
 Get-ChildItem -LiteralPath $transport -Filter '*_chunk.sql' | Sort-Object Name | ForEach-Object { Run-SqlFile $_.FullName $_.BaseName }
 $access='DO $$ BEGIN IF EXISTS (SELECT 1 FROM (VALUES (''anon''),(''authenticated''),(''service_role'')) r(role_name) WHERE has_schema_privilege(role_name,''_ssm_feasibility_install_20261017'',''USAGE'') OR has_table_privilege(role_name,''_ssm_feasibility_install_20261017.chunks'',''SELECT,INSERT,UPDATE,DELETE'')) THEN RAISE EXCEPTION ''Staging exposes application access''; END IF; END $$;'
 Run-SqlText $access 'private-stage-access'
 Run-SqlText "UPDATE _ssm_feasibility_install_20261017.chunks SET payload=payload||decode('00','hex') WHERE ordinal=1;" 'corrupt-chunk'
 Run-SqlFile (Join-Path $transport '99_execute.sql') 'corrupt-hash-denied' $true
 $unchanged='DO $$ BEGIN IF to_regprocedure(''public.assign_requirement_feasibility_review(uuid,uuid,uuid)'') IS NOT NULL OR to_regclass(''public.sales_feasibility_handover_requests'') IS NOT NULL OR EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid=''public.requirement_feasibility_reviews''::regclass AND conname=''requirement_feasibility_reviews_revision_department_key'') THEN RAISE EXCEPTION ''Failed transport changed graph''; END IF; END $$;'
 Run-SqlText $unchanged 'corrupt-rollback-check'
 Run-SqlText "UPDATE _ssm_feasibility_install_20261017.chunks SET payload=substring(payload FROM 1 FOR octet_length(payload)-1) WHERE ordinal=1; DELETE FROM _ssm_feasibility_install_20261017.chunks WHERE ordinal=9;" 'repair-and-remove-chunk'
 Run-SqlFile (Join-Path $transport '99_execute.sql') 'missing-chunk-denied' $true
 Run-SqlText $unchanged 'missing-rollback-check'
 Run-SqlFile (Join-Path $transport '09_chunk.sql') 'restore-last-chunk'
 Run-SqlFile (Join-Path $transport '99_execute.sql') 'atomic-install'
 Run-SqlText 'DO $$ BEGIN IF to_regnamespace(''_ssm_feasibility_install_20261017'') IS NOT NULL THEN RAISE EXCEPTION ''Transport retained''; END IF; END $$;' 'staging-cleanup-check'
 Run-SqlFile (Join-Path $repo 'supabase/migrations/tests/20261017053400_feasibility_protected_handover_local_acceptance.sql') 'handover-acceptance'
 Run-SqlFile (Join-Path $repo 'supabase/migrations/tests/20261017053400_feasibility_access_transition_local_acceptance.sql') 'access-acceptance'
 Write-Output 'FEASIBILITY_ATOMIC_TRANSPORT_LOCAL_PASS private_stage=true corrupt_hash_denied=true missing_chunk_denied=true unchanged_after_failure=true full_install=true cleanup=true handover_access_acceptance=true'
} finally {
 if($startupAttempted){ & (Join-Path $bin 'pg_ctl.exe') -D $data -m fast -w stop *> (Join-Path $work 'stop.log') }
 $env:PGPASSWORD=$oldPassword; $env:PGHOSTADDR=$oldAddress; $env:PGSERVICE=$oldService; $env:PGOPTIONS=$oldOptions
 if(Test-Path -LiteralPath $passwordPath){Remove-Item -LiteralPath $passwordPath}
 Write-Output "LOCAL_LOGS=$work"
}