# Plenair

Nederlandstalige site met politiek nieuws: Nederlandse politiek, de Tweede Kamer en de Amerikaanse midterms. Twee bots vullen de site automatisch:

- **Nieuwsbot** (elke 10 minuten): leest RSS-feeds, filtert op politiek, laat per bericht een eigen kop en een korte Nederlandse samenvatting schrijven door `claude-haiku-5-5`, en controleert die op letterlijk overnemen.
- **Kamerbot** (elk uur): haalt moties en stemmingen uit de open data van de Tweede Kamer en toont die ongewijzigd.

Techniek: Python 3.11+, Flask + Jinja2, SQLite. Geen JavaScript, geen cookies, geen scripts van derden.

## Installatie

```bash
git clone <jouw-repo> plenair && cd plenair
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## API-sleutel instellen

```bash
cp .env.example .env
nano .env        # vul ANTHROPIC_API_KEY=sk-ant-... in
```

`.env` staat in `.gitignore` en komt nooit in git. De code leest de sleutel alleen uit de omgeving. Een sleutel maak je aan in de Claude Console (console.anthropic.com).

## Waar de gegevens staan

De database en een kopie van `.env` staan buiten de programmamap, in `~/Plenair` (Windows: `C:\Users\<naam>\Plenair`). Een nieuwe versie van het programma gebruikt ze dus automatisch. Bij de eerste start verhuist een bestaande `data/site.db` daarheen. Op de server zetten de systemd-diensten `PLENAIR_DB` en `PLENAIR_HOME` naar `/opt/plenair/data`.

## Rubrieken

- **Nieuws** (homepage): al het nieuws behalve Tweede Kamer en midterms. Bronnen met `catch_all = "nieuws"` in `config/sources.toml` leveren hier ook algemeen nieuws aan.
- **Tweede Kamer**: nieuws over de Kamer, met de laatste stemmingen ernaast.
- **Tweede Kamer moties**: alle moties met zoeken en filteren (`/tweede-kamer/moties`).
- **VS-midterms**: nieuws over de Amerikaanse verkiezingen (ook van CNN en Fox) en de uitslagenpagina.

## Lokaal starten

```bash
./run_local.sh                     # maakt .venv, installeert alles, start op http://127.0.0.1:5000
```

`start.bat` (Windows) start de site met de bots als achtergrondtaak (`PLENAIR_RUN_BOTS=1`, zie `app/runner.py`): elke 10 minuten nieuws, elk uur moties. Op een server gebruik je dat niet; daar doen de systemd-timers het.

Of met de hand, in drie terminals:

```bash
flask --app app.web run            # de site
python -m app.newsbot              # één run van de nieuwsbot
python -m app.kamerbot --days 30   # Kamerdata van de laatste 30 dagen
```

Handige controles:

```bash
python -m app.newsbot --check-feeds     # test alle feeds, slaat niets op, kost geen API-calls
python -m app.kamerbot --check-metadata # controleert de live metadata van de Tweede Kamer
python -m pytest                        # alle tests
```

## Gratis online met GitHub (laptop mag uit)

`.github/workflows/update.yml` draait elke 15 minuten op GitHub Actions: database ophalen van branch `data`, Kamerbot, nieuwsbot, `python -m app.export public` (statische HTML onder `/<repo-naam>/`), database terugzetten, publiceren op GitHub Pages. De API-sleutel staat als secret `ANTHROPIC_API_KEY`. In statische modus zijn zoeken en motiefilters uitgeschakeld. Stap-voor-stap: zie `GITHUB-HANDLEIDING.txt`.

## Tijdelijk online zonder hosting (telefoon)

`start-telefoon.bat` start de site plus een Cloudflare Quick Tunnel (`cloudflared tunnel --url http://127.0.0.1:5000`). Je krijgt een willekeurig `https://….trycloudflare.com`-adres dat overal werkt zolang de computer aan staat. Geen account nodig. Cloudflare geeft geen uptime-garantie; bedoeld om te testen. Iedereen met het adres kan de site zien (alleen-lezen). Voor echt online gaan: zie "Deployen op een kleine VPS".

## Bronnen en filters aanpassen (zonder code)

- `config/sources.toml`: feeds toevoegen, aan- of uitzetten. `fetch_fulltext = true` laat de bot de artikelpagina lezen, maar alleen als robots.txt dat toestaat. Zet dit alleen aan als de gebruiksvoorwaarden van de bron dat toelaten. Standaard werkt de bot met titel en beschrijving uit de feed.
- `config/filters.toml`: trefwoorden per onderwerp, woorden waarmee berichten worden overgeslagen (liveblogs) en woorden die het label "Opinie" geven.
- `config/settings.toml`: sitenaam, User-Agent, model, dagbudget, prijzen, kwaliteitsgrenzen, contactadres voor correcties.

Na een wijziging herstart je de site (`sudo systemctl restart plenair-web`); de bots lezen de config bij elke run opnieuw.

## Hoe de kwaliteitspoort werkt

1. De brontekst gaat als data tussen `<bron>`-tags naar het model. De systeemprompt zegt dat instructies in de bron genegeerd moeten worden, en het antwoord moet een vast JSON-schema volgen.
2. `app/plagiarism.py` keurt af als samenvatting of kop 6 of meer opeenvolgende woorden met de bron deelt, als de samenvatting langer is dan 70% van de bron, of als er verboden vulzinnen in staan.
3. Bij afkeuring één nieuwe poging. Lukt dat niet, dan toont de site alleen de eigen kop met een link naar de bron.
4. De brontekst wordt nergens opgeslagen: de database heeft er geen kolom voor.
5. Jinja2 escapet alle output; de Content-Security-Policy staat geen scripts toe.

## Kosten bijhouden

- Dagbudget in `config/settings.toml` (`max_calls_per_day`, `max_tokens_per_day`). Is het budget op, dan blijven berichten in de wachtrij tot de volgende dag.
- Elke API-call wordt gelogd in de tabel `api_usage`, gekoppeld aan een run in `runs`.
- Overzicht per dag:

```bash
python -m app.admin kosten --dagen 14
```

- Vul `price_input_per_mtok` en `price_output_per_mtok` in met de actuele prijzen van https://www.anthropic.com/pricing om bedragen in dollars te zien. Staan ze op 0, dan zie je alleen tokens.

## Correcties

```bash
python -m app.admin correctie --artikel 12 --tekst "De naam van de minister stond verkeerd." --kop "Nieuwe kop"
python -m app.admin correctie --artikel 12 --tekst "Bericht ingetrokken." --verberg
python -m app.admin correctie --motie <zaak-id> --tekst "Datum van de stemming gecorrigeerd."
python -m app.admin afgekeurd     # berichten die de kwaliteitspoort niet haalden
```

Elke correctie verschijnt met datum op `/correcties`.

## Midterms-uitslagen

De uitslagenpagina leest `data/midterms_results.toml`. Er zit geen betaalde datafeed in. Vul cijfers alleen in nadat je ze bij een openbare bron hebt gecontroleerd; elke regel moet een bron, bron-URL en tijdstip hebben, anders toont de site hem niet.

## Deployen op een kleine VPS (Ubuntu/Debian)

```bash
sudo adduser --system --group --home /opt/plenair plenair
sudo git clone <jouw-repo> /opt/plenair && sudo chown -R plenair:plenair /opt/plenair
cd /opt/plenair
sudo -u plenair python3 -m venv .venv
sudo -u plenair .venv/bin/pip install -r requirements.txt
sudo -u plenair cp .env.example .env && sudo -u plenair nano .env
sudo chmod 600 .env

sudo cp deploy/*.service deploy/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now plenair-web plenair-newsbot.timer plenair-kamerbot.timer

sudo cp deploy/nginx-plenair.conf /etc/nginx/sites-available/plenair
sudo ln -s /etc/nginx/sites-available/plenair /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d jouwdomein.nl
```

Logs bekijken:

```bash
journalctl -u plenair-newsbot -n 50
journalctl -u plenair-kamerbot -n 50
systemctl list-timers 'plenair-*'
```

Back-up: kopieer `data/site.db` dagelijks (bijvoorbeeld met `sqlite3 data/site.db ".backup backup.db"`).

## Mappen

```
app/            code (web.py, newsbot.py, kamerbot.py, summarizer.py, plagiarism.py, ...)
app/templates/  HTML-sjablonen
app/static/     CSS en favicon
config/         bronnen, filters, instellingen
data/           SQLite-database en midterms-uitslagen
deploy/         systemd- en nginx-bestanden
tests/          tests en testdata
```

## Fase 3: factcheck

Het schema heeft al een tabel `claims` (bewering, wie, verificatiestatus, oordeel, bewijs-URL's) en een kolom `factcheck_status` in `articles`. Fase 2-groepering van berichten kan de kolom `story_key` gebruiken.
