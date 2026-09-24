# Domain modules

Each directory under `modules` owns its application rules and public service interface. Modules may depend on `platform` and `shared`; they must not reach into another module's private persistence details.

Current boundaries include `organizations`, `identity`, `academics`, `audit`,
`students`, `enrollments`, `teaching-assignments`, `attendance`, `assessments`,
`term-grades`, `report-cards`, and `transcripts`. New domains are added beside them,
not inside the UI layer.
