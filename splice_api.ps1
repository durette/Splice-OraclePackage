<#
.Synopsis
Edit a single method inside of an Oracle Database package, leaving the rest of
the package in-tact.
.Description
In the specific use case of a legacy ERP, customer-specific extensions might be
deployed to a very large monolithic package. ("We're only going to change a few
things.") Any changes to this package must be coordinated with other developers
who might be editing the package, since the package can only be deployed as a
whole entire unit. This serializes development.

To reduce the time and risk of doing this manually and to break the dependency
on the whole package from a change control perspective, this sript splices a new
header specification and a new body implementation for a single procedure or
function inside of a package, replacing the old version of that procedure or
function.

Prerequisites:
1. The method must already exist in the target package. This is not for
   deploying new methods. (If you recognize you're in this situation, you should
   be creating new packages instead of making your monolithic package bigger.)

2. The new versions of the method's head and body should be contained in these
   files in the current working directory.

   ${ApiName}_${MethodName}_head_dev.pck
   ${ApiName}_${MethodName}_body_dev.pck

   There's an "init" command available to grab the code from PROD as a starting
   point.

3. The TNS names must be set up with Oracle Wallet authentication, allowing the
   use of passwordless authentication like this:
   sqlplus /@tns_prod_environment @"myscript.sql"
   sqlplus /@tns_dev_environment @"myscript.sql"

.Example
.\splice_api.ps1 -Command init tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING
.\splice_api.ps1 -TnsName tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING

.Parameter Command
Optional command for special processing:

"init" produces a set of "after" files from which development can begin.

"cleanall" is destructive. It removes the "after" files, which may include your
developed code.

.Parameter TnsName
TNSNAMES or EZCONNECT entry for connecting to the Oracle database for IFS. These
characters also need to be valid for a filename.

.Parameter ApiName
The package to be edited

.Parameter MethodType
The allowable values are ordinarily PROCEDURE or FUNCTION.

.Parameter MethodName
The name of the function or procedure to be edited

#>

param(
	[string]$Command,
	[string]$TnsName = $( Read-Host -asSecureString "Oracle TNS name" ),
	[string]$ApiName = $( Read-Host "API to edit" ),
	[string]$MethodType = $( Read-Host "Method type (usually PROCEDURE or FUNCTION)" ),
	[string]$MethodName = $( Read-Host "Method name" ))

$TnsName = $TnsName.ToLower()
$ApiName = $ApiName.ToUpper()
$MethodType = $MethodType.ToUpper()
$MethodName = $MethodName.ToUpper()

$DateString = Get-Date -Format "yyyy'_'MM'_'dd'__'HH'_'mm'_'ss"

Remove-Item "${ApiName}_${TnsName}_${DateString}_in.pck" -ErrorAction SilentlyContinue

If ( "${Command}" -eq "cleanall" ) {
then
	Remove-Item "${ApiName}_${MethodName}_head_dev.pck" -ErrorAction SilentlyContinue
	Remove-Item "${ApiName}_${MethodName}_body_dev.pck" -ErrorAction SilentlyContinue
	Exit 0
}

# Use a here-doc to spool the old API definition to simplify script dependencies
$sqlQuery = @"
SET ARRAYSIZE 5000
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET TAB OFF
SET TIMING OFF
SET VERIFY OFF
SET LONGCHUNKSIZE 32767
SET EMBEDDED ON
SET LONG 1000000000
SET PAGESIZE 0
SET LINESIZE 32767
SET TRIMSPOOL ON
SET SERVEROUTPUT ON SIZE 100000 FORMAT WRAPPED

COLUMN ddl_col FORMAT A32767

BEGIN
   dbms_metadata.set_transform_param
      (dbms_metadata.session_transform, 'SQLTERMINATOR', TRUE);
   dbms_metadata.set_transform_param
      (dbms_metadata.session_transform, 'PRETTY',        FALSE);
   dbms_metadata.set_transform_param
      (dbms_metadata.session_transform, 'EMIT_SCHEMA',   FALSE);
END;
/

SPOOL ${ApiName}_${TnsName}_${DateString}_in.pck

SELECT dbms_metadata.get_ddl('PACKAGE', '${ApiName}') AS ddl_col
  FROM DUAL;

EXIT;
"@

$DummyOutput = $sqlQuery | sqlplus -s /@$TnsName

# The old and new APIs are broken into these 5 sections, then recomposed:
#   1. Everything before the method head
#   2. The method head
#   3. Everything between the method head and method body
#   4. The method body
#   5. Everything after the method body

$Before =
	Get-Content -LiteralPath "${ApiName}_${TnsName}_${DateString}_in.pck"

$HeadBegin =
	$Before |
	Select-String -Pattern "${MethodType}[ ]*${MethodName}(\s|\(|$|;)" |
	Select-Object -First 1 |
	Select-Object -ExpandProperty 'LineNumber'

$HeadLength =
	$Before |
	Select-Object -Skip $( $HeadBegin - 1) |
	Select-String -Pattern ";" |
	Select-Object -First 1 |
	Select-Object -ExpandProperty 'LineNumber'

$BodyBegin =
	$Before |
	Select-Object -Skip $( $HeadBegin + $HeadLength) |
	Select-String -Pattern "${MethodType}[ ]*${MethodName}(\s|\(|$)" |
	Select-Object -ExpandProperty 'LineNumber'
$BodyBegin = $($BodyBegin + $HeadBegin + $HeadLength)

$BodyLength =
	$Before |
	Select-Object -Skip $( $BodyBegin - 1) |
	Select-String -Pattern "END[ ]*${MethodName}[ ]*;" |
	Select-Object -First 1 |
	Select-Object -ExpandProperty 'LineNumber'


$Section1Length = $( $HeadBegin - 1 )
$Section3Begin = $( $HeadBegin + $HeadLength )
$Section3Length = $( $BodyBegin - $Section3Begin )
$Section5Begin = $( $BodyBegin + $BodyLength )

#Write-Output "HeadBegin = $HeadBegin"
#Write-Output "HeadLength = $HeadLength"
#Write-Output "BodyBegin = $BodyBegin"
#Write-Output "BodyLength = $BodyLength"
#Write-Output "Section1Length = $Section1Length"
#Write-Output "Section3Begin = $Section3Begin"
#Write-Output "Section3Length = $Section3Length"
#Write-Output "Section5Begin = $Section5Begin"

$Section1 =
	$Before |
	Select-Object -First $Section1Length

$Section2Before =
	$Before |
	Select-Object -Skip $( $HeadBegin - 1) |
	Select-Object -First $HeadLength

$Section3 =
	$Before |
	Select-Object -Skip $( $Section3Begin - 1) |
	Select-Object -First $Section3Length

$Section4Before =
	$Before |
	Select-Object -Skip $( $BodyBegin - 1) |
	Select-Object -First $BodyLength

$Section5 =
	$Before |
	Select-Object -Skip $( $Section5Begin - 1)

If ( "${Command}" -eq "init" ) {
	If (-not (Test-Path "${ApiName}_${MethodName}_head_dev.pck")) {
		$Section2Before | Set-Content "${ApiName}_${MethodName}_head_dev.pck"
	}
	If (-not (Test-Path "${ApiName}_${MethodName}_body_dev.pck")) {
		$Section4Before | Set-Content "${ApiName}_${MethodName}_body_dev.pck"
	}
	#Remove-Item "${ApiName}_${TnsName}_${DateString}_in.pck" -ErrorAction SilentlyContinue
	Exit 0
}

If (Test-Path "${ApiName}_${MethodName}_head_dev.pck") {
	$Section2After =
		Get-Content -LiteralPath "${ApiName}_${MethodName}_head_dev.pck"
} Else {
	Write-Error "This script needs the file ${ApiName}_${MethodName}_head_dev.pck. (Use -Command init to generate one.)"
	Exit 1
}

If (Test-Path "${ApiName}_${MethodName}_body_dev.pck") {
	$Section4After =
		Get-Content -LiteralPath "${ApiName}_${MethodName}_body_dev.pck"
} Else {
	Write-Error "This script needs the file ${ApiName}_${MethodName}_body_dev.pck. (Use -Command init to generate one.)"
	Exit 1
}

$After =
	$Section1 +
	$Section2After +
	$Section3 +
	$Section4After +
	$Section5

$After | Set-Content "${ApiName}_${TnsName}_${DateString}_out.pck"
$After | Set-Content "${ApiName}.pck"

$sqlQuery = @"
SET TIMING ON
SET SQLBLANKLINES ON
SET DEFINE OFF
SET SQLPREFIX OFF
SET BLOCKTERMINATOR OFF
@"${ApiName}.pck"
SET ECHO ON
SHOW ERRORS PACKAGE ${ApiName}
SHOW ERRORS PACKAGE BODY ${ApiName}
EXIT
"@

$sqlQuery | sqlplus -s /@$TnsName

Write-Host Done. Be sure to check in "${ApiName}.pck" to source control.
