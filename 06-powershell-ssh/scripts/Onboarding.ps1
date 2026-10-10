<#
.SYNOPSIS
    Crea utenti Active Directory da un file CSV e li inserisce nel gruppo del reparto.
.DESCRIPTION
    Per ogni riga del CSV (Nome, Cognome, Username, Reparto):
      - crea l'utente nella OU Azienda\<Reparto>\Utenti
      - imposta il cambio password al primo accesso
      - lo aggiunge al gruppo GG_<Reparto>
    Lo script e' idempotente: puo' essere rieseguito senza creare duplicati.
    La password iniziale viene chiesta a video e non e' salvata nel file.
#>
param(
    [string]$CsvPath = "C:\Scripts\nuovi_utenti.csv",
    [string]$Dominio = "azienda.local",
    [string]$BaseDN  = "OU=Azienda,DC=azienda,DC=local"
)

$password = Read-Host "Password iniziale (min. 10 caratteri, maiuscole, minuscole, numeri, simboli)" -AsSecureString

foreach ($u in Import-Csv $CsvPath) {
    $sam    = $u.Username
    $ou     = "OU=Utenti,OU=$($u.Reparto),$BaseDN"
    $gruppo = "GG_$($u.Reparto)"

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'")) {
        try {
            New-ADUser -Name "$($u.Nome) $($u.Cognome)" -GivenName $u.Nome -Surname $u.Cognome `
                -SamAccountName $sam -UserPrincipalName "$sam@$Dominio" -Path $ou `
                -AccountPassword $password -ChangePasswordAtLogon $true -Enabled $true -ErrorAction Stop
            Write-Host "Creato $sam in $($u.Reparto)" -ForegroundColor Green
        } catch {
            Write-Warning "Errore creazione ${sam}: $($_.Exception.Message)"
            # pulizia: se e' rimasto un utente a meta (es. password rifiutata dalla policy), lo rimuove
            $parziale = Get-ADUser -Filter "SamAccountName -eq '$sam'"
            if ($parziale) { Remove-ADUser -Identity $parziale -Confirm:$false }
            continue
        }
    } else {
        Write-Host "$sam esiste gia" -ForegroundColor Yellow
    }

    try {
        $membri = (Get-ADGroupMember -Identity $gruppo).SamAccountName
        if ($membri -notcontains $sam) {
            Add-ADGroupMember -Identity $gruppo -Members $sam -ErrorAction Stop
            Write-Host "$sam aggiunto a $gruppo" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Errore gruppo per ${sam}: $($_.Exception.Message)"
    }
}
