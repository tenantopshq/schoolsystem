# Domain modules

Each directory under `modules` owns its application rules and public service interface. Modules may depend on `platform` and `shared`; they must not reach into another module's private persistence details.

Initial boundaries: `organizations`, `identity`, `academics`, `audit`, and `students`. Future domains are added beside them, not inside the UI layer.
