# Domain modules

Each directory under `modules` owns its application rules and public service interface. Modules may depend on `platform` and `shared`; they must not reach into another module's private persistence details.

Current boundaries include `organizations`, `identity`, `academics`, `audit`,
`students`, `enrollments`, `teaching-assignments`, `attendance`, `assessments`,
`term-grades`, `report-cards`, `transcripts`, and `progression`. New domains are added
beside them, not inside the UI layer.

The `staff` module owns the v1.5 staff directory and employment-profile command
contracts plus its Supabase adapter. Identity invitation and membership lifecycle
remain owned by identity; the staff adapter consumes only allowlisted read and
eligible-member projections.
