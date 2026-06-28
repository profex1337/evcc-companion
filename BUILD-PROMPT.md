# Prompt: Android-App „evcc Updater" bauen

> So benutzt du das: Öffne eine **neue Claude-Code-Session im Ordner `C:\EVCC Updater`**
> und schick den Block unter „--- PROMPT ANFANG ---" ab. Alles Nötige ist hier drin;
> die heikle SSH-Update-Mechanik wurde am 2026-06-28 bereits gegen den echten evcc-Pi
> validiert (siehe „Validierte Fakten").

---------------------------------- PROMPT ANFANG ----------------------------------

Baue mir eine **Android-App „evcc Updater"** (Flutter), mit der ich evcc auf einem
Raspberry Pi **per Knopfdruck via SSH aktualisiere**. Die App ist für mich + Freunde,
wird als **APK über GitHub Releases** verteilt. iOS bewusst später (gleiche
Flutter-Codebasis hält die Tür offen, jetzt aber NICHT bauen).

## Ziel

Eine schlanke Single-Screen-App: Man trägt **evcc-IP + Pi-Zugangsdaten** ein, tippt
**einen Button**, und die App fährt per SSH das evcc-Update auf dem Pi, zeigt eine
Live-Ausgabe und meldet am Ende „evcc 0.x → 0.y aktualisiert" bzw. „war schon aktuell".

## Validierte Fakten (NICHT neu recherchieren — am 2026-06-28 gegen echten Pi geprüft)

- evcc läuft als **apt-Paket** (Repo `dl.evcc.io`) auf dem Pi. „Update" = SSH rein +
  `apt-get install --only-upgrade evcc`. Der Dienst restartet beim Upgrade automatisch.
- **Validierte SSH-Sequenz** (gegen Test-Pi, Ergebnis bestätigt):
  1. Version **vorher**: `dpkg-query -W -f='${Version}' evcc`  (Beispiel-Ausgabe: `0.310.0`)
  2. `echo "<pw>" | sudo -S apt-get update -qq`
  3. `echo "<pw>" | sudo -S apt-get install --only-upgrade -y evcc`
     (bei aktiviertem Schalter „Voll-Upgrade" stattdessen `... full-upgrade -y`)
  4. `systemctl is-active evcc`  → erwartet `active`
  5. Version **nachher** erneut auslesen → Diff melden
- **`sudo -S`** (Passwort über stdin) bewusst gewählt: funktioniert auch ohne
  passwortloses sudo. (Test-Pi hatte NOPASSWD-sudo; Freunde-Pis evtl. nicht.)
- **Dry-Run** zum gefahrlosen Testen: `... install --only-upgrade --dry-run evcc`
  ändert nichts. Beim Test-Pi lieferte das „evcc is already the newest version (0.310.0),
  0 upgraded … 28 not upgraded" — d.h. „nur evcc" vs. „Voll-Upgrade" ist ein echter
  Unterschied (28 andere OS-Pakete hatten Updates).

## App-Spezifikation

- **Plattform:** Android (APK). iOS NICHT jetzt.
- **Framework:** Flutter (Dart). **SSH via Paket `dartssh2`** (reines Dart,
  Passwort-Auth). **Sichere Speicherung via `flutter_secure_storage`** (Android Keystore).
- **UI (eine Seite):**
  - Felder: **Host/IP**, **Port** (Default `22`), **Benutzer** (Default `pi`),
    **Passwort** (verdeckt).
  - Schalter **„Komplettes System-Upgrade"** (Default AUS → nur evcc).
  - Großer Button **„evcc aktualisieren"**.
  - **Live-Log** (gestreamte Ausgabe der SSH-Befehle).
  - **Versions-Badge** vorher → nachher; klare Abschlussmeldung.
  - Eingaben werden gespeichert (Keystore) → einmal eintragen, danach nur tippen.
- **Button-Verhalten:** führt die SSH-Sequenz oben aus, streamt Ausgabe ins Log,
  meldet am Ende eindeutig: aktualisiert / war schon aktuell / Fehlerursache.
- **Architektur:** SSH-/Update-Logik in eigener, testbarer Klasse (z.B. `EvccUpdater`),
  getrennt von der UI. Kommando-Bau und Output-Parsing als reine Funktionen →
  **Unit-Tests ohne echtes SSH**.
- **Fehlerbehandlung (klare Meldungen):** Verbindungsfehler (falsche IP/offline/Timeout),
  Auth-Fehler (falsches Passwort), sudo-Fehler, kein Update verfügbar, Dienst nach Update
  nicht `active`. Verbindungs-Timeout setzen.
- **Sicherheit:** Passwort nur verschlüsselt im Keystore, **niemals klartext loggen**;
  das an `sudo -S` übergebene Passwort aus der sichtbaren Log-Ausgabe **herausfiltern**.
  Annahme: LAN-Nutzung (zuhause im WLAN). Remote optional über **Tailscale-IP**
  (kein Portforwarding). Kein Account-System, kein Cloud-Backend.

## Build & Verteilung

- **Lokal KEINE Android-Toolchain nötig** — der APK-Build läuft per **GitHub Actions**
  in der Cloud.
- **Repo: öffentlich** (damit Freunde die APK per Release-Link laden, ohne
  GitHub-Account). Kein Geheimnis liegt im Code — Zugangsdaten gibt jeder Nutzer erst
  zur Laufzeit in der App ein.
- **Workflow `.github/workflows/build.yml`:** Trigger `push` + Tag `v*`. Schritte:
  `actions/checkout`, `actions/setup-java@v4` (JDK 17), `subosito/flutter-action@v2`
  (stable), `flutter pub get`, `flutter analyze`, `flutter test`,
  `flutter build apk --release`. APK **signieren** mit einem Release-Keystore, der als
  **base64-GitHub-Secret** hinterlegt ist (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
  `KEY_ALIAS`, `KEY_PASSWORD`); der Workflow dekodiert den Keystore und signiert.
  Bei **Tag-Push**: GitHub-Release anlegen und **`app-release.apk` als Asset** anhängen.
- **Keystore** lokal mit `keytool` erzeugen (JDK ist installiert, s.u.), base64-kodieren,
  via `gh secret set …` in die Repo-Secrets legen. **Keystore NIE ins Repo committen.**
- **Beweis vor „fertig":** CI-Build **grün** (= installierbare, signierte APK existiert
  als Release-Asset). Finaler Geräte-Test (Button → evcc updatet) macht der User; die
  SSH-Mechanik vorab per **Dry-Run** gegen den echten Pi bestätigen.

## Umgebung (dieser Windows-PC — schon vorbereitet)

- **OS:** Windows 11. Shells: PowerShell (primär) + Git-Bash.
- **Projektverzeichnis:** `C:\EVCC Updater` (hier arbeiten; diese Session läuft dort).
- **Flutter ist bereits installiert & verifiziert** unter
  `C:\Users\stefa\flutterdev\flutter` (stable). **JDK 17** unter
  `C:\Users\stefa\flutterdev\jdk17`. → PATH setzen und wiederverwenden, NICHT neu laden:
  ```
  $env:Path = "C:\Users\stefa\flutterdev\flutter\bin;" + $env:Path
  $env:JAVA_HOME = "C:\Users\stefa\flutterdev\jdk17"
  ```
- **`gh` (GitHub CLI) ist installiert UND bereits eingeloggt** → direkt `gh repo create`
  möglich, kein `gh auth login` nötig.
- `node` v24 und `git` sind vorhanden. Eine Android-SDK lokal gibt es NICHT (braucht es
  auch nicht — CI baut).

## Vorgehen

1. Umgebung verifizieren: `flutter doctor`, `gh auth status`.
2. `flutter create` im Projektordner, Paketname `evcc_updater` (org z.B. `de.grasse`).
3. App + Update-Logik implementieren. **TDD** wo sinnvoll: erst Unit-Tests für
   Kommando-Bau & Output-Parsing (Version-Diff, „already newest", Fehlerfälle), dann UI.
4. GitHub-Workflow + Keystore-Signierung einrichten.
5. Öffentliches Repo anlegen, pushen, **CI grün** bekommen, getaggtes Release mit APK.
6. Beweisen: Release-APK existiert + Dry-Run-SSH-Test gegen den Pi ok.
7. Kurzes **README**: Installation (Sideload „Unbekannte Quellen"), Nutzung, Sicherheit.

## Test-Pi (nur zum Validieren der SSH-Mechanik)

- evcc-Pi: **`192.168.178.64`**, User **`pi`**. **Passwort gibst du beim Testen an**
  (NICHT ins Repo/in Logs schreiben). SSH von Windows: Git-Bash-Askpass-Trick oder
  PuTTY `plink` mit `-hostkey`.
- **Immer erst Dry-Run** (`--dry-run`); echtes Upgrade nur nach ausdrücklichem OK.

## Meine Vorgaben

- **Schlank halten:** eine Seite, ein Button. Kein Account, kein Backend, kein Schnickschnack.
- **Auf Deutsch antworten**, technische Begriffe im Original belassen.

----------------------------------- PROMPT ENDE -----------------------------------
