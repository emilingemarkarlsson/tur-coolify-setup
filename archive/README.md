# 📦 Arkiv - Inaktiva Services & Resurser

Detta är en arkivkatalog för services och resurser som inte längre används i produktionen.

## Struktur

```
archive/
├── services/     # Inaktiva services (crawlab, appsmith, clickhouse)
├── scripts/      # Inaktiva scripts (om några)
└── docs/         # Deprecated dokumentation
```

## Inaktiva Services

### Grafana
- **Status:** Inaktiv
- **Anledning:** Ej längre i bruk
- **Återställning:** Flytta tillbaka till root om behövs

### Mage AI
- **Status:** Inaktiv
- **Anledning:** Ej längre i bruk
- **Återställning:** Flytta tillbaka till root om behövs

### Crawlab
- **Status:** Inaktiv
- **Anledning:** Ej längre i bruk
- **Återställning:** Flytta tillbaka till root om behövs

### Appsmith
- **Status:** Inaktiv
- **Anledning:** Ej längre i bruk
- **Återställning:** Flytta tillbaka till root om behövs

### ClickHouse
- **Status:** Decommissioned
- **Anledning:** Disk space issues (profiling data filled 57GB)
- **Notering:** Se README.md för alternativ (PostgreSQL + TimescaleDB, DuckDB, etc.)

## Deprecated Dokumentation

All deprecated dokumentation finns i `archive/docs/deprecated/`.

## Återställning

Om du behöver återställa något från arkivet:

```bash
# Återställ en service
mv archive/services/crawlab ./

# Återställ dokumentation
mv archive/docs/deprecated/* docs/deprecated/
```

## Varning

**⚠️ Innehållet i denna katalog är INTE aktivt och används INTE i produktionen.**

