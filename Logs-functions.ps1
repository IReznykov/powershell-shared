
Function New-CloudWatch-LogGroup {
    <#
    .SYNOPSIS
    New-CloudWatch-LogGroup Function create new CloudWatch log group and return its ARN.
    .DESCRIPTION
    New-CloudWatch-LogGroup Function create new CloudWatch log group and return its ARN. If Cloud Watch log group is not created, $null is returned.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (
        # log group name
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Default')]
        [string]$LogsGroupName,

        # log group name
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Default')]
        [int]$RetentionDays = 180,

        # Tags that are added to AWS resources in the form @( "Key=Key1,Value=Value1", "Key=Key2,Value=Value2" )
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Default')]
        [array]$Tags = $null,
        
        # region name
        [Parameter(Mandatory = $false)]
        [string]$RegionName = "us-west-1",

        # AWS profile name from User .aws config file
        [Parameter(Mandatory = $false)]
        [string]$AwsProfile = "default"
    )
    Begin {
        $functionName = $($myInvocation.MyCommand.Name);
        Write-Host "$($functionName)(LogGroup=$LogsGroupName, region=$RegionName, profile=$AwsProfile) starts." -ForegroundColor Blue;

        $logsGroupARN = $null;
    }
    Process {
        # due to log group create command doesn't return any output
        # at first step we check does the log group with the name exist
        # if it exists, return its ARN
        # at second step we create new log group and repeat the first step
        # loop is run at most two times, and completing the loop means the error
        $attempt = 0;
        do {
            $jsonObjects = $null;
            $strJsonObjects = $null;
            $awsObjects = $null;
            $existObject = $false;
        
            # get log group
            $queryRequest = "logGroups[?logGroupName==``$LogsGroupName``]";
            $jsonObjects = aws --output json --profile $AwsProfile --region $RegionName --color on `
                logs describe-log-groups `
                --log-group-name-prefix $LogsGroupName `
                --query $queryRequest;
    
            if (-not $?) {
                Write-Host "Listing CloudWatch log groups failed" -ForegroundColor Red;
                return $null;
            }

            if ($jsonObjects) {
                $strJsonObjects = [string]$jsonObjects;
                $awsObjects = ConvertFrom-Json -InputObject $strJsonObjects;
                $existObject = ($awsObjects.Count -gt 0);
            }
            if ($existObject) {
                $logsGroupARN = $awsObjects.arn;
                Write-Verbose "Log group '$LogsGroupName' is found, ARN=$logsGroupARN";
                return $logsGroupARN;
            }
    
            # create log group
            if (-not $existObject) {
                Write-Verbose "Log group '$LogsGroupName' doesn't exists, let's create it";
                # no output
                aws --output json --profile $AwsProfile --region $RegionName --color on `
                    logs create-log-group `
                    --log-group-name $LogsGroupName `
                    --tags $Tags;
            
                if (-not $?) {
                    Write-Host "Creating CloudWatch log group failed" -ForegroundColor Red;
                    return $null;
                }
    
                # no output
                aws --output json --profile $AwsProfile --region $RegionName --color on `
                    logs put-retention-policy `
                    --log-group-name $LogsGroupName `
                    --retention-in-days $RetentionDays;
            
                if (-not $?) {
                    Write-Host "Updating CloudWatch log group failed" -ForegroundColor Red;
                    return $null;
                }
            }
            ++$attempt;
        } while ($attempt -lt 2);
    
        Write-Verbose "CloudWatch log group is not created";
        return $null;
    }
    End {
        Write-Host "$($functionName) ends." -ForegroundColor Blue;
    }
}
