# Fase 4 - Group Policy

Le GPO sono gestite tramite **Group Policy Management** su DC01.

## Concetti applicati
- **Ereditarietà**: una GPO collegata a una OU si applica anche alle sue sotto-OU
- **Ordine di applicazione (LSDOU)**: Local, Site, Domain, OU
- **User Configuration vs Computer Configuration**: la prima segue l'OU dell'utente, la seconda quella del computer
- La password policy del dominio si imposta solo a livello di dominio, non su una OU
- Le *Preferences* (come le unità di rete) si applicano al **login**: richiedono logoff e nuovo accesso, `gpupdate` da solo non è sufficiente

## Riepilogo delle GPO

| GPO | Collegata a | Tipo | Effetto |
|---|---|---|---|
| Default Domain Policy (modificata) | Dominio | Computer | Password policy e blocco account |
| GPO_Stagisti_BloccoPannello | OU Stagisti | Utente | Blocca il Pannello di controllo |
| GPO_Stagisti_BloccoUSB | OU Stagisti | Utente | Nega l'accesso alle periferiche removibili |
| GPO_Drive_Amministrazione | OU Amministrazione | Utente | Mappa `A:` su `\\FS01\Amministrazione` |
| GPO_Drive_Vendite | OU Vendite | Utente | Mappa `V:` su `\\FS01\Vendite` |
| GPO_Drive_IT | OU IT | Utente | Mappa `I:` su `\\FS01\IT` |
| GPO_Drive_Stagisti | OU Stagisti | Utente | Mappa `S:` su `\\FS01\Stagisti` |
| GPO_Drive_Comune | OU Azienda | Utente | Mappa `Z:` su `\\FS01\Comune` (ereditata da tutti i reparti) |

Le GPO collegate a ogni OU, in Group Policy Management:

![GPO collegate alle OU](images/03-01-struttura-ou-e-gpo.png)

## GPO 1 - GPO_Stagisti_BloccoPannello
- **Policy**: User Configuration > Administrative Templates > Control Panel > *Prohibit access to Control Panel and PC settings* = Enabled

![Editor della GPO con la policy su Enabled](images/04-01-gpo-blocco-pannello-editor.png)

- **Verifica**: sul client, con un utente Stagista, l'apertura del Pannello di controllo viene bloccata; con un utente di un altro reparto si apre normalmente.

![Messaggio Restrictions sul client](images/04-02-gpo-blocco-pannello-risultato.png)

## GPO 2 - Password policy e blocco account
- **Modificata**: *Default Domain Policy* (livello dominio)
- **Percorso**: Computer Configuration > Windows Settings > Security Settings > Account Policies

| Impostazione | Valore |
|---|---|
| Minimum password length | 10 caratteri |
| Password complexity | Enabled |
| Maximum password age | 60 giorni |
| Enforce password history | 24 password (default) |
| Account lockout threshold | 5 tentativi |
| Account lockout duration | 15 minuti |
| Reset lockout counter after | 15 minuti |

![Password policy](images/04-03-password-policy.png)

![Account lockout policy](images/04-04-lockout-policy.png)

**Verifica del blocco**: dopo 5 tentativi di accesso errati l'utente `a.fonti` risulta bloccato.

![Account bloccato al login](images/04-05-account-bloccato-login.png)

**Sblocco da interfaccia grafica**: *Properties > Account > Unlock account*.

![Sblocco dell'account da Active Directory Users and Computers](images/04-06-sblocco-account-gui.png)

**Sblocco da PowerShell**:

```powershell
Unlock-ADAccount -Identity a.fonti
```

![Sblocco con Unlock-ADAccount](images/04-07-sblocco-account-powershell.png)

## GPO 3 - GPO_Stagisti_BloccoUSB
- **Policy**: User Configuration > Administrative Templates > System > Removable Storage Access > *All Removable Storage classes: Deny all access* = Enabled
- Scelta progettuale: l'impostazione è in **User Configuration** (e non Computer), in modo da colpire gli utenti Stagisti su qualsiasi computer.

![Editor della GPO USB](images/04-08-gpo-usb-editor.png)

`gpresult` sul client con un utente Stagista: sono applicate `GPO_Stagisti_BloccoPannello` e `GPO_Stagisti_BloccoUSB`.

![gpresult con le GPO Stagisti applicate](images/04-09-gpo-usb-gpresult.png)

**Verifica**: il dispositivo USB è visibile ma l'accesso al contenuto restituisce **"Access is denied"**; con un utente di un altro reparto il contenuto è accessibile.

![E: is not accessible - Access is denied](images/04-10-gpo-usb-access-denied.png)

## GPO 4 - Mappatura delle unità di rete
Ogni reparto dispone di una GPO collegata alla propria OU; una GPO comune è collegata alla OU `Azienda`.

- **Percorso**: User Configuration > Preferences > Windows Settings > Drive Maps > New > Mapped Drive
- **Action**: Create, **Reconnect** attivo, label e lettera come nella tabella di riepilogo

![Editor di GPO_Drive_Vendite con l'unità V:](images/04-11-gpo-drive-vendite-editor.png)

**Verifica con un utente di Vendite** (logoff e nuovo accesso): l'unità `V:` compare in *This PC > Network locations*.

![Unità V: mappata](images/04-12-drive-v-mappata.png)

L'output di `gpresult /r /scope user` per `l.verdi` mostra `GPO_Drive_Vendite` tra le GPO applicate e, tra i gruppi, sia `GG_Vendite` sia `DL_Vendite_RW`, a conferma della catena AGDLP.

![gpresult di l.verdi](images/04-13-gpresult-l-verdi.png)

Un utente di un altro reparto non visualizza `V:`:

![Utente di un altro reparto senza V:](images/04-14-altro-reparto-senza-v.png)

**Risultato finale con la GPO comune**: ogni utente dispone della propria unità di reparto più `Z:`.

| Utente | Reparto | Unità mappate |
|---|---|---|
| l.verdi | Vendite | `V:` e `Z:` |
| m.rossi | Amministrazione | `A:` e `Z:` |
| a.fonti | Stagisti | `S:` e `Z:` (più le GPO di restrizione) |

Vendite:

![V: e Z: per un utente di Vendite](images/04-16-vendite-v-e-z.png)

Amministrazione (`GPO_Drive_Amministrazione` e `GPO_Drive_Comune`):

![A: e Z: per un utente di Amministrazione](images/04-17-amministrazione-a-e-z.png)

Stagisti (le due GPO di restrizione, `GPO_Drive_Stagisti` e `GPO_Drive_Comune`):

![S: e Z: per un utente Stagista](images/04-15-stagisti-s-e-z.png)

La `GPO_Drive_Comune` è collegata più in alto, alla OU `Azienda`, e per **ereditarietà** arriva a tutti i reparti.

## Comandi di diagnostica
```
gpupdate /force
gpresult /r /scope user
gpresult /r
```
