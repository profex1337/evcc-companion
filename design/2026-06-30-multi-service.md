# Pi-Tool → Multi-Service (Design-Spec)

Stand: 2026-06-30 · Status: genehmigt (Richtung), Umsetzung phasenweise · Ziel-Release: **v0.12.0**

## Ziel / Vision

Aus dem evcc-zentrierten Updater wird **Pi-Tool: self-hosted Pi-Dienste
installieren, aktualisieren und deren Web-Oberfläche öffnen** — per SSH, ohne
Terminal. Mehrere Dienste pro Pi, auto-erkannt.

## Service-Modell

Ein **Service** kapselt alles, was die App mit einem Dienst auf dem Pi tun kann:

`erkennen · installieren (wenn fehlt) · aktualisieren · Status · Web-Oberfläche öffnen · Backup (optional)`

```
abstract class PiService {
  String get id;                 // 'evcc' | 'pihole' | 'system'
  String get name;               // Anzeigename
  bool   get canInstall;         // evcc/pihole: true, system: false
  String? webUrl(scheme, host);  // Open-Web-Ziel oder null (system)
  Future<ServiceStatus> detect(SshRunner r);                    // 1 Verbindung, alle Services
  Future<void> update({runner, sudoPw, status, onLog});
  Future<void> install({runner, sudoPw, onLog});                // nur wenn canInstall
  List<ServiceAction> actions(ServiceStatus s);                 // ⋮: restart/gravity/dry-run/...
  Future<String?> backup({runner, sudoPw, onLog});              // optional, null = keins
}

class ServiceStatus { bool installed; String? version; bool active;
                      bool updateAvailable; String? kind; String detail; }
class ServiceAction { String label; IconData icon; Future<void> Function() run; }
```

**v1-Services:**
| Service | erkennen | installieren | aktualisieren | Extras | Web | Backup |
|---|---|---|---|---|---|---|
| evcc | dpkg / docker ps | apt-Repo+install (vorhanden) | apt bzw. docker compose/run (vorhanden) | Live-Status, Dienst neustarten, Probelauf | `:7070` | config+DB (vorhanden) |
| Pi-hole | `pihole -v` / `command -v pihole` | offizielles Install-Skript | `sudo pihole -up` (v5/v6) | Blocklisten `pihole -g`, DNS neustarten, Pause | `/admin` (:80) | Teleporter-Export |
| System | immer | — | `apt full-upgrade` | Reboot, Speicher/Uptime | — | — |

Architektur als „Plugin": ein weiterer web-konfigurierter Dienst (AdGuard,
Homebridge, Portainer, Uptime Kuma, OctoPrint, Cockpit, wg-easy …) = eine neue
`PiService`-Definition (Befehle + Port). Kein UI-Umbau nötig.

## Ablauf

„Verbindung testen" öffnet **eine** SSH-Sitzung, ruft `detect()` für jeden
registrierten Service auf und liefert `List<ServiceStatus>`. Update/Install/
Aktionen laufen je Service über dieselbe `_withConnection`-Naht (Host-Key-TOFU,
Passwort nur via stdin, Redaction — alles bestehend).

## UI (Variante B — Karten mit Konsolen-DNA)

Oben: Profilleiste + kompakter Test-Button (vorhanden). Darunter pro **erkanntem**
Service eine gerundete Karte (wie die Verbindungs-Card):

- Kopf: Name + Status-LED (🟢 aktiv · ⚪ aus · 🔴 Problem · 🟡 Update) + ⋮.
- Version/Status in **Monospace** (Terminal-Signatur).
- Primär: `[ Aktualisieren ]` bzw. `[ Installieren ]` (wenn nicht installiert).
- `↗ Oberfläche öffnen` (wenn `webUrl != null`).
- ⋮: service-spezifische Aktionen.

**Zustände:** vor Test → Hinweis statt leerer Karten · Test läuft → Skeleton-
Karten · erkannt → Karten · nicht installiert → ausgeblendet (optional „… nicht
gefunden – installieren?") · offline → roter Test-Button + Banner.

Übernommen 1:1: Profile, App-Sperre, Backup-vor-Update, Test-Button, Live-Log,
⋮-Menü-Querschnitt. Der heutige „Komplettes System-Upgrade"-Schalter → System-Service.

## Phasen (jede: TDD, analyze grün, adversarial Review, dann Release)

1. **Service-Abstraktion + evcc dahinter** — `PiService`/`ServiceStatus`/
   `ServiceAction`, `EvccService` + `SystemService` kapseln bestehende Logik;
   Orchestrator `detectServices()`. UI ruft vorerst weiter den evcc-Pfad. Reine
   Logik testbar. **Kein Verhaltenswechsel.**
2. **Service-Karten-UI (B)** für evcc + System; Multi-Detect; „Oberfläche öffnen".
3. **Pi-hole-Service** — detect/install/update (v5/v6)/gravity/restart/Teleporter-
   Backup/`/admin`-Link. Karte erscheint, wenn erkannt.
4. **Politur + Review + Release v0.12.0** (README/Store-Texte: „mehrere Dienste").

## Tests / Risiko

185 Tests + `SshRunner`-Fake + `FakeEvccUpdater` sind das Netz; jede Phase bleibt
grün. Pi-hole-Befehle sind rein/TDD-bar; der echte Pi-hole-Pfad ist (wie evcc-
Docker/Install) experimentell bis zu einem echten Test-Pi. Pi-hole v6 (2025,
FTL/neue Web-UI) explizit behandeln.

## Nicht in v1

Home Assistant (Install/Update zu komplex/variantenreich), die übrigen Roadmap-
Dienste, eigenständige Web-UI-Einbettung (wir verlinken nur), iOS.
