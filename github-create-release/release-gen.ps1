#
# Define all necessary variables
# ---------------------------------------------------------
# $global:github_repository = "GITHUB_REPOSITORY"
# $global:github_token = "GitHub Personal Access Token"
# $global:current_commitId = $env:APPVEYOR_REPO_COMMIT
# $global:last_release_version = "Last release version"
# $global:release_version = "Release version"


$issue_closing_pattern = new-object System.Text.RegularExpressions.Regex('([Cc]loses|[Ff]ixes) +#\d+',[System.Text.RegularExpressions.RegexOptions]::Singleline)

#
# GitHub API
# ---------------------------------------------------------
$github = New-Module -ScriptBlock {
    function GetCommits {
        param([string] $base, [string] $head)
		$headers = @{
		    'Authorization' = 'token ' + $github_token
		    'Accept' = 'application/vnd.github.v3+json'
		}
		$url = "https://api.github.com/repos/$github_repository/compare/" + $base + "..." + $head
		Write-Host ($url)
        return  Invoke-RestMethod -Uri $url -Verbose -Headers $headers
    }

    function GetLastReleaseVersion {
        $headers = @{
		    'Authorization' = 'token ' + $github_token
		    'Accept' = 'application/vnd.github.v3+json'
		}
		$url = "https://api.github.com/repos/$github_repository/releases/latest"
		Write-Host ($url)
        return  Invoke-RestMethod -Uri $url -Verbose -Headers $headers
    }
 
    Export-ModuleMember -Function GetCommits
    Export-ModuleMember -Function GetLastReleaseVersion
} -AsCustomObject
 
#
# Get all \ts from latest deployment to this commit
# ---------------------------------------------------------

Write-Host ("Getting all commits from git tag v" + $last_release_version + " to commit sha $current_commitId.")

$response_last_release_version = $github.GetLastReleaseVersion()
$last_release_version = $response_last_release_version.tag_name
Write-Host $response_last_release_version
Write-Host $last_release_version

$response_commits = $github.GetCommits($last_release_version, $current_commitId)
$commits = $response_commits.commits | Sort-Object -Property @{Expression={$_.commit.author.date}; Ascending=$false} -Descending
#
# Generate release notes based on commits and issues
# ---------------------------------------------------------
Write-Host "Generating release notes based on commits."
$nl = [Environment]::NewLine

$releaseNotes = "## Release Notes<br/>$nl" +
"#### Version [" + $release_version + "](https://github.com/$github_repository/tree/" + $release_version + ")$nl"

if ($commits -ne $null) {

	$releaseNotes = $releaseNotes + "Commit | Description<br/>$nl" + "------- | -------$nl"

	foreach ($commit in $commits) {
		
		$commitMessage = $commit.commit.message.Replace("`r`n"," ").Replace("`n"," ");
		$m = $issue_closing_pattern.Matches($commitMessage)

		foreach($match in $m) {
					$issueNumber = [regex]::Replace($match, "([Cc]loses|[Ff]ixes) +#", "");
					$matchLink = "<a href='https://github.com/$github_repository/issues/$issueNumber' target='_blank'>$match</a>";
					$commitMessage = [regex]::Replace($commitMessage, $match, $matchLink);
		}

		if (-Not $commit.commit.message.ToLower().StartsWith("merge") -and
			-Not $commit.commit.message.ToLower().StartsWith("merging") -and
			-Not $commit.commit.message.ToLower().StartsWith("private")) {
		  
			$releaseNotes = $releaseNotes + "[" + $commit.sha.Substring(0, 10) + "](https://github.com/$github_repository/commit/" + $commit.sha + ") | " + $commit.commit.message.Replace("`r`n"," ").Replace("`n"," ") + "$nl"
		}

		
		if ($commit.commit.message.ToLower().StartsWith("private")) {
			$releaseNotes = $releaseNotes + "[" + $commit.sha.Substring(0, 10) + "](https://github.com/$github_repository/commit/" + $commit.sha + ") | " + $commit.commit.message.Replace("`r`n"," ").Replace("`n"," ") + "$nl"
		}

	}
 
}
else {
    $releaseNotes = $releaseNotes + "There are no new items for this release.$nl"
}

New-Item $github_workspace/releasenotes.txt -type file -force -value $releaseNotes
#Write-Output "::set-env name=RELEASE_NOTES::$releaseNotes.Replace($nl, '\n')"
::set-output name=RELEASE_NOTES::$releaseNotes.Replace($nl, '\n')