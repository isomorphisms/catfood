# Cat Food help

Every Cat Food tool has a discoverable help topic.

`./catfood help` lists Grease plus every current `tools.tsv` entry. `./catfood help TOOL` first looks for a checked-in `docs/help/TOOL.md` page; if none exists, it generates a compact reference from the inventory with the repository, branch, submodule policy, and workbench checkout location.

That makes help total over the Cat Food inventory: adding a new `tools.tsv` row automatically adds a help topic. A richer checked-in page is appropriate when the tool exposes an API, protocol, important environment variables, target-specific behavior, or useful runnable examples.

A detailed page should record, where applicable:

- commands or API endpoints;
- arguments, methods, request and response shapes;
- authentication and configuration;
- small phone/Termux examples that can actually be copied and run;
- target-specific limitations and evidence boundaries;
- implementation files that are the source of truth.

Do not claim runtime availability merely because an implementation exists. If a listener, package, Android permission, device behavior, or other runtime condition still needs verification, say so.

Current detailed pages:

- `gopeed` — [Gopeed REST API](gopeed.md): local REST listener, Cat Food client aliases, task/config/extension endpoints, authentication, and Termux examples.

Examples:

```sh
./catfood help
./catfood help gopeed
./catfood help Idric
./catfood help ib
```
