# Copyright (c) 2002-2015 "Neo Technology,"
# Network Engine for Objects in Lund AB [http://neotechnology.com]
#
# This file is part of Neo4j.
#
# Neo4j is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


<#
.SYNOPSIS
Starts a Neo4j Server instance

.DESCRIPTION
Starts a Neo4j Server instance either as a java console application or Windows Service

.PARAMETER Neo4jServer
An object representing a Neo4j Server.  Either an empty string (path determined by Get-Neo4jHome), a string (path to Neo4j installation) or a valid Neo4j Server object

.PARAMETER Console
Start the Neo4j Server instance as a java console application

.PARAMETER ServiceName
The name of the Neo4j Server Windows Service.  If no name is specified, the name is determined from the Neo4j Configuration files (default)

.PARAMETER Wait
Wait for the java console application to finish execution

.PARAMETER PassThru
Pass through the Neo4j Server object instead of the result of the start operation

.EXAMPLE
'C:\Neo4j\neo4j-enterprise' | Start-Neo4jServer

Start the Neo4j Server Windows Service for the Neo4j installation at 'C:\Neo4j\neo4j-enterprise'

.EXAMPLE
'C:\Neo4j\neo4j-enterprise' | Start-Neo4jServer -Console -Wait

Start the Neo4j Server for the Neo4j installation at 'C:\Neo4j\neo4j-enterprise' and wait for the execution to complete

.OUTPUTS
System.Management.Automation.PSCustomObject
Neo4j Server object

System.Int
Process ExitCode for the console application

System.ServiceProcess.ServiceController
Windows Service object

#>
Function Start-Neo4jServer
{
  [cmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium',DefaultParameterSetName='WindowsService')]
  param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    [object]$Neo4jServer = ''

    ,[Parameter(Mandatory=$true,ParameterSetName='Console')]
    [switch]$Console

    ,[Parameter(Mandatory=$false,ParameterSetName='Console')]
    [switch]$Wait

    ,[Parameter(Mandatory=$false)]
    [switch]$PassThru   
    
    ,[Parameter(Mandatory=$false,ParameterSetName='WindowsService')]
    [string]$ServiceName = ''
  )
  
  Begin
  {
  }

  Process
  {
    # Get the Neo4j Server information
    if ($Neo4jServer -eq $null) { $Neo4jServer = '' }
    switch ($Neo4jServer.GetType().ToString())
    {
      'System.Management.Automation.PSCustomObject'
      {
        if (-not (Confirm-Neo4jServerObject -Neo4jServer $Neo4jServer))
        {
          Write-Error "The specified Neo4j Server object is not valid"
          return
        }
        $thisServer = $Neo4jServer
      }      
      default
      {
        $thisServer = Get-Neo4jServer -Neo4jHome $Neo4jServer
      }
    }
    if ($thisServer -eq $null) { return }
    
    if ($PsCmdlet.ParameterSetName -eq 'Console')
    {    
      $JavaCMD = Get-Java -Neo4jServer $thisServer -ForServer
      if ($JavaCMD -eq $null)
      {
        Write-Error 'Unable to locate Java'
        return
      }

      $result = 0
      if ($PSCmdlet.ShouldProcess("$($JavaCMD.java) $($JavaCMD.args)", 'Start Neo4j'))
      {
        $result = (Start-Process -FilePath $JavaCMD.java -ArgumentList $JavaCMD.args -Wait:$Wait -NoNewWindow:$Wait -PassThru -WorkingDirectory $thisServer.Home)
      }
      
      if ($PassThru) { Write-Output $thisServer } else { Write-Output $result.ExitCode }
    }
    
    if ($PsCmdlet.ParameterSetName -eq 'WindowsService')
    {
      if ($ServiceName -eq '')
      {
        $setting = ($thisServer | Get-Neo4jSetting -ConfigurationFile 'neo4j-wrapper.conf' -Name 'wrapper.name')
        if ($setting -ne $null) { $ServiceName = $setting.Value }
      }

      if ($ServiceName -eq '')
      {
        Write-Error 'Could not find the Windows Service Name for Neo4j'
        return
      }

      $result = Start-Service -Name $ServiceName -PassThru
      if ($PassThru) { Write-Output $thisServer } else { Write-Output $result }
    }
  }
  
  End
  {
  }
}
