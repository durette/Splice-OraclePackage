# Splice-OraclePackage
Edit a single method inside of an Oracle Database package, leaving the rest of the package in-tact.

## Purpose
In the specific use case of a legacy ERP, customer-specific extensions might be deployed to a very large monolithic package. ("We're only going to change a few things.") Any changes to this package must be coordinated with other developers who might be editing the package, since the package can only be deployed as a whole entire unit. This serializes development.

To reduce the time and risk of doing this manually and to break the dependency on the whole package from a change control perspective, this sript splices a new header specification and a new body implementation for a single procedure or function inside of a package, replacing the old version of that procedure or function.

## Prerequisites
* The method must already exist in the target package. This is not for deploying new methods. (If you recognize you're in this situation, you should be creating new packages instead of making your monolithic package bigger.)
* The new versions of the method's head and body should be contained in these files in the current working directory. (There's an "init" command available to grab the code from PROD as a starting point.)
  * <code>${ApiName}_${MethodName}_head_dev.pck</code>
  * <code>${ApiName}_${MethodName}_body_dev.pck</code>
* The TNS names must be set up with Oracle Wallet authentication, allowing the use of passwordless authentication like this:
  * <code>sqlplus /@tns_prod_environment @"myscript.sql"</code>
  * <code>sqlplus /@tns_dev_environment @"myscript.sql"</code>

## Example

\# We want to start developing, so let's get the current version from PROD as a baseline.<br />
<code>.\splice_api.ps1 -Command init tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING</code>

\# We'll make our changes to these filess:<br />
  * <code>C_BIG_MONOLITHIC_PACKAGE_API_THE_ONE_PROCEDURE_IM_CHANGING_head_dev.pck</code>
  * <code>C_BIG_MONOLITHIC_PACKAGE_API_THE_ONE_PROCEDURE_IM_CHANGING_body_dev.pck</code>

\# We'll deploy our changes to our DEV environment for alpha testing:<br />
<code>.\splice_api.ps1 -TnsName tns_dev_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING</code>

\# After any other testing, we'll deploy our changes to PROD. Other functions or procedures in the package may have changed since we took our initial snapshot, but we won't disturb them.<br />
<code>.\splice_api.ps1 -TnsName tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING</code>

## Setting up Oracle Wallet Authentication

Change everything that starts with "MY_" to your own values. These directions assume you're running Windows on the client machine.

### TNSNAMES.ORA on client

    MY_ENVIRONMENT =
      (DESCRIPTION =
        (ADDRESS = (PROTOCOL = TCP)(HOST = MY_ENVIRONMENT_DB_SERVER)(PORT = 1521))
        (CONNECT_DATA =
          (SERVER = DEDICATED)
          (SERVICE_NAME = MY_ENVIRONMENT_SERVICE_NAME)
        )
      )

### SQLNET.ORA on client

    SQLNET.WALLET_OVERRIDE=TRUE
    
    WALLET_LOCATION=
      (SOURCE=(METHOD=FILE)
      (METHOD_DATA=(DIRECTORY=c:\oracle\wallet)))

### Create wallet from command prompt

    set ORACLE_HOME=c:\oracle\product\12.1.0\client_1
    mkstore -create -wrl c:\oracle\wallet
    mkstore -wrl c:\oracle\wallet -createCredential MY_ENVIRONMENT MY_USERNAME MY_PASSWORD

### Use the wallet

    sqlplus /@MY_ENVIRONMENT

### Update the password

    mkstore -wrl c:\oracle\wallet -modifyCredential MY_ENVIRONMENT MY_USERNAME

