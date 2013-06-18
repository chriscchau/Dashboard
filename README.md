# Description

The dashboard is intended to be used for performing health check tasks for IT systems.

# Notes

Version :

    1.0

Date :

    18 June 2013

Author :
    
    Chris C CHAU

Requires :
    
    PowerShell V3 & .NET framework 4.0

# Components

Main file :
    
    Dashboard.ps1

Includes :

    Check-Status.ps1 (Routines for health checkings)
    Dashboard.xaml (Defination file for the GUI)
    Dashboard.xml (Configuration file for tasks to be checked)
    plink.exe (Plink executable from PuTTY for remote running UNIX scripts, which needs to be downloaded separated.)
    putty.exe (PuTTY executable from PuTTY for accessing UNIX Operator Menu, which needs to be downloaded separated.)
    putty-registry.reg (Registry of PuTTY configurations. regedit /e putty-registry.reg HKEY_CURRENT_USER\Software\Simontatham)
    prd_svc_caps.ppk (Private key to authenticate the Dashboard with remote UNIX hosts)
    AIX.jpg (Icon for UNIX Operator Menu button)
    Windows.jpg (Icon for Windows Operator Menu button)

# Functionality

- To perform health check tasks for both Windows and UNIX servers
    
- To launch Operator Menu for administrative tasks

# Legal

The code is released under the GNU General Public License.
