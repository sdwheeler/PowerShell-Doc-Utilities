USING MODULE CommonClasses

function Test-MDReference () {
    [CmdletBinding(DefaultParameterSetName="AssetList")]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
            [ValidateNotNullOrEmpty()]
            [MDReference]$Reference,
        [Parameter(Mandatory = $true, ParameterSetName="CollectionFolder")]
            [ValidateNotNullOrEmpty()]
            [ValidateScript( {Test-Path -Path $_ -PathType Container })]
            [string]$CollectionFolder,
        [Parameter(Mandatory = $true, ParameterSetName="AssetList")]
            [ValidateNotNullOrEmpty()]
            [hashtable]$AssetList,
        [switch]$OnlyFailed
        
    )
    
    BEGIN {
        if ($PSCmdlet.ParameterSetName -eq "CollectionFolder") {
            $AssetList = Get-AssetList -AssetFolder $CollectionFolder
        }
        
        $MDHeadingsCache = @{}
    } 

    PROCESS {
        if($Reference.Link -like "http*"){
            $r = Test-HttpUrl -url ($Reference.Link)

            if(($r.StatusCode -ge 200) -and ($r.StatusCode -le 299)){
                $Reference.ReferenceStatus = [MDReferenceStatus]::Passed
            }
            else {
                $Reference.ReferenceStatus = [MDReferenceStatus]::Failed
            }
        }
        else {
            $Reference.ReferenceStatus = [MDReferenceStatus]::Failed
            if (-not [string]::IsNullOrWhiteSpace($Reference.Link)) {
                $externalexists = $false
                $internalexists = $false 
                [string]$externallink = $Reference.GetExternalLink().Replace('/','\')
                [string]$internallink = $Reference.GetInternalLink()
                [string]$fulllink = [string]::Empty

                ## Test external link
                if ([string]::IsNullOrWhiteSpace($externallink)) {
                    ## reference to document itself
                    $externalexists = $true 
                    $fulllink = $Reference.DocumentPath
                }
                else {
                    $relativelink = Join-Path -Path ([System.IO.Path]::GetDirectoryName($Reference.DocumentPath)) -ChildPath $externallink
                    $externalexists = Test-Path -Path $relativelink -PathType Leaf

                    if($externalexists){
                        ## Check relative link is in the assets collection
                        $fulllink = [System.IO.Path]::GetFullPath($relativelink)
                        $documentname = [System.IO.Path]::GetFileName($fulllink)
                        $externalexists = $AssetList[$documentname] -contains $fulllink
                    }
                }

                ## Test internal link
                if([string]::IsNullOrWhiteSpace($internallink)){
                    $internalexists = $true                     
                }elseif($externalexists){
                    if(-not $MDHeadingsCache.ContainsKey($fulllink)) {
                        $MDHeadingsCache.Add($fulllink, (Get-MDHeadingReferences -DocumentPath $fulllink))
                    }

                    $internalexists = $MDHeadingsCache[$fulllink].ContainsKey($internallink)                     
                }

                if($externalexists -and $internalexists){
                    $Reference.ReferenceStatus = [MDReferenceStatus]::Passed
                }
            }
        }

        if ($OnlyFailed) {
            if ($Reference.ReferenceStatus -ne [MDReferenceStatus]::Passed) {
                $Reference
            }
        }
        else{
            $Reference
        }
    }
}