# NewIdeaScript.ps1
#
# Version History
# v0.1 -STESURA INIZIALE  Lo Script modifica la configurazione dei computer per Client:
#                          - Rinomina il computer.
#                          - Imposta la password per l'account amministratore locale.
#                          - Crea un nuovo utente chiamato "Ospite" con una password predefinita.
# v0.2                     - Crea un nuovo gruppo chiamato "Utenti Locali" e sposta l'account amministratore all'interno di esso.
#                          - Crea una nuova chiave di registro in HKLM:\Software\RETI che contenga la data e l'ora di esecuzione dello script.
# v0.3                     - Cancella tutti i file presenti nella cartella C:\Windows\Temp.
#                          - Scarica e installa il programma Notepad++ dalla pagina ufficiale.
# v1.0                     - Implementazione della funzione di logging con try catch per verificare gli errori
#
# Autore: Team1
# Data prima stesura: 19/05/2023
# Data ultima modifica: 25/04/2023
#
# Qualsiasi riproduzione non autorizzata, anche se parziale, è vietata
#
# NOTE IMPORTANTI:
# - Eseguire lo Script una volta effettuata la join a dominio
#
# REQUISITI:
# - Eseguire lo script da Amministratore
# - Avere una cartella C:\Windows\Logs  

# Data da utilizzare per la rinomina del Computer
$datadioggi = Get-Date -Format yyyyMMdd
# Variabile utilizzata per la rinomina del computer + data corrente
$nomecomputer = "CW" + "$datadioggi"
# Path del file di Log
$logfile = "C:\Windows\Logs\$nomecomputer" + ".log"

# Effettua un check della chiave di registro che verrà creata successivamente, questo permetterà di verificare se lo script sia già stato eseguito, in tal caso non eseguirà nessuna azione.
if (Test-Path "HKLM:\Software\RETI") {
        Write-Host "Lo script è già stato eseguito"
}else {
# Funzione di Log, che permette di selezionare a scelta un livello di messaggio (INFO, WARNING, ERROR, NULL), i messaggi verranno salvati nella cartella C:\Windows\Logs\$nomecomputer.log        
        function log {
                param ( [Parameter(Mandatory = $true)] [string] $messaggio, [Parameter(Mandatory = $true)][string] $log )
                $date = Get-Date -Format "dd/MM/yyyy_HH:mm:ss"
                switch ($log) {
                        info {
                                #log info 
                                $output = "$date - INFO    | $messaggio";
                                break
                        }
                        warn {
                                $env:COMPUTERNAME 
                                #log warning
                                $output = "$date - WARNING | $messaggio";
                                break
                        }
                        err {
                                #log error
                                $output = "$date - ERROR   | $messaggio";
                                break
                        }
                        null {
                                #log null
                                $output = "$messaggio"; 
                                break
                        }
                }
                Write-Output $output | Out-File -FilePath $logfile -Append
                return $output;
                Write-Host $output
        }
        # Variabile utilizzata per stampare l'ora nel primo messaggio di Log
        $ora = Get-Date -Format HH:mm:ss
        # Primo messaggio di log con data e ora di esecuzione
        log -messaggio "------------------------------------------Script eseguito il $($datadioggi) alle $($ora) ------------------------------------------" -log null

        # Rinomina il computer con la sigla CW e la data di esecuzione dello script
        try {
                Rename-Computer -NewName "$($nomecomputer)" -Force -ErrorAction Stop
                log -messaggio "Il computername è stato cambiato in $nomecomputer" -log info
        }
        catch {
                log -messaggio "Impossibile cambiare il nome del computer, causa: $_" -log err
        }
        # Cambio la Password dell'utente Administrator
        try {
                # Variabile utilizzata per la Password di Admin
                $password = "Admin_" + $nomecomputer
                # Comando per selezionare l'utente al quale si vogliono appportare modifiche, in questp caso la password, la password deve prima essere convertita in una stringa sicura tramite ConvertTo-SecureString ...
                Set-LocalUser -Name "Administrator" -Password (ConvertTo-SecureString -String $password -AsPlainText -Force)
                log -messaggio "La Password di Admin è stata cambiata" -log info
        }
        catch {
                log -messaggio "Impossibile cambiare la password dell'Amministratore, causa: $_" -log err
        }
        
        # Creazione dell'utente ospite
        try {
                $passwordospite = "Password1"
                New-LocalUser -Name "Ospite" -Password (ConvertTo-SecureString -String $passwordospite -AsPlainText -Force) -ErrorAction Stop
                log -messaggio "È stato creato l'utente Ospite" -log info
        }
        catch {
                log -messaggio "Impossibile creare l'utente ospite, causa: $_" -log err
        }
        # Creazione del Gruppo Utenti Locali 
        try {
                New-LocalGroup -Name "Utenti Locali" -ErrorAction Stop
                log -messaggio "È stato creato il gruppo utenti locali" -log info
        }
        catch {
                log -messaggio "Impossibile creare il gruppo causa: $_" -log err
        }
        # Spostamento utente Administrator in Utenti Locali
        try {
                Add-LocalGroupMember -Group "Utenti Locali" -Member "Administrator" -ErrorAction Stop
                log -messaggio "È stato creato il gruppo utenti locali ed Admin è stato spostato al suo interno " -log info
        }
        catch {
                log -messaggio "Impossibile spostare l'utente Admin al suo interno causa: $_" -log err
        }

        # Creazione della chiave di registro in HKLM\Software\Reti necessaria per check iniziale
        try {
                $dataora = Get-Date -Format ddMMyyyy_HH:mm
                New-Item -Path HKLM:\Software -Name RETI -Value "$dataora" –Force -ErrorAction Stop
                log -messaggio "É stata creata la chiave di registro" -log info
        }
        catch {
                log -messaggio "Impossibile creare la chiave di registro, causa: $_" -log err
        }

        # Rimuove tutti i file temporanei da C:\Windows\Temp
        try {
                $files = Get-ChildItem -Path "C:\Windows\Temp\*" -File -Recurse
                foreach ($file in $files) {
                        if (Test-Path -Path $file.FullName -ErrorAction SilentlyContinue) {
                                # Se il File è attualmente aperto da un'altro programma e viene salvato un messaggio di log con ERRORE
                                log -messaggio "Il file $($file.FullName) è aperto e non può essere eliminato." -log err
                        }
                        else {
                                Remove-Item -Path $file.FullName -ErrorAction Stop
                        }
                }
                log -messaggio "Sono stati cancellati i file in C:\Windows\Temp" -log info
        }
        catch {
                log -messaggio "Non è stato possibile cancellare i file, causa: $($_.Exception.Message)" -log err
        }

        # Installazione notepad++ direttamente da Repo ufficiale di GitHub

        # Variabile con path della cartella temp dell'utente che esegue lo Script
        $temppath = $env:TEMP
        try {
                # Comando per scaricare npp da GitHub
                Invoke-WebRequest -Uri "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.5.3/npp.8.5.3.Installer.x64.exe" -OutFile "$temppath\npp.exe"
                # Comando per eseguire l'installazione del programma in modalità silenziosa
                Start-Process -FilePath "$temppath\npp.exe" -ArgumentList "/S"
                Start-Sleep 20
                log -messaggio "É stato installato il programma Notepad++" -log info
                Remove-Item -Path "$($temppath)\npp.exe" -Force
        }
        catch {
                log -messaggio "Impossibile installare Notepad, causa: $_" -log err
        }
        #messaggio di log finale
        log -messaggio "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" -log null
}

# Comando necessario per mostrare le FInestre a schermo
$Form.ShowDialog() | Out-Null
