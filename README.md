# BODK-AI-Use

Et lille Windows-værktøj, der viser **Codex- og Claude Code-kvoter direkte oven på proceslinjen**. Se forbruget for fem timer og en uge uden at åbne et separat vindue.

## Sådan ser det ud

Mørkt tema:

![BODK-AI-Use i mørkt tema med demotal for Codex og Claude](docs/preview-dark.png)

Lyst tema:

![BODK-AI-Use i lyst tema med demotal for Codex og Claude](docs/preview-light.png)

Billederne viser selve widgettens Windows-kontroller med **demotal**, ikke en måling fra en konto. Ved almindelig brug står der Codex og Claude i stedet for Demo CX og Demo CL. Symbolerne er tegnede udbydermærker, ikke officielle logoer.

## Installation

1. [Download projektet som ZIP](https://github.com/BravoOscarDK/BODK-AI-Use/archive/refs/heads/main.zip), eller vælg **Code → Download ZIP**. Pak hele ZIP-filen ud, før du fortsætter.
2. Dobbeltklik på **Installer.cmd**.
3. Tallene vises til venstre for systemikonerne i den primære proceslinje.

Installationen gælder din Windows-bruger og kræver ikke administratorrettigheder. **Programmet starter automatisk, når du logger ind i Windows.** Det bruger den indbyggede Windows PowerShell 5.1 og Windows Forms.

Har du den gamle Kvoteblik installeret, skal du først afinstallere den via dens Afinstaller.cmd. Opdatér også din Claude-statuslinjes sti.

Installationen installerer selve widgetten. Følg derefter **Codex** og/eller **Claude Code** nedenfor for at få rigtige tal. En almindelig ChatGPT- eller Claude-desktopapp alene giver ikke widgetten kvotedata.

### Opdatering

Download og udpak den nye ZIP, og kør **Installer.cmd** igen. Installationen lukker den gamle BODK-AI-Use og starter den nye udgave. Dine eksisterende indstillinger og lokale målinger bevares. Du behøver ikke afinstallere først.

## Sprog / Language

Højreklik på visningen → **Sprog / Language** → **Dansk** eller **English**. Valget gælder menuer, perioderne `5t`/`5h` og `Uge`/`Week` samt programmets egne statusbeskeder. Det gemmes og bruges efter næste Windows-login.

Ved første start vælges dansk på et dansk Windows-visningssprog, ellers engelsk. Valget ændrer ikke Windows, Claude eller Codex. Installationsprogrammets konsoltekst og denne README er på dansk; beskeder fra eksterne programmer kan beholde deres eget sprog.

## Brug

- **Højreklik** på visningen for at vælge Codex, Claude eller begge.
- Vælg brugt eller resterende kvote, lyst/mørkt tema og opdateringsinterval.
- **Træk med venstre museknap** for at flytte visningen vandret. Placeringen gemmes.
- Hold musen over en procent for status og eventuelt nulstillingstidspunkt.
- Orange betyder over 80 % forbrugt; rød betyder over 95 %. Farven følger forbruget, også når du viser resterende kvote.
- En streg betyder, at en gyldig måling mangler. Demotilstand bruger kunstige eksempelværdier.

Begge udbydere vises som to kompakte rækker. Vælg én udbyder for én række.

### Placering og begrænsninger

Visningen ligger **oven på proceslinjen**. Den reserverer ikke plads og flytter ikke Windows' appknapper. Hvis den dækker en knap, træk den til et ledigt område. Højreklik → Nulstil placering gendanner udgangspunktet.

Placeringen følger den primære, vandrette proceslinje. Koden skjuler visningen, når proceslinjen er automatisk skjult eller et fuldskærmsprogram er aktivt, og finder proceslinjen igen efter en Explorer-genstart. Lodret proceslinje og andre skærmes proceslinjer understøttes ikke. Udseende og placering kan variere mellem Windows-versioner og skærmindstillinger; den fysiske placering er endnu ikke visuelt afprøvet her.

## Codex

1. Installér **Codex CLI til Windows** efter [OpenAI's officielle vejledning](https://learn.chatgpt.com/docs/codex/cli). Installér den i Windows, så den kan startes fra Windows PowerShell; en installation kun inde i WSL er ikke tilstrækkelig til denne widget.
2. Åbn et nyt PowerShell-vindue, og kontrollér installation og login:

   ```powershell
   codex --version
   codex login
   ```

3. Følg loginforløbet med din ChatGPT-konto. Se også [OpenAI's vejledning om login](https://learn.chatgpt.com/docs/auth).
4. Genstart BODK-AI-Use fra Start-menuen, hvis CLI'en lige er blevet installeret. Afslut først den kørende widget via højreklik → **Afslut / Exit**.
5. Højreklik → **Udbyder / Provider** → **Codex** eller **Begge / Both**, og vælg **Opdatér nu / Refresh now**. Vent på, at kontoen returnerer kvoterne.

Programmet læser de femtimers- og ugekvoter, som Codex-kontoen stiller til rådighed via CLI'ens lokale app-server. Det er Codex-forbrug, ikke en samlet måling af almindelig ChatGPT-brug. Kontoen skal tilbyde de relevante kvoter.

## Claude Code

1. Installér **Claude Code i Windows** efter [Anthropics officielle vejledning](https://code.claude.com/docs/en/setup). Den officielle WinGet-mulighed er:

   ```powershell
   winget install Anthropic.ClaudeCode
   ```

2. Åbn et nyt terminalvindue, start `claude`, og gennemfør login. Brug en konto og version, der sender femtimers- og ugekvoter til statuslinjen. En API-konto eller manglende kvotefelter kan give streger i widgetten.
3. Installér BODK-AI-Use, før du tilføjer statuslinjen. Åbn `%USERPROFILE%\.claude\settings.json`. Tag en kopi først, hvis filen allerede findes. Tilføj `statusLine` på øverste niveau; bevar øvrige indstillinger. Hvis filen er ny eller tom, kan hele dette eksempel bruges:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/DITNAVN/AppData/Local/BODK-AI-Use/ClaudeStatus.ps1\""
  }
}
```

4. Erstat stien med din faktiske installationssti. Find den ved at åbne `%LOCALAPPDATA%\BODK-AI-Use` i Stifinder. Brug skråstreger som i eksemplet. Gem en eventuel eksisterende `statusLine`, før du erstatter den; denne opsætning overtager Claude-statuslinjen.
5. Genstart Claude Code, send en besked, og vent på et svar. Vælg **Claude** eller **Begge / Both** i widgetten, og vælg **Opdatér nu / Refresh now**.

BODK-AI-Use læser den seneste lokale måling; nye Claude-tal afhænger af, hvornår Claude Code sender dem. En måling vises som en streg efter dens nulstillingstidspunkt, indtil der kommer nye data. Felterne er beskrevet i [Anthropics officielle statuslinjevejledning](https://code.claude.com/docs/en/statusline#rate-limit-usage).

## Når du bruger både Claude og Codex

Gennemfør begge opsætninger ovenfor, og vælg **Udbyder / Provider → Begge / Both**. Der er to uafhængige login: ChatGPT-kontoen i Codex CLI og Claude-kontoen i Claude Code. Widgetten forbinder ikke kontiene og kræver ikke, at du indsætter adgangskoder eller API-nøgler i den.

Codex hentes med det valgte interval. Claude vises fra den seneste statuslinjemåling, så Claude Code skal have sendt en måling først. Du kan derfor godt få tal i den ene række og streger i den anden.

### Hvis der kun vises streger

| Problem | Kontrollér |
| --- | --- |
| Codex mangler | Kør `codex --version` i Windows PowerShell, gennemfør `codex login`, og genstart widgetten efter installation eller ændret PATH. |
| Claude mangler | Kontrollér stien i `statusLine`, genstart Claude Code, og send en besked. Se om `%LOCALAPPDATA%\BODK-AI-Use\claude.json` bliver opdateret. |
| Claude har ingen kvotefelter | Kontrollér konto og Claude Code-version. Widgetten kan ikke beregne manglende kvoter ud fra kontekstforbrug. |
| Gamle tal | Hold musen over tallene. Claude opdateres først ved nye statuslinjedata; efter nulstilling afventer widgetten en ny måling. |
| Tallene ændrer sig ikke som forventet | Slå **Demotilstand / Demo mode** fra, og vælg **Opdatér nu / Refresh now**. |
| Visningen dækker appknapper | Træk den vandret til et ledigt område. |

## Lokale data

Program og indstillinger installeres i `%LOCALAPPDATA%\BODK-AI-Use`. Claude-broen gemmer kun kvoteværdier, nulstillingstidspunkter og måletidspunkt i `claude.json`. `settings.json` gemmer visningsvalg og placering. Disse filer er udeladt fra Git.

## Afinstallation

1. Hvis du har tilføjet Claude-statuslinjen, fjern **kun den `statusLine`-egenskab**, du tilføjede, eller gendan din tidligere statuslinje. Bevar resten af `%USERPROFILE%\.claude\settings.json` og gyldig JSON.
2. Kør **Afinstaller.cmd** fra den udpakkede projektmappe. Alternativt: Åbn **Windows-indstillinger → Apps → Installerede apps → BODK-AI-Use → Afinstaller**.
3. Afinstallationen lukker widgetten og fjerner installationsmappen, lokale målinger, indstillinger, Start-menuens genvej og automatisk opstart.
4. Du kan derefter slette den udpakkede projektmappe og ZIP-filen manuelt, hvis du vil fjerne downloadet også.

Claude Code, Codex CLI, deres login og øvrige indstillinger bliver ikke afinstalleret. Du behøver ikke fjerne dem for at slette widgetten.

## Udvikling og kontrol

Kør fra projektmappen:

```powershell
# Kontrol af layout, demoværdier, resterende kvote og tema uden at åbne et vindue
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Test-Display.ps1

# Separat eksempelvindue med demotal
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\BODK-AI-Use.ps1 -Demo -Preview

# Genskab billederne i README fra widgettens kontroller uden at åbne et vindue
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Export-Preview.ps1
```
