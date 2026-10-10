<#
.SYNOPSIS
    Offboarding di un utente Active Directory.
.DESCRIPTION
    Per l'utente indicato:
      - registra data e gruppi di appartenenza nella descrizione
      - lo rimuove dai gruppi
      - disabilita l'account
      - lo sposta nella OU Disabilitati
    L'account non viene eliminato. Supporta -WhatIf. E' idempotente.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Username,
    [string]$OuDisabilitati = "OU=Disabilitati,OU=Azienda,DC=azienda,DC=local"
)

$utente = Get-ADUser -Filter "SamAccountName -eq '$Username'" -Properties MemberOf
if (-not $utente) { Write-Warning "Utente $Username non trovato"; return }

if ($utente.DistinguishedName -like "*$OuDisabilitati") {
    Write-Host "$Username risulta gia disabilitato" -ForegroundColor Yellow
    return
}

try {
    $nomiGruppi = $utente.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }
    $descrizione = "Disabilitato il $(Get-Date -Format 'yyyy-MM-dd') - gruppi: $($nomiGruppi -join ', ')"

    Set-ADUser -Identity $utente -Description $descrizione -ErrorAction Stop
    foreach ($g in $utente.MemberOf) {
        Remove-ADGroupMember -Identity $g -Members $utente -Confirm:$false -ErrorAction Stop
    }
    Disable-ADAccount -Identity $utente -ErrorAction Stop
    Move-ADObject -Identity $utente.DistinguishedName -TargetPath $OuDisabilitati -ErrorAction Stop

    if ($WhatIfPreference) {
        Write-Host "Simulazione terminata per $Username (nessuna modifica)" -ForegroundColor Cyan
    } else {
        Write-Host "Offboarding completato per $Username" -ForegroundColor Green
    }
} catch {
    Write-Warning "Errore durante l'offboarding di ${Username}: $($_.Exception.Message)"
}
