# Splice-Oracle-Package
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
<code>.\splice_api.ps1 -Command init tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING</code>

<code>.\splice_api.ps1 -TnsName tns_prod_environment -ApiName C_BIG_MONOLITHIC_PACKAGE_API -MethodType PROCEDURE -MethodName THE_ONE_PROCEDURE_IM_CHANGING</code>
