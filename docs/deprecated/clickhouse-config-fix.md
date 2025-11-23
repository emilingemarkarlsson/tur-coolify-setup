# ClickHouse Configuration för Coolify

## Profiling problem och lösning

ClickHouse's profiling system skapade 57GB data på 2 veckor!

### Vad som behöver ändras:

1. **Avaktivera query profiler** (huvudorsaken)
2. **Konfigurera system.trace_log retention**
3. **Sätt TTL för profiling tabeller**

## Docker Compose uppdatering för ClickHouse

Lägg till environment variabler för att kontrollera profiling:

```yaml
environment:
  - CLICKHOUSE_USER=hockey_admin
  - CLICKHOUSE_PASSWORD=secure_clickhouse_hockey_2025
  - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
  # Avaktivera profiling
  - CLICKHOUSE_CONFIG_query_profiler_real_time_period_ns=0
  - CLICKHOUSE_CONFIG_query_profiler_cpu_time_period_ns=0
  - CLICKHOUSE_CONFIG_trace_log_enabled=0
```

## Eller skapa config fil

Alternativt, skapa en config fil som mountas:

```xml
<clickhouse>
    <profiles>
        <default>
            <query_profiler_real_time_period_ns>0</query_profiler_real_time_period_ns>
            <query_profiler_cpu_time_period_ns>0</query_profiler_cpu_time_period_ns>
        </default>
    </profiles>
    
    <trace_log>
        <level>none</level>
    </trace_log>
    
    <system_log>
        <query_log>
            <ttl>7 days</ttl>
        </query_log>
        <trace_log>
            <ttl>1 day</ttl>
        </trace_log>
    </system_log>
</clickhouse>
```