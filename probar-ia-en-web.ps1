<#
.SYNOPSIS
  Arranca Veridia en el navegador CON la identificacion por IA activada.

.DESCRIPTION
  Por defecto la app NO lleva la clave de Gemini en web: `lib/config/gemini_key.dart`
  la devuelve vacia cuando `kIsWeb` es cierto, y Dart elimina por tree-shaking la rama
  que lee el archivo local. Eso es a proposito -- una `const String` termina en texto
  plano dentro de `main.dart.js`, y con el sitio publicado en v3ridia.web.app la clave
  quedaba descargable por cualquiera. Ya paso una vez.

  La unica puerta de entrada es `--dart-define=GEMINI_API_KEY=...`, para que exponerla
  sea siempre una decision explicita y nunca el comportamiento por defecto. Este script
  es esa decision, automatizada para no tener que pegar la clave a mano:

    1. Lee la clave de lib/config/gemini_config.dart (gitignored, nunca se imprime).
    2. Arranca `flutter run -d chrome` pasandola por --dart-define.
    3. Al salir BORRA build/web.

  El paso 3 es el importante. `firebase.json` publica la carpeta build/web tal cual,
  SIN reconstruirla, asi que un `firebase deploy` hecho justo despues de esta sesion
  publicaria estos artefactos de depuracion -- con la clave dentro. Borrarlos cierra
  ese camino: el siguiente deploy obliga a un `flutter build web --release` limpio,
  que por definicion no lleva la clave.

  Este archivo NO contiene ninguna clave y es seguro versionarlo.

.EXAMPLE
  .\probar-ia-en-web.ps1
  .\probar-ia-en-web.ps1 -Dispositivo edge
#>
[CmdletBinding()]
param(
    # Navegador donde abrir la app. `chrome` y `edge` abren una ventana;
    # `web-server` solo sirve la URL para abrirla a mano.
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Dispositivo = 'chrome',

    [int]$Puerto = 8099,

    # No borrar build/web al terminar. Usalo solo si sabes que no vas a
    # desplegar despues; lee la nota de arriba antes.
    [switch]$ConservarBuild
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$configuracion = Join-Path $PSScriptRoot 'lib\config\gemini_config.dart'
if (-not (Test-Path -LiteralPath $configuracion)) {
    Write-Error @"
No existe lib/config/gemini_config.dart.
Copia lib/config/gemini_config.example.dart a ese nombre y pon tu clave de
Google AI Studio dentro. El archivo esta en .gitignore: no se sube al repo.
"@
    exit 1
}

$texto = Get-Content -LiteralPath $configuracion -Raw
$coincidencia = [regex]::Match($texto, "geminiApiKey\s*=\s*'([^']+)'")
if (-not $coincidencia.Success) {
    $coincidencia = [regex]::Match($texto, 'geminiApiKey\s*=\s*"([^"]+)"')
}
if (-not $coincidencia.Success) {
    Write-Error 'No se encontro la constante geminiApiKey en lib/config/gemini_config.dart.'
    exit 1
}

$clave = $coincidencia.Groups[1].Value
if ($clave.StartsWith('PON_AQUI')) {
    Write-Error 'lib/config/gemini_config.dart todavia tiene el valor de ejemplo. Pon tu clave real.'
    exit 1
}

# Solo el largo y el prefijo: suficiente para saber que leyo la correcta, sin
# dejar la clave en el historial de la consola.
Write-Host ''
Write-Host "  Clave leida  : $($clave.Substring(0,4))... ($($clave.Length) caracteres)" -ForegroundColor DarkGray
Write-Host "  Dispositivo  : $Dispositivo" -ForegroundColor DarkGray
Write-Host "  Puerto       : $Puerto" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  IA ACTIVADA en esta ejecucion de web.' -ForegroundColor Yellow
Write-Host '  No uses --dart-define con `flutter build web` para desplegar:' -ForegroundColor Yellow
Write-Host '  eso si dejaria la clave publica en v3ridia.web.app.' -ForegroundColor Yellow
Write-Host ''

try {
    & flutter run -d $Dispositivo --web-port $Puerto --dart-define="GEMINI_API_KEY=$clave"
}
finally {
    $salida = Join-Path $PSScriptRoot 'build\web'
    if ($ConservarBuild) {
        Write-Host ''
        Write-Host "  build/web CONSERVADO y contiene la clave. No despliegues sin" -ForegroundColor Red
        Write-Host "  reconstruir antes: flutter build web --release" -ForegroundColor Red
    }
    elseif (Test-Path -LiteralPath $salida) {
        Remove-Item -LiteralPath $salida -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ''
        Write-Host '  build/web borrado: ningun artefacto con la clave queda listo para desplegar.' -ForegroundColor DarkGray
    }
}
