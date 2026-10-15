# Splunk ingestion

`footprint_finder.ps1` appends one JSON object per line to `splunk_exposures.json`. That is newline-delimited JSON, which Splunk parses natively.

## 1. Create an index

In Splunk Web: **Settings → Indexes → New Index**, name it `footprint`.

## 2. Configure the Universal Forwarder

Add this stanza to `inputs.conf` on the machine that runs the script (adjust the path):

```ini
[monitor://C:\Users\<you>\footprint_system\splunk_exposures.json]
index = footprint
sourcetype = _json
disabled = 0
```

If Splunk Enterprise is installed on the same machine, you can add the same file as a **Files & Directories** input in Splunk Web instead.

## 3. Example searches

These are starting points. Adjust the index name to match yours.

New exposures by source:

```spl
index=footprint event_type=new_footprint_exposure
| stats count by source
| sort - count
```

Exposures over time:

```spl
index=footprint event_type=new_footprint_exposure
| timechart span=1d count by source
```

Breaches only, with the breach name pulled out of the indicator:

```spl
index=footprint source=HaveIBeenPwned
| rex field=indicator "^hibp://breach/(?<email>[^/]+)/(?<breach>.+)$"
| stats count by breach
```

## 4. Alert idea

Save the first search with a trigger of **number of results > 0**, run on a daily schedule. Because the diff engine only emits *new* findings, any result is a change worth reviewing.

## Field reference

| Field | Meaning |
|---|---|
| `timestamp` | UTC time of the scan (ISO 8601) |
| `host` | Machine that ran the scan |
| `event_type` | Always `new_footprint_exposure` |
| `status` | Always `Found` |
| `source` | `Sherlock` or `HaveIBeenPwned` |
| `indicator` | Profile URL, or `hibp://breach/<email>/<breach>` |
| `action_required` | Suggested next step |

> **Privacy note:** the `indicator` field contains email addresses for breach hits. Keep the `footprint` index restricted to yourself.
