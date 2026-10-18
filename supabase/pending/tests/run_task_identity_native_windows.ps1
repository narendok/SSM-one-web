# Starts an isolated native PostgreSQL 17 cluster; never accepts a remote connection.
param([Parameter(Mandatory=$true)][string]$PostgresBin,[Parameter(Mandatory=$true)][string]$NodeExe)
$ErrorActionPreference='Stop'
$bin=(Resolve-Path -LiteralPath $PostgresBin).Path
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$version=& (Join-Path $bin 'postgres.exe') --version
if($version -notmatch 'PostgreSQL\) 17\.') {throw 'Native PostgreSQL 17 required'}
$work=Join-Path ([IO.Path]::GetTempPath()) ('ssm-task-native-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work|Out-Null
$data=Join-Path $work 'data'; $pwfile=Join-Path $work 'password.txt'
$secret=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($pwfile,$secret)
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start();$port=$listener.LocalEndpoint.Port;$listener.Stop()
$oldPort=$env:SSM_TASK_FIXTURE_PORT;$oldPassword=$env:SSM_TASK_FIXTURE_PASSWORD;$started=$false
try {
 & (Join-Path $bin 'initdb.exe') -D $data -U ssm_fixture --encoding=UTF8 --no-locale --auth-host=scram-sha-256 --auth-local=scram-sha-256 --pwfile=$pwfile *> (Join-Path $work 'initdb.log')
 if($LASTEXITCODE -ne 0){throw "Fixture init failed; logs $work"}
 $started=$true
 $startup=Start-Process -FilePath (Join-Path $bin 'pg_ctl.exe') -ArgumentList @('-D',('"'+$data+'"'),'-l',('"'+(Join-Path $work 'server.log')+'"'),'-o',('"-h 127.0.0.1 -p '+$port+'"'),'-w','start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'startup.log') -RedirectStandardError (Join-Path $work 'startup-error.log')
 $startup.WaitForExit();if($startup.ExitCode -ne 0){throw "Fixture startup failed; logs $work"}
 $env:SSM_TASK_FIXTURE_PORT="$port";$env:SSM_TASK_FIXTURE_PASSWORD=$secret
 & $NodeExe (Join-Path $PSScriptRoot 'task_identity_steward_local.mjs') (Join-Path $PSScriptRoot 'task_identity_native_adapter.mjs') *> (Join-Path $work 'acceptance.log')
 if($LASTEXITCODE -ne 0){throw "Native acceptance failed; logs $work"}
 & $NodeExe (Join-Path $PSScriptRoot 'task_identity_native_overlap.mjs') *> (Join-Path $work 'overlap.log')
 if($LASTEXITCODE -ne 0){throw "Native overlap failed; logs $work"}
 Get-Content (Join-Path $work 'overlap.log')
 Get-Content (Join-Path $work 'acceptance.log')
 "TASK_IDENTITY_NATIVE_17_PASS runtime=$version managed_execution=false concurrency_acceptance=false"
} finally {
 if($started){& (Join-Path $bin 'pg_ctl.exe') -D $data -m fast -w stop *> (Join-Path $work 'stop.log')}
 $env:SSM_TASK_FIXTURE_PORT=$oldPort;$env:SSM_TASK_FIXTURE_PASSWORD=$oldPassword
 if(Test-Path -LiteralPath $pwfile){Remove-Item -LiteralPath $pwfile}
 "LOCAL_LOGS=$work"
}

