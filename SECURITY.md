# Security and responsible use

## Intended use

This tool is for assessing the exposure of **your own** digital identity, or an identity you have explicit written permission to assess (for example, a family member who has asked for your help).

It must not be used to locate, profile, monitor or harass another person.

## Data handling

- Target lists, baselines, raw scan output and event logs contain personal information. They are excluded by the allow-list `.gitignore` and must never be committed.
- Before every push, run `git status` and `git diff --cached --stat` and confirm only the script, docs and `*.example.txt` files are staged.
- The Have I Been Pwned API key is read from the `HIBP_API_Key` user environment variable. Never place it in a script, a commit, or an issue.
- If a key or personal data is committed by mistake, treat it as exposed: rotate the key at haveibeenpwned.com and purge the history with `git filter-repo` before pushing.

## Third-party terms

Respect the terms of service and rate limits of every service queried, including the HIBP API.

## Reporting a vulnerability

Open a private security advisory on this repository, or contact me via [bidarisagar.com](https://bidarisagar.com).
