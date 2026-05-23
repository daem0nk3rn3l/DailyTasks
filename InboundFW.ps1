Get-NetFirewallRule |
	# Where-Object {($_.Profiles -band [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.Profile]::Domain) -or ($_.Profiles -eq [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.Profile]::Any)} |
Where-Object {(($_.Profiles -band 1) -or ($_.Profiles -like 'Any')) -and $_.Direction -like 'Inbound'} |	
ForEach-Object {
		$portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_
		$_ | Select-Object -Property `
			Name,
			DisplayName,
			DisplayGroup,
			Profiles,
			Direction,
			@{n='Protocol'; e={$portFilter.Protocol}},
			@{n='LocalPort'; e={$portFilter.LocalPort}},
			@{n='RemotePort'; e={$portFilter.RemotePort}},
			@{n='RemoteAddress'; e={(Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $_).RemoteAddress}},
			Enabled,
			Profile,
			Action
	} | Out-GridView
