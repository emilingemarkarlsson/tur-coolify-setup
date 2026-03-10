# Arkiv - Ändringslogg

## 2025-12-26 - Initial Arkivering

### Services flyttade till arkiv:
- **crawlab/** → `archive/services/crawlab/`
  - Anledning: Ej längre i aktivt bruk
  - Status: Inaktiv

- **appsmith/** → `archive/services/appsmith/`
  - Anledning: Ej längre i aktivt bruk
  - Status: Inaktiv

- **clickhouse/** → `archive/services/clickhouse/`
  - Anledning: Decommissioned pga disk space issues
  - Status: Decommissioned

- **grafana/** → `archive/services/grafana/`
  - Anledning: Ej längre i aktivt bruk
  - Status: Inaktiv

- **mage-ai/** → `archive/services/mage-ai/`
  - Anledning: Ej längre i aktivt bruk
  - Status: Inaktiv

### Scripts flyttade till arkiv:
- **post-reboot-recover.sh** → `archive/scripts/post-reboot-recover.sh`
  - Anledning: Ersatt av mer moderna recovery-scripts
  - Status: Deprecated

### Dokumentation flyttad till arkiv:
- **docs/deprecated/** → `archive/docs/deprecated/`
  - Innehåller: clickhouse-config-fix.md, clickhouse-coolify-updated.yml, console-commands.txt
  - Status: Deprecated

## Återställning

Om något behöver återställas från arkivet, se `archive/README.md` för instruktioner.

