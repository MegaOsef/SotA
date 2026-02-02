# Examples

## Not correct (for test purpose)

```json
{"player": "Landkinton", "dkpChange": 10, "type":"manual"}
[{"dkpChange": 10, "type":"manual"}]
[{"player": "Landkinton", "dkpChange": 0, "type":"manual"}]
[{"player": "Landkinton", "dkpChange": -10000, "type":"manual"}]
[{"player": "Noexists", "dkpChange": 10, "type":"manual"}]
```

## Correct
```json
[{"player": "Landkinton", "dkpChange": 10, "type":"manual"}]
```