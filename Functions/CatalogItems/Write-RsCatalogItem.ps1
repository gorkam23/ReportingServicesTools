# Copyright (c) 2016 Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT License (MIT)

<#
.SYNOPSIS
    Uploads an item from disk to a repot server.

.DESCRIPTION
    Uploads an item from disk to a repot server.
    Currently, we are only supporting Report, DataSource and DataSet for uploads

.PARAMETER ReportServerUri
    Specify the Report Server URL to your SQL Server Reporting Services Instance.
    Has to be provided if proxy is not provided.

.PARAMETER ReportServerCredentials
    Specify the credentials to use when connecting to your SQL Server Reporting Services Instance.

.PARAMETER proxy
    Report server proxy to use. 
    Has to be provided if ReportServerUri is not provided.

.PARAMETER Path
    Path to item to upload on disk.

.PARAMETER Destination
    Folder on reportserver to upload the item to.

.PARAMETER override
    Override existing catalog item.

.EXAMPLE
    Write-RsCatalogItem -ReportServerUri 'http://localhost/reportserver_sql2012' -Path c:\reports\monthlyreport.rdl -Destination /monthlyreports
   
    Description
    -----------
    Uploads the report monthlyreport.rdl to folder /monthlyreports
#>

function Write-RsCatalogItem
{
    param(
        [string]
        $ReportServerUri = 'http://localhost/reportserver',
                
        [System.Management.Automation.PSCredential]
        $ReportServerCredentials,
        
        $Proxy,
        
        [Parameter(Mandatory=$True)]
        [string]
        $Path,
        
        [Parameter(Mandatory=$True)]
        [string]
        $Destination,
        
        [switch]
        $Override
    )

    function Get-ItemType
    {
        param(
            [string]$FileExtension
        )

        if($FileExtension -eq '.rdl')
        {
            return 'Report'
        }
        elseif ($FileExtension -eq '.rsds') 
        {
            return 'DataSource'
        }
        elseif ($FileExtension -eq '.rsd')
        {
            return 'DataSet'
        }
        else
        {
            throw 'Uploading currently only supports .rdl, .rsds and .rsd files'
        }
    }
    
    if(-not $Proxy)
    {
        $Proxy = New-RSWebServiceProxy -ReportServerUri $ReportServerUri -Credentials $ReportServerCredentials 
    }

    if (!(Test-Path $Path))
    {
        throw "No item found at the specified path: $Path!"
    }

    $EntirePath = Resolve-Path $Path
    $item = Get-Item $EntirePath 
    $itemType = Get-ItemType $item.Extension
    $itemName = $item.BaseName
    
    
    if($Destination -eq "/")
    {
        Write-Verbose "Uploading $EntirePath to /$($itemName)"
    }
    else 
    {
        Write-Verbose "Uploading $EntirePath to $Destination/$($itemName)"        
    }
    
    if ($itemType -eq 'DataSource') 
    {
        [xml] $content = Get-Content -Path $EntirePath
        if ($content.DataSourceDefinition -eq $null)
        {
            throw "Data Source Definition not found in the specified file: $EntirePath!"
        }

        $extension = $content.DataSourceDefinition.Extension
        $connectionString = $content.DataSourceDefinition.ConnectString
        $enabled = $content.DataSourceDefinition.Enabled
        $credentialRetrieval = 'None'

        $newDataSourceCmd = "New-RsDataSource -Destination $Destination -Name $itemName -Extension $extension -CredentialRetrieval $credentialRetrieval"

        if (![String]::IsNullOrEmpty($connectionString))
        {
            $newDataSourceCmd = $newDataSourceCmd + " -ConnectionString $connectionString"
        }

        if ($Override)
        {
            if ($enabled -eq $false)
            {
                New-RsDataSource -Proxy $Proxy -Destination $Destination -Name $itemName -Extension $extension -ConnectionString $connectionString -CredentialRetrieval $credentialRetrieval -Disabled -Overwrite | Out-Null
            }
            else 
            {
                New-RsDataSource -Proxy $Proxy -Destination $Destination -Name $itemName -Extension $extension -ConnectionString $connectionString -CredentialRetrieval $credentialRetrieval -Overwrite | Out-Null
            }
        }
        else 
        {
            if ($enabled -eq $false)
            {
                New-RsDataSource -Proxy $Proxy -Destination $Destination -Name $itemName -Extension $extension -ConnectionString $connectionString -CredentialRetrieval $credentialRetrieval -Disabled | Out-Null
            }
            else 
            {
                New-RsDataSource -Proxy $Proxy -Destination $Destination -Name $itemName -Extension $extension -ConnectionString $connectionString -CredentialRetrieval $credentialRetrieval | Out-Null
            }  
        }
    } 
    else 
    {
        $bytes = [System.IO.File]::ReadAllBytes($EntirePath)
        $warnings = $null
        $Proxy.CreateCatalogItem($itemType, $itemName, $Destination, $override, $bytes, $null, [ref]$warnings) | Out-Null
    }

    Write-Information "$EntirePath was uploaded to $Destination successfully!"
}