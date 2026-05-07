# Obelisk Contracts

## shift_start_times default seed

The default value for `shift_start_times` is `["08:00","11:00"]` (two entries). The design doc's `[08:00]` (single entry) is superseded by this contract. Existing installs with the old single-entry value are migrated via an idempotent UPDATE in `_seedDefaults`.
