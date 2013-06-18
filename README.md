SYNOPSIS
========

Operation Dashboard

DESCRIPTION
===========

The dashboard is intended to be used for performing health check tasks for IT systems.

NOTES
=====

Version     : 1.0

Date        : 18 June 2013

Author      : Chris C CHAU

Requires    : PowerShell V3 & .NET framework 4.0

COMPONENT
=========

Main file   : Dashboard.ps1

Includes    :

    Check-Status.ps1 (Routines for health checkings)
    Dashboard.xaml (Defination file for the GUI)
    Dashboard.xml (Configuration file for tasks to be checked)
    plink.exe (Plink executable from PuTTY for remote running UNIX scripts, which needs to be downloaded separated.)
    putty.exe (PuTTY executable from PuTTY for accessing UNIX Operator Menu, which needs to be downloaded separated.)
    putty-registry.reg (Registry of PuTTY configurations. regedit /e putty-registry.reg HKEY_CURRENT_USER\Software\Simontatham)
    prd_svc_caps.ppk (Private key to authenticate the Dashboard with remote UNIX hosts)
    AIX.jpg (Icon for UNIX Operator Menu button)
    Windows (Icon for Windows Operator Menu button)

FUNCTIONALITY
=============

- To perform health check tasks for both Windows and UNIX servers
    
- To launch Operator Menu for administrative tasks

LICENSE
=======

The code is licensed under the GNU GPL license.
